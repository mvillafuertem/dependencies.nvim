#!/usr/bin/env -S nvim -l

-- Diferentes formas de imprimir los iconos de nvim-web-devicons

print("=== Método 1: vim.inspect (formato legible) ===")
local icons = require'nvim-web-devicons'.get_icons()
print(vim.inspect(icons))

print("\n=== Método 2: Iterar y mostrar cada icono ===")
for name, icon_data in pairs(icons) do
  print(string.format("%s: %s (color: %s, cterm: %s)",
    name,
    icon_data.icon,
    icon_data.color or "N/A",
    icon_data.cterm_color or "N/A"
  ))
end

print("\n=== Método 3: Contar total de iconos ===")
local count = 0
for _ in pairs(icons) do
  count = count + 1
end
print(string.format("Total de iconos: %d", count))

print("\n=== Método 4: Mostrar algunos ejemplos específicos ===")
local examples = {"lua", "vim", "js", "ts", "py", "rb"}
for _, ext in ipairs(examples) do
  local icon = icons[ext]
  if icon then
    print(string.format(".%s → %s %s", ext, icon.icon, icon.name))
  end
end

