-- Test para debuggear la query con la dependencia problemática

local script_path = debug.getinfo(1).source:sub(2)
local plugin_dir = vim.fn.fnamemodify(script_path, ':h:h:h')
vim.opt.runtimepath:prepend(plugin_dir)

local test_content = [[
libraryDependencies ++= Seq(
  "com.github.jwt-scala" %% "jwt-circe" % "9.4.5" % "test,it" (exclude "org.netty" % "netty-all")
)
]]

local bufnr = vim.api.nvim_create_buf(false, true)
local lines = vim.split(test_content, "\n")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

vim.wait(100)

local parser = vim.treesitter.get_parser(bufnr, "scala")
local tree = parser:parse()[1]
local root = tree:root()

-- Probar la query actual
local dep_query = vim.treesitter.query.parse("scala", [[
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

print("=== Probando queries ===")
local count = 0
for id, node in dep_query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = dep_query.captures[id]
  local text = vim.treesitter.get_node_text(node, bufnr)
  count = count + 1
  print(string.format("%d. Capture '%s': %s", count, capture_name, text:gsub("\n", "\\n"):sub(1, 60)))
end

print(string.format("\nTotal captures: %d", count))

