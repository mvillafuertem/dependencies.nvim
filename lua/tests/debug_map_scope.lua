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

local parser = vim.treesitter.get_parser(bufnr, "scala")
local tree = parser:parse()[1]
local root = tree:root()

local function print_tree(node, indent, max_depth, current_depth)
  indent = indent or ""
  max_depth = max_depth or 15
  current_depth = current_depth or 0

  if current_depth > max_depth then return end

  local node_type = node:type()
  local text = vim.treesitter.get_node_text(node, bufnr)
  text = text:gsub("\n", "\\n"):sub(1, 80)

  print(string.format("%s%s: %s", indent, node_type, text))

  for child in node:iter_children() do
    print_tree(child, indent .. "  ", max_depth, current_depth + 1)
  end
end

print("=== AST for libraryDependencies += ===")
print_tree(root)

