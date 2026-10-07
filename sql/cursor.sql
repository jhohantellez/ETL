

DECLARE @Id INT, @TipoDoc NVARCHAR(50), @NumDoc NVARCHAR(50),
        @N1 NVARCHAR(100), @N2 NVARCHAR(100), @A1 NVARCHAR(100), @A2 NVARCHAR(100),
        @IngTxt NVARCHAR(100), @GasTxt NVARCHAR(100),
        @Ing DECIMAL(18,2), @Gas DECIMAL(18,2), @Motivo NVARCHAR(500),
        @Procesados INT = 0, @Aceptados INT = 0, @Rechazados INT = 0;


DECLARE cur_balance CURSOR LOCAL FAST_FORWARD FOR
    SELECT SourceRowId, DocumentType, DocumentNumber,
           FirstName, MiddleName, LastName, SecondLastName,
           MonthlyIncome, MonthlyExpenses
    FROM dbo.StagingETL
    WHERE SourceRowId BETWEEN 1 AND 100
    ORDER BY SourceRowId;


OPEN cur_balance;


FETCH NEXT FROM cur_balance
    INTO @Id, @TipoDoc, @NumDoc, @N1, @N2, @A1, @A2, @IngTxt, @GasTxt;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Procesados += 1;
    SET @Motivo = '';

    -- Quitar espacios en extremos y repetidos; vacío o 'NULL' => NULL
    SET @TipoDoc = NULLIF(NULLIF(LTRIM(RTRIM(@TipoDoc)), ''), 'NULL');
    SET @NumDoc  = NULLIF(NULLIF(NULLIF(LTRIM(RTRIM(@NumDoc)), ''), 'NULL'), 'SIN-DATO');
    SET @N1 = NULLIF(NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(@N1)), '  ', ' '), '  ', ' '), ''), 'NULL');
    SET @N2 = NULLIF(NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(@N2)), '  ', ' '), '  ', ' '), ''), 'NULL');
    SET @A1 = NULLIF(NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(@A1)), '  ', ' '), '  ', ' '), ''), 'NULL');
    SET @A2 = NULLIF(NULLIF(REPLACE(REPLACE(LTRIM(RTRIM(@A2)), '  ', ' '), '  ', ' '), ''), 'NULL');

    -- Estandarizar escritura
    SET @TipoDoc = UPPER(@TipoDoc);
    SET @NumDoc  = UPPER(@NumDoc);
    SET @N1 = UPPER(LEFT(@N1,1)) + LOWER(SUBSTRING(@N1,2,LEN(@N1)));
    SET @N2 = UPPER(LEFT(@N2,1)) + LOWER(SUBSTRING(@N2,2,LEN(@N2)));
    SET @A1 = UPPER(LEFT(@A1,1)) + LOWER(SUBSTRING(@A1,2,LEN(@A1)));
    SET @A2 = UPPER(LEFT(@A2,1)) + LOWER(SUBSTRING(@A2,2,LEN(@A2)));

    -- Campos obligatorios
    IF @NumDoc IS NULL SET @Motivo += 'Documento faltante; ';
    IF @N1 IS NULL     SET @Motivo += 'Primer nombre faltante; ';
    IF @A1 IS NULL     SET @Motivo += 'Primer apellido faltante; ';

    -- Importes: limpiar símbolos y espacios
    SET @IngTxt = NULLIF(NULLIF(LTRIM(RTRIM(@IngTxt)), ''), 'NULL');
    SET @GasTxt = NULLIF(NULLIF(LTRIM(RTRIM(@GasTxt)), ''), 'NULL');
    SET @IngTxt = REPLACE(REPLACE(REPLACE(UPPER(@IngTxt), '$', ''), 'COP', ''), ' ', '');
    SET @GasTxt = REPLACE(REPLACE(REPLACE(UPPER(@GasTxt), '$', ''), 'COP', ''), ' ', '');

    -- Formato alterno: punto = miles, coma = decimal
    IF @IngTxt LIKE '%,%' SET @IngTxt = REPLACE(REPLACE(@IngTxt, '.', ''), ',', '.');
    IF @GasTxt LIKE '%,%' SET @GasTxt = REPLACE(REPLACE(@GasTxt, '.', ''), ',', '.');

    -- Conversión a número (si no se puede, queda NULL)
    SET @Ing = TRY_CAST(@IngTxt AS DECIMAL(18,2));
    SET @Gas = TRY_CAST(@GasTxt AS DECIMAL(18,2));

    -- Validación de ingreso
    IF @IngTxt IS NULL      SET @Motivo += 'Ingreso faltante; ';
    ELSE IF @Ing IS NULL    SET @Motivo += 'Ingreso no numérico; ';
    ELSE IF @Ing < 0        SET @Motivo += 'Ingreso negativo; ';

    -- Validación de gasto
    IF @GasTxt IS NULL      SET @Motivo += 'Gasto faltante; ';
    ELSE IF @Gas IS NULL    SET @Motivo += 'Gasto no numérico; ';
    ELSE IF @Gas < 0        SET @Motivo += 'Gasto negativo; ';


    IF @Motivo = ''
    BEGIN
        INSERT INTO dbo.RegistroValido
        VALUES (@Id, @TipoDoc, @NumDoc, @N1, @N2, @A1, @A2, @Ing, @Gas, @Ing - @Gas);
        SET @Aceptados += 1;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.RegistroRechazado VALUES (@Id, @Motivo);
        SET @Rechazados += 1;
    END

  
    FETCH NEXT FROM cur_balance
        INTO @Id, @TipoDoc, @NumDoc, @N1, @N2, @A1, @A2, @IngTxt, @GasTxt;
END


CLOSE cur_balance;
DEALLOCATE cur_balance;

-- Resultados
SELECT @Procesados AS Procesados, @Aceptados AS Aceptados, @Rechazados AS Rechazados;
SELECT * FROM dbo.RegistroValido ORDER BY SourceRowId;
SELECT * FROM dbo.RegistroRechazado ORDER BY SourceRowId;