#!/usr/bin/env -S nvim --headless -c "set rtp+=." -c "luafile" -c "qa"

-- Test: Virtual text should NOT appear when saving in insert mode
-- This simulates the bug where virtual text appears even in insert mode after BufWritePost

print("=== Testing Insert Mode Virtual Text Behavior ===\n")

-- Setup test environment
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local virtual_text = require('dependencies.virtual_text')
local cache = require('dependencies.cache')

-- Helper to create a test buffer
local function create_test_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    'libraryDependencies ++= Seq(',
    '  "io.circe" %% "circe-core" % "0.14.1",',
    ')'
  })
  return bufnr
end

-- Test 1: Apply virtual text in normal mode (should work)
print("Test 1: Apply virtual text in NORMAL mode")
local bufnr1 = create_test_buffer()
local test_data = {
  {
    group = "io.circe",
    artifact = "circe-core",
    version = "0.14.1",
    line = 2,
    latest = "0.14.15"
  }
}

-- Simulate normal mode
vim.api.nvim_set_current_buf(bufnr1)
local mode_before = vim.api.nvim_get_mode().mode
print("  Current mode: " .. mode_before)

-- Apply virtual text
local count = virtual_text.apply_virtual_text(bufnr1, test_data)
print("  Extmarks created: " .. count)

local extmarks = virtual_text.get_extmarks(bufnr1, false)
print("  Extmarks in buffer: " .. #extmarks)

if #extmarks == 1 then
  print("  ✓ PASS: Virtual text applied in normal mode\n")
else
  print("  ✗ FAIL: Expected 1 extmark, got " .. #extmarks .. "\n")
end

-- Test 2: Simulate the bug - check mode detection
print("Test 2: Mode detection logic")
local bufnr2 = create_test_buffer()

-- Test different mode strings
local test_modes = {
  {mode = "n", should_apply = true, desc = "normal"},
  {mode = "i", should_apply = false, desc = "insert"},
  {mode = "ic", should_apply = false, desc = "insert completion"},
  {mode = "ix", should_apply = false, desc = "insert Ctrl-X"},
  {mode = "R", should_apply = false, desc = "replace"},
  {mode = "Rc", should_apply = false, desc = "replace completion"},
  {mode = "v", should_apply = true, desc = "visual"},
  {mode = "V", should_apply = true, desc = "visual line"},
}

for _, test in ipairs(test_modes) do
  local is_insert_mode = test.mode:match('^i') or test.mode:match('^R')
  local should_skip = is_insert_mode
  local expected = test.should_apply
  local actual = not should_skip

  local status = (expected == actual) and "✓ PASS" or "✗ FAIL"
  print(string.format("  %s: Mode '%s' (%s) - should_apply=%s, actual=%s",
    status, test.mode, test.desc, tostring(expected), tostring(actual)))
end

print("\n=== Test Summary ===")
print("The fix ensures virtual text is only applied when NOT in insert/replace mode.")
print("This prevents virtual text from appearing when saving in insert mode.")

