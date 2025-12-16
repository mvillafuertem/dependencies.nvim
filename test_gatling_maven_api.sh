#!/bin/bash

# Test script to query Maven Central directly for Gatling versions
# User reports: Plugin shows 3.13.5 when build.sbt has 3.14.9

echo "=== Gatling Maven Central API Test ==="
echo ""

GROUP="io.gatling.highcharts"
ARTIFACT="gatling-charts-highcharts"
CURRENT="3.14.9"

echo "Testing: $GROUP:$ARTIFACT"
echo "Current version in build.sbt: $CURRENT"
echo ""

# Convert group ID to URL path (replace dots with slashes)
GROUP_PATH=$(echo "$GROUP" | tr '.' '/')

# Test 1: Query maven-metadata.xml
echo "--- Test 1: maven-metadata.xml (Primary Source) ---"
METADATA_URL="https://repo1.maven.org/maven2/${GROUP_PATH}/${ARTIFACT}/maven-metadata.xml"
echo "URL: $METADATA_URL"
echo ""

METADATA=$(curl -s "$METADATA_URL")
echo "$METADATA" | head -40
echo ""

# Extract latest version from XML (compatible with macOS grep)
LATEST_XML=$(echo "$METADATA" | grep '<latest>' | sed 's/.*<latest>\(.*\)<\/latest>.*/\1/')
echo "Latest version (from <latest> tag): $LATEST_XML"
echo ""

# Extract release version from XML
RELEASE_XML=$(echo "$METADATA" | grep '<release>' | sed 's/.*<release>\(.*\)<\/release>.*/\1/')
echo "Release version (from <release> tag): $RELEASE_XML"
echo ""

# Extract all versions (last 20)
echo "All versions (last 20):"
echo "$METADATA" | grep '<version>' | sed 's/.*<version>\(.*\)<\/version>.*/\1/' | tail -20
echo ""

# Test 2: Query Solr Search API
echo "--- Test 2: Solr Search API (Fallback) ---"
SOLR_URL="https://search.maven.org/solrsearch/select?q=g:${GROUP}+AND+a:${ARTIFACT}&rows=1&wt=json"
echo "URL: $SOLR_URL"
echo ""

SOLR_RESPONSE=$(curl -s "$SOLR_URL")
LATEST_SOLR=$(echo "$SOLR_RESPONSE" | jq -r '.response.docs[0].latestVersion // "not found"')
echo "Latest version (from Solr): $LATEST_SOLR"
echo ""

# Analysis
echo "=== Analysis ==="
echo "Current version in build.sbt: $CURRENT"
echo "Latest from maven-metadata.xml: $LATEST_XML"
echo "Latest from Solr API: $LATEST_SOLR"
echo ""

if [[ "$LATEST_XML" == "$CURRENT" ]]; then
  echo "✅ maven-metadata.xml shows CORRECT version: $LATEST_XML"
  echo "   User is on the latest stable release"
  echo ""
fi

if [[ "$LATEST_SOLR" == "3.13.5" ]]; then
  echo "⚠️  ISSUE CONFIRMED: Solr Search API has STALE data!"
  echo "    Solr shows: 3.13.5"
  echo "    Actual latest: $LATEST_XML"
  echo "    Lag: Solr is behind by $(($CURRENT - $LATEST_SOLR)) versions"
  echo ""
  echo "    This is exactly like the netty-tcnative issue we fixed!"
  echo "    The plugin should use maven-metadata.xml (primary source)"
  echo "    and fall back to Solr only if XML fails."
  echo ""
elif [[ "$LATEST_SOLR" == "$LATEST_XML" ]]; then
  echo "✅ Solr Search API is up to date: $LATEST_SOLR"
else
  echo "⚠️  Version mismatch between sources:"
  echo "    XML: $LATEST_XML"
  echo "    Solr: $LATEST_SOLR"
fi

echo ""
echo "=== Root Cause ==="
echo "The plugin is likely using Solr Search API which has indexing lag."
echo "Solution: Ensure plugin prioritizes maven-metadata.xml over Solr."
echo ""
echo "=== Test Complete ==="

