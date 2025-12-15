local M = {}

local config = require('dependencies.config')

-- Ya no necesitamos parse_dependency porque ahora recibimos
-- directamente {group, artifact, version, line} del parser

-- Verificar si una versión es pre-release (alpha, beta, milestone, RC)
local function is_prerelease(version)
  if not version then
    return false
  end
  -- Patrones comunes de pre-release
  local patterns = {
    "%-M%d+",      -- -M1, -M2 (milestone)
    "%-RC%d+",     -- -RC1, -RC2 (release candidate)
    "%-alpha",     -- -alpha, -alpha1
    "%-beta",      -- -beta, -beta1
    "%-SNAPSHOT",  -- -SNAPSHOT (development)
    "%.Alpha",     -- .Alpha, .Alpha1
    "%.Beta",      -- .Beta, .Beta1
    "%.CR",        -- .CR1 (candidate release)
  }

  for _, pattern in ipairs(patterns) do
    if version:match(pattern) then
      return true
    end
  end

  return false
end

-- Ejecutar curl de forma asíncrona usando vim.loop
local function curl_async(url, callback)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local output = ""
  local error_output = ""

  local handle
  handle = vim.loop.spawn('curl', {
    args = {'-s', '-m', '10', url},  -- -m 10: timeout de 10 segundos
    stdio = {nil, stdout, stderr}
  }, function(code, signal)
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

-- Procesar respuesta de maven-metadata.xml
local function process_metadata_xml(response, include_prerelease)
  -- Extraer todas las versiones del XML
  local all_versions = {}
  for version in response:gmatch("<version>([^<]+)</version>") do
    table.insert(all_versions, version)
  end

  if #all_versions == 0 then
    return nil
  end

  -- Si include_prerelease es false (por defecto), retornar solo la última versión estable
  if not include_prerelease then
    local stable_versions = {}
    for _, version in ipairs(all_versions) do
      if not is_prerelease(version) then
        table.insert(stable_versions, version)
      end
    end

    -- Retornar la última versión estable (la última en la lista)
    if #stable_versions > 0 then
      return stable_versions[#stable_versions]
    end
    return nil
  end

  -- Si include_prerelease es true, retornar las últimas 3 versiones
  -- garantizando que al menos una sea estable si existe
  local stable_versions = {}
  local prerelease_versions = {}

  for _, version in ipairs(all_versions) do
    if is_prerelease(version) then
      table.insert(prerelease_versions, version)
    else
      table.insert(stable_versions, version)
    end
  end

  -- Construir lista de últimas 3 versiones con al menos una estable
  local result_versions = {}

  -- Agregar la última versión estable si existe
  if #stable_versions > 0 then
    table.insert(result_versions, stable_versions[#stable_versions])
  end

  -- Agregar las últimas versiones pre-release hasta completar 3
  local prerelease_count = math.min(2, #prerelease_versions)
  for i = #prerelease_versions - prerelease_count + 1, #prerelease_versions do
    if i > 0 and #result_versions < 3 then
      table.insert(result_versions, prerelease_versions[i])
    end
  end

  -- Si no tenemos 3 versiones y hay más estables, agregar más estables
  if #result_versions < 3 then
    local stable_start = math.max(1, #stable_versions - (3 - #result_versions))
    for i = stable_start, #stable_versions - 1 do
      if i > 0 then
        table.insert(result_versions, 1, stable_versions[i])
      end
    end
  end

  return result_versions
end

-- Obtener versiones desde maven-metadata.xml (fuente autoritativa) - async
local function fetch_from_metadata_xml_async(group_id, artifact_id, include_prerelease, callback)
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

    local result = process_metadata_xml(response, include_prerelease)
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

-- Hacer request a Maven Central para obtener la última versión - async
local function fetch_latest_version_async(group_id, artifact_id, scala_version, callback)
  -- Obtener configuración de include_prerelease
  local include_prerelease = config.get().include_prerelease

  -- Si tenemos scala_version, intentar primero con el sufijo
  if scala_version then
    local artifact_with_scala = artifact_id .. "_" .. scala_version

    -- Intentar maven-metadata.xml primero (fuente autoritativa)
    fetch_from_metadata_xml_async(group_id, artifact_with_scala, include_prerelease, function(version)
      if version then
        callback(version)
        return
      end

      -- Fallback a Solr search
      fetch_from_solr_search_async(group_id, artifact_with_scala, function(version)
        if version then
          callback(version)
          return
        end

        -- Si falló con sufijo, intentar sin sufijo
        fetch_from_metadata_xml_async(group_id, artifact_id, include_prerelease, function(version)
          if version then
            callback(version)
            return
          end

          -- Último intento: Solr sin sufijo
          fetch_from_solr_search_async(group_id, artifact_id, function(version)
            callback(version or nil)
          end)
        end)
      end)
    end)
  else
    -- Si no tenemos scala_version, intentar sin sufijo
    fetch_from_metadata_xml_async(group_id, artifact_id, include_prerelease, function(version)
      if version then
        callback(version)
        return
      end

      -- Fallback a Solr search
      fetch_from_solr_search_async(group_id, artifact_id, function(version)
        callback(version or nil)
      end)
    end)
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
    -- dep_info ahora tiene: {group, artifact, version, line}
    local group_id = dep_info.group
    local artifact_id = dep_info.artifact
    local current_version = dep_info.version

    if group_id and artifact_id then
      fetch_latest_version_async(group_id, artifact_id, scala_version, function(latest_version)
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

return M

