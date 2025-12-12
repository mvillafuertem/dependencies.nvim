# Tests para Detección de Versión de Scala

## Problema Identificado

Las librerías de Scala como `io.circe:circe-core`, `io.circe:circe-generic`, `io.circe:circe-parser` y `com.github.jwt-scala:jwt-circe` están devolviendo `unknown` porque no se está detectando correctamente la versión de Scala desde el `build.sbt`.

## Cambios Realizados

### 1. Fix en `lua/dependencies/parser.lua`

Se corrigió la función `find_scala_version` que tenía un bug en la lógica de iteración:

**Antes (con bug):**
```lua
for id, node in scala_version_query:iter_captures(root, bufnr, 0, -1) do
  if capture_name == "scala_version_name" then
    local name = vim.treesitter.get_node_text(node, bufnr)
    if name == "scalaVersion" then
      -- ❌ Esto creaba un NUEVO iterador, no funcionaba
      local next_id, next_node = scala_version_query:iter_captures(root, bufnr, 0, -1)()
      ...
    end
  end
end
```

**Después (corregido):**
```lua
local current_match = {}

for id, node in scala_version_query:iter_captures(root, bufnr, 0, -1) do
  local capture_name = scala_version_query.captures[id]

  if capture_name == "scala_version_name" then
    current_match.name = vim.treesitter.get_node_text(node, bufnr)
  elseif capture_name == "scala_version_value" then
    current_match.value = get_node_text_without_quotes(node, bufnr)

    -- ✅ Cuando tenemos ambos, verificar y retornar
    if current_match.name == "scalaVersion" and current_match.value then
      return extract_scala_binary_version(current_match.value)
    end

    -- Resetear para el siguiente match
    current_match = {}
  end
end
```

### 2. Tests Añadidos en `lua/tests/parser_spec.lua`

Se añadieron 8 nuevos tests para verificar la detección de `scalaVersion`:

- ✅ Detección con operador `:=`
- ✅ Scala 2.12, 2.13, 3.x
- ✅ Build.sbt complejo
- ✅ ScalaVersion al final del archivo
- ✅ Comillas simples y dobles
- ✅ Ignorar líneas comentadas
- ✅ Retornar `nil` cuando no hay scalaVersion

### 3. Tests Añadidos en `lua/tests/maven_spec.lua`

Se añadieron 6 nuevos tests para verificar la integración con Maven Central:

- ✅ Librerías Scala con sufijo `_2.13`
- ✅ Librerías Java sin sufijo (fallback)
- ✅ Diferentes versiones de Scala (2.12, 2.13)
- ✅ Retrocompatibilidad sin scala_version
- ✅ Múltiples dependencias mixtas
- ✅ Scala 3 con sufijo `_3`

## Cómo Verificar el Fix

### Opción 1: Test Manual en Neovim (Recomendado)

1. Abre tu archivo `build.sbt` en Neovim
2. Ejecuta el comando:
   ```vim
   :SbtDepsLatest
   ```

3. Deberías ver en la salida:
   ```
   Detectada versión de Scala: 2.13
   Consultando Maven Central para obtener últimas versiones...
   ```

4. Las librerías de Scala ahora deberían mostrar versiones en lugar de `unknown`:
   ```
   33: io.circe:circe-core:0.14.1 -> latest: 0.14.10
   34: io.circe:circe-generic:0.14.1 -> latest: 0.14.10
   35: io.circe:circe-parser:0.14.1 -> latest: 0.14.10
   23: com.github.jwt-scala:jwt-circe:9.4.5 -> latest: 10.0.1
   ```

### Opción 2: Script de Test de Detección de Scala

```bash
cd /Users/miguel.villafuerte/gbg/dependencies.nvim
nvim --headless -c "set rtp+=." -c "luafile test_scala_version.lua" -c "qa"
```

Este script prueba:
- ✅ `scalaVersion := "2.13.10"` → debería detectar `2.13`
- ✅ `scalaVersion := "2.12.18"` → debería detectar `2.12`
- ✅ `scalaVersion := "3.3.1"` → debería detectar `3.3`
- ✅ Build.sbt complejo → debería encontrar scalaVersion
- ✅ Sin scalaVersion → debería retornar `nil`

### Opción 3: Script de Test de Maven Central

```bash
cd /Users/miguel.villafuerte/gbg/dependencies.nvim
nvim --headless -c "set rtp+=." -c "luafile test_maven_central.lua" -c "qa"
```

Este script verifica las consultas reales a Maven Central:
- ✅ `io.circe:circe-core_2.13` → debería encontrar versión
- ✅ `com.github.jwt-scala:jwt-circe_2.13` → debería encontrar versión
- ✅ `com.typesafe:config` (Java) → debería funcionar sin sufijo

## Debug Manual

Si aún no funciona, puedes debuggear manualmente:

1. Abre `build.sbt` en Neovim
2. Ejecuta en modo comando:
   ```vim
   :lua print(require('dependencies.parser').get_scala_version(vim.api.nvim_get_current_buf()))
   ```

3. Debería imprimir: `2.13` (o la versión que tengas en tu build.sbt)
4. Si imprime `nil`, el problema está en la detección
5. Si imprime la versión correcta pero las librerías siguen en `unknown`, el problema está en Maven Central

## Por Qué Necesitamos la Versión de Scala

Maven Central almacena las librerías Scala con sufijos de versión:

- ❌ `io.circe:circe-core:0.14.1` → No existe en Maven Central
- ✅ `io.circe:circe-core_2.13:0.14.1` → Existe

Las librerías Java NO necesitan el sufijo:

- ✅ `com.typesafe:config:1.4.2` → Existe sin sufijo

Por eso es crítico detectar la versión de Scala correctamente.

## Conclusión

El fix en `find_scala_version` debería resolver el problema. La función ahora:

1. ✅ Acumula ambos valores (`name` y `value`) en un objeto temporal
2. ✅ Verifica que el `name` sea exactamente `"scalaVersion"`
3. ✅ Extrae la versión binaria correctamente (`2.13.10` → `2.13`)
4. ✅ Resetea el match para búsquedas subsecuentes

Por favor ejecuta `:SbtDepsLatest` en tu build.sbt y verifica que ahora detecte la versión de Scala y muestre las versiones correctas para las librerías de Scala.

