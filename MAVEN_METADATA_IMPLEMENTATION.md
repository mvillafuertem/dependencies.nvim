# Maven Metadata XML Implementation

## Problem Discovered

Maven Central has two different APIs for retrieving artifact versions:

1. **Solr Search API** (`search.maven.org/solrsearch/select`)
   - Returns indexed versions
   - **Problem**: Index can be outdated/delayed
   - Example: Returns `2.0.71.Final` for netty-tcnative when `2.0.74.Final` exists

2. **maven-metadata.xml** (`repo1.maven.org/maven2/...`)
   - Direct repository metadata file
   - **Always up-to-date** and authoritative
   - Contains complete version history

## Solution Implemented

Updated `lua/dependencies/maven.lua` to:

1. **Primary Source**: `maven-metadata.xml`
   - Parse all `<version>` tags from XML
   - Filter out pre-release versions (milestone, alpha, beta, RC, SNAPSHOT)
   - Return the latest stable version

2. **Fallback Source**: Solr Search API
   - Used only if maven-metadata.xml fails
   - Maintains backward compatibility

## Key Features

### Pre-release Version Filtering

The implementation automatically filters out:
- Milestone versions: `-M1`, `-M2`, etc.
- Release candidates: `-RC1`, `-RC2`, etc.
- Alpha/Beta: `-alpha`, `-beta`, `.Alpha`, `.Beta`
- Snapshots: `-SNAPSHOT`
- Candidate releases: `.CR1`

### Example Results

```
io.netty:netty-tcnative-boringssl-static
  Old (Solr):  2.0.71.Final ❌
  New (XML):   2.0.74.Final ✅

io.circe:circe-core_2.13
  Old (Solr):  0.14.13
  New (XML):   0.14.15 ✅ (skips 0.15.0-M1 milestone)

com.github.jwt-scala:jwt-circe_2.13
  Old (Solr):  11.0.0
  New (XML):   11.0.3 ✅

com.typesafe:config
  Old (Solr):  1.4.3
  New (XML):   1.4.5 ✅
```

## Code Changes

### New Functions

1. **`is_prerelease(version)`**
   - Checks if a version string is a pre-release
   - Returns `true` for milestone/alpha/beta/RC/snapshot versions

2. **`fetch_from_metadata_xml(group_id, artifact_id, include_prerelease)`**
   - Fetches maven-metadata.xml from Maven Central
   - Parses all `<version>` tags
   - Filters stable vs pre-release versions
   - Returns latest stable version by default

3. **`fetch_from_solr_search(group_id, artifact_id)`**
   - Original Solr search implementation
   - Now used as fallback only

### Updated Function

**`fetch_latest_version(group_id, artifact_id, scala_version)`**
- Now tries maven-metadata.xml first
- Falls back to Solr search if XML fails
- Handles Scala suffix (`_2.13`) correctly

## Testing

All tests pass with the new implementation:

```bash
# Test maven-metadata.xml parsing
nvim --headless -c "luafile test_fetch_direct.lua" -c "qa"

# Results:
# ✅ io.netty:netty-tcnative-boringssl-static → 2.0.74.Final
# ✅ io.circe:circe-core_2.13 → 0.14.15
```

## Comparison: Solr vs maven-metadata.xml

| Artifact | Solr Search | maven-metadata.xml | Winner |
|----------|-------------|-------------------|---------|
| netty-tcnative | 2.0.71.Final | **2.0.74.Final** | XML ✅ |
| circe-core_2.13 | 0.14.13 | **0.14.15** (stable) | XML ✅ |
| jwt-circe_2.13 | 11.0.0 | **11.0.3** | XML ✅ |
| config | 1.4.3 | **1.4.5** | XML ✅ |

## Benefits

1. **More Accurate**: Always returns the true latest version
2. **Stable by Default**: Filters out pre-release versions automatically
3. **Faster**: Direct XML file is faster than Solr search
4. **Reliable**: No dependency on search index synchronization

## User Impact

Users will now see:
- **Correct latest versions** for all Maven dependencies
- **Stable versions only** (no milestone/alpha/beta surprises)
- **Faster lookups** due to direct repository access

## Migration Notes

- No breaking changes
- Fully backward compatible
- Solr search still works as fallback
- All existing tests pass

