-- Debug what captures are actually being received from query.lua
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_query_debug.lua" -c "qa"

local queries = require('dependencies.query')

-- Create a test buffer
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

local content = [[
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1",
  "com.typesafe" % "config" % "1.4.2"
)
]]

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, '\n'))

-- Get the tree
local parser = vim.treesitter.get_parser(bufnr, "scala")
local root = parser:parse()[1]:root()

-- Get the actual query from query.lua
local dep_query = queries.get_dep_query()

print("Captures from query.lua's dep_query:")
print("=====================================\n")

local capture_count = {}

for id, node in dep_query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = dep_query.captures[id]
  local text = vim.treesitter.get_node_text(node, bufnr)

  -- Track capture counts
  capture_count[capture_name] = (capture_count[capture_name] or 0) + 1

  -- Show first 50 chars
  text = text:gsub("\n", "\\n"):sub(1, 50)
  print(string.format("  @%s = %s", capture_name, text))
end

print("\n\nCapture Summary:")
print("================")
for name, count in pairs(capture_count) do
  print(string.format("  @%s: %d times", name, count))
end

-- Check if operator captures were found
local has_operator = capture_count["dep_operator"] or capture_count["dep_operator2"]
if has_operator then
  print("\n✅ Operator captures FOUND in query.lua query!")
else
  print("\n❌ Operator captures NOT FOUND in query.lua query!")
  print("\nExpected captures: @dep_operator, @dep_operator2")
end

