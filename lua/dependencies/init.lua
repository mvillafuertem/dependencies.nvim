local M = {}

local config = require('dependencies.config')
local parser = require('dependencies.parser')
local maven = require('dependencies.maven')
local virtual_text = require('dependencies.virtual_text')
local cache = require('dependencies.cache')

local function extract_dependency_strings(dependencies)
  local result = {}
  for _, dep_info in ipairs(dependencies) do
    -- Construct dependency string from structured format: group:artifact:version
    local dep_string = string.format("%s:%s:%s", dep_info.group, dep_info.artifact, dep_info.version)
    table.insert(result, dep_string)
  end
  return result
end

local function print_dependencies(dependencies)
  print("=== Dependencias encontradas ===")
  for _, dep_info in ipairs(dependencies) do
    -- Construct dependency string from structured format
    local dep_string = string.format("%s:%s:%s", dep_info.group, dep_info.artifact, dep_info.version)
    print(string.format("%d: %s", dep_info.line, dep_string))
  end
  print(string.format("\nTotal: %d dependencias", #dependencies))
  print("\nLista completa:")
  print(vim.inspect(extract_dependency_strings(dependencies)))
end

local function print_dependencies_with_versions(dependencies_with_versions)
  print("=== Dependencias con últimas versiones ===")
  for _, dep_info in ipairs(dependencies_with_versions) do
    -- Construct dependency string from structured format
    local dep_string = string.format("%s:%s:%s", dep_info.group, dep_info.artifact, dep_info.version)

    -- Manejar tanto versión única (string) como múltiples versiones (tabla)
    local latest_display
    if type(dep_info.latest) == "table" then
      -- Múltiples versiones: unir con comas
      latest_display = table.concat(dep_info.latest, ", ")
    else
      -- Versión única (string)
      latest_display = dep_info.latest
    end
    print(string.format("%d: %s -> latest: %s", dep_info.line, dep_string, latest_display))
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

function M.list_dependencies_with_versions(force)
  force = force or false
  local bufnr = vim.api.nvim_get_current_buf()
  local opts = config.get()

  -- Verificar si tenemos datos válidos en caché (si no es forzado)
  if not force and cache.is_valid(bufnr, opts.cache_ttl) then
    local cached_data = cache.get(bufnr)
    if cached_data then
      print("📦 Usando caché (válido por " .. opts.cache_ttl .. ")")
      -- print_dependencies_with_versions(cached_data)
      virtual_text.apply_virtual_text(bufnr, cached_data)
      return cached_data
    end
  end

  local deps = M.extract_dependencies(bufnr)
  local scala_version = parser.get_scala_version(bufnr)

  if scala_version then
    print(string.format("Detectada versión de Scala: %s", scala_version))
  end

  -- Mostrar indicador de progreso mientras se consulta
  if force then
    print(string.format("🔄 Forzando actualización para %d dependencias...", #deps))
  else
    print(string.format("Consultando Maven Central para %d dependencias...", #deps))
  end

  -- Limpiar virtual text previo y mostrar indicador de "checking..."
  virtual_text.clear(bufnr)
  for _, dep_info in ipairs(deps) do
    virtual_text.show_checking_indicator(bufnr, dep_info.line)
  end

  -- Usar versión asíncrona para evitar bloquear el UI
  maven.enrich_with_latest_versions_async(deps, scala_version, function(deps_with_versions)
    -- print_dependencies_with_versions(deps_with_versions)

    -- Guardar en caché
    cache.set(bufnr, deps_with_versions)

    -- Limpiar indicadores y aplicar virtual text con resultados
    virtual_text.clear(bufnr)
    virtual_text.apply_virtual_text(bufnr, deps_with_versions)
  end)
end

function M.setup(opts)
  -- Inicializar configuración con opciones del usuario
  config.setup(opts)
  local cfg = config.get()
  local patterns = config.get_patterns()

  -- Crear comandos de usuario
  vim.api.nvim_create_user_command("SbtDeps", M.list_dependencies, {})
  vim.api.nvim_create_user_command("SbtDepsLatest", function()
    M.list_dependencies_with_versions(false)
  end, {})

  -- Comando para forzar actualización (ignorar caché)
  vim.api.nvim_create_user_command("SbtDepsLatestForce", function()
    M.list_dependencies_with_versions(true)
  end, { desc = "Forzar actualización de dependencias (ignorar caché)" })

  -- Auto-ejecutar al abrir archivos (si está habilitado en config)
  if cfg.auto_check_on_open then
    vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
      pattern = patterns,
      callback = function()
        -- Pequeño delay para asegurar que el buffer esté completamente cargado
        vim.defer_fn(function()
          M.list_dependencies_with_versions(false) -- No forzar, usar caché si está disponible
        end, 100)
      end,
      desc = "Listar dependencias automáticamente al abrir archivos configurados"
    })
  end

  -- Autocommand para actualizar dependencias cuando se guarda el archivo
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = patterns,
    callback = function()
      M.list_dependencies_with_versions(false)
    end,
    desc = "Actualizar dependencias al guardar archivo"
  })

  -- Ocultar virtual text en modo inserción, mostrarlo en modo normal/visual
  vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = patterns,
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      virtual_text.clear(bufnr)
    end,
    desc = "Ocultar virtual text en modo inserción"
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = patterns,
    callback = function()
      -- Al salir del modo inserción, actualizar dependencias
      M.list_dependencies_with_versions(false)
    end,
    desc = "Actualizar dependencias al salir del modo inserción"
  })
end

return M
