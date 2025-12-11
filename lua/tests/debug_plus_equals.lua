-- Debug para entender la estructura del AST de +=
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
  max_depth = max_depth or 10
  current_depth = current_depth or 0

  if current_depth > max_depth then return end

  local node_type = node:type()
  local text = vim.treesitter.get_node_text(node, bufnr)
  text = text:gsub("\n", "\\n"):sub(1, 60)

  print(string.format("%s[%d] %s: %s", indent, node:child_count(), node_type, text))

  for child in node:iter_children() do
    print_tree(child, indent .. "  ", max_depth, current_depth + 1)
  end
end

print("=== AST for libraryDependencies += ===")
print_tree(root)

print("\n=== Testing new query ===")
local single_dep_query = vim.treesitter.query.parse("scala", [[
  ; Patrón completo: outer infix con % version
  (infix_expression
    left: (infix_expression
      left: (infix_expression
        left: (identifier) @lib_dep_name
        operator: (operator_identifier) @plus_eq
        right: (string) @org_single)
      operator: (operator_identifier)
      right: (string) @artifact_single)
    operator: (operator_identifier)
    right: [(string) (identifier)] @version_single) @single_dep_node
]])

local captures = {}
for id, node in single_dep_query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = single_dep_query.captures[id]
  local text = vim.treesitter.get_node_text(node, bufnr)
  table.insert(captures, {name = capture_name, text = text:sub(1, 60), type = node:type()})
end

print(string.format("Found %d captures:", #captures))
for i, cap in ipairs(captures) do
  print(string.format("  %d. @%s (%s): %s", i, cap.name, cap.type, cap.text))
end

