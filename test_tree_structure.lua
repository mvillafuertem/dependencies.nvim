-- Debug script to see Treesitter tree structure
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_tree_structure.lua" -c "qa"

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

-- Print tree structure
local function print_node(node, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  local text = vim.treesitter.get_node_text(node, bufnr)

  -- Trim text for display
  if #text > 50 then
    text = text:sub(1, 47) .. "..."
  end
  text = text:gsub("\n", "\\n")

  print(string.format("%s%s: %s", prefix, node:type(), text))

  -- Print children
  for i = 0, node:child_count() - 1 do
    print_node(node:child(i), indent + 1)
  end
end

print("Tree structure:")
print("===============\n")
print_node(root)

