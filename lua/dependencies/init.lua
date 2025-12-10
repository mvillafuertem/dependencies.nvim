local M = {}

-- Importar queries desde archivo separado
local queries = require('dependencies.query')
local val_query = queries.val_query
local dep_query = queries.dep_query
local map_query = queries.map_query

-- Recolectar valores de variables usando query
local function find_vals(root, bufnr)
  local val_values = {}
  local current_val = {}

  for id, node in val_query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = val_query.captures[id]

    if capture_name == "val_name" then
      current_val.name = vim.treesitter.get_node_text(node, bufnr)
    elseif capture_name == "val_value" then
      current_val.value = vim.treesitter.get_node_text(node, bufnr):gsub('"', '')

      -- Cuando tenemos ambos, guardar
      if current_val.name and current_val.value then
        val_values[current_val.name] = current_val.value
        current_val = {}
      end
    end
  end

  return val_values
end

-- Buscar dependencias usando queries
local function find_dependencies(root, bufnr, val_values)
  local dependencies = {}
  local seen = {}

  -- Procesar capturas en orden del documento
  local current_match = {}
  local last_dep_node_line = -1

  -- Patrón 1: "org" % "artifact" % "version"
  for id, node in dep_query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = dep_query.captures[id]

    if capture_name == "dep_node" or capture_name == "dep_node2" then
      -- Cuando encontramos un dep_node, procesar el match anterior si existe
      local line_num = node:range() + 1

      if last_dep_node_line ~= -1 and last_dep_node_line ~= line_num and
         current_match.org and current_match.artifact and current_match.version_text then
        local version = val_values[current_match.version_text] or current_match.version_text
        local dep = current_match.org .. ":" .. current_match.artifact .. ":" .. version

        if not seen[dep] then
          seen[dep] = true
          table.insert(dependencies, {
            dependency = dep,
            line = last_dep_node_line
          })
        end
      end

      -- Iniciar nuevo match
      current_match = {}
      last_dep_node_line = line_num

    elseif capture_name == "org" or capture_name == "org2" then
      current_match.org = vim.treesitter.get_node_text(node, bufnr):gsub('"', '')
    elseif capture_name == "artifact" or capture_name == "artifact2" then
      current_match.artifact = vim.treesitter.get_node_text(node, bufnr):gsub('"', '')
    elseif capture_name == "version" or capture_name == "version2" then
      current_match.version_text = vim.treesitter.get_node_text(node, bufnr):gsub('"', '')
    end
  end

  -- Procesar el último match
  if last_dep_node_line ~= -1 and current_match.org and current_match.artifact and current_match.version_text then
    local version = val_values[current_match.version_text] or current_match.version_text
    local dep = current_match.org .. ":" .. current_match.artifact .. ":" .. version

    if not seen[dep] then
      seen[dep] = true
      table.insert(dependencies, {
        dependency = dep,
        line = last_dep_node_line
      })
    end
  end

  -- Patrón 2: .map(_ % "version")
  local map_deps = {}
  for id, node in map_query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = map_query.captures[id]

    if capture_name == "map_field" then
      local field = vim.treesitter.get_node_text(node, bufnr)
      if field ~= "map" then
        map_deps = {}
      end
    elseif capture_name == "seq_args" then
      map_deps.seq_args = node
    elseif capture_name == "version" then
      map_deps.version_text = vim.treesitter.get_node_text(node, bufnr):gsub('"', '')

      if map_deps.seq_args and map_deps.version_text then
        local version = val_values[map_deps.version_text] or map_deps.version_text

        for i = 0, map_deps.seq_args:child_count() - 1 do
          local arg = map_deps.seq_args:child(i)
          if arg and arg:type() == "infix_expression" then
            local org_node = arg:child(0)
            local artifact_node = arg:child(2)

            if org_node and org_node:type() == "string" and
               artifact_node and artifact_node:type() == "string" then
              local org = vim.treesitter.get_node_text(org_node, bufnr):gsub('"', '')
              local artifact = vim.treesitter.get_node_text(artifact_node, bufnr):gsub('"', '')

              local dep = org .. ":" .. artifact .. ":" .. version
              if not seen[dep] then
                seen[dep] = true
                local line_num = arg:range() + 1
                table.insert(dependencies, {
                  dependency = dep,
                  line = line_num
                })
              end
            end
          end
        end

        map_deps = {}
      end
    end
  end


  return dependencies
end

-- Función principal para extraer dependencias de un buffer
function M.extract_dependencies(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local parser = vim.treesitter.get_parser(bufnr, "scala")
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Primero recolectar valores de variables
  local val_values = find_vals(root, bufnr)

  -- Luego buscar dependencias
  local dependencies = find_dependencies(root, bufnr, val_values)

  return dependencies
end

-- Función para listar dependencias del buffer actual
function M.list_dependencies()
  local bufnr = vim.api.nvim_get_current_buf()
  local deps = M.extract_dependencies(bufnr)

  print("=== Dependencias encontradas ===")
  for i, dep_info in ipairs(deps) do
    print(string.format("%d: %s", dep_info.line, dep_info.dependency))
  end
  print(string.format("\nTotal: %d dependencias", #deps))
  print("\nLista completa:")
  local deps_list = {}
  for _, dep_info in ipairs(deps) do
    table.insert(deps_list, dep_info.dependency)
  end
  print(vim.inspect(deps_list))

  return deps
end

-- Comando para usar el plugin
vim.api.nvim_create_user_command("SbtDeps", function()
  M.list_dependencies()
end, {})

return M

