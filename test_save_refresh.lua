-- Test: Verificar que el virtual text se refresca al guardar
-- Reproduce el problema del usuario

-- Configurar path
vim.opt.runtimepath:append('.')

-- Requerir módulos
local dependencies = require('dependencies')
local virtual_text = require('dependencies.virtual_text')
local cache = require('dependencies.cache')

print("=== Test: Refresh on Save ===\n")

-- Setup
dependencies.setup({
  patterns = { "*.sbt" },
  cache_ttl = "1d",
  auto_check_on_open = false,
})

-- Crear buffer de prueba
local content = [[
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1",
  "org.typelevel" %% "cats-core" % "2.9.0",
)
]]

local lines = vim.split(content, "\n", { plain = true })
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, "test.sbt")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_set_current_buf(bufnr)

print("Step 1: Buffer created")
print("  Buffer number:", bufnr)
print("  File name:", vim.api.nvim_buf_get_name(bufnr))

-- Limpiar caché
cache.clear(bufnr)
print("\nStep 2: Cache cleared")

-- Simular primera carga (llenar caché)
print("\nStep 3: First load (populate cache)")
print("  Calling list_dependencies_with_versions(false)...")
dependencies.list_dependencies_with_versions(false)

-- Esperar a que termine la operación asíncrona
vim.wait(2000, function() return cache.get(bufnr) ~= nil end)

local cached_data = cache.get(bufnr)
if cached_data then
  print("  ✓ Cache populated with", #cached_data, "dependencies")
else
  print("  ✗ Cache NOT populated!")
end

-- Verificar extmarks después de primera carga
local extmarks1 = virtual_text.get_extmarks(bufnr, false)
print("  Extmarks after first load:", #extmarks1)

-- Simular edición: agregar línea en blanco al principio
print("\nStep 4: Simulate edit (add blank line at top)")
vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {""})

-- Mostrar contenido del buffer
print("  Buffer content after edit:")
local new_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
for i, line in ipairs(new_lines) do
  if i <= 6 then  -- Mostrar solo primeras 6 líneas
    print(string.format("    Line %d: %s", i, line))
  end
end

-- Simular guardar archivo (BufWritePost)
print("\nStep 5: Simulate save (:w)")
print("  Current mode:", vim.api.nvim_get_mode().mode)

-- Limpiar extmarks antes de guardar para ver si se recrean
virtual_text.clear(bufnr)
print("  Extmarks after clear:", #virtual_text.get_extmarks(bufnr, false))

-- Ejecutar el callback de BufWritePost manualmente
print("  Executing BufWritePost callback...")
dependencies.list_dependencies_with_versions(false)

-- Esperar un poco para que se apliquen los cambios
vim.wait(500)

-- Verificar extmarks después de guardar
local extmarks2 = virtual_text.get_extmarks(bufnr, false)
print("  Extmarks after save:", #extmarks2)

if #extmarks2 > 0 then
  print("\n  ✓ SUCCESS: Virtual text refreshed on save")
  print("  Extmark positions:")
  for i, mark in ipairs(extmarks2) do
    local row = mark[2]
    local line_content = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    print(string.format("    Extmark %d at row %d: %s", i, row, line_content:sub(1, 50)))
  end
else
  print("\n  ✗ FAIL: Virtual text NOT refreshed on save")
  print("  Expected: 2 extmarks")
  print("  Actual: 0 extmarks")

  -- Debug: ¿Hay datos en caché?
  local cached = cache.get(bufnr)
  if cached then
    print("\n  Debug: Cache still has data:")
    for _, dep in ipairs(cached) do
      print(string.format("    Line %d: %s:%s:%s -> %s",
        dep.line, dep.group, dep.artifact, dep.version, dep.latest))
    end
  end
end

print("\n=== Test Complete ===")

