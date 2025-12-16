-- Debug script to test single quote parsing
vim.o.runtimepath = vim.o.runtimepath .. ',.'

local parser = require('dependencies.parser')

-- Test 1: Double quotes (working)
print("\n=== Test 1: Double quotes ===")
local bufnr1 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr1, 0, -1, false, {
  'scalaVersion := "2.13.10"'
})
local result1 = parser.get_scala_version(bufnr1)
print("Result with double quotes: " .. tostring(result1))

-- Test 2: Single quotes (failing)
print("\n=== Test 2: Single quotes ===")
local bufnr2 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr2, 0, -1, false, {
  "scalaVersion := '2.13.10'"
})
local result2 = parser.get_scala_version(bufnr2)
print("Result with single quotes: " .. tostring(result2))

-- Test 3: Check what Treesitter sees
print("\n=== Test 3: Treesitter parse tree ===")
local ts_parser = vim.treesitter.get_parser(bufnr2, "scala")
local tree = ts_parser:parse()[1]
local root = tree:root()

local function print_tree(node, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  local node_text = vim.treesitter.get_node_text(node, bufnr2)
  print(prefix .. node:type() .. ': "' .. node_text .. '"')

  for child in node:iter_children() do
    print_tree(child, indent + 1)
  end
end

print_tree(root)

