-- Debug script to trace query captures
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_query_captures.lua" -c "qa"

local queries = require('dependencies.query')

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

-- Get the direct dependency query
local dep_query = queries.dep_query

print("Testing direct dependency query captures:")
print("=========================================\n")

for id, node in dep_query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = dep_query.captures[id]
  local text = vim.treesitter.get_node_text(node, bufnr)
  local start_row = node:range()

  print(string.format("Capture: @%s", capture_name))
  print(string.format("  Text: %s", text:gsub("\n", "\\n")))
  print(string.format("  Line: %d", start_row + 1))
  print(string.format("  Node type: %s", node:type()))
  print()
end

