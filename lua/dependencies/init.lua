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
  -- print_dependencies(deps)
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

      -- RE-PARSEAR para obtener números de línea actuales
      -- (las líneas pueden haber cambiado si el usuario editó el archivo)
      local current_deps = M.extract_dependencies(bufnr)

      -- DEBUG
      print("🔍 DEBUG: Re-parsed dependencies after potential edit:")
      for _, dep in ipairs(current_deps) do
        print(string.format("  Line %d: %s:%s:%s", dep.line, dep.group, dep.artifact, dep.version))
      end

      -- Merge: actualizar líneas pero mantener versiones de cache
      local merged_data = {}
      for _, current_dep in ipairs(current_deps) do
        local dep_key = string.format("%s:%s:%s", current_dep.group, current_dep.artifact, current_dep.version)

        -- Buscar en cache por group:artifact:version
        local found_in_cache = false
        for _, cached_dep in ipairs(cached_data) do
          local cached_key = string.format("%s:%s:%s", cached_dep.group, cached_dep.artifact, cached_dep.version)
          if dep_key == cached_key then
            -- Usar línea actual pero versión latest de cache
            local merged_entry = {
              group = current_dep.group,
              artifact = current_dep.artifact,
              version = current_dep.version,
              line = current_dep.line,  -- LÍNEA ACTUAL (actualizada)
              latest = cached_dep.latest  -- VERSIÓN DE CACHE
            }
            -- DEBUG
            -- print(string.format("🔍 DEBUG: Merged - Line %d (was %d): %s -> %s",
            --  merged_entry.line, cached_dep.line, dep_key, merged_entry.latest))
            table.insert(merged_data, merged_entry)
            found_in_cache = true
            break
          end
        end

        -- Si no está en cache, usar la versión actual como latest
        -- (esto ocurre si el usuario agregó una nueva dependencia)
        -- En el próximo refresh se consultará Maven para obtener la versión real
        if not found_in_cache then
          table.insert(merged_data, {
            group = current_dep.group,
            artifact = current_dep.artifact,
            version = current_dep.version,
            line = current_dep.line,
            latest = current_dep.version  -- Mostrar versión actual en lugar de "unknown"
          })
        end
      end

      -- DEBUG: Verificar merged_data antes de pasarlo a virtual_text
      -- print("🔍 DEBUG: Final merged_data to be passed to apply_virtual_text:")
      -- for i, dep in ipairs(merged_data) do
      --   print(string.format("  %d) Line %d: %s:%s:%s -> %s",
      --     i, dep.line, dep.group, dep.artifact, dep.version, dep.latest))
      -- end

      -- Solo aplicar virtual text si NO estamos en modo inserción
      local mode = vim.api.nvim_get_mode().mode
      local is_insert_mode = mode:match('^i') or mode:match('^R')
      if not is_insert_mode then
        virtual_text.apply_virtual_text(bufnr, merged_data)
      end

      return merged_data
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

  -- Mostrar indicador de "checking..." (clear se hace automáticamente en apply_virtual_text)
  virtual_text.clear(bufnr)
  for _, dep_info in ipairs(deps) do
    virtual_text.show_checking_indicator(bufnr, dep_info.line)
  end

  -- Usar versión asíncrona para evitar bloquear el UI
  maven.enrich_with_latest_versions_async(deps, scala_version, function(deps_with_versions)
    -- print_dependencies_with_versions(deps_with_versions)

    -- Guardar en caché
    cache.set(bufnr, deps_with_versions)

    -- Solo aplicar virtual text si NO estamos en modo inserción
    local mode = vim.api.nvim_get_mode().mode
    local is_insert_mode = mode:match('^i') or mode:match('^R')
    if not is_insert_mode then
      virtual_text.apply_virtual_text(bufnr, deps_with_versions)
    end
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
