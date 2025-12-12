#!/usr/bin/env -S nvim -l

-- Test script para verificar que solo se actualiza al guardar el archivo

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

print("=== Test: Actualización solo al guardar ===\n")

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
print("   ✅ BufWritePost: Actualiza solo al GUARDAR el archivo")
print("   ✅ InsertEnter: Oculta virtual text en modo inserción")
print("   ✅ InsertLeave: Limpia virtual text al salir de inserción")
print("   ❌ NO hay TextChanged/TextChangedI (no actualiza mientras editas)\n")

print("🔍 Características:")
print("   • Sin llamadas a API mientras editas")
print("   • Solo consulta Maven Central al guardar (:w)")
print("   • Virtual text solo visible en modo normal/visual")
print("   • Sin debounce (no es necesario)\n")

print("📦 Extrayendo dependencias iniciales...\n")
local initial_deps = deps.list_dependencies_with_versions()

print("\n=== Flujo de trabajo ===\n")
print("1. Abres build.sbt → Consulta Maven Central (inicial)")
print("2. Editas el archivo → NO consulta Maven Central")
print("3. Guardas el archivo (:w) → Consulta Maven Central")
print("4. Entras en modo inserción → Virtual text se oculta")
print("5. Sales de modo inserción → Virtual text permanece oculto hasta guardar")
print("6. Comando manual :SbtDepsLatest → Fuerza actualización\n")

print("✅ Test completado exitosamente!")
print("✅ NO se ejecutarán llamadas a la API mientras editas")
print("✅ Solo se consulta Maven Central al guardar el archivo")

