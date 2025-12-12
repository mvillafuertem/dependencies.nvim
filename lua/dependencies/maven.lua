local M = {}

-- Parsear una dependencia en formato "org.example:artifact:version"
-- o "org.example %% artifact % version"
local function parse_dependency(dep_string)
  -- Remover comillas y espacios
  local cleaned = dep_string:gsub('"', ''):gsub("'", ""):gsub('%s+', '')

  -- Intentar parsear formato con ":"
  local parts = {}
  for part in cleaned:gmatch("[^:]+") do
    table.insert(parts, part)
  end

  -- Si no funcionó con ":", intentar con "%"
  if #parts < 2 then
    parts = {}
    for part in cleaned:gmatch("[^%%]+") do
      table.insert(parts, part)
    end
  end

  if #parts >= 2 then
    return {
      group_id = parts[1],
      artifact_id = parts[2],
      version = parts[3] or "unknown"
    }
  end

  return nil
end

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

-- Obtener la última versión desde maven-metadata.xml (fuente autoritativa)
local function fetch_from_metadata_xml(group_id, artifact_id, include_prerelease)
  -- Convertir group_id a ruta (org.example -> org/example)
  local group_path = group_id:gsub("%.", "/")

  -- URL del maven-metadata.xml
  local url = string.format(
    "https://repo1.maven.org/maven2/%s/%s/maven-metadata.xml",
    group_path,
    artifact_id
  )

  local curl_cmd = string.format('curl -s "%s"', url)
  local response = vim.fn.system(curl_cmd)

  -- Si include_prerelease es false (por defecto), buscar la última versión estable
  -- parseando todas las versiones disponibles
  if not include_prerelease then
    local versions = {}
    for version in response:gmatch("<version>([^<]+)</version>") do
      if not is_prerelease(version) then
        table.insert(versions, version)
      end
    end

    -- Retornar la última versión estable (la última en la lista)
    if #versions > 0 then
      return versions[#versions]
    end
  end

  -- Si include_prerelease es true o no hay versiones estables, usar <latest> o <release>
  local version = response:match("<latest>([^<]+)</latest>")

  -- Si no hay tag <latest>, intentar con <release>
  if not version then
    version = response:match("<release>([^<]+)</release>")
  end

  return version
end

-- Fallback: obtener versión desde Maven Central Search API (Solr)
local function fetch_from_solr_search(group_id, artifact_id)
  -- Usar core=gav para obtener versiones individuales ordenadas por timestamp
  local url = string.format(
    "https://search.maven.org/solrsearch/select?q=g:%s+AND+a:%s&core=gav&rows=1&wt=json",
    group_id,
    artifact_id
  )

  local curl_cmd = string.format('curl -s "%s"', url)
  local response = vim.fn.system(curl_cmd)

  -- Parsear JSON response
  local success, json = pcall(vim.fn.json_decode, response)
  if not success then
    return nil
  end

  -- Con core=gav, la versión está en el campo 'v' del primer doc
  if json.response and json.response.docs and #json.response.docs > 0 then
    return json.response.docs[1].v
  end

  return nil
end

-- Hacer request a Maven Central para obtener la última versión
local function fetch_latest_version(group_id, artifact_id, scala_version)
  -- Si tenemos scala_version, intentar primero con el sufijo
  if scala_version then
    local artifact_with_scala = artifact_id .. "_" .. scala_version

    -- Intentar maven-metadata.xml primero (fuente autoritativa, solo versiones estables)
    local version = fetch_from_metadata_xml(group_id, artifact_with_scala, false)
    if version then
      return version
    end

    -- Fallback a Solr search
    version = fetch_from_solr_search(group_id, artifact_with_scala)
    if version then
      return version
    end
  end

  -- Si no funcionó con scala_version o no la tenemos, intentar sin sufijo
  -- Intentar maven-metadata.xml primero (fuente autoritativa, solo versiones estables)
  local version = fetch_from_metadata_xml(group_id, artifact_id, false)
  if version then
    return version
  end

  -- Fallback a Solr search
  version = fetch_from_solr_search(group_id, artifact_id)
  if version then
    return version
  end

  return nil, "No version found"
end

-- Función principal que toma las dependencias y retorna con latest version
function M.enrich_with_latest_versions(dependencies, scala_version)
  local result = {}

  for _, dep_info in ipairs(dependencies) do
    local parsed = parse_dependency(dep_info.dependency)
    local latest_version = nil
    local current_version = parsed and parsed.version or "unknown"

    if parsed then
      latest_version, _ = fetch_latest_version(parsed.group_id, parsed.artifact_id, scala_version)
    end

    table.insert(result, {
      line = dep_info.line,
      dependency = dep_info.dependency,
      current = current_version,
      latest = latest_version or "unknown"
    })
  end

  return result
end

-- Función asíncrona para obtener versiones (para evitar bloquear el UI)
function M.enrich_with_latest_versions_async(dependencies, scala_version, callback)
  vim.schedule(function()
    local result = M.enrich_with_latest_versions(dependencies, scala_version)
    callback(result)
  end)
end

return M

