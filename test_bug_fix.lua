-- Test script to verify the bug fix: current version should be filtered from virtual text
-- Run: nvim --headless -c "set rtp+=." -c "luafile test_bug_fix.lua" -c "qa"

local virtual_text = require('dependencies.virtual_text')
local helper = require('tests.test_helper')

print("=== Bug Fix Verification Test ===\n")

-- Test Case 1: Current version is in the latest array
print("Test 1: Current version (0.14.15) is in latest array")
print("Expected: Only show versions that differ (0.14.0-M7, 0.15.0-M1)")

local bufnr = helper.setup_buffer_with_content("")
local deps = {
  { line = 1, dependency = "io.circe:circe-core:0.14.15", version = "0.14.15",
    latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"} }
}

virtual_text.apply_virtual_text(bufnr, deps)
local extmarks = virtual_text.get_extmarks(bufnr, true)

if #extmarks == 1 then
  local text = extmarks[1][4].virt_text[1][1]
  if text == "  ← latest: 0.14.0-M7, 0.15.0-M1" then
    print("✓ PASS: Current version correctly filtered out")
    print("  Displayed: " .. text)
  else
    print("✗ FAIL: Unexpected text")
    print("  Expected: '  ← latest: 0.14.0-M7, 0.15.0-M1'")
    print("  Got:      '" .. text .. "'")
  end
else
  print("✗ FAIL: Expected 1 extmark, got " .. #extmarks)
end

print()

-- Test Case 2: All versions equal current (should NOT create extmark)
print("Test 2: All versions equal current (0.14.15)")
print("Expected: No extmark created")

bufnr = helper.setup_buffer_with_content("")
deps = {
  { line = 1, dependency = "io.circe:circe-core:0.14.15", version = "0.14.15",
    latest = {"0.14.15", "0.14.15", "0.14.15"} }
}

virtual_text.apply_virtual_text(bufnr, deps)
extmarks = virtual_text.get_extmarks(bufnr, true)

if #extmarks == 0 then
  print("✓ PASS: No extmark created when all versions match current")
else
  print("✗ FAIL: Expected 0 extmarks, got " .. #extmarks)
end

print()

-- Test Case 3: None of the versions match current (should show all)
print("Test 3: None of the versions match current (0.14.1)")
print("Expected: Show all three versions")

bufnr = helper.setup_buffer_with_content("")
deps = {
  { line = 1, dependency = "io.circe:circe-core:0.14.1", version = "0.14.1",
    latest = {"0.14.15", "0.14.0-M7", "0.15.0-M1"} }
}

virtual_text.apply_virtual_text(bufnr, deps)
extmarks = virtual_text.get_extmarks(bufnr, true)

if #extmarks == 1 then
  local text = extmarks[1][4].virt_text[1][1]
  if text == "  ← latest: 0.14.15, 0.14.0-M7, 0.15.0-M1" then
    print("✓ PASS: All different versions displayed")
    print("  Displayed: " .. text)
  else
    print("✗ FAIL: Unexpected text")
    print("  Expected: '  ← latest: 0.14.15, 0.14.0-M7, 0.15.0-M1'")
    print("  Got:      '" .. text .. "'")
  end
else
  print("✗ FAIL: Expected 1 extmark, got " .. #extmarks)
end

print("\n=== Bug Fix Verification Complete ===")
