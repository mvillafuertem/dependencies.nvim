local M = {}

local config = require('dependencies.config')

local PRERELEASE_PATTERNS = {
  "%-M%d+", "%-RC%d+", "%-alpha", "%-beta", "%-SNAPSHOT",
  "%.Alpha", "%.Beta", "%.CR"
}

local PRERELEASE_ORDER = {
  [""] = 5, ["RC"] = 4, ["M"] = 3, ["beta"] = 2,
  ["alpha"] = 1, ["SNAPSHOT"] = 0, ["other"] = 0
}

local function is_prerelease(version)
  if not version then return false end
  for _, pattern in ipairs(PRERELEASE_PATTERNS) do
    if version:match(pattern) then return true end
  end
  return false
end

local function extract_numbers(version_string)
  local parts = {}
  for num in version_string:gmatch("%d+") do
    table.insert(parts, tonumber(num))
  end
  return parts[1] or 0, parts[2] or 0, parts[3] or 0, parts[4] or 0
end

local function extract_prerelease(suffix)
  local patterns = {
    { type = "M", pattern = "%-M(%d+)" },
    { type = "RC", pattern = "%-RC(%d+)" },
    { type = "alpha", pattern = "%-alpha(%d*)" },
    { type = "beta", pattern = "%-beta(%d*)" },
    { type = "SNAPSHOT", pattern = "%-SNAPSHOT" }
  }

  for _, p in ipairs(patterns) do
    if suffix:match(p.pattern) then
      local num = suffix:match(p.pattern)
      return p.type, tonumber(num) or 0
    end
  end

  return "other", 0
end

local function parse_version(version)
  if not version then return nil end

  local main_part, prerelease_part = version:match("^([%d%.]+)(.*)$")
  if not main_part then
    return {major = 0, minor = 0, patch = 0, build = 0, prerelease_type = "", prerelease_num = 0, original = version}
  end

  local major, minor, patch, build = extract_numbers(main_part)
  local prerelease_type, prerelease_num = "", 999999

  if prerelease_part and prerelease_part ~= "" then
    prerelease_type, prerelease_num = extract_prerelease(prerelease_part)
  end

  return {
    major = major, minor = minor, patch = patch, build = build,
    prerelease_type = prerelease_type, prerelease_num = prerelease_num,
    original = version
  }
end

local function compare_component(a, b)
  if a ~= b then return a < b and -1 or 1 end
  return nil
end

local function compare_versions(v1, v2)
  local p1, p2 = parse_version(v1), parse_version(v2)
  if not p1 or not p2 then return 0 end

  -- Compare components directly (can't use ipairs with nil values)
  local result = compare_component(p1.major, p2.major)
  if result then return result end

  result = compare_component(p1.minor, p2.minor)
  if result then return result end

  result = compare_component(p1.patch, p2.patch)
  if result then return result end

  result = compare_component(p1.build, p2.build)
  if result then return result end

  local type1_priority = PRERELEASE_ORDER[p1.prerelease_type] or 0
  local type2_priority = PRERELEASE_ORDER[p2.prerelease_type] or 0

  return compare_component(type1_priority, type2_priority)
    or compare_component(p1.prerelease_num, p2.prerelease_num)
    or 0
end

local function curl_async(url, callback)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local output = ""
  local error_output = ""

  local handle
  handle = vim.loop.spawn('curl', {
    args = {'-s', '-m', '10', url},
    stdio = {nil, stdout, stderr}
  }, function(code, _)
    stdout:close()
    stderr:close()
    handle:close()

    vim.schedule(function()
      if code == 0 then
        callback(output, nil)
      else
        callback(nil, string.format("curl failed with code %d: %s", code, error_output))
      end
    end)
  end)

  if not handle then
    callback(nil, "Failed to spawn curl process")
    return
  end

  stdout:read_start(function(err, data)
    if err then
      error_output = error_output .. (err or "")
    elseif data then
      output = output .. data
    end
  end)

  stderr:read_start(function(err, data)
    if err then
      error_output = error_output .. (err or "")
    elseif data then
      error_output = error_output .. data
    end
  end)
end

local function extract_versions_from_xml(xml)
  local versions = {}
  for v in xml:gmatch("<version>([^<]+)</version>") do
    table.insert(versions, v)
  end
  return versions
end

local function filter_newer(versions, current_version)
  local newer = {}
  for _, v in ipairs(versions) do
    if compare_versions(v, current_version) > 0 then
      table.insert(newer, v)
    end
  end
  return newer
end

local function sort_versions(versions)
  table.sort(versions, function(a, b) return compare_versions(a, b) < 0 end)
  return versions
end

local function partition_versions(versions)
  local stable, prerelease = {}, {}
  for _, v in ipairs(versions) do
    if is_prerelease(v) then
      table.insert(prerelease, v)
    else
      table.insert(stable, v)
    end
  end
  return stable, prerelease
end

local function take_last_n(list, n)
  local result = {}
  local start = math.max(1, #list - n + 1)
  for i = start, #list do
    table.insert(result, list[i])
  end
  return result
end

local function select_versions_to_return(stable, prerelease)
  if #stable > 0 then
    local selected = {stable[#stable]}
    local pr_selected = take_last_n(prerelease, 2)
    for _, pr in ipairs(pr_selected) do
      table.insert(selected, pr)
    end
    return sort_versions(selected)
  else
    return take_last_n(prerelease, 3)
  end
end

local function process_metadata_xml(response, current_version, include_prerelease)
  local all_versions = extract_versions_from_xml(response)
  if #all_versions == 0 then return nil end

  local better_versions = filter_newer(all_versions, current_version)
  if #better_versions == 0 then return current_version end

  sort_versions(better_versions)

  if not include_prerelease then
    local stable = {}
    for _, v in ipairs(better_versions) do
      if not is_prerelease(v) then
        table.insert(stable, v)
      end
    end
    return #stable > 0 and stable[#stable] or nil
  end

  local stable, prerelease = partition_versions(better_versions)
  return select_versions_to_return(stable, prerelease)
end

-- Obtener versiones desde maven-metadata.xml (fuente autoritativa) - async
local function fetch_from_metadata_xml_async(group_id, artifact_id, current_version, include_prerelease, callback)
  -- Convertir group_id a ruta (org.example -> org/example)
  local group_path = group_id:gsub("%.", "/")

  -- URL del maven-metadata.xml
  local url = string.format(
    "https://repo1.maven.org/maven2/%s/%s/maven-metadata.xml",
    group_path,
    artifact_id
  )

  curl_async(url, function(response, err)
    if err or not response then
      callback(nil)
      return
    end

    local result = process_metadata_xml(response, current_version, include_prerelease)
    callback(result)
  end)
end

-- Fallback: obtener versión desde Maven Central Search API (Solr) - async
local function fetch_from_solr_search_async(group_id, artifact_id, callback)
  -- Usar core=gav para obtener versiones individuales ordenadas por timestamp
  local url = string.format(
    "https://search.maven.org/solrsearch/select?q=g:%s+AND+a:%s&core=gav&rows=1&wt=json",
    group_id,
    artifact_id
  )

  curl_async(url, function(response, err)
    if err or not response then
      callback(nil)
      return
    end

    -- Parsear JSON response
    local success, json = pcall(vim.fn.json_decode, response)
    if not success then
      callback(nil)
      return
    end

    -- Con core=gav, la versión está en el campo 'v' del primer doc
    if json.response and json.response.docs and #json.response.docs > 0 then
      callback(json.response.docs[1].v)
    else
      callback(nil)
    end
  end)
end

local function try_metadata_then_solr(group_id, artifact_id, current_version, include_prerelease, callback)
  fetch_from_metadata_xml_async(group_id, artifact_id, current_version, include_prerelease, function(metadata_result)
    if metadata_result then
      callback(metadata_result)
    else
      fetch_from_solr_search_async(group_id, artifact_id, callback)
    end
  end)
end

local function fetch_latest_version_async(group_id, artifact_id, current_version, scala_version, dep_type, callback)
  local include_prerelease = config.get().include_prerelease

  -- Optimización: usar dep_type para evitar intentos innecesarios
  if dep_type == "java" then
    -- Dependencia Java (%) - solo intentar sin sufijo Scala
    try_metadata_then_solr(group_id, artifact_id, current_version, include_prerelease, callback)
  elseif dep_type == "scala" and scala_version then
    -- Dependencia Scala (%%) - solo intentar con sufijo Scala
    local artifact_with_scala = artifact_id .. "_" .. scala_version
    try_metadata_then_solr(group_id, artifact_with_scala, current_version, include_prerelease, callback)
  elseif scala_version then
    -- Tipo desconocido - mantener comportamiento anterior (fallback)
    local artifact_with_scala = artifact_id .. "_" .. scala_version

    try_metadata_then_solr(group_id, artifact_with_scala, current_version, include_prerelease, function(scala_result)
      if scala_result then
        callback(scala_result)
      else
        try_metadata_then_solr(group_id, artifact_id, current_version, include_prerelease, callback)
      end
    end)
  else
    try_metadata_then_solr(group_id, artifact_id, current_version, include_prerelease, callback)
  end
end

-- Función asíncrona para obtener versiones (para evitar bloquear el UI)
function M.enrich_with_latest_versions_async(dependencies, scala_version, callback)
  if #dependencies == 0 then
    callback({})
    return
  end

  local result = {}
  local completed = 0
  local total = #dependencies

  for _, dep_info in ipairs(dependencies) do
    -- dep_info ahora tiene: {group, artifact, version, line, type}
    local group_id = dep_info.group
    local artifact_id = dep_info.artifact
    local current_version = dep_info.version
    local dep_type = dep_info.type or "unknown"

    if group_id and artifact_id then
      fetch_latest_version_async(group_id, artifact_id, current_version, scala_version, dep_type, function(latest_version)
        -- Manejar tanto versiones únicas (string) como múltiples (tabla)
        local latest_value
        if type(latest_version) == "table" then
          latest_value = latest_version
        else
          latest_value = latest_version or "unknown"
        end

        table.insert(result, {
          group = group_id,
          artifact = artifact_id,
          version = current_version,
          line = dep_info.line,
          latest = latest_value
        })

        completed = completed + 1
        if completed == total then
          -- Ordenar resultados por número de línea antes de devolver
          table.sort(result, function(a, b) return a.line < b.line end)
          callback(result)
        end
      end)
    else
      -- Si no tenemos group o artifact, agregar con "unknown"
      table.insert(result, {
        group = group_id or "unknown",
        artifact = artifact_id or "unknown",
        version = current_version or "unknown",
        line = dep_info.line,
        latest = "unknown"
      })

      completed = completed + 1
      if completed == total then
        table.sort(result, function(a, b) return a.line < b.line end)
        callback(result)
      end
    end
  end
end

-- Export for testing purposes
M.parse_version = parse_version
M.compare_versions = compare_versions
M.process_metadata_xml = process_metadata_xml

return M

