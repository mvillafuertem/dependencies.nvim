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

  -- Autocommand para detectar archivos build.sbt y listar dependencias automáticamente
  vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
    pattern = "build.sbt",
    callback = function()
      -- Pequeño delay para asegurar que el buffer esté completamente cargado
      vim.defer_fn(function()
        M.list_dependencies()
      end, 100)
    end,
    desc = "Listar dependencias automáticamente al abrir build.sbt"
  })
end

return M
