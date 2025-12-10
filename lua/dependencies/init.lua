print("Hola dependencies")

local parser = require("dependencies.parser")
 
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
 pattern = "build.sbt",
 callback = function(ev)
   local deps = parser.parse_dependencies(ev.buf)
   print("==== DEPENDENCIAS ====")
   for _, d in ipairs(deps) do
     print(string.format("%s:%s:%s", d.org, d.artifact, d.version or "NO_VERSION"))
   end
   print("======================")
 end
})
