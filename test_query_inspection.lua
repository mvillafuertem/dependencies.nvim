-- Inspect the query object to see what's different
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_query_inspection.lua" -c "qa"

package.loaded['dependencies.query'] = nil
local queries = require('dependencies.query')

print("Inspecting query object from query.lua:")
print("=========================================\n")

local dep_query = queries.get_dep_query()

print("Query captures list:")
for i, name in ipairs(dep_query.captures) do
  print(string.format("  %d: %s", i, name))
end

print("\n\nNow comparing with manual query:")
print("==================================\n")

local manual_query_string = [[
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

local ok, manual_query = pcall(vim.treesitter.query.parse, "scala", manual_query_string)

if ok then
  print("Manual query captures list:")
  for i, name in ipairs(manual_query.captures) do
    print(string.format("  %d: %s", i, name))
  end
else
  print("❌ Manual query failed to parse")
end

