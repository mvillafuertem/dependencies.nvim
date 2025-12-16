-- Debug: Check what find_scala_version returns
local parser = require('dependencies.parser')

local content = [[
scalaVersion := "2.13.10"
]]

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

print("Testing get_scala_version:")
local scala_version = parser.get_scala_version(bufnr)
print("  Result: " .. tostring(scala_version))

print("\nTesting extract_dependencies:")
local deps = parser.extract_dependencies(bufnr)
print("  Found " .. #deps .. " dependencies")
for i, dep in ipairs(deps) do
  print(string.format("  [%d] %s:%s:%s (line %d)", i, dep.group, dep.artifact, dep.version, dep.line))
end
