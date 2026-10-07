# ETL Personas: Excel → modelo relacional → DW

Actividad de ETL con SQL Server y SSIS. Se leen 1000 registros de un Excel, se validan y tratan, se cargan en un modelo relacional (`PersonasETL`) y luego en un DW en estrella (`PersonasDW`).

## Integrantes

- Jhohan Tellez
- Andrey Lopez
- Juan David Garzon

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `sql/` | Scripts: modelo relacional, diagnóstico, cursor, DW y consultas de verificación |
| `ssis/PersonasETL/` | Proyecto de Visual Studio con `PaqueteA` (Excel → modelo relacional) y `PaqueteB` (modelo → DW) |

## Requisitos

- SQL Server (instancia `JHOHAN\SQLEXPRESS`) y SSMS
- Visual Studio con la extensión SQL Server Integration Services Projects
- Carpeta `C:\ETL` creada en el equipo: `PaqueteA` guarda allí el archivo intermedio `validas.raw`
- Proyecto configurado con `Run64BitRuntime = False` (por el origen de Excel)

## Orden de ejecución

1. Ejecutar `sql/modelo_relacional.sql`: crea `PersonasETL` con catálogos, `Persona`, `Empleador`, `Observacion` y tablas de control.
2. Ejecutar `sql/personasDW.sql`: crea la base `PersonasDW` con las dimensiones y el hecho.
3. Cargar el Excel a `StagingETL` (copia fiel en texto, usada por el diagnóstico y el cursor).
4. Ejecutar `sql/diagnostico.sql` y `sql/cursor.sql` (filas 1 a 100: 81 aceptados, 19 rechazados).
5. Ejecutar `PaqueteA.dtsx`. Resultado esperado: 178 rechazadas, 353 en revisión, 36 duplicadas y 433 cargadas (suma 1000).
6. Ejecutar `PaqueteB.dtsx`. Resultado esperado: 433 filas en `FactObservacion`.
7. Ejecutar `sql/Consultas_verificaciones.sql` para comprobar los conteos.
8. Ejecutar ambos paquetes una segunda vez: los conteos no deben cambiar (sin duplicados).

## Notas

- Todo el tratamiento se hace con componentes nativos de SSIS, sin Script Component.
- Los valores desconocidos (`SIN-DATO`, `ND`, etc.) quedan en `NULL`; no se inventan datos.
- `RechazoETL` refleja la última ejecución. `LogETL` guarda los cambios aplicados (71 registros).