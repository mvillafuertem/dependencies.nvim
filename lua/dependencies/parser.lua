local query_mod = require("dependencies.query")
local M = {}

-- Extrae un string eliminando comillas
local function strip_quotes(str)
	return str:gsub('^"(.*)"$', "%1")
end

-- Convierte node TS a string
local function node_text(bufnr, node)
	return vim.treesitter.get_node_text(node, bufnr)
end

-- Resuelve variables de versión: val x = "1.0"
local function extract_variables(bufnr)
	local vars = {}
	local root = vim.treesitter.get_parser(bufnr, "scala"):parse()[1]:root()
	for id, node in root:iter_children() do
		if node:type() == "val_declaration" then
			local name = node:child(1)
			local value = node:child(node:child_count() - 1)
			if name and value then
				value = strip_quotes(node_text(bufnr, value))
				vars[node_text(bufnr, name)] = value
			end
		end
	end
	return vars
end

-- Parser principal
function M.parse_dependencies(bufnr)
	local deps = {}
	local parser = vim.treesitter.get_parser(bufnr, "scala")
	local tree = parser:parse()[1]
	local root = tree:root()
	local query = vim.treesitter.query.parse("scala", query_mod.query)
	-- Primero resolvemos variables
	local variables = extract_variables(bufnr)
	-- Búsqueda de dependencias
	for id, captures, metadata in query:iter_matches(root, bufnr) do
		local org = captures[1]
		local op = captures[2]
		local art = captures[3]
		local version = captures[5]
		if org and art then
			org = strip_quotes(node_text(bufnr, org))
			art = strip_quotes(node_text(bufnr, art))
			local v = nil
			if version then
				local raw = node_text(bufnr, version)
				v = strip_quotes(raw)
				v = variables[v] or v
			end
			table.insert(deps, {
				org = org,
				artifact = art,
				version = v,
			})
		end
	end
	return deps
end

return M
