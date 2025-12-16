-- Manual query test to verify operator capture
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_manual_query.lua" -c "qa"

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

-- Try simpler query first
local simple_query = vim.treesitter.query.parse("scala", [[
  (infix_expression
    left: (string) @org
    operator: (operator_identifier) @op
    right: (string) @artifact)
]])

print("Testing simple query (org %% artifact):")
print("========================================\n")

for id, node in simple_query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = simple_query.captures[id]
  local text = vim.treesitter.get_node_text(node, bufnr)
  print(string.format("  @%s = %s", capture_name, text))
end

print("\n\nNow testing full nested query:")
print("================================\n")

local nested_query = vim.treesitter.query.parse("scala", [[
  (infix_expression
    left: (infix_expression
      left: (string) @org
      operator: (operator_identifier) @dep_operator
      right: (string) @artifact)
    operator: (operator_identifier) @version_operator
    right: [(string) (identifier)] @version) @dep_node
]])

for id, node in nested_query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = nested_query.captures[id]
  local text = vim.treesitter.get_node_text(node, bufnr)
  text = text:gsub("\n", "\\n"):sub(1, 50)
  print(string.format("  @%s = %s", capture_name, text))
end

