# Prerelease Configuration Cache Invalidation

## Overview

This document describes the automatic cache invalidation feature when the `include_prerelease` configuration option is changed.

## Problem

Previously, when a user changed the `include_prerelease` configuration from `true` to `false` (or vice versa), the plugin would continue using cached data that was generated with the previous setting. This caused inconsistent behavior:

- **Scenario 1**: User had `include_prerelease = false` (cache has single stable version strings)
  - Changes to `include_prerelease = true`
  - Expected: Should fetch 3 versions (stable + pre-releases) from Maven
  - Previous behavior: Used cached single version string (WRONG!)

- **Scenario 2**: User had `include_prerelease = true` (cache has array of 3 versions)
  - Changes to `include_prerelease = false`
  - Expected: Should fetch only stable version from Maven
  - Previous behavior: Used cached array of 3 versions (WRONG!)

## Solution

The cache system now tracks which `include_prerelease` setting was used when the cache entry was created. When validating the cache, the system compares the current `include_prerelease` setting with the cached one:

- If they match → Cache is valid (respects TTL)
- If they differ → Cache is automatically invalidated, triggers fresh Maven query

## Implementation Details

### Cache Entry Structure

```json
{
  "timestamp": 1702900000,
  "buffer_name": "/path/to/project/build.sbt",
  "include_prerelease": false,
  "data": [
    {
      "group": "io.circe",
      "artifact": "circe-core",
      "version": "0.14.1",
      "line": 5,
      "latest": "0.14.15"
    }
  ]
}
```

### Files Modified

#### 1. `lua/dependencies/cache.lua`

**Function: `M.set(bufnr, data, include_prerelease)`**
- Added `include_prerelease` parameter
- Stores the value in cache entry
- Signature changed from: `M.set(bufnr, data)`
- To: `M.set(bufnr, data, include_prerelease)`

**Function: `M.is_valid(bufnr, ttl_str, include_prerelease)`**
- Added `include_prerelease` parameter
- Compares current setting with cached value
- Returns `false` if values differ (invalidates cache)
- Signature changed from: `M.is_valid(bufnr, ttl_str)`
- To: `M.is_valid(bufnr, ttl_str, include_prerelease)`

```lua
function M.is_valid(bufnr, ttl_str, include_prerelease)
  -- ... (read cache entry)

  -- Verificar si el valor de include_prerelease cambió
  if entry.include_prerelease ~= include_prerelease then
    return false  -- Cache invalidated!
  end

  -- ... (check TTL)
end
```

#### 2. `lua/dependencies/init.lua`

**Function: `M.list_dependencies_with_versions(force)`**
- Updated cache validation call to pass `opts.include_prerelease`
- Updated cache storage call to pass `opts.include_prerelease`

**Changes:**
```lua
-- Before:
if not force and cache.is_valid(bufnr, opts.cache_ttl) then
  -- ...
end
cache.set(bufnr, deps_with_versions)

-- After:
if not force and cache.is_valid(bufnr, opts.cache_ttl, opts.include_prerelease) then
  -- ...
end
cache.set(bufnr, deps_with_versions, opts.include_prerelease)
```

## Usage Example

### Scenario: User wants to see pre-release versions

1. **Initial state**: `include_prerelease = false`
   ```lua
   require('dependencies').setup({
     include_prerelease = false,
     cache_ttl = "1d"
   })
   ```
   - Opens `build.sbt`: Queries Maven, gets stable versions
   - Cache stores: `latest = "0.14.15"` (string)

2. **User changes config**: `include_prerelease = true`
   ```lua
   require('dependencies').setup({
     include_prerelease = true,  -- Changed!
     cache_ttl = "1d"
   })
   ```
   - Reopens `build.sbt`: Cache detected as invalid (setting changed)
   - Queries Maven again (ignores cache)
   - Cache updated: `latest = ["0.14.15", "0.14.0-M7", "0.15.0-M1"]` (table)

3. **User changes back**: `include_prerelease = false`
   - Cache invalid again (setting changed back)
   - Queries Maven, gets stable version only
   - Cache updated: `latest = "0.14.15"` (string)

## Test Coverage

Created comprehensive test script: `test_prerelease_cache_invalidation.lua`

**Test Cases:**
1. ✅ Save cache with `include_prerelease = false`
2. ✅ Verify cache valid with same value (false)
3. ✅ Verify cache invalidated when changed to true
4. ✅ Save cache with `include_prerelease = true`
5. ✅ Verify cache valid with same value (true)
6. ✅ Verify cache invalidated when changed to false

**Run tests:**
```bash
./test_prerelease_cache_invalidation.lua
```

**Expected output:**
```
✅ TODOS LOS TESTS PASARON
```

## Benefits

1. **Consistency**: Cache always matches current configuration
2. **Automatic**: No manual cache clearing required
3. **User-friendly**: Changes take effect immediately
4. **Transparent**: Users don't need to understand cache mechanics
5. **Reliable**: Test coverage prevents regression

## Impact

- **Breaking change**: No (backward compatible, gracefully handles old cache format)
- **Performance**: Minimal (one additional boolean comparison)
- **User experience**: Improved (automatic cache invalidation)
- **Data integrity**: Enhanced (cache matches configuration)

## Related Documentation

- `CONFIGURATION.md` - Complete configuration guide
- `AGENTS.md` - Project handover document
- `VERSION_CHANGE_CACHE_FIX.md` - Related cache fix documentation
- `UNKNOWN_VERSION_FIX.md` - Version display fix documentation

