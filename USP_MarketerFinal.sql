USE LANDING;
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Kodjovi Togbey
-- Create date: 05/15/2019
-- Description:	To create the marketer Final
-- Exec USP_MarketerFinal 
-- =============================================
ALTER PROCEDURE USP_MarketerFinal 
	-- Add the parameters for the stored procedure here

AS
BEGIN

	SET NOCOUNT ON;

    -- Insert statements for procedure here

DROP TABLE IF EXISTS [LANDING].[Marketer].[MarketerHistory];
SELECT m.AcctNo, 
       v.Rep_ID AS OriginalRepID, 
       v.Rep_ID AS CurrentRepID, 
       m.StartDate, 
       m.EndDate, 
       WinBack, 
       [Retention]
INTO [LANDING].[Marketer].[MarketerHistory]
FROM [LANDING].[Marketer].[Marketer] m
     LEFT JOIN EDW.MARKETER.uvwTEMPdimmarketerhier v ON isnull(m.rep_iD,'unknown') = v.repvalue
                                                AND m.CurrentMarketer = v.marketer
WHERE 1 = 1
      AND AcctNo <> 0
      AND v.rep_iD IS NOT NULL
ORDER BY AcctNo, 
         StartDate;

--Select *
--from [LANDING].[dbo].[MarketerHistory]
--order by AcctNo, StartDate
--******************************************FIRST UPDATE***********************************************
DROP TABLE IF EXISTS #TEMP;
SELECT *, 
       ROW_NUMBER() OVER(PARTITION BY AcctNo
       ORDER BY StartDate ASC) AS RN--OriginalRepID, min(startDate)
INTO #TEMP
FROM [LANDING].[Marketer].[MarketerHistory]
WHERE 1 = 1
--and AcctNo=126410
ORDER BY StartDate;

UPDATE [LANDING].[Marketer].[MarketerHistory]
  SET 
      OriginalRepID = t.OriginalRepID
FROM [LANDING].[Marketer].[MarketerHistory] a
     INNER JOIN #TEMP t ON a.AcctNo = t.AcctNo
                           AND t.rn = 1
WHERE 1 = 1;
--and a.AcctNo=126410

--SELECT * --count(*)
--FROM [LANDING].[Marketer].[MarketerHistory]
----where AcctNo= 126410--248130--110513
--ORDER BY  
--         AcctNo, StartDate,EndDate;


----------**********ONLINE DATA CLEANUP**********-----------------------------
 DROP TABLE IF EXISTS [LANDING].[Marketer].TEMPmarketerhistory;  
	 SELECT a.*, 
            r.RepValue, 
            r.Marketer, 
            r.Channel, 
            r.Dept 
    
     Into [LANDING].[Marketer].TEMPmarketerhistory
     FROM [LANDING].[Marketer].[MarketerHistory] a
          LEFT JOIN EDW.MARKETER.uvwTEMPdimmarketerhier r ON r.Rep_ID = a.CurrentRepID




UPDATE  [LANDING].[Marketer].TEMPmarketerhistory

SET  Marketer=
       CASE
           WHEN repvalue = '100' AND marketer IN('che', 'online') 
				THEN 'CHE'
			WHEN repvalue = 'NEM' AND marketer IN('NEM', 'online') 
				THEN 'NEM'
			WHEN repvalue = 'PST' AND marketer IN('PST', 'online') 
				THEN 'PST'
			WHEN repvalue = 'PT' AND marketer IN('PT', 'online') 
				THEN 'PT'
			WHEN repvalue = 'MTS' AND marketer IN('MTS', 'online') 
				THEN 'MTS'
			WHEN marketer in  ('Online-WebJob','Online-API','Online') AND channel='WEB'
				THEN 'Online'
           ELSE Marketer
       END  
	    ,Channel = CASE
           WHEN repvalue = '100' AND marketer IN('che', 'online') 
			THEN 'Shopsite'
			WHEN repvalue = 'NEM' AND marketer IN('NEM', 'online') 
				THEN 'Shopsite'
			WHEN repvalue = 'PST' AND marketer IN('PST', 'online') 
				THEN 'Shopsite'
			WHEN repvalue = 'PT' AND marketer IN('PT', 'online') 
				THEN 'Shopsite'
			WHEN repvalue = 'MTS' AND marketer IN('MTS', 'online') 
				THEN 'Shopsite'
           ELSE Channel
       END 
--INTO #TEMP
FROM [LANDING].[Marketer].TEMPmarketerhistory 
     --LEFT JOIN ClearviewPrd..CustomerMaster b ON a.acctno = b.cm_CustNo
WHERE 1 = 1
      --AND b.cm_CurrentStatus IN('new', 'PendActive', 'Active')
     AND dept = 'Online'



UPDATE  [LANDING].[Marketer].TEMPmarketerhistory
SET Repvalue= a.Marketer

FROM [LANDING].[Marketer].TEMPmarketerhistory a
WHERE 1 = 1
      AND a.dept = 'Online'



--Select *
--FRom LANDING.Marketer.uvwTEMPmarketerhistory

--  ORDER BY  
--               acctno,StartDate,
--              enddate;


---------******VERIFICATION*****-------
--Select cm_CustNo--, cm_AgentInformation
--from ClearviewPrd..CustomerMaster
--where cm_CurrentStatus not in('x-out','Info Call')
--EXCEPT
--Select acctno--, marketer
--FROM landing.Marketer.uvwTEMPmarketerhistory

--Select acctno
--from [Marketer].[Marketer]
--where acctno !=790383
--except 
--select acctno
--from [Marketer].[MarketerHistory]


END
GO
