-- Debug completo para entender el flujo de collect_single_dependencies
local script_path = debug.getinfo(1).source:sub(2)
local plugin_dir = vim.fn.fnamemodify(script_path, ':h:h:h')
vim.opt.runtimepath:prepend(plugin_dir)

local test_content = [[
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
]]

local bufnr = vim.api.nvim_create_buf(false, true)
local lines = vim.split(test_content, "\n")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

vim.wait(100)

local parser_module = require('dependencies.parser')
local deps = parser_module.extract_dependencies(bufnr)

print("=== Result from extract_dependencies ===")
print(string.format("Found %d dependencies:", #deps))
for i, dep in ipairs(deps) do
  local dep_string = dep.group .. ":" .. dep.artifact .. ":" .. dep.version
  print(string.format("  %d. Line %d: %s", i, dep.line, dep_string))
end

if #deps == 0 then
  print("\n=== Manual debug of the query ===")
  local queries = require('dependencies.query')
  local single_dep_query = queries.single_dep_query

  local parser = vim.treesitter.get_parser(bufnr, "scala")
  local tree = parser:parse()[1]
  local root = tree:root()

  print("\nCaptures in order:")
  local count = 0
  for id, node in single_dep_query:iter_captures(root, bufnr, 0, -1) do
    count = count + 1
    local capture_name = single_dep_query.captures[id]
    local text = vim.treesitter.get_node_text(node, bufnr)
    print(string.format("  %d. @%s: %s", count, capture_name, text:sub(1, 40)))
  end
  print(string.format("Total captures: %d", count))
end

