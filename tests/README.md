# Tests

Este directorio contiene los tests de integración y unitarios para el plugin dependencies.nvim.

## Estructura

- `lua/tests/parser_spec.lua` - Tests para el parser de dependencias de build.sbt
- `lua/tests/maven_spec.lua` - Tests para la integración con Maven Central API
- `run_maven_test.sh` - Script para ejecutar los tests de Maven

## Ejecutar tests

### Tests de Maven (Integración con Maven Central)

```bash
./tests/run_maven_test.sh
```

Este test:
- ✅ Verifica el formato de salida `[{line, dependency, latest}]`
- ✅ Prueba la consulta real a Maven Central API
- ✅ Maneja dependencias malformadas
- ✅ Verifica múltiples dependencias
- ✅ Comprueba que los campos se preservan correctamente

### Tests de Parser

```bash
nvim --headless -c "set runtimepath+=." -c "luafile lua/tests/parser_spec.lua" -c "qa"
```

## Requisitos

- Neovim instalado
- Conexión a internet para tests de integración con Maven Central
- curl instalado (para las requests a Maven Central)

## Salida esperada

Cuando los tests pasan, verás:

```
=== Maven Integration Tests ===
✓ enrich_with_latest_versions returns correct format
✓ enrich_with_latest_versions handles empty input
✓ fetch latest version for known Scala library
...

=== Test Summary ===
Tests passed: 11
Tests failed: 0
Total tests: 11

✅ All tests passed!
```

## Notas

- Los tests de Maven hacen requests reales a Maven Central, por lo que pueden fallar si hay problemas de red
- Los tests marcan con ⚠️ cuando no se puede conectar a Maven Central
- El módulo `test_helper.lua` proporciona funciones comunes para todos los tests

