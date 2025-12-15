-- Virtual Text Module
-- Manages the display of virtual text (latest versions) in the buffer

local M = {}

local config = require('dependencies.config')

-- Namespace for virtual text extmarks
M.ns = vim.api.nvim_create_namespace('sbt_deps_versions')

--- Clears all virtual text from the buffer
--- @param bufnr number Buffer number
function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
end

--- Shows a "checking..." indicator at the specified line
--- @param bufnr number Buffer number
--- @param line number Line number (1-indexed)
function M.show_checking_indicator(bufnr, line)
  vim.api.nvim_buf_set_extmark(bufnr, M.ns, line - 1, 0, {
    virt_text = { { '  ← checking...', 'Comment' } },
    virt_text_pos = 'eol',
  })
end

--- Applies virtual text to show latest versions for dependencies
--- @param bufnr number Buffer number
--- @param deps_with_versions table Array of {line, dependency, current, latest}
--- @return number Number of extmarks created
function M.apply_virtual_text(bufnr, deps_with_versions)
  -- Limpiar extmarks anteriores para evitar duplicados
  M.clear(bufnr)

  local extmarks_created = 0

  for _, dep_info in ipairs(deps_with_versions) do
    -- Manejar tanto versión única (string) como múltiples versiones (tabla)
    local latest_display = nil
    local should_show = false

    if type(dep_info.latest) == "table" then
      -- Múltiples versiones: filtrar las que son diferentes a la actual
      if #dep_info.latest > 0 then
        local different_versions = {}
        for _, version in ipairs(dep_info.latest) do
          if version ~= dep_info.version then
            table.insert(different_versions, version)
          end
        end
        -- Mostrar solo si hay versiones diferentes
        if #different_versions > 0 then
          should_show = true
          latest_display = table.concat(different_versions, ", ")
        end
      end
    else
      -- Versión única (string): usar lógica original
      if dep_info.latest and dep_info.latest ~= "unknown" and dep_info.version ~= dep_info.latest then
        should_show = true
        latest_display = dep_info.latest
      end
    end

    -- Mostrar virtual text si corresponde
    if should_show and latest_display then
      local prefix = config.get().virtual_text_prefix
      vim.api.nvim_buf_set_extmark(bufnr, M.ns, dep_info.line - 1, 0, {
        virt_text = { { string.format('%s%s', prefix, latest_display), 'Comment' } },
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

