-- Test helper functions for all test suites

local M = {}

-- State tracking
M.tests_passed = 0
M.tests_failed = 0

-- Setup a buffer with the given content for testing
function M.setup_buffer_with_content(content)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'scala')
  vim.wait(100)
  return bufnr
end

-- Assert that two values are equal
function M.assert_equal(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nExpected: %s\nActual: %s", message, vim.inspect(expected), vim.inspect(actual)))
  end
end

-- Assert that two tables are equal
function M.assert_table_equal(actual, expected, message)
  if vim.inspect(actual) ~= vim.inspect(expected) then
    error(string.format("%s\nExpected: %s\nActual: %s", message, vim.inspect(expected), vim.inspect(actual)))
  end
end

-- Run a single test and return success status
function M.run_test(name, test_fn)
  local ok, err = pcall(test_fn)
  if ok then
    io.write(string.format("✓ %s\n", name))
  else
    io.write(string.format("✗ %s\n", name))
    io.write(string.format("  Error: %s\n", err))
  end
  return ok
end

-- Test wrapper that tracks pass/fail counts
function M.test(name, fn)
  if M.run_test(name, fn) then
    M.tests_passed = M.tests_passed + 1
  else
    M.tests_failed = M.tests_failed + 1
  end
end

-- Reset test counters
function M.reset_counters()
  M.tests_passed = 0
  M.tests_failed = 0
end

-- Print test summary
function M.print_summary()
  io.write("\n=== Test Summary ===\n")
  io.write(string.format("Tests passed: %d\n", M.tests_passed))
  io.write(string.format("Tests failed: %d\n", M.tests_failed))
  io.write(string.format("Total tests: %d\n", M.tests_passed + M.tests_failed))

  if M.tests_failed > 0 then
    io.write("\n❌ Some tests failed\n")
  else
    io.write("\n✅ All tests passed!\n")
  end
  io.flush()
end

return M

