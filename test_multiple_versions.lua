#!/usr/bin/env nvim -l

-- Script de prueba para verificar el funcionamiento de múltiples versiones
-- cuando include_prerelease = true

-- Agregar el directorio actual al runtime path
vim.opt.runtimepath:append('.')

-- Configurar el plugin con include_prerelease = true
local deps = require('dependencies')
deps.setup({
  patterns = { "build.sbt" },
  include_prerelease = true,
  virtual_text_prefix = "  ← versiones: ",
})

print("=== Test: Múltiples Versiones con include_prerelease = true ===\n")

-- Crear un buffer de prueba con contenido de build.sbt
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

local test_content = [[
scalaVersion := "2.13.10"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1",
  "org.typelevel" %% "cats-core" % "2.9.0",
  "com.typesafe.akka" %% "akka-actor" % "2.6.20"
)
]]

local lines = vim.split(test_content, '\n')
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

print("Contenido del buffer de prueba:")
print(test_content)
print("\n" .. string.rep("=", 60) .. "\n")

-- Ejecutar extracción de dependencias
print("1. Extrayendo dependencias del buffer...")
local extracted_deps = deps.extract_dependencies(bufnr)
print(string.format("   ✓ Encontradas %d dependencias\n", #extracted_deps))

-- Obtener versión de Scala
local parser = require('dependencies.parser')
local scala_version = parser.get_scala_version(bufnr)
print(string.format("2. Versión de Scala detectada: %s\n", scala_version or "ninguna"))

-- Enriquecer con versiones de Maven Central
print("3. Consultando Maven Central (esto puede tardar unos segundos)...")
local maven = require('dependencies.maven')
local enriched = maven.enrich_with_latest_versions(extracted_deps, scala_version)

print("\n" .. string.rep("=", 60))
print("RESULTADOS:")
print(string.rep("=", 60) .. "\n")

for _, dep_info in ipairs(enriched) do
  print(string.format("Línea %d: %s", dep_info.line, dep_info.dependency))
  print(string.format("  Versión actual: %s", dep_info.current))

  if type(dep_info.latest) == "table" then
    print(string.format("  Versiones disponibles: %s", table.concat(dep_info.latest, ", ")))
    print(string.format("  Total de versiones: %d", #dep_info.latest))
  else
    print(string.format("  Última versión: %s", dep_info.latest))
  end
  print()
end

print(string.rep("=", 60))
print("\n4. Verificando configuración:")
local config = require('dependencies.config')
print(string.format("   include_prerelease: %s", tostring(config.get().include_prerelease)))
print(string.format("   virtual_text_prefix: '%s'", config.get().virtual_text_prefix))

print("\n✓ Test completado exitosamente!")
print("\nEjemplo de virtual text que se mostrará:")
print("  io.circe %% circe-core % 0.14.1  ← versiones: 0.14.10, 0.15.0-M1, 0.15.0-M2")

