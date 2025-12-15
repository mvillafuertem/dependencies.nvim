-- Check where modules are being loaded from

package.loaded['dependencies.maven'] = nil

-- Check package.path
print("=== package.path ===")
print(package.path)
print()

-- Try to find where maven.lua would be loaded from
print("=== Searching for maven.lua in package.path ===")
for path in package.path:gmatch("[^;]+") do
  local file_path = path:gsub("%?", "dependencies/maven")
  local f = io.open(file_path, "r")
  if f then
    print("✓ FOUND: " .. file_path)
    -- Read first few lines to verify it's the right file
    local content = f:read("*all")
    f:close()

    if content:match("DEBUG maven%.lua") then
      print("  → Contains DEBUG line ✓")
    else
      print("  → Does NOT contain DEBUG line ✗")
    end
  end
end

print()
print("=== Loading maven module ===")
local maven = require('dependencies.maven')

-- Check where it was loaded from
local info = debug.getinfo(maven.enrich_with_latest_versions, "S")
print("maven.enrich_with_latest_versions loaded from:")
print("  " .. info.source)

