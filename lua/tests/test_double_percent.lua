-- Test para ver cómo tree-sitter parsea %%

local script_path = debug.getinfo(1).source:sub(2)
local plugin_dir = vim.fn.fnamemodify(script_path, ':h:h:h')
vim.opt.runtimepath:prepend(plugin_dir)

local test_content = [[
libraryDependencies ++= Seq(
  "com.github.jwt-scala" %% "jwt-circe" % "9.4.5" % "test,it" (exclude "org.netty" % "netty-all")
)
]]

local bufnr = vim.api.nvim_create_buf(false, true)
local lines = vim.split(test_content, "\n")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

vim.wait(100)

local parser = vim.treesitter.get_parser(bufnr, "scala")
local tree = parser:parse()[1]
local root = tree:root()

-- Función para imprimir el árbol
local function print_tree(node, indent)
  indent = indent or ""
  local node_type = node:type()
  local text = vim.treesitter.get_node_text(node, bufnr)

  -- Limitar el texto a una línea
  text = text:gsub("\n", "\\n"):sub(1, 50)

  print(string.format("%s%s: %s", indent, node_type, text))

  for child in node:iter_children() do
    print_tree(child, indent .. "  ")
  end
end

print("=== Árbol AST para %% ===")
print_tree(root)

