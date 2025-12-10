local parser = require("dependencies.parser")
local uv = vim.loop

describe("SBT dependency parser", function()
	local function parse(input)
		-- Create a temporary file
		local tmpfile = uv.fs_mkstemp("test_scala_XXXXXX")
		local fd = uv.fs_open(tmpfile, "w", 438) -- 438 is octal for 0666 permissions
		uv.fs_write(fd, input)
		uv.fs_close(fd)
		-- Parse the temporary file
		vim.cmd(string.format("edit %s", tmpfile))
		vim.bo.filetype = "scala"
		local deps = parser.parse_dependencies(0)
		vim.cmd("bwipeout!")
		uv.fs_unlink(tmpfile)
		return deps
	end

	it("parses simple % deps", function()
		local deps = parse([[
     "io.circe" % "circe-core" % "0.14.1"
   ]])
		assert.same({
			{ org = "io.circe", artifact = "circe-core", version = "0.14.1" },
		}, deps)
	end)

	it("handles version variables", function()
		local deps = parse([[
     val v = "1.2.3"
     "a.b" %% "c" % v
   ]])
		assert.same({
			{ org = "a.b", artifact = "c", version = "1.2.3" },
		}, deps)
	end)

	it("handles map(_ % version)", function()
		local deps = parse([[
     Seq("org" % "a") .map(_ % "9.9.9")
   ]])
		assert.same({
			{ org = "org", artifact = "a", version = "9.9.9" },
		}, deps)
	end)
end)
