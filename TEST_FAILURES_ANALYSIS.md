# Test Failures Analysis

**Date:** 2025-12-12
**Test Suite:** `lua/tests/integration_spec.lua`
**Status:** 18/23 tests passing, 5 tests failing

---

## Summary of Failures

### Root Cause
All failing tests have the same root cause: **Buffer Line Count Mismatch**

Tests create buffers with `setup_buffer_with_content("")` which creates a buffer with only **1 line**, but then try to place extmarks on lines that don't exist (lines 2, 3, 5, 10, etc.).

### Neovim Extmark Requirement
`nvim_buf_set_extmark()` requires that the line number exists in the buffer before placing an extmark. If you try to place an extmark on line 5 in a buffer with only 1 line, you get:
```
Error: Invalid 'line': out of range
```

---

## Failing Tests

### 1. ✗ apply_virtual_text places extmark on correct line
**Location:** Line ~133-147
**Problem:** Creates empty buffer (1 line), tries to place extmark on line 5
**Error:** `Invalid 'line': out of range`

```lua
local bufnr = setup_buffer_with_content("")  -- Only 1 line!
local deps_with_versions = {
  { line = 5, dependency = "...", current = "1.4.0", latest = "1.4.5" }  -- Line 5 doesn't exist
}
```

**Fix:** Create buffer with at least 5 lines
```lua
local bufnr = setup_buffer_with_content("line1\nline2\nline3\nline4\nline5")
```

---

### 2. ✗ apply_virtual_text with multiple dependencies creates multiple extmarks
**Location:** Line ~154-170
**Problem:** Creates empty buffer (1 line), tries to place extmarks on lines 1, 2, 3
**Error:** `Invalid 'line': out of range`

```lua
local bufnr = setup_buffer_with_content("")  -- Only 1 line!
local deps_with_versions = {
  { line = 1, ... },
  { line = 2, ... },  -- Line 2 doesn't exist
  { line = 3, ... }   -- Line 3 doesn't exist
}
```

**Fix:** Create buffer with at least 3 lines
```lua
local bufnr = setup_buffer_with_content("line1\nline2\nline3")
```

---

### 3. ✗ apply_virtual_text places extmarks on correct lines for multiple dependencies
**Location:** Line ~196-210
**Problem:** Creates empty buffer (1 line), tries to place extmarks on lines 5, 10
**Error:** `Invalid 'line': out of range`

```lua
local bufnr = setup_buffer_with_content("")  -- Only 1 line!
local deps_with_versions = {
  { line = 5, ... },   -- Line 5 doesn't exist
  { line = 10, ... }   -- Line 10 doesn't exist
}
```

**Fix:** Create buffer with at least 10 lines
```lua
local bufnr = setup_buffer_with_content("line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10")
```

---

### 4. ✗ apply_virtual_text skips dependencies with 'unknown' version
**Location:** Line ~237-257
**Problem:** Creates empty buffer (1 line), tries to place extmarks on lines 1, 2, 3
**Error:** `Invalid 'line': out of range`

```lua
local bufnr = setup_buffer_with_content("")  -- Only 1 line!
local deps_with_versions = {
  { line = 1, ... },
  { line = 2, ... },  -- Line 2 doesn't exist
  { line = 3, ... }   -- Line 3 doesn't exist
}
```

**Fix:** Create buffer with at least 3 lines
```lua
local bufnr = setup_buffer_with_content("line1\nline2\nline3")
```

---

### 5. ✗ get_extmarks without details flag returns basic info
**Location:** Line ~280-295
**Problem:** Different issue - expects `extmarks[1][4]` to be a table, but it's `nil`
**Error:** `Expected: "table", Actual: "nil"`

```lua
local extmarks = virtual_text.get_extmarks(bufnr, false)  -- false = no details
assert_equal(type(extmarks[1][4]), "table", "Should have details table")  -- But we asked for NO details!
```

**Root Cause:** The test asks for `with_details = false` but then expects `extmarks[1][4]` to be a table. When `details = false`, Neovim's `nvim_buf_get_extmarks` returns `[id, row, col]` without the details table at index 4.

**Fix:** Either:
- Option A: Change test to use `with_details = true`
- Option B: Remove the assertion that expects `extmarks[1][4]` to be a table

---

## Solution Approach

### Option 1: Fix Each Test Individually (Recommended)
Create buffers with appropriate number of lines for each test.

### Option 2: Modify Helper Function
Create a new helper function that automatically creates buffers with enough lines:

```lua
function M.setup_buffer_with_lines(num_lines)
  local lines = {}
  for i = 1, num_lines do
    lines[i] = string.format("line%d", i)
  end
  local content = table.concat(lines, "\n")
  return M.setup_buffer_with_content(content)
end
```

---

## Implementation Plan

1. Fix test #1: "places extmark on correct line"
   - Change: `setup_buffer_with_content("")` → `setup_buffer_with_content("line1\nline2\nline3\nline4\nline5")`

2. Fix test #2: "with multiple dependencies creates multiple extmarks"
   - Change: `setup_buffer_with_content("")` → `setup_buffer_with_content("line1\nline2\nline3")`

3. Fix test #3: "places extmarks on correct lines for multiple dependencies"
   - Change: `setup_buffer_with_content("")` → Create buffer with 10 lines

4. Fix test #4: "skips dependencies with 'unknown' version"
   - Change: `setup_buffer_with_content("")` → `setup_buffer_with_content("line1\nline2\nline3")`

5. Fix test #5: "get_extmarks without details flag returns basic info"
   - Change: `assert_equal(type(extmarks[1][4]), "table", ...)` → Remove or fix logic

---

## Expected Outcome

After fixes:
- All 23 tests should pass
- No "out of range" errors
- Virtual text extmarks placed correctly on specified lines

---

**Status:** Analysis complete, ready to implement fixes

