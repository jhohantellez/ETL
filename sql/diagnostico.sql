

-- ------------------------------------------------------------
-- Faltantes por columna (NULL, vacio y marcadores "sin dato")
-- ------------------------------------------------------------
SELECT v.Columna,
       COUNT(*) AS Total,
       SUM(CASE WHEN v.Valor IS NULL THEN 1 ELSE 0 END) AS NulosReales,
       SUM(CASE WHEN LTRIM(RTRIM(v.Valor)) = '' THEN 1 ELSE 0 END) AS Vacios,
       SUM(CASE WHEN UPPER(LTRIM(RTRIM(v.Valor))) IN ('NULL','SIN-DATO','N/A','NA','NAN','-','?','SIN DATO','ND') THEN 1 ELSE 0 END) AS Marcadores
FROM dbo.StagingETL s
CROSS APPLY (VALUES
    ('DocumentType', s.DocumentType), ('DocumentNumber', s.DocumentNumber),
    ('FirstName', s.FirstName), ('MiddleName', s.MiddleName),
    ('LastName', s.LastName), ('SecondLastName', s.SecondLastName),
    ('BirthDate', s.BirthDate), ('ReportedAge', s.ReportedAge),
    ('Sex', s.Sex), ('MaritalStatus', s.MaritalStatus),
    ('Email', s.Email), ('Phone', s.Phone),
    ('DepartmentCode', s.DepartmentCode), ('DepartmentName', s.DepartmentName),
    ('MunicipalityCode', s.MunicipalityCode), ('MunicipalityName', s.MunicipalityName),
    ('Zone', s.Zone), ('Address', s.Address),
    ('HousingType', s.HousingType), ('SocioeconomicStratum', s.SocioeconomicStratum),
    ('EducationLevel', s.EducationLevel), ('EmploymentStatus', s.EmploymentStatus),
    ('OccupationCode', s.OccupationCode), ('OccupationName', s.OccupationName),
    ('EmployerName', s.EmployerName), ('ContractType', s.ContractType),
    ('EmploymentStartDate', s.EmploymentStartDate), ('MonthlyIncome', s.MonthlyIncome),
    ('MonthlyExpenses', s.MonthlyExpenses), ('Dependents', s.Dependents),
    ('HouseholdSize', s.HouseholdSize), ('HealthRegime', s.HealthRegime),
    ('Disability', s.Disability), ('SurveyDate', s.SurveyDate),
    ('UpdatedAt', s.UpdatedAt), ('SourceChannel', s.SourceChannel)
) v(Columna, Valor)
GROUP BY v.Columna
HAVING SUM(CASE WHEN v.Valor IS NULL OR LTRIM(RTRIM(v.Valor)) = ''
                 OR UPPER(LTRIM(RTRIM(v.Valor))) IN ('NULL','SIN-DATO','N/A','NA','NAN','-','?','SIN DATO','ND')
                THEN 1 ELSE 0 END) > 0
ORDER BY v.Columna;
GO

-- ------------------------------------------------------------
-- Duplicados: resumen (misma persona y fecha de encuesta)
-- ------------------------------------------------------------
WITH d AS (
    SELECT UPPER(LTRIM(RTRIM(DocumentType)))   AS Tipo,
           UPPER(LTRIM(RTRIM(DocumentNumber))) AS Numero,
           COUNT(*) AS Filas,
           COUNT(DISTINCT LTRIM(RTRIM(SurveyDate))) AS Fechas
    FROM dbo.StagingETL
    WHERE NULLIF(LTRIM(RTRIM(DocumentNumber)), '') IS NOT NULL
      AND UPPER(LTRIM(RTRIM(DocumentNumber))) NOT IN ('SIN-DATO','NULL')
    GROUP BY UPPER(LTRIM(RTRIM(DocumentType))), UPPER(LTRIM(RTRIM(DocumentNumber)))
    HAVING COUNT(*) > 1
)
SELECT COUNT(*)                                    AS DocumentosRepetidos,
       SUM(Filas)                                  AS FilasInvolucradas,
       SUM(Filas - 1)                              AS FilasSobrantes,
       SUM(CASE WHEN Fechas = 1 THEN 1 ELSE 0 END) AS TodasMismaFecha,
       SUM(CASE WHEN Fechas > 1 THEN 1 ELSE 0 END) AS ConFechasDistintas
FROM d;
GO

-- ------------------------------------------------------------
-- Duplicados: detalle de como difieren las versiones
-- ------------------------------------------------------------
SELECT TOP 40
       SourceRowId, DocumentType, DocumentNumber, SurveyDate, UpdatedAt,
       MonthlyIncome, MonthlyExpenses, Email
FROM dbo.StagingETL
WHERE UPPER(LTRIM(RTRIM(DocumentNumber))) IN (
        SELECT UPPER(LTRIM(RTRIM(DocumentNumber)))
        FROM dbo.StagingETL
        WHERE NULLIF(LTRIM(RTRIM(DocumentNumber)), '') IS NOT NULL
          AND UPPER(LTRIM(RTRIM(DocumentNumber))) NOT IN ('SIN-DATO','NULL')
        GROUP BY UPPER(LTRIM(RTRIM(DocumentType))), UPPER(LTRIM(RTRIM(DocumentNumber)))
        HAVING COUNT(*) > 1)
ORDER BY UPPER(LTRIM(RTRIM(DocumentNumber))), SourceRowId;
GO

-- ------------------------------------------------------------
-- Duplicados: cuantos pares difieren en cada columna
-- ------------------------------------------------------------
WITH k AS (
    SELECT *,
           UPPER(LTRIM(RTRIM(DocumentType)))   AS KT,
           UPPER(LTRIM(RTRIM(DocumentNumber))) AS KN
    FROM dbo.StagingETL
    WHERE NULLIF(LTRIM(RTRIM(DocumentNumber)), '') IS NOT NULL
      AND UPPER(LTRIM(RTRIM(DocumentNumber))) NOT IN ('SIN-DATO','NULL')
)
SELECT v.Columna,
       SUM(CASE WHEN ISNULL(v.A,'~') <> ISNULL(v.B,'~') THEN 1 ELSE 0 END) AS ParesQueDifieren
FROM k a
JOIN k b ON a.KT = b.KT AND a.KN = b.KN AND a.SourceRowId < b.SourceRowId
CROSS APPLY (VALUES
    ('DocumentType', a.DocumentType, b.DocumentType),
    ('FirstName', a.FirstName, b.FirstName), ('MiddleName', a.MiddleName, b.MiddleName),
    ('LastName', a.LastName, b.LastName), ('SecondLastName', a.SecondLastName, b.SecondLastName),
    ('BirthDate', a.BirthDate, b.BirthDate), ('ReportedAge', a.ReportedAge, b.ReportedAge),
    ('Sex', a.Sex, b.Sex), ('MaritalStatus', a.MaritalStatus, b.MaritalStatus),
    ('Email', a.Email, b.Email), ('Phone', a.Phone, b.Phone),
    ('DepartmentCode', a.DepartmentCode, b.DepartmentCode), ('DepartmentName', a.DepartmentName, b.DepartmentName),
    ('MunicipalityCode', a.MunicipalityCode, b.MunicipalityCode), ('MunicipalityName', a.MunicipalityName, b.MunicipalityName),
    ('Zone', a.Zone, b.Zone), ('Address', a.Address, b.Address),
    ('HousingType', a.HousingType, b.HousingType), ('SocioeconomicStratum', a.SocioeconomicStratum, b.SocioeconomicStratum),
    ('EducationLevel', a.EducationLevel, b.EducationLevel), ('EmploymentStatus', a.EmploymentStatus, b.EmploymentStatus),
    ('OccupationCode', a.OccupationCode, b.OccupationCode), ('OccupationName', a.OccupationName, b.OccupationName),
    ('EmployerName', a.EmployerName, b.EmployerName), ('ContractType', a.ContractType, b.ContractType),
    ('EmploymentStartDate', a.EmploymentStartDate, b.EmploymentStartDate),
    ('MonthlyIncome', a.MonthlyIncome, b.MonthlyIncome), ('MonthlyExpenses', a.MonthlyExpenses, b.MonthlyExpenses),
    ('Dependents', a.Dependents, b.Dependents), ('HouseholdSize', a.HouseholdSize, b.HouseholdSize),
    ('HealthRegime', a.HealthRegime, b.HealthRegime), ('Disability', a.Disability, b.Disability),
    ('SurveyDate', a.SurveyDate, b.SurveyDate), ('UpdatedAt', a.UpdatedAt, b.UpdatedAt),
    ('SourceChannel', a.SourceChannel, b.SourceChannel)
) v(Columna, A, B)
GROUP BY v.Columna
HAVING SUM(CASE WHEN ISNULL(v.A,'~') <> ISNULL(v.B,'~') THEN 1 ELSE 0 END) > 0
ORDER BY v.Columna;
GO

-- ------------------------------------------------------------
-- Duplicados: pares que difieren, lado a lado
-- ------------------------------------------------------------
WITH k AS (
    SELECT *,
           UPPER(LTRIM(RTRIM(DocumentType)))   AS KT,
           UPPER(LTRIM(RTRIM(DocumentNumber))) AS KN
    FROM dbo.StagingETL
    WHERE NULLIF(LTRIM(RTRIM(DocumentNumber)), '') IS NOT NULL
      AND UPPER(LTRIM(RTRIM(DocumentNumber))) NOT IN ('SIN-DATO','NULL')
)
SELECT a.KN AS Documento,
       a.SourceRowId AS Fila_A, a.MonthlyIncome AS Ingreso_A, a.UpdatedAt AS Actualizado_A,
       b.SourceRowId AS Fila_B, b.MonthlyIncome AS Ingreso_B, b.UpdatedAt AS Actualizado_B
FROM k a
JOIN k b ON a.KT = b.KT AND a.KN = b.KN AND a.SourceRowId < b.SourceRowId
WHERE ISNULL(a.MonthlyIncome,'~') <> ISNULL(b.MonthlyIncome,'~')
   OR ISNULL(a.UpdatedAt,'~')     <> ISNULL(b.UpdatedAt,'~')
ORDER BY a.SourceRowId;
GO

-- ------------------------------------------------------------
-- Formatos de fecha
-- ------------------------------------------------------------
SELECT Columna, Formato, COUNT(*) AS Cantidad, MIN(Valor) AS Ejemplo
FROM (
    SELECT v.Columna, v.Valor,
           CASE WHEN v.Valor IS NULL THEN 'NULL'
                WHEN v.Valor LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' THEN 'yyyy-mm-dd'
                WHEN v.Valor LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]' THEN 'yyyy-mm-dd hh:mm:ss'
                WHEN v.Valor LIKE '[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9]' THEN 'dd/mm/yyyy'
                ELSE 'OTRO' END AS Formato
    FROM dbo.StagingETL s
    CROSS APPLY (VALUES
        ('BirthDate', LTRIM(RTRIM(s.BirthDate))),
        ('SurveyDate', LTRIM(RTRIM(s.SurveyDate))),
        ('UpdatedAt', LTRIM(RTRIM(s.UpdatedAt))),
        ('EmploymentStartDate', LTRIM(RTRIM(s.EmploymentStartDate)))
    ) v(Columna, Valor)
) t
GROUP BY Columna, Formato
ORDER BY Columna, Formato;
GO

-- ------------------------------------------------------------
-- Formatos de importes
-- ------------------------------------------------------------
SELECT Columna, Formato, COUNT(*) AS Cantidad, MIN(Valor) AS Ejemplo
FROM (
    SELECT v.Columna, v.Valor,
           CASE WHEN v.Valor IS NULL THEN 'NULL'
                WHEN v.Valor NOT LIKE '%[^0-9]%' THEN 'Entero limpio'
                WHEN v.Valor LIKE '-%' AND SUBSTRING(v.Valor,2,50) NOT LIKE '%[^0-9]%' THEN 'Negativo'
                WHEN v.Valor LIKE '%$%' THEN 'Con simbolo $'
                WHEN v.Valor LIKE '%[0-9],[0-9]%' AND v.Valor NOT LIKE '%[^0-9,]%' THEN 'Decimal con coma'
                WHEN v.Valor LIKE '%[0-9].[0-9]%' AND v.Valor NOT LIKE '%[^0-9.]%' THEN 'Con punto'
                WHEN v.Valor LIKE '%[A-Za-z]%' THEN 'Texto'
                ELSE 'OTRO' END AS Formato
    FROM dbo.StagingETL s
    CROSS APPLY (VALUES
        ('MonthlyIncome', LTRIM(RTRIM(s.MonthlyIncome))),
        ('MonthlyExpenses', LTRIM(RTRIM(s.MonthlyExpenses)))
    ) v(Columna, Valor)
) t
GROUP BY Columna, Formato
ORDER BY Columna, Formato;
GO

-- ------------------------------------------------------------
-- Textos no numericos en ingreso
-- ------------------------------------------------------------
SELECT LTRIM(RTRIM(MonthlyIncome)) AS TextoIngreso, COUNT(*) AS Cantidad
FROM dbo.StagingETL
WHERE LTRIM(RTRIM(MonthlyIncome)) LIKE '%[A-Za-z]%'
GROUP BY LTRIM(RTRIM(MonthlyIncome));
GO

-- ------------------------------------------------------------
-- Contacto: correos
-- ------------------------------------------------------------
SELECT CASE WHEN Email IS NULL THEN 'NULL'
            WHEN Email LIKE '% %' THEN 'Con espacios'
            WHEN Email NOT LIKE '_%@_%._%' THEN 'Sin formato de correo'
            WHEN Email <> LOWER(Email) COLLATE Latin1_General_CS_AS THEN 'Con mayusculas'
            ELSE 'Valido' END AS Clasificacion,
       COUNT(*) AS Cantidad, MIN(Email) AS Ejemplo
FROM dbo.StagingETL
GROUP BY CASE WHEN Email IS NULL THEN 'NULL'
              WHEN Email LIKE '% %' THEN 'Con espacios'
              WHEN Email NOT LIKE '_%@_%._%' THEN 'Sin formato de correo'
              WHEN Email <> LOWER(Email) COLLATE Latin1_General_CS_AS THEN 'Con mayusculas'
              ELSE 'Valido' END;
GO

-- ------------------------------------------------------------
-- Contacto: telefonos
-- ------------------------------------------------------------
SELECT CASE WHEN Phone IS NULL THEN 'NULL'
            WHEN Phone NOT LIKE '%[^0-9]%' AND LEN(Phone) = 10 AND Phone LIKE '000%' THEN 'Valido (10 digitos, empieza por 000)'
            WHEN Phone NOT LIKE '%[^0-9]%' AND LEN(Phone) = 10 THEN '10 digitos sin prefijo 000'
            WHEN Phone NOT LIKE '%[^0-9]%' THEN 'Solo digitos, longitud distinta'
            ELSE 'Con caracteres no numericos' END AS Clasificacion,
       COUNT(*) AS Cantidad, MIN(Phone) AS Ejemplo
FROM dbo.StagingETL
GROUP BY CASE WHEN Phone IS NULL THEN 'NULL'
              WHEN Phone NOT LIKE '%[^0-9]%' AND LEN(Phone) = 10 AND Phone LIKE '000%' THEN 'Valido (10 digitos, empieza por 000)'
              WHEN Phone NOT LIKE '%[^0-9]%' AND LEN(Phone) = 10 THEN '10 digitos sin prefijo 000'
              WHEN Phone NOT LIKE '%[^0-9]%' THEN 'Solo digitos, longitud distinta'
              ELSE 'Con caracteres no numericos' END;
GO

-- ------------------------------------------------------------
-- Espacios y mayusculas por columna
-- ------------------------------------------------------------
SELECT v.Columna,
       SUM(CASE WHEN DATALENGTH(v.Valor) <> DATALENGTH(LTRIM(RTRIM(v.Valor))) THEN 1 ELSE 0 END) AS EspaciosExtremos,
       SUM(CASE WHEN v.Valor LIKE '%  %' THEN 1 ELSE 0 END) AS EspaciosDobles,
       SUM(CASE WHEN v.Tipo = 'CAT'
                 AND v.Valor <> UPPER(v.Valor) COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END) AS NoEstanEnMayuscula,
       SUM(CASE WHEN v.Tipo = 'NOM'
                 AND v.Valor <> (UPPER(LEFT(v.Valor,1)) + LOWER(SUBSTRING(v.Valor,2,200))) COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END) AS NoEstanEnFormatoTitulo
FROM dbo.StagingETL s
CROSS APPLY (VALUES
    ('DocumentType','CAT',s.DocumentType), ('Sex','CAT',s.Sex), ('MaritalStatus','CAT',s.MaritalStatus),
    ('Zone','CAT',s.Zone), ('HousingType','CAT',s.HousingType), ('EducationLevel','CAT',s.EducationLevel),
    ('EmploymentStatus','CAT',s.EmploymentStatus), ('ContractType','CAT',s.ContractType),
    ('HealthRegime','CAT',s.HealthRegime), ('Disability','CAT',s.Disability),
    ('SourceChannel','CAT',s.SourceChannel), ('MunicipalityName','CAT',s.MunicipalityName),
    ('FirstName','NOM',s.FirstName), ('MiddleName','NOM',s.MiddleName),
    ('LastName','NOM',s.LastName), ('SecondLastName','NOM',s.SecondLastName),
    ('Address','TXT',s.Address), ('EmployerName','TXT',s.EmployerName)
) v(Columna, Tipo, Valor)
WHERE v.Valor IS NOT NULL
GROUP BY v.Columna
HAVING SUM(CASE WHEN DATALENGTH(v.Valor) <> DATALENGTH(LTRIM(RTRIM(v.Valor))) THEN 1 ELSE 0 END) > 0
    OR SUM(CASE WHEN v.Valor LIKE '%  %' THEN 1 ELSE 0 END) > 0
    OR SUM(CASE WHEN v.Tipo = 'CAT' AND v.Valor <> UPPER(v.Valor) COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END) > 0
    OR SUM(CASE WHEN v.Tipo = 'NOM' AND v.Valor <> (UPPER(LEFT(v.Valor,1)) + LOWER(SUBSTRING(v.Valor,2,200))) COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END) > 0
ORDER BY v.Columna;
GO

-- ------------------------------------------------------------
-- Reglas de coherencia: conteo por regla
-- ------------------------------------------------------------
WITH c AS (
    SELECT SourceRowId,
           CASE WHEN BirthDate LIKE '%/%' THEN TRY_CONVERT(date, BirthDate, 103)
                ELSE TRY_CONVERT(date, BirthDate, 23) END AS BD,
           TRY_CONVERT(date, SurveyDate, 23)          AS SD,
           TRY_CONVERT(date, EmploymentStartDate, 23) AS ESD,
           TRY_CAST(ReportedAge AS int)               AS Edad,
           TRY_CAST(SocioeconomicStratum AS int)      AS Estrato,
           TRY_CAST(Dependents AS int)                AS Dep,
           TRY_CAST(HouseholdSize AS int)             AS HH,
           BirthDate, ReportedAge, SocioeconomicStratum, Dependents, HouseholdSize,
           EmploymentStartDate, MonthlyIncome
    FROM dbo.StagingETL
), e AS (
    SELECT *,
           CASE WHEN BD IS NOT NULL AND SD IS NOT NULL
                THEN DATEDIFF(year, BD, SD)
                     - CASE WHEN DATEADD(year, DATEDIFF(year, BD, SD), BD) > SD THEN 1 ELSE 0 END
           END AS EdadCalc
    FROM c
)
SELECT '01 Nacimiento no convertible a fecha' AS Regla, COUNT(*) AS Cantidad FROM e WHERE BirthDate IS NOT NULL AND BD IS NULL
UNION ALL SELECT '02 Nacimiento posterior a la encuesta', COUNT(*) FROM e WHERE BD > SD
UNION ALL SELECT '03 Fecha de encuesta futura', COUNT(*) FROM e WHERE SD > CAST(GETDATE() AS date)
UNION ALL SELECT '04 Edad reportada no numerica o fuera de 0-120', COUNT(*) FROM e WHERE Edad IS NULL OR Edad NOT BETWEEN 0 AND 120
UNION ALL SELECT '05 Edad distinta a la calculada (cualquier diferencia)', COUNT(*) FROM e WHERE EdadCalc IS NOT NULL AND Edad IS NOT NULL AND Edad <> EdadCalc
UNION ALL SELECT '06 Edad distinta a la calculada (mas de 1 anio)', COUNT(*) FROM e WHERE EdadCalc IS NOT NULL AND Edad IS NOT NULL AND ABS(Edad - EdadCalc) > 1
UNION ALL SELECT '07 Estrato no numerico o fuera de 1-6', COUNT(*) FROM e WHERE Estrato IS NULL OR Estrato NOT BETWEEN 1 AND 6
UNION ALL SELECT '08 Dependientes no numerico o negativo', COUNT(*) FROM e WHERE Dep IS NULL OR Dep < 0
UNION ALL SELECT '09 Tamano del hogar no numerico o menor a 1', COUNT(*) FROM e WHERE HH IS NULL OR HH < 1
UNION ALL SELECT '10 Dependientes mayores al tamano del hogar', COUNT(*) FROM e WHERE Dep > HH
UNION ALL SELECT '11 Dependientes iguales al tamano del hogar', COUNT(*) FROM e WHERE Dep = HH
UNION ALL SELECT '12 Inicio de empleo no convertible', COUNT(*) FROM e WHERE EmploymentStartDate IS NOT NULL AND ESD IS NULL
UNION ALL SELECT '13 Inicio de empleo posterior a la encuesta', COUNT(*) FROM e WHERE ESD > SD
UNION ALL SELECT '14 Ingreso exactamente 0', COUNT(*) FROM e WHERE LTRIM(RTRIM(MonthlyIncome)) = '0'
ORDER BY Regla;
GO

-- ------------------------------------------------------------
-- Reglas de coherencia: ejemplos de cada regla
-- ------------------------------------------------------------
WITH c AS (
    SELECT SourceRowId, BirthDate, SurveyDate, ReportedAge, EmploymentStartDate,
           CASE WHEN BirthDate LIKE '%/%' THEN TRY_CONVERT(date, BirthDate, 103)
                ELSE TRY_CONVERT(date, BirthDate, 23) END AS BD,
           TRY_CONVERT(date, SurveyDate, 23)          AS SD,
           TRY_CONVERT(date, EmploymentStartDate, 23) AS ESD,
           TRY_CAST(ReportedAge AS int)               AS Edad
    FROM dbo.StagingETL
), e AS (
    SELECT *, CASE WHEN BD IS NOT NULL AND SD IS NOT NULL
                   THEN DATEDIFF(year, BD, SD)
                        - CASE WHEN DATEADD(year, DATEDIFF(year, BD, SD), BD) > SD THEN 1 ELSE 0 END
              END AS EdadCalc
    FROM c
)
SELECT * FROM (SELECT TOP 5 '01 Nacimiento no convertible' AS Regla, SourceRowId,
       BirthDate AS Fecha1, SurveyDate AS Encuesta, CAST(ReportedAge AS nvarchar(30)) AS Detalle
       FROM e WHERE BirthDate IS NOT NULL AND BD IS NULL ORDER BY SourceRowId) a
UNION ALL
SELECT * FROM (SELECT TOP 5 '02 Nacimiento posterior a encuesta' AS Regla, SourceRowId,
       BirthDate AS Fecha1, SurveyDate AS Encuesta, CAST(ReportedAge AS nvarchar(30)) AS Detalle
       FROM e WHERE BD > SD ORDER BY SourceRowId) b
UNION ALL
SELECT * FROM (SELECT TOP 5 '05 Edad distinta a la calculada' AS Regla, SourceRowId,
       BirthDate AS Fecha1, SurveyDate AS Encuesta,
       'Reportada ' + CAST(Edad AS nvarchar(10)) + ' / Calculada ' + CAST(EdadCalc AS nvarchar(10)) AS Detalle
       FROM e WHERE EdadCalc IS NOT NULL AND Edad IS NOT NULL AND Edad <> EdadCalc ORDER BY SourceRowId) c2
UNION ALL
SELECT * FROM (SELECT TOP 5 '13 Empleo posterior a encuesta' AS Regla, SourceRowId,
       EmploymentStartDate AS Fecha1, SurveyDate AS Encuesta, CAST('' AS nvarchar(30)) AS Detalle
       FROM e WHERE ESD > SD ORDER BY SourceRowId) d;
GO

-- ------------------------------------------------------------
-- Municipio-departamento e informacion laboral
-- ------------------------------------------------------------
WITH x AS (
    SELECT s.SourceRowId,
           m.MunicipioId AS MunId,
           d.Codigo AS DepCat,
           UPPER(LTRIM(RTRIM(s.DepartmentCode)))  AS DepExcel,
           UPPER(LTRIM(RTRIM(s.EmploymentStatus))) AS Est,
           UPPER(LTRIM(RTRIM(s.ContractType)))     AS Contrato,
           NULLIF(LTRIM(RTRIM(s.EmployerName)), '')      AS Emp,
           NULLIF(LTRIM(RTRIM(s.OccupationCode)), '')    AS Ocu,
           NULLIF(LTRIM(RTRIM(s.EmploymentStartDate)), '') AS FIni
    FROM dbo.StagingETL s
    LEFT JOIN dbo.Municipio    m ON m.Codigo = UPPER(LTRIM(RTRIM(s.MunicipalityCode)))
    LEFT JOIN dbo.Departamento d ON d.DepartamentoId = m.DepartamentoId
)
SELECT '01 Municipio no esta en el catalogo' AS Regla, COUNT(*) AS Cantidad FROM x WHERE MunId IS NULL
UNION ALL SELECT '02 Departamento no corresponde al municipio', COUNT(*) FROM x WHERE MunId IS NOT NULL AND DepCat <> DepExcel
UNION ALL SELECT '03 Situacion laboral fuera del catalogo', COUNT(*) FROM x WHERE Est IS NOT NULL AND Est NOT IN ('EMPLEADO','INDEPENDIENTE','DESEMPLEADO','ESTUDIANTE','PENSIONADO')
UNION ALL SELECT '04 Sin trabajo con empleador', COUNT(*) FROM x WHERE Est IN ('DESEMPLEADO','ESTUDIANTE','PENSIONADO') AND Emp IS NOT NULL
UNION ALL SELECT '05 Sin trabajo con fecha de inicio de empleo', COUNT(*) FROM x WHERE Est IN ('DESEMPLEADO','ESTUDIANTE','PENSIONADO') AND FIni IS NOT NULL
UNION ALL SELECT '06 Sin trabajo con contrato distinto de NO_APLICA', COUNT(*) FROM x WHERE Est IN ('DESEMPLEADO','ESTUDIANTE','PENSIONADO') AND ISNULL(Contrato,'') <> 'NO_APLICA'
UNION ALL SELECT '07 Empleado sin empleador', COUNT(*) FROM x WHERE Est = 'EMPLEADO' AND Emp IS NULL
UNION ALL SELECT '08 Empleado sin ocupacion (vacia o O99)', COUNT(*) FROM x WHERE Est = 'EMPLEADO' AND (Ocu IS NULL OR Ocu = 'O99')
UNION ALL SELECT '09 Empleado con contrato NO_APLICA', COUNT(*) FROM x WHERE Est = 'EMPLEADO' AND Contrato = 'NO_APLICA'
ORDER BY Regla;
GO

-- ------------------------------------------------------------
-- Municipio fuera del catalogo
-- ------------------------------------------------------------
SELECT 'Municipio fuera del catalogo' AS Revision, UPPER(LTRIM(RTRIM(MunicipalityCode))) AS Valor, COUNT(*) AS Cantidad
FROM dbo.StagingETL
WHERE UPPER(LTRIM(RTRIM(MunicipalityCode))) NOT IN (SELECT Codigo FROM dbo.Municipio)
   OR MunicipalityCode IS NULL
GROUP BY UPPER(LTRIM(RTRIM(MunicipalityCode)))
UNION ALL
SELECT 'Telefono con caracteres', REPLACE(REPLACE(REPLACE(Phone, '0',''),'1',''),'2',''), COUNT(*)
FROM dbo.StagingETL
WHERE Phone LIKE '%[^0-9]%'
GROUP BY REPLACE(REPLACE(REPLACE(Phone, '0',''),'1',''),'2','');
GO