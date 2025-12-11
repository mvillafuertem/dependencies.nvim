-- Test para verificar la funcionalidad de += individual
local script_path = debug.getinfo(1).source:sub(2)
local plugin_dir = vim.fn.fnamemodify(script_path, ':h:h:h')
vim.opt.runtimepath:prepend(plugin_dir)

local parser = require('dependencies.parser')

local function setup_buffer_with_content(content)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')
  vim.wait(100)
  return bufnr
end

print("=== Tests para libraryDependencies += ===\n")

-- Test 1: Dependencia individual con += y versión literal
print("Test 1: Dependencia individual con += y versión literal")
local content1 = [[
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
]]
local bufnr1 = setup_buffer_with_content(content1)
local deps1 = parser.extract_dependencies(bufnr1)

print(string.format("  Dependencias encontradas: %d", #deps1))
if #deps1 == 1 then
  print(string.format("  ✓ Dependencia: %s", deps1[1].dependency))
  if deps1[1].dependency == "io.netty:netty-tcnative-boringssl-static:2.0.74.Final" then
    print("  ✓ PASSED: Dependencia parseada correctamente")
  else
    print("  ✗ FAILED: Dependencia incorrecta")
  end
else
  print("  ✗ FAILED: Debería encontrar 1 dependencia")
end

print()

-- Test 2: Dependencia individual con += y versión variable
print("Test 2: Dependencia individual con += y versión variable")
local content2 = [[
val nettyVersion = "2.0.74.Final"
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % nettyVersion
]]
local bufnr2 = setup_buffer_with_content(content2)
local deps2 = parser.extract_dependencies(bufnr2)

print(string.format("  Dependencias encontradas: %d", #deps2))
if #deps2 == 1 then
  print(string.format("  ✓ Dependencia: %s", deps2[1].dependency))
  if deps2[1].dependency == "io.netty:netty-tcnative-boringssl-static:2.0.74.Final" then
    print("  ✓ PASSED: Variable de versión resuelta correctamente")
  else
    print("  ✗ FAILED: Variable de versión no resuelta correctamente")
  end
else
  print("  ✗ FAILED: Debería encontrar 1 dependencia")
end

print()

-- Test 3: Múltiples dependencias con += y ++= mezcladas
print("Test 3: Múltiples dependencias con += y ++= mezcladas")
local content3 = [[
val gatlingVersion = "3.8.4"
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
libraryDependencies ++= Seq(
  "io.gatling.highcharts" % "gatling-charts-highcharts" % gatlingVersion
)
libraryDependencies += "com.github.jwt-scala" %% "jwt-circe" % "9.4.5"
]]
local bufnr3 = setup_buffer_with_content(content3)
local deps3 = parser.extract_dependencies(bufnr3)

print(string.format("  Dependencias encontradas: %d", #deps3))
for i, dep in ipairs(deps3) do
  print(string.format("  %d. Línea %d: %s", i, dep.line, dep.dependency))
end

if #deps3 == 3 then
  print("  ✓ PASSED: Se encontraron las 3 dependencias")
else
  print(string.format("  ✗ FAILED: Debería encontrar 3 dependencias, encontró %d", #deps3))
end

print()
print("=== Fin de tests ===")

