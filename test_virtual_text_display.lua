-- Test virtual text display with multiple versions

-- Force clean
package.loaded['dependencies.config'] = nil
package.loaded['dependencies.maven'] = nil
package.loaded['dependencies.virtual_text'] = nil

-- Setup config
local config = require('dependencies.config')
config.setup({
  include_prerelease = true,
  virtual_text_prefix = "  ← latest: ",
})

print("=== Test: Virtual Text Display with Multiple Versions ===\n")

local virtual_text = require('dependencies.virtual_text')

-- Create buffer
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  'scalaVersion := "2.13.10"',
  '',
  'libraryDependencies ++= Seq(',
  '  "io.circe" %% "circe-core" % "0.14.1",',
  '  "org.typelevel" %% "cats-core" % "2.9.0"',
  ')',
})

-- Simulate enriched dependencies
local deps_with_versions = {
  {
    line = 3,  -- 0-indexed line 3 = visual line 4
    dependency = "io.circe:circe-core:0.14.1",
    current = "0.14.1",
    latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"}  -- TABLE with 3 versions
  },
  {
    line = 4,  -- 0-indexed line 4 = visual line 5
    dependency = "org.typelevel:cats-core:2.9.0",
    current = "2.9.0",
    latest = {"2.13.0", "2.3.0-M1", "2.3.0-M2"}  -- TABLE with 3 versions
  }
}

print("1. Aplicando virtual text con múltiples versiones...\n")
virtual_text.apply_virtual_text(bufnr, deps_with_versions)

print("2. Obteniendo extmarks con detalles...\n")
local extmarks = virtual_text.get_extmarks(bufnr, true)

print("3. Resultado:\n")
for _, mark in ipairs(extmarks) do
  local id, row, col, details = mark[1], mark[2], mark[3], mark[4]
  print(string.format("   Extmark ID: %d", id))
  print(string.format("   Línea: %d (0-indexed)", row))
  print(string.format("   Columna: %d", col))
  if details and details.virt_text then
    local virt_text = details.virt_text[1]
    print(string.format("   Texto virtual: '%s'", virt_text[1]))
    print(string.format("   Highlight: %s", virt_text[2]))
  end
  print()
end

print("4. Buffer lines con virtual text:\n")
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
for i, line in ipairs(lines) do
  print(string.format("   %d: %s", i, line))

  -- Check if this line has virtual text
  for _, mark in ipairs(extmarks) do
    if mark[2] == i - 1 then  -- 0-indexed
      local details = mark[4]
      if details and details.virt_text then
        local virt_text = details.virt_text[1][1]
        print(string.format("      %s", virt_text))
      end
    end
  end
end

print("\n✓ Virtual text display test completed")

