# ipairs Bug Fix - 4-Part Version Comparison

## Date: December 16, 2025

## Problem

Version comparison was failing for 4-part versions (e.g., `1.2.3.4` vs `1.2.3.5`). The `compare_versions()` function was treating all versions as equal, regardless of differences in the 4th component (build number).

**Test Failure:**
```
✗ process_metadata_xml: handles version with 4 parts (1.2.3.4)
Expected: "1.2.3.5"
Actual: "1.2.3.4"
```

## Root Cause: Lua's ipairs Gotcha

The issue was a classic Lua gotcha with `ipairs()`. The function stops iterating at the **first `nil` value** in an array.

**Original Code:**
```lua
local function compare_versions(v1, v2)
  local p1, p2 = parse_version(v1), parse_version(v2)
  if not p1 or not p2 then return 0 end

  local components = {
    compare_component(p1.major, p2.major),  -- nil (when equal)
    compare_component(p1.minor, p2.minor),  -- nil (when equal)
    compare_component(p1.patch, p2.patch),  -- nil (when equal)
    compare_component(p1.build, p2.build)   -- -1 (different!)
  }

  for _, result in ipairs(components) do  -- ❌ NEVER reached index 4!
    if result then return result end
  end

  -- ... prerelease comparison ...
end
```

**Why It Failed:**
- `compare_component()` returns `nil` when components are equal
- For `1.2.3.4` vs `1.2.3.5`: major, minor, patch are equal → all return `nil`
- `ipairs()` treats the array as **empty** because it stops at the first `nil`
- The 4th element (build comparison: `-1`) is never checked!

## Debug Process

### Step 1: Verified Parsing Was Correct
```lua
parse_version("1.2.3.4") → {major=1, minor=2, patch=3, build=4}
parse_version("1.2.3.5") → {major=1, minor=2, patch=3, build=5}
```
✅ Parsing worked correctly

### Step 2: Verified Component Comparison
```lua
compare_component(4, 5) → -1  ✅ (correct)
```

### Step 3: Verified Full Comparison
```lua
compare_versions("1.2.3.4", "1.2.3.5") → 0  ❌ (wrong! should be -1)
```

### Step 4: Discovered ipairs Bug
Created standalone test:
```lua
local components = {
  compare_component(1, 1),  -- nil
  compare_component(2, 2),  -- nil
  compare_component(3, 3),  -- nil
  compare_component(4, 5)   -- -1
}

-- Printing components array:
-- Result: EMPTY! (nothing printed)
-- ipairs stopped at first nil
```

## Solution

Replace the `ipairs` loop with **explicit sequential checks**:

```lua
local function compare_versions(v1, v2)
  local p1, p2 = parse_version(v1), parse_version(v2)
  if not p1 or not p2 then return 0 end

  -- Compare components directly (can't use ipairs with nil values)
  local result = compare_component(p1.major, p2.major)
  if result then return result end

  result = compare_component(p1.minor, p2.minor)
  if result then return result end

  result = compare_component(p1.patch, p2.patch)
  if result then return result end

  result = compare_component(p1.build, p2.build)
  if result then return result end

  -- Prerelease comparison...
  local type1_priority = PRERELEASE_ORDER[p1.prerelease_type] or 0
  local type2_priority = PRERELEASE_ORDER[p2.prerelease_type] or 0

  return compare_component(type1_priority, type2_priority)
    or compare_component(p1.prerelease_num, p2.prerelease_num)
    or 0
end
```

## Changes Made

**File:** `lua/dependencies/maven.lua`
- **Lines 77-99**: Refactored `compare_versions()` function
- **Change**: Replaced `ipairs` loop with explicit sequential checks
- **Synced**: Updated installed plugin at `~/.local/share/nvim/lazy/dependencies.nvim/`

## Test Results

**Before Fix:**
- Maven tests: 47/48 passing (1 failure)
- Failing test: "process_metadata_xml: handles version with 4 parts"

**After Fix:**
- Maven tests: 48/48 passing ✅ (100%)
- All version comparison tests passing

## Impact

### Fixed Behavior
- ✅ 4-part version comparison now works correctly
- ✅ Libraries using build numbers properly compared (e.g., Netty, Gatling)
- ✅ Prevents showing "you're on latest" when actually on older version

### Examples Now Working
```lua
compare_versions("1.2.3.4", "1.2.3.5") → -1 ✅  (v1 < v2)
compare_versions("1.0", "1.0.1")       → -1 ✅  (v1 < v2)
compare_versions("2.0.74.Final", "2.0.74.Final") → 0 ✅ (equal)
```

### Version Schemes Supported
- 1-part: `1` → `{major=1, minor=0, patch=0, build=0}`
- 2-part: `1.2` → `{major=1, minor=2, patch=0, build=0}`
- 3-part: `1.2.3` → `{major=1, minor=2, patch=3, build=0}`
- 4-part: `1.2.3.4` → `{major=1, minor=2, patch=3, build=4}`

## Lua Learning: ipairs Pitfall

**Key Takeaway:** `ipairs()` stops at the first `nil` value in an array.

**When to Avoid ipairs:**
- Arrays that may contain `nil` values as meaningful data
- Sparse arrays (non-consecutive keys)
- Arrays where you need to check all indices

**Alternatives:**
1. **Explicit checks** (used in this fix):
   ```lua
   local result = check(component1)
   if result then return result end
   ```

2. **Numeric for loop**:
   ```lua
   for i = 1, #array do
     if array[i] then return array[i] end
   end
   ```

3. **pairs()** (for all keys, but order not guaranteed):
   ```lua
   for key, value in pairs(table) do
     -- process
   end
   ```

## Related Documentation

- `AGENTS.md` - Updated with this fix in "Recent Critical Fixes" section
- `lua/tests/maven_spec.lua` - Test case: "process_metadata_xml: handles version with 4 parts"
- `lua/dependencies/maven.lua` - Fixed `compare_versions()` function

## References

- Lua ipairs documentation: https://www.lua.org/manual/5.1/manual.html#pdf-ipairs
- Related issue: Maven test failure with 4-part versions
- Previous fixes: ORDER_MAP_FIX.md, GATLING_VERSION_BUG.md

