-- Test if clearing the module cache fixes the issue
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_cache_clear.lua" -c "qa"

print("Testing with cache clear...")
print("============================\n")

-- Clear the cached queries module
package.loaded['dependencies.query'] = nil

-- Now load it fresh
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

-- Get the query
local dep_query = queries.get_dep_query()

print("Captures after cache clear:")
print("============================\n")

local capture_count = {}

for id, node in dep_query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = dep_query.captures[id]
  local text = vim.treesitter.get_node_text(node, bufnr)

  capture_count[capture_name] = (capture_count[capture_name] or 0) + 1
  text = text:gsub("\n", "\\n"):sub(1, 50)
  print(string.format("  @%s = %s", capture_name, text))
end

print("\n\nCapture Summary:")
print("================")
for name, count in pairs(capture_count) do
  print(string.format("  @%s: %d times", name, count))
end

if capture_count["dep_operator"] or capture_count["dep_operator2"] then
  print("\n✅ OPERATOR CAPTURED AFTER CACHE CLEAR!")
else
  print("\n❌ OPERATOR STILL NOT CAPTURED!")
end

