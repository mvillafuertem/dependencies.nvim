local M = {}

M.val_query = vim.treesitter.query.parse("scala", [[
  (val_definition
    pattern: (identifier) @val_name
    value: (string) @val_value)
]])

M.dep_query = vim.treesitter.query.parse("scala", [[
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

-- Query específica para libraryDependencies += (sin Seq)
-- Captura el patrón completo de libraryDependencies += "org" % "artifact" % "version"
M.single_dep_query = vim.treesitter.query.parse("scala", [[
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

M.map_query = vim.treesitter.query.parse("scala", [[
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

return M

