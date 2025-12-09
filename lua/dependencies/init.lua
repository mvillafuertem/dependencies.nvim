print("Hola dependencies")

vim.treesitter.query.set(
	"scala",
	"dependencies",
	[[
    (call_expression
     function: (field_expression
                 value: (call_expression
                          function: (identifier) @_seq
                          arguments: (arguments
                            (infix_expression
                              left: (string) @organization
                              operator: (operator_identifier) @op.org_art
                              right: (string) @artifact
                              (#any-of? @op.org_art "%" "%%"))))
                 field: (identifier) @_map)
     arguments: (arguments
                  (infix_expression
                    left: (wildcard)
                    operator: (operator_identifier) @op.version_op
                    right: (_) @version
                    (#eq? @op.version_op "%"))) ;; solo el primer %
     (#eq? @_seq "Seq")
     (#eq? @_map "map")
    )
  ]]
)

local group = vim.api.nvim_create_augroup("dependencies", {})

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
	pattern = "build.sbt",
	group = group,
	callback = function(event)
		-- Paso 1: Imprimir detalles del evento
		print("Detalles del evento:", vim.inspect(event))

		-- Paso 2: Obtener la query para dependencies en Scala
		local query = vim.treesitter.query.get("scala", "dependencies")

		if not query then
			print("No se encontró la query para Scala dependencies")
			return
		end

		print("Query obtenida:", vim.inspect(query))

		-- Paso 3: Parsear el árbol sintáctico de Treesitter
		local parser = vim.treesitter.get_parser(event.buf, "scala")
		local tree = parser:parse()[1]
		local root = tree:root()

		print("Árbol sintáctico raíz:", vim.inspect(root))

		-- Paso 4: Iterar sobre los matches de la query
		for match, pattern_id, metadata in query:iter_matches(root, event.buf, 0, -1) do
			print("Tipo de 'match':", type(match))
			print("Contenido de 'match':", vim.inspect(match))
			print("Pattern ID:", vim.inspect(pattern_id))
			print("Metadata:", vim.inspect(metadata))
			for id, node_capture, node_meta in query:iter_captures(root, event.buf, 0, -1) do
				local capture_name = query.captures[id] -- Capturar nombre de cada identidad
				print("Capture ID:", id, "Nombre:", capture_name)

				-- Intenta obtener texto del nodo
				local node_text = vim.treesitter.get_node_text(node_capture, event.buf)
				print("Texto capturado para", capture_name, ":", node_text)
			end
		end

		local dependencies = {}
		local current_dependency = { organization = nil, artifact = nil, version = nil }

		for id, node_capture, node_meta in query:iter_captures(root, event.buf, 0, -1) do
			local capture_name = query.captures[id]
			local captured_text = vim.treesitter.get_node_text(node_capture, event.buf)

			if capture_name == "organization" then
				current_dependency.organization = captured_text
			elseif capture_name == "artifact" then
				current_dependency.artifact = captured_text
			elseif capture_name == "version" then
				current_dependency.version = captured_text
			end

			-- Cuando todos los valores han sido capturados, construimos la cadena y la guardamos
			if current_dependency.organization and current_dependency.artifact and current_dependency.version then
				table.insert(
					dependencies,
					string.format(
						"%s:%s:%s",
						current_dependency.organization,
						current_dependency.artifact,
						current_dependency.version
					)
				)
				-- Reiniciar la captura para la siguiente dependencia
				current_dependency = { organization = nil, artifact = nil, version = nil }
			end
		end

		-- Imprimir las dependencias capturadas
		for _, dependency in ipairs(dependencies) do
			print("Dependency:", dependency)
		end
	end,
})
