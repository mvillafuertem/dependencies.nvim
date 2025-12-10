-- Test para diagnosticar las queries de tree-sitter

local script_path = debug.getinfo(1).source:sub(2)
local plugin_dir = vim.fn.fnamemodify(script_path, ':h:h:h')
vim.opt.runtimepath:prepend(plugin_dir)

-- Contenido de prueba simple
local test_content = [[
val gatlingVersion = "3.8.4"

libraryDependencies ++= Seq(
  "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
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

-- Test query 1: valores
print("=== Test Query 1: val definitions ===")
local val_query = vim.treesitter.query.parse("scala", [[
  (val_definition
    pattern: (identifier) @val_name
    value: (string) @val_value)
]])

local count = 0
for pattern_id, match, metadata in val_query:iter_matches(root, bufnr, 0, -1) do
  count = count + 1
  print(string.format("Match %d:", count))
  print(string.format("  Pattern ID: %d", pattern_id))

  -- En Neovim 0.11+, match es un array donde match[i] es el nodo capturado
  for i = 1, #val_query.captures do
    local capture_name = val_query.captures[i]
    local node = match[i]

    print(string.format("  Capture %d (%s):", i, capture_name))
    if node then
      print(string.format("    Node type: %s", type(node)))
      if type(node) == "table" then
        print(string.format("    Is TSNode: %s", tostring(node.type)))
      end
      local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
      if ok then
        print(string.format("    Text: %s", text))
      else
        print(string.format("    Error: %s", text))
      end
    else
      print("    Node is nil")
    end
  end
end
print(string.format("Total matches: %d\n", count))

-- Test query 2: dependencias simples
print("=== Test Query 2: simple dependencies ===")
local dep_query = vim.treesitter.query.parse("scala", [[
  (infix_expression
    left: (infix_expression
      left: (string) @org
      operator: (operator_identifier)
      right: (string) @artifact)
    operator: (operator_identifier)
    right: [(string) (identifier)] @version) @dep_node
]])

count = 0
for pattern_id, match, metadata in dep_query:iter_matches(root, bufnr, 0, -1) do
  count = count + 1
  print(string.format("Match %d:", count))
  for id, node in pairs(match) do
    if node and type(node) == "userdata" then
      local name = dep_query.captures[id]
      if name and name ~= "dep_node" then
        local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
        if ok then
          print(string.format("  %s = %s", name, text))
        end
      end
    end
  end
end
print(string.format("Total matches: %d", count))

