-- Test the exact query from query.lua
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_actual_query.lua" -c "qa"

-- Create a simple test buffer
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

local content = [[
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1"
)
]]

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, '\n'))

-- Get the tree
local parser = vim.treesitter.get_parser(bufnr, "scala")
local root = parser:parse()[1]:root()

-- Exact query from query.lua
local exact_query = vim.treesitter.query.parse("scala", [[
  ; Patrón básico: "org" % "artifact" % "version"
  (infix_expression
    left: (infix_expression
      left: (string) @org
      operator: (operator_identifier) @dep_operator
      right: (string) @artifact)
    operator: (operator_identifier)
    right: [(string) (identifier)] @version) @dep_node

  ; Patrón cuando está dentro de otro infix_expression (con modificadores)
  (infix_expression
    left: (infix_expression
      left: (infix_expression
        left: (string) @org2
        operator: (operator_identifier) @dep_operator2
        right: (string) @artifact2)
      operator: (operator_identifier)
      right: [(string) (identifier)] @version2) @dep_node2
    operator: (operator_identifier))
]])

print("Testing exact query from query.lua:")
print("====================================\n")

local captures = {}
for id, node in exact_query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = exact_query.captures[id]
  local text = vim.treesitter.get_node_text(node, bufnr)
  text = text:gsub("\n", "\\n"):sub(1, 50)
  table.insert(captures, {name = capture_name, text = text})
end

-- Print all captures
for _, cap in ipairs(captures) do
  print(string.format("  @%s = %s", cap.name, cap.text))
end

print(string.format("\nTotal captures: %d", #captures))

-- Check if @dep_operator was captured
local found_operator = false
for _, cap in ipairs(captures) do
  if cap.name == "dep_operator" or cap.name == "dep_operator2" then
    found_operator = true
    print(string.format("\n✅ Found operator capture: @%s = %s", cap.name, cap.text))
  end
end

if not found_operator then
  print("\n❌ No operator capture found!")
end

