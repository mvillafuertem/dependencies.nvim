local M = {}

-- Lazy loading de queries - solo se parsean cuando se necesitan
local _val_query
local _dep_query
local _single_dep_query
local _map_query
local _scala_version_query

function M.get_val_query()
  if not _val_query then
    local ok, query = pcall(vim.treesitter.query.parse, "scala", [[
      (val_definition
        pattern: (identifier) @val_name
        value: (string) @val_value)
    ]])
    if not ok then
      error("Failed to parse val_query. Make sure treesitter parser for Scala is installed: :TSInstall scala")
    end
    _val_query = query
  end
  return _val_query
end

function M.get_dep_query()
  if not _dep_query then
    local ok, query = pcall(vim.treesitter.query.parse, "scala", [[
      ; Patrón básico: "org" % "artifact" % "version"
      (infix_expression
        left: (infix_expression
          left: (string) @org
          operator: (operator_identifier)
          right: (string) @artifact)
        operator: (operator_identifier)
        right: [(string) (identifier)] @version) @dep_node

      ; Patrón cuando está dentro de otro infix_expression (con modificadores)
      (infix_expression
        left: (infix_expression
          left: (infix_expression
            left: (string) @org2
            operator: (operator_identifier)
            right: (string) @artifact2)
          operator: (operator_identifier)
          right: [(string) (identifier)] @version2) @dep_node2
        operator: (operator_identifier))
    ]])
    if not ok then
      error("Failed to parse dep_query. Make sure treesitter parser for Scala is installed: :TSInstall scala")
    end
    _dep_query = query
  end
  return _dep_query
end

function M.get_single_dep_query()
  if not _single_dep_query then
    local ok, query = pcall(vim.treesitter.query.parse, "scala", [[
      ; Patrón completo: outer infix con % version
      (infix_expression
        left: (infix_expression
          left: (infix_expression
            left: (identifier) @lib_dep_name
            operator: (operator_identifier) @plus_eq
            right: (string) @org_single)
          operator: (operator_identifier)
          right: (string) @artifact_single)
        operator: (operator_identifier)
        right: [(string) (identifier)] @version_single) @single_dep_node
    ]])
    if not ok then
      error("Failed to parse single_dep_query. Make sure treesitter parser for Scala is installed: :TSInstall scala")
    end
    _single_dep_query = query
  end
  return _single_dep_query
end

function M.get_map_query()
  if not _map_query then
    local ok, query = pcall(vim.treesitter.query.parse, "scala", [[
      ; Patrón simple: .map(_ % "version")
      (call_expression
        function: (field_expression
          value: (call_expression
            function: (identifier) @seq_name
            arguments: (arguments) @seq_args)
          field: (identifier) @map_field)
        arguments: (arguments
          (infix_expression
            left: (wildcard)
            operator: (operator_identifier)
            right: [(string) (identifier)] @version))) @map_node

      ; Patrón con scope: .map(_ % version % "test,it")
      ; Capturamos la versión del infix_expression interno
      (call_expression
        function: (field_expression
          value: (call_expression
            function: (identifier) @seq_name2
            arguments: (arguments) @seq_args2)
          field: (identifier) @map_field2)
        arguments: (arguments
          (infix_expression
            left: (infix_expression
              left: (wildcard)
              operator: (operator_identifier)
              right: [(string) (identifier)] @version2)
            operator: (operator_identifier)))) @map_node2
    ]])
    if not ok then
      error("Failed to parse map_query. Make sure treesitter parser for Scala is installed: :TSInstall scala")
    end
    _map_query = query
  end
  return _map_query
end

function M.get_scala_version_query()
  if not _scala_version_query then
    local ok, query = pcall(vim.treesitter.query.parse, "scala", [[
      (infix_expression
        left: (identifier) @scala_version_name
        operator: (operator_identifier)
        right: (string) @scala_version_value)
    ]])
    if not ok then
      error("Failed to parse scala_version_query. Make sure treesitter parser for Scala is installed: :TSInstall scala")
    end
    _scala_version_query = query
  end
  return _scala_version_query
end

-- Backward compatibility: mantener las propiedades antiguas
-- pero ahora cargan las queries de forma lazy
setmetatable(M, {
  __index = function(t, k)
    if k == "val_query" then
      return M.get_val_query()
    elseif k == "dep_query" then
      return M.get_dep_query()
    elseif k == "single_dep_query" then
      return M.get_single_dep_query()
    elseif k == "map_query" then
      return M.get_map_query()
    end
  end
})

return M

