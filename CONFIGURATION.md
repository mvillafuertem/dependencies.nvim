# Configuración de dependencies.nvim

Este documento describe las opciones de configuración disponibles para el plugin `dependencies.nvim`.

## Configuración Básica

### Configuración por defecto

Si no pasas ninguna opción, el plugin usará la configuración por defecto:

```lua
{
  'mvillafuertem/dependencies.nvim',
  ft = { 'scala' },
  config = function()
    require('dependencies').setup()
    -- Usará: patterns = { "build.sbt" }
  end,
}
```

## Opciones Disponibles

### `patterns` (Lista de strings)

Patrones de archivos donde el plugin buscará dependencias. Soporta patrones glob de Neovim.

**Tipo:** `table` (lista de strings)
**Default:** `{ "build.sbt" }`

### `include_prerelease` (Boolean)

Incluir versiones pre-release (alpha, beta, milestone, RC, SNAPSHOT) al buscar la última versión disponible.

**Tipo:** `boolean`
**Default:** `false` (solo versiones estables)

**Versiones pre-release detectadas:**
- Milestone: `-M1`, `-M2`, etc.
- Release Candidate: `-RC1`, `-RC2`, etc.
- Alpha: `-alpha`, `-alpha1`, `.Alpha`, etc.
- Beta: `-beta`, `-beta1`, `.Beta`, etc.
- Candidate Release: `.CR1`, `.CR2`, etc.
- Snapshot: `-SNAPSHOT`

### `virtual_text_prefix` (String)

Prefijo del texto virtual que se muestra al final de la línea cuando hay una versión más reciente disponible.

**Tipo:** `string`
**Default:** `"  ← latest: "`

**Nota:** El plugin automáticamente añade la versión después del prefijo. Por ejemplo, con el default se mostrará: `  ← latest: 1.2.3`


### `auto_check_on_open` (Boolean)

Controla si el plugin debe ejecutarse automáticamente al abrir archivos que coincidan con los patterns configurados.

**Tipo:** `boolean`
**Default:** `true`

**Comportamiento:**
- `true`: Al abrir un archivo `build.sbt` (o cualquier pattern configurado), el plugin automáticamente consulta Maven Central para obtener las últimas versiones. Usa caché para evitar consultas innecesarias.
- `false`: Debes ejecutar manualmente `:SbtDepsLatest` para consultar las versiones. Útil si prefieres control manual completo.

**Ejemplo:**
```lua
-- Deshabilitar auto-ejecución al abrir archivos
require('dependencies').setup({
  auto_check_on_open = false,  -- Requiere ejecución manual de :SbtDepsLatest
})
```

### `cache_ttl` (String)

Duración del caché para los resultados de consultas a Maven Central. El caché evita hacer múltiples consultas innecesarias a la API cuando abres el mismo archivo repetidamente.

**Tipo:** `string`
**Default:** `"1d"` (1 día)

**Formatos soportados:**
- `"30m"` = 30 minutos
- `"6h"` = 6 horas
- `"1d"` = 1 día (default)
- `"1w"` = 1 semana
- `"1M"` = 1 mes (30 días)

**Comportamiento del caché:**
- Al abrir un archivo o ejecutar `:SbtDepsLatest`, el plugin primero verifica si hay datos en caché válidos
- Si el caché existe y no ha expirado, muestra esos datos inmediatamente sin consultar Maven Central
- Si el caché ha expirado o no existe, consulta Maven Central y guarda los resultados
- Usa `:SbtDepsLatestForce` para ignorar el caché y forzar una actualización

**Ejemplos:**
```lua
-- Caché corto (útil durante desarrollo activo)
require('dependencies').setup({
  cache_ttl = "30m",  -- 30 minutos
})

-- Caché largo (útil para proyectos estables)
require('dependencies').setup({
  cache_ttl = "1w",  -- 1 semana
})

-- Sin caché práctico (siempre consultar, útil para testing)
require('dependencies').setup({
  cache_ttl = "1m",  -- 1 minuto
})
```

**Nota:** El caché es por archivo y se almacena en memoria. Si reinicias Neovim, el caché se pierde y se consultará Maven Central nuevamente.

#### Ejemplos de uso:

**1. Solo build.sbt (default):**
```lua
require('dependencies').setup({
  patterns = { "build.sbt" }
})
```

**2. Mill build tool (archivos .sc):**
```lua
require('dependencies').setup({
  patterns = { "*.sc" }
})
```

**3. Archivo de dependencias separado:**
```lua
require('dependencies').setup({
  patterns = { "Dependencies.scala" }
})
```

**4. Archivos en directorio project/:**
```lua
require('dependencies').setup({
  patterns = { "project/*.scala" }
})
```

**5. Múltiples patrones (proyecto mixto):**
```lua
require('dependencies').setup({
  patterns = {
    "build.sbt",           -- SBT
    "*.sc",                -- Mill
    "Dependencies.scala",  -- Archivo separado
    "project/*.scala",     -- Archivos en project/
  }
})
```

#### Ejemplos de uso para `include_prerelease`:

**1. Solo versiones estables (default):**
```lua
require('dependencies').setup({
  patterns = { "build.sbt" },
  include_prerelease = false,  -- default
})
-- Mostrará: 1.2.0, 2.0.0, 3.1.4, etc.
-- NO mostrará: 1.3.0-M1, 2.0.0-RC1, 1.5.0-alpha, etc.
```

**2. Incluir versiones pre-release:**
```lua
require('dependencies').setup({
  patterns = { "build.sbt" },
  include_prerelease = true,
})
-- Mostrará también: 1.3.0-M1, 2.0.0-RC1, 1.5.0-alpha, etc.
```

**3. Configuración para desarrollo activo:**
```lua
-- Útil cuando trabajas con versiones de desarrollo
require('dependencies').setup({
  patterns = { "build.sbt", "*.sc" },
  include_prerelease = true,
})
```

**4. Configuración para producción:**
```lua
-- Solo versiones estables para proyectos en producción
require('dependencies').setup({
  patterns = { "build.sbt" },
  include_prerelease = false,  -- explícito
})
```

#### Ejemplos de uso para `virtual_text_prefix`:

**1. Prefijo por defecto:**
```lua
require('dependencies').setup({
  patterns = { "build.sbt" },
  virtual_text_prefix = "  ← latest: ",  -- default
})
-- Mostrará: "org.typelevel" %% "cats-core" % "2.9.0"  ← latest: 2.10.0
```

**2. Prefijo personalizado con emoji:**
```lua
require('dependencies').setup({
  patterns = { "build.sbt" },
  virtual_text_prefix = " 🔄 ",
})
-- Mostrará: "org.typelevel" %% "cats-core" % "2.9.0" 🔄 2.10.0
```

**3. Prefijo simple sin flechas:**
```lua
require('dependencies').setup({
  patterns = { "build.sbt" },
  virtual_text_prefix = "  latest: ",
})
-- Mostrará: "org.typelevel" %% "cats-core" % "2.9.0"  latest: 2.10.0
```

**4. Prefijo con iconos Nerd Font:**
```lua
require('dependencies').setup({
  patterns = { "build.sbt" },
  virtual_text_prefix = "   ",
})
-- Mostrará: "org.typelevel" %% "cats-core" % "2.9.0"  2.10.0
```

**5. Prefijo en español:**
```lua
require('dependencies').setup({
  patterns = { "build.sbt" },
  virtual_text_prefix = "  → última: ",
})
-- Mostrará: "org.typelevel" %% "cats-core" % "2.9.0"  → última: 2.10.0
```

**6. Configuración completa personalizada:**
```lua
require('dependencies').setup({
  patterns = { "build.sbt", "*.sc" },
  include_prerelease = false,
  virtual_text_prefix = " ⬆️  ",
})
```

## Ejemplos Completos por Gestor de Build

### SBT (Scala Build Tool)

```lua
-- lazy.nvim
{
  'mvillafuertem/dependencies.nvim',
  ft = { 'scala' },
  config = function()
    require('dependencies').setup({
      patterns = { "build.sbt" }
    })
  end,
}
```

### Mill

```lua
-- lazy.nvim
{
  'mvillafuertem/dependencies.nvim',
  ft = { 'scala' },
  config = function()
    require('dependencies').setup({
      patterns = { "*.sc" }
    })
  end,
}
```

### Proyecto con Dependencias Separadas

```lua
-- lazy.nvim
{
  'mvillafuertem/dependencies.nvim',
  ft = { 'scala' },
  config = function()
    require('dependencies').setup({
      patterns = {
        "build.sbt",
        "Dependencies.scala",
        "project/Dependencies.scala",
      }
    })
  end,
}
```

### Proyecto Mixto (SBT + Mill)

```lua
-- lazy.nvim
{
  'mvillafuertem/dependencies.nvim',
  ft = { 'scala' },
  config = function()
    require('dependencies').setup({
      patterns = {
        "build.sbt",  -- SBT
        "*.sc",       -- Mill
      }
    })
  end,
}
```

## Patrones Glob Soportados

El plugin usa los patrones glob de Neovim. Ejemplos:

- `build.sbt` - Archivo específico
- `*.sc` - Todos los archivos .sc en el directorio actual
- `**/*.sc` - Todos los archivos .sc recursivamente
- `project/*.scala` - Archivos .scala en el directorio project/
- `project/**/*.scala` - Archivos .scala recursivamente en project/

## Validación de Configuración

El plugin valida automáticamente la configuración:

### Error: patterns no es una tabla
```lua
-- ❌ INCORRECTO
require('dependencies').setup({
  patterns = "build.sbt"  -- String, no tabla!
})
-- Error: "dependencies.nvim: 'patterns' debe ser una tabla/lista"
```

```lua
-- ✅ CORRECTO
require('dependencies').setup({
  patterns = { "build.sbt" }  -- Tabla con un elemento
})
```

### Warning: patterns vacía
```lua
-- ❌ INCORRECTO
require('dependencies').setup({
  patterns = {}  -- Vacía!
})
-- Warning: "dependencies.nvim: 'patterns' no puede estar vacía, usando default"
-- Usará: { "build.sbt" }
```

## Opciones Futuras (Planificadas)

Las siguientes opciones están comentadas en el código y pueden ser implementadas en futuras versiones:

```lua
require('dependencies').setup({
  patterns = { "build.sbt" },

  -- Opciones futuras:
  -- update_on_save = true,        -- Actualizar al guardar
  -- update_on_insert_leave = true, -- Actualizar al salir del modo inserción
  -- show_virtual_text = true,     -- Mostrar virtual text
  -- cache_duration = 3600,        -- Duración del cache en segundos
})
```

## Comportamiento del Plugin

Con cualquier configuración de `patterns`, el plugin:

1. **Al abrir archivo que coincida con patterns** → Consulta Maven Central automáticamente (si `auto_check_on_open = true`, default). Usa caché si está disponible y no ha expirado.
2. **En modo inserción** → Oculta el virtual text
3. **Al salir del modo inserción** → Consulta Maven Central (usa caché si está disponible) y muestra versiones actualizadas
4. **Al guardar el archivo** → Consulta Maven Central (usa caché si está disponible) y actualiza
5. **En modo normal/visual** → Muestra el virtual text con las versiones

**Sistema de Caché:**
- El caché evita consultas redundantes a Maven Central
- Por defecto dura 1 día (configurable con `cache_ttl`)
- Se almacena en memoria (se pierde al cerrar Neovim)
- Usa `:SbtDepsLatestForce` para ignorar el caché y forzar actualización

**Notas:**
- Si `auto_check_on_open = false`, debes ejecutar `:SbtDepsLatest` manualmente
- Todas las operaciones son asíncronas (no bloquean el editor)

## Comandos Disponibles

Los comandos funcionan en cualquier buffer que coincida con los `patterns` configurados:

- `:SbtDeps` - Lista todas las dependencias encontradas (sin consultar Maven)
- `:SbtDepsLatest` - Lista dependencias con últimas versiones disponibles (usa caché si está disponible)
- `:SbtDepsLatestForce` - Fuerza actualización ignorando caché (siempre consulta Maven Central)

## Soporte

Para más información, consulta:
- [README.md](README.md) - Documentación general
- [AGENTS.md](AGENTS.md) - Documentación técnica detallada

