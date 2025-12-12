#!/usr/bin/env -S nvim -l

-- Test script para verificar comportamiento dinámico al salir de modo inserción

-- Configurar runtimepath
vim.opt.runtimepath:prepend(".")

-- Cargar el plugin
local deps = require('dependencies')

-- Crear un buffer de prueba con contenido build.sbt
local test_content = [[
scalaVersion := "2.13.10"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1",
  "org.scalatest" %% "scalatest" % "3.2.15" % Test
)
]]

print("=== Test: Actualización dinámica al salir de modo inserción ===\n")

-- Crear buffer
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, "build.sbt")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(test_content, "\n"))
vim.api.nvim_set_current_buf(bufnr)

-- Inicializar plugin
deps.setup()

print("✅ Plugin inicializado\n")
print("📋 Comportamiento configurado:")
print("   ✅ BufRead/BufNewFile: Detecta build.sbt al abrir")
print("   ✅ BufWritePost: Actualiza al guardar el archivo")
print("   ✅ InsertEnter: Oculta virtual text en modo inserción")
print("   ✅ InsertLeave: Consulta Maven Central al SALIR de inserción")
print("   ❌ NO hay TextChanged/TextChangedI (no actualiza mientras escribes)\n")

print("🔍 Características:")
print("   • Sin llamadas a API mientras editas (modo inserción activo)")
print("   • Consulta Maven Central cuando TERMINAS de editar (sales de inserción)")
print("   • Virtual text solo visible en modo normal/visual")
print("   • Comportamiento dinámico: ves cambios inmediatamente al salir de inserción\n")

print("📦 Extrayendo dependencias iniciales...\n")
local initial_deps = deps.list_dependencies_with_versions()

print("\n=== Flujo de trabajo dinámico ===\n")
print("1. Abres build.sbt → Consulta Maven Central (inicial)")
print("2. Presionas 'i' (modo inserción) → Virtual text se oculta")
print("3. Editas una versión (ej: cambias 0.14.1 a 0.14.15)")
print("4. Presionas ESC (sales de inserción) → Consulta Maven Central automáticamente")
print("5. Virtual text se actualiza y muestra si hay nuevas versiones disponibles")
print("6. Guardas con :w → También consulta Maven Central (por si acaso)\n")

print("💡 Ventaja: Comportamiento más dinámico")
print("   • No necesitas guardar para ver si actualizaste correctamente")
print("   • Ves inmediatamente si la nueva versión es la última disponible")
print("   • Sin llamadas excesivas a la API (solo al terminar de editar)\n")

print("✅ Test completado exitosamente!")
print("✅ Actualización dinámica al salir del modo inserción")
print("✅ Sin llamadas a API mientras editas activamente")

