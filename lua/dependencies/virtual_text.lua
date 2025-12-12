-- Virtual Text Module
-- Manages the display of virtual text (latest versions) in the buffer

local M = {}

-- Namespace for virtual text extmarks
M.ns = vim.api.nvim_create_namespace('sbt_deps_versions')

--- Clears all virtual text from the buffer
--- @param bufnr number Buffer number
function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
end

--- Applies virtual text to show latest versions for dependencies
--- @param bufnr number Buffer number
--- @param deps_with_versions table Array of {line, dependency, latest}
--- @return number Number of extmarks created
function M.apply_virtual_text(bufnr, deps_with_versions)
  local extmarks_created = 0

  for _, dep_info in ipairs(deps_with_versions) do
    if dep_info.latest and dep_info.latest ~= "unknown" then
      vim.api.nvim_buf_set_extmark(bufnr, M.ns, dep_info.line - 1, 0, {
        virt_text = { { string.format('  ← latest: %s', dep_info.latest), 'Comment' } },
        virt_text_pos = 'eol',
      })
      extmarks_created = extmarks_created + 1
    end
  end

  return extmarks_created
end

--- Gets all extmarks in the buffer for this namespace
--- @param bufnr number Buffer number
--- @param with_details boolean Whether to include details
--- @return table Array of extmarks
function M.get_extmarks(bufnr, with_details)
  return vim.api.nvim_buf_get_extmarks(bufnr, M.ns, 0, -1, { details = with_details or false })
end

return M

