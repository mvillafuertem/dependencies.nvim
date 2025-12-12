#!/usr/bin/env lua

-- Script de prueba manual para verificar la detección de versión de Scala
-- Uso: nvim --headless -c "luafile test_scala_version.lua" -c "qa"

print("=== Test de detección de versión de Scala ===\n")

-- Cargar el módulo parser
local parser = require('dependencies.parser')

-- Crear un buffer temporal con contenido de build.sbt
local bufnr = vim.api.nvim_create_buf(false, true)

-- Test 1: scalaVersion simple
print("Test 1: scalaVersion := \"2.13.10\"")
local content1 = [[
scalaVersion := "2.13.10"
]]
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content1, "\n"))
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')
local version1 = parser.get_scala_version(bufnr)
print(string.format("  Resultado: %s (esperado: 2.13)\n", version1 or "nil"))

-- Test 2: scalaVersion en build.sbt complejo
print("Test 2: scalaVersion en build.sbt complejo")
local content2 = [[
enablePlugins(GatlingPlugin)

scalaVersion := "2.13.18"

val gatlingVersion = "3.8.4"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1"
)
]]
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content2, "\n"))
local version2 = parser.get_scala_version(bufnr)
print(string.format("  Resultado: %s (esperado: 2.13)\n", version2 or "nil"))

-- Test 3: scalaVersion con Scala 2.12
print("Test 3: scalaVersion := \"2.12.18\"")
local content3 = [[
scalaVersion := "2.12.18"
]]
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content3, "\n"))
local version3 = parser.get_scala_version(bufnr)
print(string.format("  Resultado: %s (esperado: 2.12)\n", version3 or "nil"))

-- Test 4: scalaVersion con Scala 3
print("Test 4: scalaVersion := \"3.3.1\"")
local content4 = [[
scalaVersion := "3.3.1"
]]
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content4, "\n"))
local version4 = parser.get_scala_version(bufnr)
print(string.format("  Resultado: %s (esperado: 3.3)\n", version4 or "nil"))

-- Test 5: Sin scalaVersion
print("Test 5: Sin scalaVersion en el archivo")
local content5 = [[
libraryDependencies += "io.circe" %% "circe-core" % "0.14.1"
]]
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content5, "\n"))
local version5 = parser.get_scala_version(bufnr)
print(string.format("  Resultado: %s (esperado: nil)\n", version5 or "nil"))

-- Limpiar
vim.api.nvim_buf_delete(bufnr, { force = true })

print("\n=== Fin de tests ===")

