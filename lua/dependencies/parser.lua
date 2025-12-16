local M = {}

local queries = require('dependencies.query')

-- Lazy loading de queries - accederlas solo cuando se necesiten
local function get_val_query()
  return queries.val_query
end

local function get_dep_query()
  return queries.dep_query
end

local function get_map_query()
  return queries.map_query
end

local function get_single_dep_query()
  return queries.single_dep_query
end

local function get_scala_version_query()
  return queries.get_scala_version_query()
end

local function get_node_text_without_quotes(node, bufnr)
  return vim.treesitter.get_node_text(node, bufnr):gsub('["\']', '')
end

local function detect_dep_type(operator_text)
  if operator_text == "%%" then
    return "scala"
  elseif operator_text == "%" then
    return "java"
  end
  return "unknown"
end

local function is_val_name_capture(capture_name)
  return capture_name == "val_name"
end

local function is_val_value_capture(capture_name)
  return capture_name == "val_value"
end

local function store_val_if_complete(current_val, val_values)
  if current_val.name and current_val.value then
    val_values[current_val.name] = current_val.value
    return {}
  end
  return current_val
end

local function find_vals(root, bufnr)
  local val_values = {}
  local current_val = {}
  local val_query = get_val_query()

  for id, node in val_query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = val_query.captures[id]

    if is_val_name_capture(capture_name) then
      current_val.name = vim.treesitter.get_node_text(node, bufnr)
    elseif is_val_value_capture(capture_name) then
      current_val.value = get_node_text_without_quotes(node, bufnr)
      current_val = store_val_if_complete(current_val, val_values)
    end
  end

  return val_values
end

local function is_dep_node_capture(capture_name)
  return capture_name == "dep_node" or capture_name == "dep_node2"
end

local function is_org_capture(capture_name)
  return capture_name == "org" or capture_name == "org2"
end

local function is_artifact_capture(capture_name)
  return capture_name == "artifact" or capture_name == "artifact2"
end

local function is_version_capture(capture_name)
  return capture_name == "version" or capture_name == "version2"
end

local function has_complete_dependency(match_data)
  return match_data.org and match_data.artifact and match_data.version_text
end

local function resolve_version(version_text, val_values)
  return val_values[version_text] or version_text
end

local function create_dependency_key(org, artifact, version)
  return org .. ":" .. artifact .. ":" .. version
end

local function add_dependency_if_new(org, artifact, version, line, dep_type, dependencies, seen)
  local key = create_dependency_key(org, artifact, version)
  if not seen[key] then
    seen[key] = true
    table.insert(dependencies, {
      group = org,
      artifact = artifact,
      version = version,
      line = line,
      type = dep_type or "unknown"
    })
  end
end

local function save_current_match(current_match, last_line, val_values, dependencies, seen)
  if last_line == -1 then return end
  if not has_complete_dependency(current_match) then return end

  local version = resolve_version(current_match.version_text, val_values)
  local dep_type = detect_dep_type(current_match.operator or "")
  add_dependency_if_new(current_match.org, current_match.artifact, version, last_line, dep_type, dependencies, seen)
end

local function should_save_previous_match(last_line, current_line, match_data)
  return last_line ~= -1 and last_line ~= current_line and has_complete_dependency(match_data)
end

local function process_dep_node(node, current_match, last_line, val_values, dependencies, seen)
  local line_num = node:range() + 1

  if should_save_previous_match(last_line, line_num, current_match) then
    save_current_match(current_match, last_line, val_values, dependencies, seen)
  end

  return {}, line_num
end

local function collect_direct_dependencies(root, bufnr, val_values, dependencies, seen)
  local current_match = {}
  local last_dep_node_line = -1
  local dep_query = get_dep_query()

  for id, node in dep_query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = dep_query.captures[id]

    if is_dep_node_capture(capture_name) then
      current_match, last_dep_node_line = process_dep_node(
        node, current_match, last_dep_node_line, val_values, dependencies, seen
      )
    elseif is_org_capture(capture_name) then
      current_match.org = get_node_text_without_quotes(node, bufnr)
    elseif is_artifact_capture(capture_name) then
      current_match.artifact = get_node_text_without_quotes(node, bufnr)
    elseif is_version_capture(capture_name) then
      current_match.version_text = get_node_text_without_quotes(node, bufnr)
    elseif capture_name == "dep_operator" or capture_name == "dep_operator2" then
      current_match.operator = vim.treesitter.get_node_text(node, bufnr)
    end
  end

  save_current_match(current_match, last_dep_node_line, val_values, dependencies, seen)
end

local function is_string_node(node)
  return node and node:type() == "string"
end

local function is_infix_expression(node)
  return node and node:type() == "infix_expression"
end

local function extract_org_and_artifact(arg, bufnr)
  local org_node = arg:child(0)
  local operator_node = arg:child(1)
  local artifact_node = arg:child(2)

  if not (is_string_node(org_node) and is_string_node(artifact_node)) then
    return nil, nil, nil
  end

  local operator_text = operator_node and vim.treesitter.get_node_text(operator_node, bufnr) or ""
  return get_node_text_without_quotes(org_node, bufnr),
         get_node_text_without_quotes(artifact_node, bufnr),
         operator_text
end

local function process_seq_arg(arg, bufnr, version, dependencies, seen)
  if not is_infix_expression(arg) then return end

  local org, artifact, operator_text = extract_org_and_artifact(arg, bufnr)
  if not org or not artifact then return end

  local line_num = arg:range() + 1
  local dep_type = detect_dep_type(operator_text or "")
  add_dependency_if_new(org, artifact, version, line_num, dep_type, dependencies, seen)
end

local function process_seq_children(seq_args, bufnr, version, dependencies, seen)
  for i = 0, seq_args:child_count() - 1 do
    process_seq_arg(seq_args:child(i), bufnr, version, dependencies, seen)
  end
end

local function has_complete_map_data(map_data)
  return map_data.seq_args and map_data.version_text
end

local function process_map_dependencies(map_data, bufnr, val_values, dependencies, seen)
  if not has_complete_map_data(map_data) then return end

  local version = resolve_version(map_data.version_text, val_values)
  process_seq_children(map_data.seq_args, bufnr, version, dependencies, seen)
end

local function is_map_field(field_text)
  return field_text == "map"
end

local function collect_mapped_dependencies(root, bufnr, val_values, dependencies, seen)
  local map_data = {}
  local map_query = get_map_query()

  for id, node in map_query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = map_query.captures[id]

    if capture_name == "map_field" or capture_name == "map_field2" then
      if not is_map_field(vim.treesitter.get_node_text(node, bufnr)) then
        map_data = {}
      end
    elseif capture_name == "seq_args" or capture_name == "seq_args2" then
      map_data.seq_args = node
    elseif capture_name == "version" or capture_name == "version2" then
      map_data.version_text = get_node_text_without_quotes(node, bufnr)
      process_map_dependencies(map_data, bufnr, val_values, dependencies, seen)
      map_data = {}
    end
  end
end

local function is_library_dependencies(identifier_text)
  return identifier_text == "libraryDependencies"
end

local function is_plus_equals_operator(operator_text)
  return operator_text == "+="
end

local function extract_dependency_from_node(node, bufnr)
  if node:type() ~= "infix_expression" then
    return nil
  end

  -- Debe ser: (infix_expression left: (infix_expression ...) operator: % right: version)
  local left_node = node:child(0)
  local version_node = node:child(2)

  if not left_node or not version_node then
    return nil
  end

  -- left_node debe ser: (infix_expression left: org operator: % right: artifact)
  if left_node:type() ~= "infix_expression" then
    return nil
  end

  local org_node = left_node:child(0)
  local artifact_node = left_node:child(2)

  if not org_node or not artifact_node then
    return nil
  end

  -- Verificar que org y artifact sean strings
  if org_node:type() ~= "string" or artifact_node:type() ~= "string" then
    return nil
  end

  -- version puede ser string o identifier (variable)
  if version_node:type() ~= "string" and version_node:type() ~= "identifier" then
    return nil
  end

  return {
    org = get_node_text_without_quotes(org_node, bufnr),
    artifact = get_node_text_without_quotes(artifact_node, bufnr),
    version_text = get_node_text_without_quotes(version_node, bufnr)
  }
end

local function collect_single_dependencies(root, bufnr, val_values, dependencies, seen)
  local current_match = {}
  local single_dep_query = get_single_dep_query()

  for id, node in single_dep_query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = single_dep_query.captures[id]

    if capture_name == "single_dep_node" then
      current_match.dep_node = node
    elseif capture_name == "lib_dep_name" then
      local identifier_text = vim.treesitter.get_node_text(node, bufnr)
      if is_library_dependencies(identifier_text) then
        current_match.lib_dep_name = true
      else
        current_match.lib_dep_name = false
      end
    elseif capture_name == "plus_eq" then
      local operator_text = vim.treesitter.get_node_text(node, bufnr)
      if is_plus_equals_operator(operator_text) then
        current_match.plus_eq = true
      else
        current_match.plus_eq = false
      end
    elseif capture_name == "dep_operator_single" then
      current_match.operator = vim.treesitter.get_node_text(node, bufnr)
    elseif capture_name == "org_single" then
      current_match.org = get_node_text_without_quotes(node, bufnr)
    elseif capture_name == "artifact_single" then
      current_match.artifact = get_node_text_without_quotes(node, bufnr)
    elseif capture_name == "version_single" then
      current_match.version_text = get_node_text_without_quotes(node, bufnr)

      if current_match.lib_dep_name and current_match.plus_eq and
         current_match.org and current_match.artifact and current_match.version_text and current_match.dep_node then
        local version = resolve_version(current_match.version_text, val_values)
        local line_num = current_match.dep_node:range() + 1
        local dep_type = detect_dep_type(current_match.operator or "")
        add_dependency_if_new(current_match.org, current_match.artifact, version, line_num, dep_type, dependencies, seen)
      end
      current_match = {}
    end
  end
end

local function find_dependencies(root, bufnr, val_values)
  local dependencies = {}
  local seen = {}

  collect_direct_dependencies(root, bufnr, val_values, dependencies, seen)
  collect_mapped_dependencies(root, bufnr, val_values, dependencies, seen)
  collect_single_dependencies(root, bufnr, val_values, dependencies, seen)

  return dependencies
end

local function parse_tree(bufnr)
  local parser = vim.treesitter.get_parser(bufnr, "scala")
  return parser:parse()[1]:root()
end

-- Extrae la versión de Scala del archivo (ej: "2.13.10" -> "2.13")
local function extract_scala_binary_version(scala_version)
  -- Extraer x.y de x.y.z
  local major, minor = scala_version:match("^(%d+)%.(%d+)")
  if major and minor then
    return major .. "." .. minor
  end
  return nil
end

-- Busca scalaVersion en el build.sbt y devuelve la versión completa y la línea
local function find_scala_full_version(root, bufnr)
  local scala_version_query = get_scala_version_query()
  local current_match = {}
  local line_num = nil

  for id, node in scala_version_query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = scala_version_query.captures[id]

    if capture_name == "scala_version_name" then
      current_match.name = vim.treesitter.get_node_text(node, bufnr)
      line_num = node:range() + 1
    elseif capture_name == "scala_version_value" then
      current_match.value = get_node_text_without_quotes(node, bufnr)

      -- Cuando tenemos ambos, verificar y retornar
      if current_match.name == "scalaVersion" and current_match.value and line_num then
        return current_match.value, line_num
      end

      -- Resetear para el siguiente match
      current_match = {}
      line_num = nil
    end
  end

  return nil, nil
end

-- Busca scalaVersion en el build.sbt y devuelve la versión binaria (ej: "2.13")
local function find_scala_version(root, bufnr)
  local full_version, _ = find_scala_full_version(root, bufnr)
  if full_version then
    return extract_scala_binary_version(full_version)
  end
  return nil
end

function M.extract_dependencies(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local root = parse_tree(bufnr)
  local val_values = find_vals(root, bufnr)

  local dependencies = find_dependencies(root, bufnr, val_values)

  -- Add Scala version as a dependency if found
  local scala_full_version = find_scala_version(root, bufnr)
  if scala_full_version then
    -- Determine if it's Scala 2 or Scala 3
    local major_version = scala_full_version:match("^(%d+)%.%d+")
    local group = "org.scala-lang"
    local artifact
    local dep_type = "java"  -- Scala compiler is a Java dependency

    if major_version == "3" then
      artifact = "scala3-library_3"
    else
      artifact = "scala-library"
    end

    -- Find the line where scalaVersion is defined
    local scala_version_query = get_scala_version_query()
    local scala_line = nil
    for id, node in scala_version_query:iter_captures(root, bufnr, 0, -1) do
      local capture_name = scala_version_query.captures[id]
      if capture_name == "scala_version_name" then
        local row = node:range()
        scala_line = row + 1  -- Convert to 1-based line number
        break
      end
    end

    -- Get the full version (not just binary version) for the dependency
    local full_version = nil
    for id, node in scala_version_query:iter_captures(root, bufnr, 0, -1) do
      local capture_name = scala_version_query.captures[id]
      if capture_name == "scala_version_value" then
        full_version = get_node_text_without_quotes(node, bufnr)
        break
      end
    end

    if scala_line and full_version then
      table.insert(dependencies, {
        group = group,
        artifact = artifact,
        version = full_version,
        line = scala_line,
        type = dep_type
      })
    end
  end

  return dependencies
end

function M.get_scala_version(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local root = parse_tree(bufnr)
  return find_scala_version(root, bufnr)
end

return M

