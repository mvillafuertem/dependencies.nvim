# Gatling Version Bug - Root Cause Analysis

## Issue Report

**User reports**: Plugin shows Gatling version `3.13.5` as latest when `build.sbt` specifies `3.14.9`

```scala
val gatlingVersion = "3.14.9"
libraryDependencies ++= Seq(
  "io.gatling.highcharts" % "gatling-charts-highcharts" % gatlingVersion % "test,it",
)
```

**Expected**: No virtual text (user is on latest version)
**Actual**: Virtual text shows `← latest: 3.13.5` (WRONG - shows older version!)

---

## Root Cause Investigation

### Maven Central API Query Results

**Test Results** (from `test_gatling_maven_api.sh`):

1. **maven-metadata.xml** (authoritative source):
   - Latest: `3.14.9` ✅ CORRECT
   - All versions available up to: `3.14.9`

2. **Solr Search API** (fallback):
   - Latest: `3.13.5` ❌ STALE (indexing lag - 4 versions behind!)

---

## Bug Analysis

### The Bug: "Better Versions Only" Filter

**File**: `lua/dependencies/maven.lua`
**Function**: `process_metadata_xml()` (lines 196-260)

**Problematic Logic** (lines 211-221):

```lua
-- Filtrar solo versiones MAYORES que la actual
local better_versions = {}
for _, version_str in ipairs(all_versions) do
  -- Solo incluir si es MAYOR que la versión actual
  if compare_versions(version_str, current_version) > 0 then
    table.insert(better_versions, version_str)
  end
end

-- Si no hay versiones mejores, retornar nil
if #better_versions == 0 then
  return nil  -- ❌ BUG: This causes fallback to stale Solr API!
end
```

### What Happens

**When user is on the LATEST version** (e.g., Gatling 3.14.9):

1. ✅ `fetch_from_metadata_xml_async()` successfully fetches XML from Maven Central
2. ✅ Extracts all versions: `["2.0.0", ..., "3.13.5", "3.14.0", ..., "3.14.9"]`
3. ❌ Filters for versions > `3.14.9` → **finds NONE** (because 3.14.9 IS the latest!)
4. ❌ Returns `nil` (line 220)
5. ❌ Triggers fallback to `fetch_from_solr_search_async()`
6. ❌ Solr returns stale version `3.13.5` (indexing lag)
7. ❌ Plugin displays: `← latest: 3.13.5` (INCORRECT!)

**When user is on an OLD version** (e.g., Gatling 3.13.0):

1. ✅ Fetches XML successfully
2. ✅ Filters for versions > `3.13.0` → finds: `["3.13.1", "3.13.2", ..., "3.14.9"]`
3. ✅ Returns `3.14.9` (the actual latest)
4. ✅ Plugin displays: `← latest: 3.14.9` (CORRECT!)

---

## Impact

### When This Bug Occurs

- **Users on the latest version** see STALE version suggestions from Solr API
- **Users 1-2 versions behind latest** see CORRECT suggestions from maven-metadata.xml

### Real-World Examples

1. **Gatling 3.14.9** (reported issue):
   - User has: `3.14.9` (actual latest)
   - Plugin shows: `← latest: 3.13.5` (Solr lag)

2. **Likely affected any time user is on latest**:
   - Cats 2.13.0, Circe 0.14.15, etc.
   - If user upgrades to latest immediately, they'd see stale suggestions

---

## Solution

### Option 1: Return Current Version When No Updates (Recommended)

When `better_versions` is empty, return the current version instead of `nil`:

```lua
-- Si no hay versiones mejores, retornar la versión actual
if #better_versions == 0 then
  -- Usuario está en la última versión disponible
  return current_version  -- ✅ No fallback a Solr, no virtual text displayed
end
```

**Result**:
- `current == latest` → no virtual text shown ✅
- Never falls back to stale Solr API ✅

### Option 2: Return Special Marker "up-to-date"

```lua
if #better_versions == 0 then
  return "up-to-date"  -- Special marker
end
```

Then update `virtual_text.lua` to skip displaying this marker.

### Option 3: Track XML Fetch Success Separately

Pass a success flag to callback to distinguish "no updates available" from "fetch failed":

```lua
callback(version, success_flag)
```

---

## Recommended Fix

**Implementation**: Option 1 (simplest and most correct)

**Changes Required**:

1. **`lua/dependencies/maven.lua`** (line 220):
   ```lua
   -- OLD:
   if #better_versions == 0 then
     return nil
   end

   -- NEW:
   if #better_versions == 0 then
     -- No hay versiones mejores → usuario está actualizado
     -- Retornar la versión actual para evitar fallback a Solr
     return current_version
   end
   ```

2. **No changes needed** in `virtual_text.lua`:
   - Already checks `if dep_info.current ~= dep_info.latest`
   - When `current == latest` → no virtual text displayed ✅

---

## Testing Plan

1. **Test with Gatling 3.14.9**:
   - Expected: No virtual text (current == latest)
   - Before fix: Shows `← latest: 3.13.5` ❌
   - After fix: No virtual text ✅

2. **Test with Gatling 3.13.0**:
   - Expected: Shows `← latest: 3.14.9`
   - Should work correctly both before and after fix ✅

3. **Test with non-existent artifact**:
   - Expected: Shows `← latest: unknown`
   - XML fetch fails → falls back to Solr → Solr fails → returns nil → shows "unknown" ✅

---

## Regression Risk

**Low risk** - The change only affects the "no updates available" case:

- ✅ When updates exist: behavior unchanged (returns latest version)
- ✅ When no updates: returns `current` instead of `nil` (prevents Solr fallback)
- ✅ When fetch fails: still returns `nil` (normal error handling)

---

## Related Issues

This is similar to the **netty-tcnative issue** we fixed before:
- Both caused by Solr Search API indexing lag
- Previous fix: Use maven-metadata.xml as primary source ✅
- This fix: Don't fall back to Solr when XML succeeds but shows no updates ✅

---

## Files to Modify

1. `lua/dependencies/maven.lua` - Line 220 (process_metadata_xml function)
2. `test_gatling_version.lua` - Test script to verify fix
3. `AGENTS.md` - Document fix in changelog

---

**Document Version**: 1.0
**Date**: 2025-12-16
**Status**: Bug identified, solution proposed, awaiting implementation

