-- Parser Tests
-- Run from command line: nvim --headless -c "set runtimepath+=." -c "luafile lua/tests/parser_spec.lua" -c "qa"

local parser = require('dependencies.parser')
local helper = require('tests.test_helper')

-- Extract helper functions for convenience
local setup_buffer_with_content = helper.setup_buffer_with_content
local assert_equal = helper.assert_equal
local assert_table_equal = helper.assert_table_equal
local test = helper.test

-- Reset test counters at the start
helper.reset_counters()

io.write("=== Parser Tests ===\n")
io.flush()

-- ============================================================================
-- Casos base: archivos vacíos o sin dependencias
-- ============================================================================

test("empty build.sbt returns empty dependencies", function()
  -- g i v e n
  local content = ""
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 0, "Should return empty array for empty file")
end)

test("build.sbt with only comments returns empty dependencies", function()
  -- g i v e n
  local content = [[
// This is a comment
/* Multi-line
   comment */
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 0, "Should return empty array for file with only comments")
end)

-- ============================================================================
-- Dependencias simples con += (nueva funcionalidad)
-- ============================================================================

test("single dependency with += operator and literal version", function()
  -- g i v e n
  local content = [[
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 1, "Should find one dependency with +=")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should parse += dependency correctly")
  assert_equal(deps[1].line, 1, "Should capture line 1")
end)

test("single dependency with += operator and variable version", function()
  -- g i v e n
  local content = [[
val nettyVersion = "2.0.74.Final"
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % nettyVersion
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 1, "Should find one dependency with += and variable")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should resolve variable with += operator")
  assert_equal(deps[1].line, 2, "Should capture line 2")
end)

test("single dependency with += operator, scope and excludeAll with literal version", function()
  -- g i v e n
  local content = [[
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final" % "test,it" excludeAll(
  ExclusionRule(organization = "com.sun.jmx", name = "jmxi"),
  ExclusionRule(organization = "javax.jms")
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 1, "Should find one dependency with += despite scope and excludeAll")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should extract main dependency ignoring scope and exclusions")
  assert_equal(deps[1].line, 1, "Should capture line 1")
end)

test("single dependency with += operator, scope and excludeAll with variable version", function()
  -- g i v e n
  local content = [[
val nettyVersion = "2.0.74.Final"
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % nettyVersion % "test,it" excludeAll(
  ExclusionRule(organization = "com.sun.jmx", name = "jmxi"),
  ExclusionRule(organization = "javax.jms")
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 1, "Should find one dependency with += and variable despite scope and excludeAll")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should resolve variable and ignore scope and exclusions")
  assert_equal(deps[1].line, 2, "Should capture line 2")
end)

-- ============================================================================
-- Dependencias básicas con ++= Seq()
-- ============================================================================

test("simple dependency in Seq with literal version", function()
  -- g i v e n
  local content = [[
libraryDependencies ++= Seq(
  "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 1, "Should find one dependency")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should parse dependency correctly")
  assert_equal(deps[1].line, 2, "Should capture correct line number")
end)

test("dependency with double percent operator in Seq", function()
  -- g i v e n
  local content = [[
libraryDependencies ++= Seq(
  "com.github.jwt-scala" %% "jwt-circe" % "9.4.5"
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 1, "Should find one dependency")
  assert_equal(deps[1].dependency, "com.github.jwt-scala:jwt-circe:9.4.5", "Should parse dependency with %% correctly")
  assert_equal(deps[1].line, 2, "Should capture line 2")
end)

-- ============================================================================
-- Resolución de variables
-- ============================================================================

test("dependency with variable version in Seq", function()
  -- g i v e n
  local content = [[
val gatlingVersion = "3.8.4"
libraryDependencies ++= Seq(
  "io.gatling.highcharts" % "gatling-charts-highcharts" % gatlingVersion
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 1, "Should find one dependency")
  assert_equal(deps[1].dependency, "io.gatling.highcharts:gatling-charts-highcharts:3.8.4", "Should resolve version variable")
  assert_equal(deps[1].line, 3, "Should capture line 3")
end)

-- ============================================================================
-- Múltiples dependencias
-- ============================================================================

test("multiple dependencies with same version variable", function()
  -- g i v e n
  local content = [[
val gatlingVersion = "3.8.4"
libraryDependencies ++= Seq(
  "io.gatling.highcharts" % "gatling-charts-highcharts" % gatlingVersion,
  "io.gatling" % "gatling-test-framework" % gatlingVersion
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 2, "Should find two dependencies")
  assert_equal(deps[1].dependency, "io.gatling.highcharts:gatling-charts-highcharts:3.8.4", "First dependency should resolve version")
  assert_equal(deps[1].line, 3, "First dependency on line 3")
  assert_equal(deps[2].dependency, "io.gatling:gatling-test-framework:3.8.4", "Second dependency should resolve version")
  assert_equal(deps[2].line, 4, "Second dependency on line 4")
end)

test("dependencies are returned in document order in Seq", function()
  -- g i v e n
  local content = [[
libraryDependencies ++= Seq(
  "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final",
  "io.gatling.highcharts" % "gatling-charts-highcharts" % "3.8.4",
  "com.github.jwt-scala" %% "jwt-circe" % "9.4.5"
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 3, "Should find three dependencies")
  assert_equal(deps[1].line, 2, "First dependency on line 2")
  assert_equal(deps[2].line, 3, "Second dependency on line 3")
  assert_equal(deps[3].line, 4, "Third dependency on line 4")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "First in order")
  assert_equal(deps[2].dependency, "io.gatling.highcharts:gatling-charts-highcharts:3.8.4", "Second in order")
  assert_equal(deps[3].dependency, "com.github.jwt-scala:jwt-circe:9.4.5", "Third in order")
end)

test("no duplicate dependencies in Seq", function()
  -- g i v e n
  local content = [[
libraryDependencies ++= Seq(
  "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final",
  "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 1, "Should deduplicate identical dependencies")
  assert_equal(deps[1].line, 2, "Should capture line 2 (first occurrence)")
end)

test("mixed literals and variables", function()
  -- g i v e n
  local content = [[
val nettyVersion = "2.0.74.Final"
val gatlingVersion = "3.8.4"

libraryDependencies ++= Seq(
  "io.netty" % "netty-tcnative-boringssl-static" % nettyVersion,
  "io.gatling.highcharts" % "gatling-charts-highcharts" % gatlingVersion,
  "com.github.jwt-scala" %% "jwt-circe" % "9.4.5"
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 3, "Should find three dependencies")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should resolve first variable")
  assert_equal(deps[1].line, 5, "First dependency on line 5")
  assert_equal(deps[2].dependency, "io.gatling.highcharts:gatling-charts-highcharts:3.8.4", "Should resolve second variable")
  assert_equal(deps[2].line, 6, "Second dependency on line 6")
  assert_equal(deps[3].dependency, "com.github.jwt-scala:jwt-circe:9.4.5", "Should use literal version")
  assert_equal(deps[3].line, 7, "Third dependency on line 7")
end)

-- ============================================================================
-- Patrones .map() para aplicar versión a múltiples dependencias
-- ============================================================================

test("dependencies in Seq with map pattern", function()
  -- g i v e n
  local content = [[
libraryDependencies ++= Seq(
  "software.amazon.awssdk" % "auth",
  "software.amazon.awssdk" % "http-auth-aws",
  "software.amazon.awssdk" % "opensearchserverless"
).map(_ % "2.40.2")
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 3, "Should find three dependencies")
  assert_equal(deps[1].dependency, "software.amazon.awssdk:auth:2.40.2", "First dependency from map pattern")
  assert_equal(deps[1].line, 2, "First dependency on line 2")
  assert_equal(deps[2].dependency, "software.amazon.awssdk:http-auth-aws:2.40.2", "Second dependency from map pattern")
  assert_equal(deps[2].line, 3, "Second dependency on line 3")
  assert_equal(deps[3].dependency, "software.amazon.awssdk:opensearchserverless:2.40.2", "Third dependency from map pattern")
  assert_equal(deps[3].line, 4, "Third dependency on line 4")
end)

test("dependencies with map pattern using variable", function()
  -- g i v e n
  local content = [[
val circeVersion = "0.14.1"
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core",
  "io.circe" %% "circe-generic",
  "io.circe" %% "circe-parser"
).map(_ % circeVersion)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 3, "Should find three dependencies")
  assert_equal(deps[1].dependency, "io.circe:circe-core:0.14.1", "Should resolve version variable in map")
  assert_equal(deps[1].line, 3, "First dependency on line 3")
  assert_equal(deps[2].dependency, "io.circe:circe-generic:0.14.1", "Should resolve version variable in map")
  assert_equal(deps[2].line, 4, "Second dependency on line 4")
  assert_equal(deps[3].dependency, "io.circe:circe-parser:0.14.1", "Should resolve version variable in map")
  assert_equal(deps[3].line, 5, "Third dependency on line 5")
end)

test("map pattern with version and scope modifier", function()
  -- g i v e n
  local content = [[
val circeVersion = "0.14.1"
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core",
  "io.circe" %% "circe-generic",
  "io.circe" %% "circe-parser"
).map(_ % circeVersion % "test,it")
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 3, "Should find three dependencies")
  assert_equal(deps[1].dependency, "io.circe:circe-core:0.14.1", "Should extract main dependency ignoring scope in map")
  assert_equal(deps[1].line, 3, "First dependency on line 3")
  assert_equal(deps[2].dependency, "io.circe:circe-generic:0.14.1", "Should extract main dependency ignoring scope in map")
  assert_equal(deps[2].line, 4, "Second dependency on line 4")
  assert_equal(deps[3].dependency, "io.circe:circe-parser:0.14.1", "Should extract main dependency ignoring scope in map")
  assert_equal(deps[3].line, 5, "Third dependency on line 5")
end)

test("chained map pattern with version and scope", function()
  -- g i v e n
  local content = [[
val circeVersion = "0.14.1"
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core",
  "io.circe" %% "circe-generic",
  "io.circe" %% "circe-parser"
).map(_ % circeVersion).map(_ % "test,it")
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 3, "Should find three dependencies with chained map")
  assert_equal(deps[1].dependency, "io.circe:circe-core:0.14.1", "Should resolve version from first map")
  assert_equal(deps[1].line, 3, "First dependency on line 3")
  assert_equal(deps[2].dependency, "io.circe:circe-generic:0.14.1", "Should resolve version from first map")
  assert_equal(deps[2].line, 4, "Second dependency on line 4")
  assert_equal(deps[3].dependency, "io.circe:circe-parser:0.14.1", "Should resolve version from first map")
  assert_equal(deps[3].line, 5, "Third dependency on line 5")
end)

-- ============================================================================
-- Casos avanzados: modificadores, exclude, etc.
-- ============================================================================

test("dependency with modifiers and exclude in Seq", function()
  -- g i v e n
  local content = [[
libraryDependencies ++= Seq(
  "com.github.jwt-scala" %% "jwt-circe" % "9.4.5" % "test,it" (exclude "org.netty" % "netty-all")
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 1, "Should find one dependency despite modifiers")
  assert_equal(deps[1].dependency, "com.github.jwt-scala:jwt-circe:9.4.5", "Should extract main dependency ignoring modifiers")
  assert_equal(deps[1].line, 2, "Should capture line 2")
end)

-- ============================================================================
-- Casos del mundo real: build.sbt complejos
-- ============================================================================

test("complex real-world build.sbt", function()
  -- g i v e n
  local content = [[
enablePlugins(GatlingPlugin)

scalaVersion := "2.13.18"

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
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local deps = parser.extract_dependencies(bufnr)

  -- t h e n
  assert_equal(#deps, 10, "Should find all 10 dependencies")

  local expected_deps = {
    "io.netty:netty-tcnative-boringssl-static:2.0.74.Final",
    "io.gatling.highcharts:gatling-charts-highcharts:3.8.4",
    "io.gatling:gatling-test-framework:3.8.4",
    "com.github.jwt-scala:jwt-circe:9.4.5",
    "software.amazon.awssdk:auth:2.40.2",
    "software.amazon.awssdk:http-auth-aws:2.40.2",
    "software.amazon.awssdk:opensearchserverless:2.40.2",
    "io.circe:circe-core:0.14.1",
    "io.circe:circe-generic:0.14.1",
    "io.circe:circe-parser:0.14.1"
  }

  local expected_lines = {8, 9, 10, 11, 13, 14, 15, 21, 22, 23}

  for i, expected_dep in ipairs(expected_deps) do
    assert_equal(deps[i].dependency, expected_dep, string.format("Dependency %d should match", i))
    assert_equal(deps[i].line, expected_lines[i], string.format("Dependency %d should be on line %d", i, expected_lines[i]))
  end
end)

-- ============================================================================
-- Tests para detección de versión de Scala
-- ============================================================================

test("get_scala_version detects scalaVersion with := operator", function()
  -- g i v e n
  local content = [[
scalaVersion := "2.13.10"
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local scala_version = parser.get_scala_version(bufnr)

  -- t h e n
  assert_equal(scala_version, "2.13", "Should extract binary version 2.13 from 2.13.10")
end)

test("get_scala_version detects scalaVersion with Scala 2.12", function()
  -- g i v e n
  local content = [[
scalaVersion := "2.12.18"
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local scala_version = parser.get_scala_version(bufnr)

  -- t h e n
  assert_equal(scala_version, "2.12", "Should extract binary version 2.12 from 2.12.18")
end)

test("get_scala_version detects scalaVersion with Scala 3", function()
  -- g i v e n
  local content = [[
scalaVersion := "3.3.1"
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local scala_version = parser.get_scala_version(bufnr)

  -- t h e n
  assert_equal(scala_version, "3.3", "Should extract binary version 3.3 from 3.3.1")
end)

test("get_scala_version returns nil when no scalaVersion found", function()
  -- g i v e n
  local content = [[
libraryDependencies += "io.circe" %% "circe-core" % "0.14.1"
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local scala_version = parser.get_scala_version(bufnr)

  -- t h e n
  assert_equal(scala_version, nil, "Should return nil when scalaVersion is not found")
end)

test("get_scala_version detects scalaVersion in complex build.sbt", function()
  -- g i v e n
  local content = [[
enablePlugins(GatlingPlugin)

scalaVersion := "2.13.18"

val gatlingVersion = "3.8.4"

libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1"
)
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local scala_version = parser.get_scala_version(bufnr)

  -- t h e n
  assert_equal(scala_version, "2.13", "Should find scalaVersion in complex file and extract 2.13")
end)

test("get_scala_version handles scalaVersion at end of file", function()
  -- g i v e n
  local content = [[
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core" % "0.14.1"
)

scalaVersion := "2.13.10"
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local scala_version = parser.get_scala_version(bufnr)

  -- t h e n
  assert_equal(scala_version, "2.13", "Should find scalaVersion even at end of file")
end)

test("get_scala_version handles scalaVersion with single quotes", function()
  -- g i v e n
  local content = [[
scalaVersion := '2.13.10'
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local scala_version = parser.get_scala_version(bufnr)

  -- t h e n
  assert_equal(scala_version, "2.13", "Should handle single quotes")
end)

test("get_scala_version ignores commented scalaVersion", function()
  -- g i v e n
  local content = [[
// scalaVersion := "2.12.18"
scalaVersion := "2.13.10"
]]
  local bufnr = setup_buffer_with_content(content)

  -- w h e n
  local scala_version = parser.get_scala_version(bufnr)

  -- t h e n
  assert_equal(scala_version, "2.13", "Should ignore commented line and use active scalaVersion")
end)

-- Print test summary
helper.print_summary()


