-- Test para entender iter_matches en Neovim 0.11+

local script_path = debug.getinfo(1).source:sub(2)
local plugin_dir = vim.fn.fnamemodify(script_path, ':h:h:h')
vim.opt.runtimepath:prepend(plugin_dir)

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

local dep_query = vim.treesitter.query.parse("scala", [[
  (infix_expression
    left: (infix_expression
      left: (string) @org
      operator: (operator_identifier)
      right: (string) @artifact)
    operator: (operator_identifier)
    right: [(string) (identifier)] @version) @dep_node
]])

print("=== Test iter_matches ===")
for pattern_id, match, metadata in dep_query:iter_matches(root, bufnr, 0, -1) do
  print(string.format("Pattern: %d, Match type: %s", pattern_id, type(match)))
  print(string.format("Match length: %d", #match))

  -- Probar acceso directo por índice
  for i = 1, #match do
    local node = match[i]
    print(string.format("  match[%d]: type=%s", i, type(node)))
    if node and type(node) == "userdata" then
      local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
      if ok then
        print(string.format("    text: %s", text:sub(1, 40)))
      end
    end
  end
end

