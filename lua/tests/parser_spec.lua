local parser = require('dependencies.parser')

local function setup_buffer_with_content(content)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')
  vim.wait(100)
  return bufnr
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nExpected: %s\nActual: %s", message, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_table_equal(actual, expected, message)
  if vim.inspect(actual) ~= vim.inspect(expected) then
    error(string.format("%s\nExpected: %s\nActual: %s", message, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function run_test(name, test_fn)
  local ok, err = pcall(test_fn)
  if ok then
    print(string.format("✓ %s", name))
  else
    print(string.format("✗ %s", name))
    print(string.format("  Error: %s", err))
  end
  return ok
end

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
  if run_test(name, fn) then
    tests_passed = tests_passed + 1
  else
    tests_failed = tests_failed + 1
  end
end

print("=== Parser Tests ===\n")

-- ============================================================================
-- Casos base: archivos vacíos o sin dependencias
-- ============================================================================

test("empty build.sbt returns empty dependencies", function()
  local content = ""
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 0, "Should return empty array for empty file")
end)

test("build.sbt with only comments returns empty dependencies", function()
  local content = [[
// This is a comment
/* Multi-line
   comment */
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 0, "Should return empty array for file with only comments")
end)

-- ============================================================================
-- Dependencias simples con += (nueva funcionalidad)
-- ============================================================================

test("single dependency with += operator and literal version", function()
  local content = [[
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 1, "Should find one dependency with +=")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should parse += dependency correctly")
end)

test("single dependency with += operator and variable version", function()
  local content = [[
val nettyVersion = "2.0.74.Final"
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % nettyVersion
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 1, "Should find one dependency with += and variable")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should resolve variable with += operator")
end)

test("single dependency with += operator, scope and excludeAll with literal version", function()
  local content = [[
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final" % "test,it" excludeAll(
  ExclusionRule(organization = "com.sun.jmx", name = "jmxi"),
  ExclusionRule(organization = "javax.jms")
)
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 1, "Should find one dependency with += despite scope and excludeAll")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should extract main dependency ignoring scope and exclusions")
end)

test("single dependency with += operator, scope and excludeAll with variable version", function()
  local content = [[
val nettyVersion = "2.0.74.Final"
libraryDependencies += "io.netty" % "netty-tcnative-boringssl-static" % nettyVersion % "test,it" excludeAll(
  ExclusionRule(organization = "com.sun.jmx", name = "jmxi"),
  ExclusionRule(organization = "javax.jms")
)
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 1, "Should find one dependency with += and variable despite scope and excludeAll")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should resolve variable and ignore scope and exclusions")
end)

-- ============================================================================
-- Dependencias básicas con ++= Seq()
-- ============================================================================

test("simple dependency in Seq with literal version", function()
  local content = [[
libraryDependencies ++= Seq(
  "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
)
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 1, "Should find one dependency")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should parse dependency correctly")
  assert_equal(deps[1].line, 2, "Should capture correct line number")
end)

test("dependency with double percent operator in Seq", function()
  local content = [[
libraryDependencies ++= Seq(
  "com.github.jwt-scala" %% "jwt-circe" % "9.4.5"
)
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 1, "Should find one dependency")
  assert_equal(deps[1].dependency, "com.github.jwt-scala:jwt-circe:9.4.5", "Should parse dependency with %% correctly")
end)

-- ============================================================================
-- Resolución de variables
-- ============================================================================

test("dependency with variable version in Seq", function()
  local content = [[
val gatlingVersion = "3.8.4"
libraryDependencies ++= Seq(
  "io.gatling.highcharts" % "gatling-charts-highcharts" % gatlingVersion
)
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 1, "Should find one dependency")
  assert_equal(deps[1].dependency, "io.gatling.highcharts:gatling-charts-highcharts:3.8.4", "Should resolve version variable")
end)

-- ============================================================================
-- Múltiples dependencias
-- ============================================================================

test("multiple dependencies with same version variable", function()
  local content = [[
val gatlingVersion = "3.8.4"
libraryDependencies ++= Seq(
  "io.gatling.highcharts" % "gatling-charts-highcharts" % gatlingVersion,
  "io.gatling" % "gatling-test-framework" % gatlingVersion
)
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 2, "Should find two dependencies")
  assert_equal(deps[1].dependency, "io.gatling.highcharts:gatling-charts-highcharts:3.8.4", "First dependency should resolve version")
  assert_equal(deps[2].dependency, "io.gatling:gatling-test-framework:3.8.4", "Second dependency should resolve version")
end)

test("dependencies are returned in document order in Seq", function()
  local content = [[
libraryDependencies ++= Seq(
  "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final",
  "io.gatling.highcharts" % "gatling-charts-highcharts" % "3.8.4",
  "com.github.jwt-scala" %% "jwt-circe" % "9.4.5"
)
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 3, "Should find three dependencies")
  assert_equal(deps[1].line, 2, "First dependency on line 2")
  assert_equal(deps[2].line, 3, "Second dependency on line 3")
  assert_equal(deps[3].line, 4, "Third dependency on line 4")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "First in order")
  assert_equal(deps[2].dependency, "io.gatling.highcharts:gatling-charts-highcharts:3.8.4", "Second in order")
  assert_equal(deps[3].dependency, "com.github.jwt-scala:jwt-circe:9.4.5", "Third in order")
end)

test("no duplicate dependencies in Seq", function()
  local content = [[
libraryDependencies ++= Seq(
  "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final",
  "io.netty" % "netty-tcnative-boringssl-static" % "2.0.74.Final"
)
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 1, "Should deduplicate identical dependencies")
end)

test("mixed literals and variables", function()
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
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 3, "Should find three dependencies")
  assert_equal(deps[1].dependency, "io.netty:netty-tcnative-boringssl-static:2.0.74.Final", "Should resolve first variable")
  assert_equal(deps[2].dependency, "io.gatling.highcharts:gatling-charts-highcharts:3.8.4", "Should resolve second variable")
  assert_equal(deps[3].dependency, "com.github.jwt-scala:jwt-circe:9.4.5", "Should use literal version")
end)

-- ============================================================================
-- Patrones .map() para aplicar versión a múltiples dependencias
-- ============================================================================

test("dependencies in Seq with map pattern", function()
  local content = [[
libraryDependencies ++= Seq(
  "software.amazon.awssdk" % "auth",
  "software.amazon.awssdk" % "http-auth-aws",
  "software.amazon.awssdk" % "opensearchserverless"
).map(_ % "2.40.2")
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 3, "Should find three dependencies")
  assert_equal(deps[1].dependency, "software.amazon.awssdk:auth:2.40.2", "First dependency from map pattern")
  assert_equal(deps[2].dependency, "software.amazon.awssdk:http-auth-aws:2.40.2", "Second dependency from map pattern")
  assert_equal(deps[3].dependency, "software.amazon.awssdk:opensearchserverless:2.40.2", "Third dependency from map pattern")
end)

test("dependencies with map pattern using variable", function()
  local content = [[
val circeVersion = "0.14.1"
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core",
  "io.circe" %% "circe-generic",
  "io.circe" %% "circe-parser"
).map(_ % circeVersion)
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 3, "Should find three dependencies")
  assert_equal(deps[1].dependency, "io.circe:circe-core:0.14.1", "Should resolve version variable in map")
  assert_equal(deps[2].dependency, "io.circe:circe-generic:0.14.1", "Should resolve version variable in map")
  assert_equal(deps[3].dependency, "io.circe:circe-parser:0.14.1", "Should resolve version variable in map")
end)

test("map pattern with version and scope modifier", function()
  local content = [[
val circeVersion = "0.14.1"
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core",
  "io.circe" %% "circe-generic",
  "io.circe" %% "circe-parser"
).map(_ % circeVersion % "test,it")
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 3, "Should find three dependencies")
  assert_equal(deps[1].dependency, "io.circe:circe-core:0.14.1", "Should extract main dependency ignoring scope in map")
  assert_equal(deps[2].dependency, "io.circe:circe-generic:0.14.1", "Should extract main dependency ignoring scope in map")
  assert_equal(deps[3].dependency, "io.circe:circe-parser:0.14.1", "Should extract main dependency ignoring scope in map")
end)

test("chained map pattern with version and scope", function()
  local content = [[
val circeVersion = "0.14.1"
libraryDependencies ++= Seq(
  "io.circe" %% "circe-core",
  "io.circe" %% "circe-generic",
  "io.circe" %% "circe-parser"
).map(_ % circeVersion).map(_ % "test,it")
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 3, "Should find three dependencies with chained map")
  assert_equal(deps[1].dependency, "io.circe:circe-core:0.14.1", "Should resolve version from first map")
  assert_equal(deps[2].dependency, "io.circe:circe-generic:0.14.1", "Should resolve version from first map")
  assert_equal(deps[3].dependency, "io.circe:circe-parser:0.14.1", "Should resolve version from first map")
end)

-- ============================================================================
-- Casos avanzados: modificadores, exclude, etc.
-- ============================================================================

test("dependency with modifiers and exclude in Seq", function()
  local content = [[
libraryDependencies ++= Seq(
  "com.github.jwt-scala" %% "jwt-circe" % "9.4.5" % "test,it" (exclude "org.netty" % "netty-all")
)
]]
  local bufnr = setup_buffer_with_content(content)
  local deps = parser.extract_dependencies(bufnr)

  assert_equal(#deps, 1, "Should find one dependency despite modifiers")
  assert_equal(deps[1].dependency, "com.github.jwt-scala:jwt-circe:9.4.5", "Should extract main dependency ignoring modifiers")
end)

-- ============================================================================
-- Casos del mundo real: build.sbt complejos
-- ============================================================================

test("complex real-world build.sbt", function()
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
  local deps = parser.extract_dependencies(bufnr)

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

  for i, expected_dep in ipairs(expected_deps) do
    assert_equal(deps[i].dependency, expected_dep, string.format("Dependency %d should match", i))
  end
end)

