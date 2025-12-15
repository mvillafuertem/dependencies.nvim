# Unknown Version Fix - Documentation

## Problem Statement

**Issue**: When a dependency was not found in the cache (e.g., newly added dependency), the plugin displayed `latest = "unknown"` in the virtual text, which confused users.

**User Feedback**:
> "aparecen unknown cuando ya estas en la ultima version, pero no quiero ese comportamiento ya que es confuso, si la ultima version es 1.0 -> 1.0 asi deberia mostrarse"

**Example of Problem**:
```
Merged data:
  Line 23: com.github.jwt-scala:jwt-circe:9.4.5 -> 11.0.3  ✅ found in cache
  Line 25: software.amazon.awssdk:auth:2.40.6 -> unknown   ❌ not in cache (confusing!)
  Line 33: io.circe:circe-core:0.14.15 -> unknown         ❌ not in cache (confusing!)
```

## Root Cause

In `lua/dependencies/init.lua` (lines 115-124), when a dependency was not found in the cache merge logic, it was explicitly marked as:

```lua
latest = "unknown"
```

This happened when:
1. User adds a new dependency to `build.sbt`
2. File is saved (triggers `BufWritePost` autocommand)
3. Cache is checked and found valid
4. New dependency is not in cache (because it was just added)
5. Merge logic marked it as "unknown"

## Solution

**Changed behavior**: Show the **current version** as the latest version when dependency is not in cache.

### Code Changes

**File**: `lua/dependencies/init.lua`
**Lines**: 115-124

**Before**:
```lua
-- Si no está en cache, marcarlo como desconocido
if not found_in_cache then
  table.insert(merged_data, {
    group = current_dep.group,
    artifact = current_dep.artifact,
    version = current_dep.version,
    line = current_dep.line,
    latest = "unknown"  -- ❌ Confusing!
  })
end
```

**After**:
```lua
-- Si no está en cache, usar la versión actual como latest
-- (esto ocurre si el usuario agregó una nueva dependencia)
-- En el próximo refresh se consultará Maven para obtener la versión real
if not found_in_cache then
  table.insert(merged_data, {
    group = current_dep.group,
    artifact = current_dep.artifact,
    version = current_dep.version,
    line = current_dep.line,
    latest = current_dep.version  -- ✅ Show current version instead of "unknown"
  })
end
```

## New Behavior

### For Dependencies in Cache
- ✅ Show real latest version from Maven Central
- Example: `cats-core:2.9.0 -> 2.13.0`

### For Dependencies NOT in Cache
- ✅ Show current version as latest (e.g., `1.0.0 -> 1.0.0`)
- ✅ **No virtual text displayed** (because current == latest, so no update indicator needed)
- ✅ Next cache refresh will query Maven and update with real latest version
- ✅ **No confusing "unknown" text**

## User Experience Flow

### Scenario: User Adds New Dependency

1. **Initial state**: `build.sbt` with 2 dependencies
   ```scala
   libraryDependencies ++= Seq(
     "io.circe" %% "circe-core" % "0.14.1",      // ← latest: 0.14.15
     "org.typelevel" %% "cats-core" % "2.9.0",   // ← latest: 2.13.0
   )
   ```

2. **User adds new dependency**:
   ```scala
   libraryDependencies ++= Seq(
     "io.circe" %% "circe-core" % "0.14.1",      // ← latest: 0.14.15
     "org.typelevel" %% "cats-core" % "2.9.0",   // ← latest: 2.13.0
     "com.example" %% "new-lib" % "1.0.0",       // (no virtual text - clean!)
   )
   ```

3. **User saves file** (`:w`)
   - Cache is checked (still valid)
   - `circe-core` and `cats-core`: Found in cache → show latest from cache
   - `new-lib`: **NOT** in cache → show current version as latest (`1.0.0`)
   - Since `1.0.0 == 1.0.0`, **no virtual text displayed** for `new-lib`

4. **Next cache refresh** (TTL expires or `:SbtDepsLatestForce`)
   - Maven Central queried for all dependencies
   - If `new-lib` has update available (e.g., `1.2.0`):
     ```scala
     "com.example" %% "new-lib" % "1.0.0",  // ← latest: 1.2.0
     ```

## Benefits

### Before Fix
- ❌ Confusing "unknown" text displayed
- ❌ User unsure if plugin is working correctly
- ❌ "unknown" appears even when dependency is at latest version

### After Fix
- ✅ Clean display - no "unknown" text
- ✅ Intuitive behavior - no virtual text means "probably up-to-date"
- ✅ Next refresh provides accurate information from Maven
- ✅ User experience matches expectation: "1.0 -> 1.0" = no update needed

## Test Coverage

### Test File: `test_unknown_fix.lua`

**Test Scenario**:
1. Create buffer with 3 dependencies
2. Set cache with only 2 dependencies (simulates pre-existing cache)
3. Extract all 3 dependencies from buffer
4. Merge with cache (simulating real cache hit scenario)
5. Verify 3rd dependency shows current version, not "unknown"

**Test Results**:
```
✅ ALL TESTS PASSED

Test Summary:
• Dependencies in cache: Show real latest version from Maven
• Dependencies NOT in cache: Show current version (no 'unknown')
• Next cache refresh will query Maven for real latest version
• User experience: No confusing 'unknown' text!
```

### Running the Test

```bash
nvim --headless -c "set rtp+=." -c "luafile test_unknown_fix.lua" -c "qa"
```

## Edge Cases Handled

### Case 1: All Dependencies in Cache
- ✅ All show cached latest versions
- ✅ Normal operation

### Case 2: No Dependencies in Cache (Empty Cache)
- ✅ All show current version as latest
- ✅ No virtual text displayed (all versions match)
- ✅ Next refresh queries Maven for all

### Case 3: Mixed (Some in Cache, Some Not)
- ✅ Cached dependencies: Show cached latest versions
- ✅ Non-cached dependencies: Show current version as latest
- ✅ Clean, consistent behavior

### Case 4: Dependency Already at Latest Version
- ✅ Virtual text not displayed (current == latest)
- ✅ No unnecessary noise in editor

## Related Issues

This fix resolves the confusion mentioned in the user feedback and aligns with the design principle:

**Design Principle**: Virtual text should only appear when there's actionable information (update available). If we don't know the latest version yet, showing nothing is better than showing "unknown".

## Files Modified

1. **`lua/dependencies/init.lua`** (lines 115-124)
   - Changed `latest = "unknown"` to `latest = current_dep.version`
   - Updated comment to reflect new behavior

2. **`~/.local/share/nvim/lazy/dependencies.nvim/lua/dependencies/init.lua`**
   - Synced with working directory version

## Documentation Updated

1. **`AGENTS.md`** - Added changelog entry for 2025-12-15
2. **`UNKNOWN_VERSION_FIX.md`** - This document

## Conclusion

This fix improves the user experience by eliminating confusing "unknown" text. The behavior is now more intuitive:
- If you see virtual text → update available
- If you see no virtual text → either up-to-date or not yet checked (will be checked on next refresh)

The fix maintains the plugin's performance benefits (caching) while providing a cleaner, less confusing interface.

---

**Date**: 2025-12-15
**Fix Type**: User Experience Improvement
**Impact**: Low risk, high usability improvement
**Testing**: Comprehensive test created and passing

