local script_path = debug.getinfo(1).source:sub(2)
local plugin_dir = vim.fn.fnamemodify(script_path, ':h:h:h')
vim.opt.runtimepath:prepend(plugin_dir)

local queries = require('dependencies.query')

local test_content = [[
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
]]

local bufnr = vim.api.nvim_create_buf(false, true)
local lines = vim.split(test_content, "\n")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')
vim.wait(100)

local parser = vim.treesitter.get_parser(bufnr, "scala")
local tree = parser:parse()[1]
local root = tree:root()

print("=== Testing dep_query on single dependency ===")
local count = 0
for id, node in queries.dep_query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = queries.dep_query.captures[id]
  local text = vim.treesitter.get_node_text(node, bufnr)
  count = count + 1
  print(string.format("%d. %s: %s", count, capture_name, text:sub(1, 50)))
end

print(string.format("\nTotal captures: %d", count))

