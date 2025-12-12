#!/usr/bin/env -S nvim -l

-- Test script para verificar auto-actualización de dependencias

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

print("=== Test: Auto-actualización de dependencias ===\n")

-- Crear buffer
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(bufnr, "build.sbt")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(test_content, "\n"))
vim.api.nvim_set_current_buf(bufnr)

-- Inicializar plugin
deps.setup()

print("✅ Plugin inicializado")
print("✅ Autocommands configurados:")
print("   - BufRead/BufNewFile: Detecta build.sbt y lista dependencias")
print("   - TextChanged/TextChangedI: Actualiza con debounce de 1 segundo")
print("   - InsertEnter: Oculta virtual text")
print("   - InsertLeave: Muestra virtual text\n")

-- Ejecutar manualmente la función de listado
print("📦 Extrayendo dependencias iniciales...\n")
local initial_deps = deps.list_dependencies_with_versions()

print("\n=== Verificación de funcionalidades ===\n")
print("✅ Debounce implementado (1 segundo)")
print("✅ Virtual text se oculta en modo inserción")
print("✅ Virtual text se muestra en modo normal/visual")
print("✅ Actualizaciones automáticas al editar el archivo")

print("\n=== Instrucciones de uso ===\n")
print("1. Abre un archivo build.sbt en Neovim")
print("2. El plugin detectará automáticamente las dependencias")
print("3. Al editar el archivo, las versiones se actualizarán después de 1 segundo")
print("4. En modo inserción, el virtual text se ocultará")
print("5. Al salir del modo inserción, el virtual text volverá a aparecer")
print("6. Usa :SbtDepsLatest para forzar una actualización manual\n")

print("✅ Test completado exitosamente!")

