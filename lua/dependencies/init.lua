local M = {}

local parser = require('dependencies.parser')

local function extract_dependency_strings(dependencies)
  local result = {}
  for _, dep_info in ipairs(dependencies) do
    table.insert(result, dep_info.dependency)
  end
  return result
end

local function print_dependencies(dependencies)
  print("=== Dependencias encontradas ===")
  for _, dep_info in ipairs(dependencies) do
    print(string.format("%d: %s", dep_info.line, dep_info.dependency))
  end
  print(string.format("\nTotal: %d dependencias", #dependencies))
  print("\nLista completa:")
  print(vim.inspect(extract_dependency_strings(dependencies)))
end

function M.extract_dependencies(bufnr)
  return parser.extract_dependencies(bufnr)
end

function M.list_dependencies()
  local deps = M.extract_dependencies(vim.api.nvim_get_current_buf())
  print_dependencies(deps)
  return deps
end

function M.setup()
  vim.api.nvim_create_user_command("SbtDeps", M.list_dependencies, {})
end

M.setup()

return M
