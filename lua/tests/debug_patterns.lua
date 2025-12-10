-- lua/tests/debug_patterns.lua

-- Agregar el directorio raíz al runtimepath
local script_path = debug.getinfo(1).source:sub(2)
local plugin_dir = vim.fn.fnamemodify(script_path, ':h:h:h')
vim.opt.runtimepath:prepend(plugin_dir)

-- Cargar el módulo de dependencias
local ok, dependencies = pcall(require, 'dependencies')
if not ok then
  print("ERROR cargando módulo:", dependencies)
  return
end


-- Contenido del build.sbt embebido
local build_sbt_content = [[
enablePlugins(GatlingPlugin)

scalaVersion := "2.13.18"

scalacOptions := Seq(
  "-encoding",
  "UTF-8",
  "-target:jvm-1.8",
  "-deprecation",
  "-feature",
  "-unchecked",
  "-language:postfixOps"
)

Test / resourceDirectory := baseDirectory.value / "src" / "test" / "resources"
Test / scalaSource := baseDirectory.value / "src" / "test" / "scala"

val gatlingVersion = "3.8.4"

libraryDependencies ++= Seq(
  "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final",
  "io.gatling.highcharts" % "gatling-charts-highcharts" % gatlingVersion % "test,it",
  "io.gatling" % "gatling-test-framework" % gatlingVersion % "test,it",
  "com.github.jwt-scala" %% "jwt-circe" % "9.4.5" % "test,it" (exclude "org.netty" % "netty-all")
) ++ Seq(
  "software.amazon.awssdk" % "auth",
  "software.amazon.awssdk" % "http-auth-aws",
  "software.amazon.awssdk" % "opensearchserverless"
).map(_ % "2.40.2")

val circeVersion = "0.14.1"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core",
  "io.circe" %% "circe-generic",
  "io.circe" %% "circe-parser"
).map(_ % circeVersion)
]]

-- Crear buffer temporal con el contenido de prueba
local bufnr = vim.api.nvim_create_buf(false, true)
local lines = vim.split(build_sbt_content, "\n")
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')

-- Esperar a que tree-sitter parsee el contenido
vim.wait(100)

-- Extraer dependencias usando el módulo
print("=== Dependencias encontradas ===")
local deps = dependencies.extract_dependencies(bufnr)

for i, dep_info in ipairs(deps) do
  print(string.format("%d: %s", dep_info.line, dep_info.dependency))
end

print(string.format("\nTotal: %d dependencias", #deps))
print("\nLista completa:")
local deps_list = {}
for _, dep_info in ipairs(deps) do
  table.insert(deps_list, dep_info.dependency)
end
print(vim.inspect(deps_list))

