#!/usr/bin/env -S nvim -l

-- Script para mostrar iconos de nvim-web-devicons de forma visual

local icons = require'nvim-web-devicons'.get_icons()

-- Crear un buffer temporal para mostrar los iconos
vim.cmd('new')
local buf = vim.api.nvim_get_current_buf()

-- Configurar el buffer como temporal y no modificable
vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
vim.api.nvim_buf_set_option(buf, 'swapfile', false)

-- Preparar las líneas para mostrar
local lines = {
  "=== Iconos de nvim-web-devicons ===",
  "",
  "Formato: extensión → icono nombre (color)",
  "",
}

-- Recopilar y ordenar las extensiones
local sorted_names = {}
for name, _ in pairs(icons) do
  table.insert(sorted_names, name)
end
table.sort(sorted_names)

-- Agregar cada icono a las líneas
for _, name in ipairs(sorted_names) do
  local icon_data = icons[name]
  local line = string.format("%s → %s %s (color: %s)",
    name,
    icon_data.icon,
    icon_data.name,
    icon_data.color or "N/A"
  )
  table.insert(lines, line)
end

-- Agregar estadísticas al final
table.insert(lines, "")
table.insert(lines, string.format("Total de iconos: %d", #sorted_names))

-- Escribir las líneas al buffer
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
vim.api.nvim_buf_set_option(buf, 'modifiable', false)

-- Mostrar mensaje
print(string.format("✓ Mostrando %d iconos en el buffer", #sorted_names))

