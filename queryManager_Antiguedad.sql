DECLARE @fechaRegistro DATETIME
SET @fechaRegistro = '2025-03-11'; #Variable de fecha de registro

WITH ReconData AS (
    SELECT T0.ShortName AS SN, T0.TransId, SUM(T0.ReconSum) AS ReconSum, T0.IsCredit AS DebHab, T0.TransRowId AS Linea
    FROM ITR1 T0
    INNER JOIN OITR T1 ON T1.ReconNum = T0.ReconNum
    WHERE T1.ReconDate <= @fechaRegistro AND T1.CancelAbs = ''
    GROUP BY T0.ShortName, T0.TransId, T0.IsCredit, T0.TransRowId
),

Informe_Antiguedad AS (
    SELECT T1.*, T0.CardCode AS Nit, T0.CardName AS Industrial, T5.U_NAME /*Campo personalizado agrega el tuyo aqui*/ AS Usuario, 
    T4.BaseRef AS DocInterno, T3.ReconSum, T3.DebHab,
           CASE
               WHEN T3.DebHab = 'D' THEN (T1.Debit - T1.Credit - T3.ReconSum)
               WHEN T3.DebHab = 'C' THEN (T1.Debit - T1.Credit + T3.ReconSum)
               ELSE (T1.Debit - T1.Credit)
           END AS Saldo,
           CASE T1.TransType
               WHEN '13' THEN (SELECT Y.Comments FROM OINV Y WHERE Y.TransId = T1.TransId)
               WHEN '14' THEN (SELECT Y.Comments FROM ORIN Y WHERE Y.TransId = T1.TransId)
               ELSE T1.LineMemo
           END AS Comentarios, T6.descript
    FROM OCRD T0
    INNER JOIN JDT1 T1 ON T1.ShortName = T0.CardCode
    INNER JOIN OACT T2 ON T2.AcctCode = T1.Account
    LEFT JOIN ReconData T3 ON T3.TransId = T1.TransId AND T3.SN = T1.ShortName AND T3.Linea = T1.Line_ID    
    INNER JOIN OJDT T4 ON T4.TransId = T1.TransId   
    INNER JOIN OUSR T5 ON T5.USERID = T1.UserSign
    INNER JOIN OTER T6 ON T6.territryID = T0.Territory
    WHERE T0.CardType = 'C' AND T1.RefDate <= @fechaRegistro
)

SELECT 
	Nit, Industrial, TransId [Asiento], DocInterno [Num. Docum], 
	CONVERT(DATE, RefDate) [Fecha Referencia], 
	CONVERT(DATE, TaxDate) [Fecha Documento], 
	CONVERT(DATE, DueDate) [Fecha Contab.], 
	Saldo,
       CASE WHEN DATEDIFF(DAY, RefDate, @fechaRegistro) <= 30 THEN Saldo END AS "0-30 dias",
       CASE WHEN DATEDIFF(DAY, RefDate, @fechaRegistro) BETWEEN 31 AND 60 THEN Saldo END AS "31-60 dias",
       CASE WHEN DATEDIFF(DAY, RefDate, @fechaRegistro) BETWEEN 61 AND 90 THEN Saldo END AS "61-90 dias",
       CASE WHEN DATEDIFF(DAY, RefDate, @fechaRegistro) BETWEEN 91 AND 120 THEN Saldo END AS "91-120 dias",
       CASE WHEN DATEDIFF(DAY, RefDate, @fechaRegistro) > 120 THEN Saldo END AS "+120 dias",
       CASE
           WHEN DATEDIFF(DAY, RefDate, @fechaRegistro) BETWEEN 121 AND 365 THEN Saldo * 0.75
           WHEN DATEDIFF(DAY, RefDate, @fechaRegistro) > 365 THEN Saldo
       END AS "Deuda Dudosa",
       Comentarios,
       Usuario, descript [Ciudad]
FROM Informe_Antiguedad
WHERE Saldo != 0
ORDER BY Industrial, TransId ASC; 
