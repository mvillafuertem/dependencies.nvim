-- Test the exact query string from query.lua
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_query_string_exact.lua" -c "qa"

-- Create a test buffer
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

-- Use the EXACT query string from query.lua lines 27-46
local query_string = [[
      ; Patrón básico: "org" % "artifact" % "version"
      (infix_expression
        left: (infix_expression
          left: (string) @org
          operator: (operator_identifier) @dep_operator
          right: (string) @artifact)
        operator: (operator_identifier)
        right: [(string) (identifier)] @version) @dep_node

      ; Patrón cuando está dentro de otro infix_expression (con modificadores)
      (infix_expression
        left: (infix_expression
          left: (infix_expression
            left: (string) @org2
            operator: (operator_identifier) @dep_operator2
            right: (string) @artifact2)
          operator: (operator_identifier)
          right: [(string) (identifier)] @version2) @dep_node2
        operator: (operator_identifier))
]]

print("Testing EXACT query string from query.lua:")
print("===========================================\n")

local ok, query = pcall(vim.treesitter.query.parse, "scala", query_string)

if not ok then
  print("❌ Query failed to parse: " .. tostring(query))
  return
end

print("✅ Query parsed successfully\n")
print("Captures:")

local capture_count = {}

for id, node in query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = query.captures[id]
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

-- Check for operator
if capture_count["dep_operator"] or capture_count["dep_operator2"] then
  print("\n✅ OPERATOR CAPTURED!")
else
  print("\n❌ OPERATOR NOT CAPTURED!")
end

