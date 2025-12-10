local M = {}

-- Query para encontrar definiciones de variables (val gatlingVersion = "3.8.4")
M.val_query = vim.treesitter.query.parse("scala", [[
  (val_definition
    pattern: (identifier) @val_name
    value: (string) @val_value)
]])

-- Query para encontrar dependencias patrón: "org" % "artifact" % "version"
-- Captura tanto % como %% (el operador se ignora, solo importa la estructura)
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
  ; Capturamos el nodo interno que tiene la estructura básica
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

-- Query para encontrar dependencias con .map(_ % "version")
M.map_query = vim.treesitter.query.parse("scala", [[
  (call_expression
    function: (field_expression
      value: (call_expression
        function: (identifier) @seq_name
        arguments: (arguments) @seq_args)
      field: (identifier) @map_field)
    arguments: (arguments
      (infix_expression
        right: [(string) (identifier)] @version))) @map_node
]])

return M

