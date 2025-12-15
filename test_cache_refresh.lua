#!/usr/bin/env -S nvim --headless -c "set rtp+=." -c "luafile" -c "qa"

-- Test: Verificar que el virtual text se refresca cuando se usa cache

print("=== Testing Cache Refresh Behavior ===\n")

-- Setup test environment
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local virtual_text = require('dependencies.virtual_text')
local cache = require('dependencies.cache')

-- Counter for unique buffer names
local buffer_counter = 0

-- Helper to create a test buffer
local function create_test_buffer()
  buffer_counter = buffer_counter + 1
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, "test_build_" .. buffer_counter .. ".sbt")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    'libraryDependencies ++= Seq(',
    '  "io.circe" %% "circe-core" % "0.14.1",',
    '  "org.typelevel" %% "cats-core" % "2.9.0",',
    ')'
  })
  return bufnr
end

-- Test data
local test_data = {
  {
    group = "io.circe",
    artifact = "circe-core",
    version = "0.14.1",
    line = 2,
    latest = "0.14.15"
  },
  {
    group = "org.typelevel",
    artifact = "cats-core",
    version = "2.9.0",
    line = 3,
    latest = "2.13.0"
  }
}

-- Test 1: Initial apply
print("Test 1: Initial apply of virtual text")
local bufnr = create_test_buffer()
vim.api.nvim_set_current_buf(bufnr)

local count1 = virtual_text.apply_virtual_text(bufnr, test_data)
local extmarks1 = virtual_text.get_extmarks(bufnr, true)

print("  Extmarks created: " .. count1)
print("  Extmarks in buffer: " .. #extmarks1)

if #extmarks1 == 2 then
  print("  ✓ PASS: Initial virtual text applied correctly\n")
else
  print("  ✗ FAIL: Expected 2 extmarks, got " .. #extmarks1 .. "\n")
end

-- Test 2: Reapply (simulate cache hit + BufWritePost)
print("Test 2: Reapply virtual text (simulating cache refresh)")
local count2 = virtual_text.apply_virtual_text(bufnr, test_data)
local extmarks2 = virtual_text.get_extmarks(bufnr, true)

print("  Extmarks created: " .. count2)
print("  Extmarks in buffer: " .. #extmarks2)

if #extmarks2 == 2 then
  print("  ✓ PASS: Virtual text refreshed correctly\n")
else
  print("  ✗ FAIL: Expected 2 extmarks, got " .. #extmarks2 .. "\n")
end

-- Test 3: Verify extmarks are not duplicated
print("Test 3: Verify no duplication after multiple applies")
local count3 = virtual_text.apply_virtual_text(bufnr, test_data)
local count4 = virtual_text.apply_virtual_text(bufnr, test_data)
local extmarks_final = virtual_text.get_extmarks(bufnr, true)

print("  Final extmarks in buffer: " .. #extmarks_final)

if #extmarks_final == 2 then
  print("  ✓ PASS: No duplication, still 2 extmarks\n")
else
  print("  ✗ FAIL: Expected 2 extmarks, got " .. #extmarks_final .. "\n")
end

-- Test 4: Test with cache module
print("Test 4: Cache integration test")
local bufnr2 = create_test_buffer()
vim.api.nvim_set_current_buf(bufnr2)

-- Set cache
cache.set(bufnr2, test_data)
print("  Cache set for buffer")

-- Get from cache
local cached_data = cache.get(bufnr2)
print("  Retrieved from cache: " .. (cached_data and #cached_data or 0) .. " items")

-- Apply virtual text from cached data
if cached_data then
  local count = virtual_text.apply_virtual_text(bufnr2, cached_data)
  local extmarks = virtual_text.get_extmarks(bufnr2, false)

  print("  Extmarks created: " .. count)
  print("  Extmarks in buffer: " .. #extmarks)

  if #extmarks == 2 then
    print("  ✓ PASS: Cache → virtual text works correctly\n")
  else
    print("  ✗ FAIL: Expected 2 extmarks, got " .. #extmarks .. "\n")
  end
else
  print("  ✗ FAIL: No cached data retrieved\n")
end

-- Test 5: Mode check with cache
print("Test 5: Mode check prevents apply in insert mode")
local bufnr3 = create_test_buffer()
vim.api.nvim_set_current_buf(bufnr3)

-- Simulate the logic in init.lua
local function simulate_cache_hit(bufnr, mode_string)
  local cached_data = test_data

  -- Simulate mode
  local is_insert_mode = mode_string:match('^i') or mode_string:match('^R')

  if not is_insert_mode then
    virtual_text.apply_virtual_text(bufnr, cached_data)
    return true
  else
    return false
  end
end

local applied_normal = simulate_cache_hit(bufnr3, "n")
local extmarks_normal = virtual_text.get_extmarks(bufnr3, false)
print("  Normal mode: applied=" .. tostring(applied_normal) .. ", extmarks=" .. #extmarks_normal)

virtual_text.clear(bufnr3)
local applied_insert = simulate_cache_hit(bufnr3, "i")
local extmarks_insert = virtual_text.get_extmarks(bufnr3, false)
print("  Insert mode: applied=" .. tostring(applied_insert) .. ", extmarks=" .. #extmarks_insert)

if applied_normal and #extmarks_normal == 2 and not applied_insert and #extmarks_insert == 0 then
  print("  ✓ PASS: Mode check works correctly with cache\n")
else
  print("  ✗ FAIL: Mode check not working as expected\n")
end

print("\n=== Test Summary ===")
print("All tests verify that virtual text refreshes correctly when using cache.")
print("The apply_virtual_text() function clears before applying, preventing duplication.")

