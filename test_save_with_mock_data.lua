-- Test: Verificar refresh con datos mock (evitar queries Maven)
-- Reproduce el problema real del usuario

vim.opt.runtimepath:append('.')

-- Limpiar cache de módulos para forzar recarga
package.loaded['dependencies'] = nil
package.loaded['dependencies.init'] = nil
package.loaded['dependencies.virtual_text'] = nil
package.loaded['dependencies.cache'] = nil
package.loaded['dependencies.parser'] = nil
package.loaded['dependencies.maven'] = nil
package.loaded['dependencies.config'] = nil

local dependencies = require('dependencies')
local virtual_text = require('dependencies.virtual_text')
local cache = require('dependencies.cache')

print("=== Test: Save Refresh with Mock Data ===\n")

-- Setup plugin
dependencies.setup({
  patterns = { "*.sbt" },
  cache_ttl = "1d",
  auto_check_on_open = false,
})

-- Crear buffer
local content = [[
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1",
  "org.typelevel" %% "cats-core" % "2.9.0",
)
]]

local lines = vim.split(content, "\n", { plain = true })
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, "test_save.sbt")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_set_current_buf(bufnr)

print("Step 1: Buffer created")
print("  Lines in buffer:", #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))

-- Crear datos mock en caché (simular que ya se consultó Maven)
local mock_cache_data = {
  {
    group = "io.circe",
    artifact = "circe-core",
    version = "0.14.1",
    line = 2,
    latest = "0.14.15"
  },
  {
    group = "org.typelevel",
    artifact = "cats-core",
    version = "2.9.0",
    line = 3,
    latest = "2.13.0"
  }
}

cache.set(bufnr, mock_cache_data)
print("\nStep 2: Mock cache data created")
print("  Cache entries:", #mock_cache_data)
for _, dep in ipairs(mock_cache_data) do
  print(string.format("    Line %d: %s:%s:%s -> %s",
    dep.line, dep.group, dep.artifact, dep.version, dep.latest))
end

-- Verificar que el caché es válido
print("\nStep 3: Verify cache is valid")
print("  Cache valid?", cache.is_valid(bufnr, "1d"))

-- Llamar list_dependencies_with_versions (debería usar caché)
print("\nStep 4: Call list_dependencies_with_versions(false)")
print("  Current mode:", vim.api.nvim_get_mode().mode)
dependencies.list_dependencies_with_versions(false)

-- Esperar un poco
vim.wait(200)

-- Verificar extmarks
local extmarks1 = virtual_text.get_extmarks(bufnr, true)
print("\nStep 5: Check extmarks after call")
print("  Extmarks created:", #extmarks1)

if #extmarks1 > 0 then
  print("  Extmark details:")
  for i, mark in ipairs(extmarks1) do
    local row = mark[2]
    local details = mark[4]
    local virt_text = details.virt_text and details.virt_text[1] and details.virt_text[1][1] or "none"
    local line_content = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    print(string.format("    %d) Row %d: %s", i, row, virt_text))
    print(string.format("       Line: %s", line_content:sub(1, 60)))
  end
  print("  ✓ SUCCESS: Virtual text displayed")
else
  print("  ✗ FAIL: No extmarks created")

  -- Debug: verificar si los datos tienen latest != version
  print("\n  Debug: Check merged data from cache")
  local cached = cache.get(bufnr)
  if cached then
    for _, dep in ipairs(cached) do
      print(string.format("    Line %d: version=%s latest=%s (different=%s)",
        dep.line, dep.version, dep.latest, tostring(dep.version ~= dep.latest)))
    end
  end
end

-- Ahora simular edición y guardar
print("\n\nStep 6: Simulate edit (add blank line)")
vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {""})

local new_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
print("  New buffer content:")
for i, line in ipairs(new_content) do
  if i <= 5 then
    print(string.format("    Line %d: %s", i, line))
  end
end

-- Limpiar virtual text
print("\nStep 7: Clear virtual text")
virtual_text.clear(bufnr)
print("  Extmarks after clear:", #virtual_text.get_extmarks(bufnr, false))

-- Simular BufWritePost
print("\nStep 8: Simulate :w (BufWritePost)")
print("  Current mode:", vim.api.nvim_get_mode().mode)

-- Debug: Ver qué dependencias detecta el parser ANTES del merge
local parser = require('dependencies.parser')
local current_deps_before_merge = parser.extract_dependencies(bufnr)
print("  Dependencies detected by parser after edit:")
for _, dep in ipairs(current_deps_before_merge) do
  local line_content = vim.api.nvim_buf_get_lines(bufnr, dep.line - 1, dep.line, false)[1] or ""
  print(string.format("    Line %d: %s:%s:%s", dep.line, dep.group, dep.artifact, dep.version))
  print(string.format("            %s", line_content:sub(1, 60)))
end

-- Hook into apply_virtual_text to see what data it receives
local original_apply = virtual_text.apply_virtual_text
virtual_text.apply_virtual_text = function(buf, deps_with_versions)
  print("  DEBUG: apply_virtual_text called with:")
  for i, dep in ipairs(deps_with_versions) do
    print(string.format("    %d) Line %d: %s:%s:%s -> %s",
      i, dep.line, dep.group, dep.artifact, dep.version, dep.latest))
  end
  return original_apply(buf, deps_with_versions)
end

dependencies.list_dependencies_with_versions(false)

-- Esperar
vim.wait(200)

-- Restore original
virtual_text.apply_virtual_text = original_apply

-- Verificar extmarks finales
local extmarks2 = virtual_text.get_extmarks(bufnr, true)
print("\nStep 9: Check extmarks after save")
print("  Extmarks created:", #extmarks2)

if #extmarks2 > 0 then
  print("  ✓ SUCCESS: Virtual text refreshed after save")
  print("  Extmark positions after edit:")
  for i, mark in ipairs(extmarks2) do
    local row = mark[2]
    local details = mark[4]
    local virt_text = details.virt_text and details.virt_text[1] and details.virt_text[1][1] or "none"
    local line_content = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    print(string.format("    %d) Row %d: %s", i, row, virt_text))
    print(string.format("       Line: %s", line_content:sub(1, 60)))
  end
else
  print("  ✗ FAIL: Virtual text NOT refreshed after save")
end

print("\n=== Test Complete ===")

