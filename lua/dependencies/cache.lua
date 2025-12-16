-- Cache Module
-- Manages persistent file-based cache for dependency check results with TTL support
-- Cache location: ~/.cache/nvim/dependencies/<project-hash>.json

local M = {}

--- Get XDG cache directory following Neovim standards
--- @return string Cache directory path
local function get_cache_dir()
  local cache_home = vim.env.XDG_CACHE_HOME
  if not cache_home or cache_home == "" then
    cache_home = vim.fn.expand("~/.cache")
  end
  return cache_home .. "/nvim/dependencies"
end

--- Generate a unique hash for a file path
--- @param path string File path
--- @return string Hash string
local function hash_path(path)
  -- Simple hash: convert path to hex representation
  local hash = 0
  for i = 1, #path do
    hash = (hash * 31 + string.byte(path, i)) % 0x7FFFFFFF
  end
  return string.format("%08x", hash)
end

--- Get the cache file path for a buffer
--- @param bufnr number Buffer number
--- @return string|nil Cache file path or nil if buffer has no name
local function get_cache_file_path(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == "" then
    return nil
  end

  -- Get project root (directory containing the buffer)
  local project_root = vim.fn.fnamemodify(bufname, ":h")
  local hash = hash_path(project_root)
  local cache_dir = get_cache_dir()

  return cache_dir .. "/" .. hash .. ".json"
end

--- Ensure cache directory exists
--- @return boolean Success
local function ensure_cache_dir()
  local cache_dir = get_cache_dir()
  local stat = vim.loop.fs_stat(cache_dir)

  if not stat then
    -- Create directory recursively
    local success = vim.fn.mkdir(cache_dir, "p")
    return success == 1
  end

  return true
end

--- Read cache data from file
--- @param filepath string Cache file path
--- @return table|nil Cache entry or nil if not found/invalid
local function read_cache_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  if not content or content == "" then
    return nil
  end

  -- Parse JSON
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    vim.notify(
      "dependencies.nvim: Failed to parse cache file: " .. filepath,
      vim.log.levels.WARN
    )
    return nil
  end

  return decoded
end

--- Write cache data to file
--- @param filepath string Cache file path
--- @param entry table Cache entry with data and timestamp
--- @return boolean Success
local function write_cache_file(filepath, entry)
  if not ensure_cache_dir() then
    vim.notify(
      "dependencies.nvim: Failed to create cache directory",
      vim.log.levels.ERROR
    )
    return false
  end

  local ok, encoded = pcall(vim.json.encode, entry)
  if not ok then
    vim.notify(
      "dependencies.nvim: Failed to encode cache data",
      vim.log.levels.ERROR
    )
    return false
  end

  local file = io.open(filepath, "w")
  if not file then
    vim.notify(
      "dependencies.nvim: Failed to write cache file: " .. filepath,
      vim.log.levels.ERROR
    )
    return false
  end

  file:write(encoded)
  file:close()

  return true
end

--- Parses TTL string to seconds
--- Supported formats: "30m", "6h", "1d", "1w", "1M"
--- @param ttl_str string Time-to-live string
--- @return number Seconds
function M.parse_ttl(ttl_str)
  if type(ttl_str) ~= "string" then
    return 86400 -- Default: 1 day
  end

  local value, unit = ttl_str:match("^(%d+)([mhdwM])$")
  if not value or not unit then
    vim.notify(
      string.format("dependencies.nvim: Invalid cache_ttl format '%s', using 1d", ttl_str),
      vim.log.levels.WARN
    )
    return 86400
  end

  value = tonumber(value)

  -- Convert to seconds
  if unit == "m" then
    return value * 60 -- minutes
  elseif unit == "h" then
    return value * 3600 -- hours
  elseif unit == "d" then
    return value * 86400 -- days
  elseif unit == "w" then
    return value * 604800 -- weeks (7 days)
  elseif unit == "M" then
    return value * 2592000 -- months (30 days)
  else
    vim.notify(
      string.format("dependencies.nvim: Unknown time unit '%s', using 1d", unit),
      vim.log.levels.WARN
    )
    return 86400
  end
end

--- Checks if cached data is still valid (not expired and same include_prerelease setting)
--- @param bufnr number Buffer number
--- @param ttl_str string Time-to-live string (e.g., "1d", "6h")
--- @param include_prerelease boolean Current include_prerelease setting
--- @return boolean True if cache is valid, not expired, and matches include_prerelease setting
function M.is_valid(bufnr, ttl_str, include_prerelease)
  local filepath = get_cache_file_path(bufnr)
  if not filepath then
    return false
  end

  local entry = read_cache_file(filepath)
  if not entry or not entry.timestamp then
    return false
  end

  -- Verificar si el valor de include_prerelease cambió
  -- Si cambió, la cache no es válida (necesitamos refrescar desde Maven)
  if entry.include_prerelease ~= include_prerelease then
    return false
  end

  local ttl_seconds = M.parse_ttl(ttl_str)
  local elapsed = os.time() - entry.timestamp

  return elapsed < ttl_seconds
end

--- Retrieves cached data for the given buffer
--- @param bufnr number Buffer number
--- @return table|nil Cached data or nil if not found
function M.get(bufnr)
  local filepath = get_cache_file_path(bufnr)
  if not filepath then
    return nil
  end

  local entry = read_cache_file(filepath)
  if entry and entry.data then
    return entry.data
  end

  return nil
end

--- Stores data in cache for the given buffer
--- @param bufnr number Buffer number
--- @param data table Dependency data to cache
--- @param include_prerelease boolean Whether prerelease versions were included
--- @return boolean Success
function M.set(bufnr, data, include_prerelease)
  local filepath = get_cache_file_path(bufnr)
  if not filepath then
    return false
  end

  local entry = {
    data = data,
    timestamp = os.time(),
    buffer_name = vim.api.nvim_buf_get_name(bufnr),
    include_prerelease = include_prerelease
  }

  return write_cache_file(filepath, entry)
end

--- Clears cache for a specific buffer
--- @param bufnr number Buffer number
--- @return boolean Success
function M.clear(bufnr)
  local filepath = get_cache_file_path(bufnr)
  if not filepath then
    return false
  end

  -- Delete the cache file
  local ok = pcall(os.remove, filepath)
  return ok
end

--- Clears all cached data
--- @return boolean Success
function M.clear_all()
  local cache_dir = get_cache_dir()

  -- Use vim.fn.glob to find all .json files
  local cache_files = vim.fn.glob(cache_dir .. "/*.json", false, true)

  local success = true
  for _, filepath in ipairs(cache_files) do
    local ok = pcall(os.remove, filepath)
    if not ok then
      success = false
    end
  end

  return success
end

--- Get cache statistics (for debugging)
--- @return table Statistics with entry count and file paths
function M.get_stats()
  local cache_dir = get_cache_dir()
  local cache_files = vim.fn.glob(cache_dir .. "/*.json", false, true)

  return {
    entry_count = #cache_files,
    cache_dir = cache_dir,
    cache_files = cache_files
  }
end

return M
