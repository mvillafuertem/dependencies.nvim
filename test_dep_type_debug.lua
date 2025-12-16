-- Debug script to trace type detection
-- Run with: nvim --headless -c "set rtp+=." -c "luafile test_dep_type_debug.lua" -c "qa"

local parser = require('dependencies.parser')

-- Create a simple test buffer
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

local content = [[
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1"
)
]]

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, '\n'))

-- Extract dependencies
local deps = parser.extract_dependencies(bufnr)

print("Number of dependencies found:", #deps)

for i, dep in ipairs(deps) do
  print(string.format("\nDependency %d:", i))
  print("  group:", dep.group)
  print("  artifact:", dep.artifact)
  print("  version:", dep.version)
  print("  line:", dep.line)
  print("  type:", dep.type)
  print("  type (type()):", type(dep.type))

  -- Check all fields
  print("\n  All fields:")
  for k, v in pairs(dep) do
    print(string.format("    %s = %s", k, tostring(v)))
  end
end

