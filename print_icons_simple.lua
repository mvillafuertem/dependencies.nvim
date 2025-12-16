#!/usr/bin/env -S nvim -l

-- Forma simple de imprimir todos los iconos con mejor formato

local icons = require'nvim-web-devicons'.get_icons()

print("╔════════════════════════════════════════════════════════════════════════════════╗")
print("║                        ICONOS DISPONIBLES EN NVIM                              ║")
print("╚════════════════════════════════════════════════════════════════════════════════╝\n")

-- Ordenar por nombre
local sorted = {}
for name, data in pairs(icons) do
  -- Convertir a string para ordenar (algunos nombres pueden ser números)
  table.insert(sorted, {name = tostring(name), data = data})
end
table.sort(sorted, function(a, b) return a.name < b.name end)

-- Encabezado de columnas
print(string.format("  %-25s  %-8s  %-35s  %s",
  "EXTENSIÓN",
  "ICONO",
  "NOMBRE",
  "COLOR"
))
print("  " .. string.rep("─", 80))

-- Imprimir cada uno con mejor espaciado
for _, item in ipairs(sorted) do
  local name = item.name
  local data = item.data

  -- Icono más grande con espacios extra
  local icon_display = "  " .. data.icon .. "  "

  -- Formato indentado con columnas alineadas
  print(string.format("  %-25s  %-8s  %-35s  %s",
    name,
    icon_display,
    data.name,
    data.color or "#FFFFFF"
  ))
end

print("\n  " .. string.rep("─", 80))
print(string.format("  Total: %d iconos disponibles\n", #sorted))

