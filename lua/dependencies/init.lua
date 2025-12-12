local M = {}

local parser = require('dependencies.parser')
local maven = require('dependencies.maven')
local virtual_text = require('dependencies.virtual_text')

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

local function print_dependencies_with_versions(dependencies_with_versions)
  print("=== Dependencias con últimas versiones ===")
  for _, dep_info in ipairs(dependencies_with_versions) do
    print(string.format("%d: %s -> latest: %s", dep_info.line, dep_info.dependency, dep_info.latest))
  end
  print(string.format("\nTotal: %d dependencias", #dependencies_with_versions))
  print("\nLista completa:")
  print(vim.inspect(dependencies_with_versions))
end

function M.extract_dependencies(bufnr)
  return parser.extract_dependencies(bufnr)
end

function M.list_dependencies()
  local deps = M.extract_dependencies(vim.api.nvim_get_current_buf())
  print_dependencies(deps)
  return deps
end

function M.list_dependencies_with_versions()
  local bufnr = vim.api.nvim_get_current_buf()
  local deps = M.extract_dependencies(bufnr)
  local scala_version = parser.get_scala_version(bufnr)

  if scala_version then
    print(string.format("Detectada versión de Scala: %s", scala_version))
  end

  print("Consultando Maven Central para obtener últimas versiones...")
  local deps_with_versions = maven.enrich_with_latest_versions(deps, scala_version)
  print_dependencies_with_versions(deps_with_versions)

  -- Limpiar y aplicar virtual text
  virtual_text.clear(bufnr)
  virtual_text.apply_virtual_text(bufnr, deps_with_versions)

  return deps_with_versions
end

function M.setup()
  vim.api.nvim_create_user_command("SbtDeps", M.list_dependencies, {})
  vim.api.nvim_create_user_command("SbtDepsLatest", M.list_dependencies_with_versions, {})

  -- Autocommand para detectar archivos build.sbt y listar dependencias automáticamente
  vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
    pattern = "build.sbt",
    callback = function()
      -- Pequeño delay para asegurar que el buffer esté completamente cargado
      vim.defer_fn(function()
        M.list_dependencies_with_versions()
      end, 100)
    end,
    desc = "Listar dependencias automáticamente al abrir build.sbt"
  })

  -- Autocommand para actualizar dependencias cuando se guarda el archivo
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "build.sbt",
    callback = function()
      M.list_dependencies_with_versions()
    end,
    desc = "Actualizar dependencias al guardar build.sbt"
  })

  -- Ocultar virtual text en modo inserción, mostrarlo en modo normal/visual
  vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = "build.sbt",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      virtual_text.clear(bufnr)
    end,
    desc = "Ocultar virtual text en modo inserción"
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "build.sbt",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      -- El virtual text volverá a aparecer al guardar el archivo
      -- No se hace ninguna consulta a Maven Central aquí
      virtual_text.clear(bufnr)
    end,
    desc = "Limpiar virtual text al salir del modo inserción"
  })
end

return M
