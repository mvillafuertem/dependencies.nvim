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

-- Hacer request a Maven Central API para obtener la última versión
local function fetch_latest_version(group_id, artifact_id)
  local url = string.format(
    "https://search.maven.org/solrsearch/select?q=g:%s+AND+a:%s&rows=1&wt=json",
    group_id,
    artifact_id
  )

  -- Usar vim.fn.system para hacer la request con curl
  local curl_cmd = string.format('curl -s "%s"', url)
  local response = vim.fn.system(curl_cmd)

  -- Parsear JSON response
  local success, json = pcall(vim.fn.json_decode, response)
  if not success then
    return nil, "Error parsing JSON response"
  end

  -- Extraer la última versión del response
  if json.response and json.response.docs and #json.response.docs > 0 then
    return json.response.docs[1].latestVersion or json.response.docs[1].v
  end

  return nil, "No version found"
end

-- Función principal que toma las dependencias y retorna con latest version
function M.enrich_with_latest_versions(dependencies)
  local result = {}

  for _, dep_info in ipairs(dependencies) do
    local parsed = parse_dependency(dep_info.dependency)
    local latest_version = nil

    if parsed then
      latest_version, _ = fetch_latest_version(parsed.group_id, parsed.artifact_id)
    end

    table.insert(result, {
      line = dep_info.line,
      dependency = dep_info.dependency,
      latest = latest_version or "unknown"
    })
  end

  return result
end

-- Función asíncrona para obtener versiones (para evitar bloquear el UI)
function M.enrich_with_latest_versions_async(dependencies, callback)
  vim.schedule(function()
    local result = M.enrich_with_latest_versions(dependencies)
    callback(result)
  end)
end

return M

