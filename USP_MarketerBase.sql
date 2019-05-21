USE LANDING;
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Kodjovi Togbey
-- Create date: 05/15/2019
-- Description:	To create a the marketer Base population 
-- Exec USP_MarketerBase 
-- =============================================
ALTER PROCEDURE USP_MarketerBase 
	-- Add the parameters for the stored procedure here

AS
BEGIN

	SET NOCOUNT ON;

    -- Insert statements for procedure here

--DECLARE @CustNo INT= -1;
--DECLARE @CustNoHigh INT= 2100000;

--**** Identification of Duplicate Sales****-------

DROP TABLE IF EXISTS [LANDING].[dbo].#TEMP_DUP;
SELECT DISTINCT 
       CustNo, 
       CAST(SELL_DATE AS DATE) SELL_DATE, 
       REP_ID, 
       AGENT
INTO #TEMP_DUP
FROM raw.cvos.SALESRECORDSALL a WITH(NOLOCK)
WHERE CustNo > 0
      AND ACTION IN('Imported', 'Duplicate Account No Disc', 'Upgrade');

----*** BASE POPULATION***-------

DROP TABLE IF EXISTS [LANDING].[dbo].#Temp;
SELECT DISTINCT
       (CustNo) AS AcctNo, 
       agent AS CurrentMarketer, 
       CONVERT(VARCHAR(10), Sell_Date, 112) AS [StartDate], 
       Rep_ID
INTO #Temp
FROM Raw.cvos.SalesRecordsAll WITH(NOLOCK)
WHERE 1 = 1
      AND ACTION IN('Imported', 'Duplicate Account No Disc', 'Upgrade')
--and CustNo ='110513'
AND custNo <> 0;

--Select *
--FRom #Temp
--where AcctNo=204574

--***** ADDING END DATE TO BASE POPULATION into MarketerHistory1****-----------

DROP TABLE IF EXISTS [LANDING].[Marketer].[MarketerHistory1];
SELECT AcctNo, 
       CurrentMarketer, 
       [StartDate], 
       ISNULL(LEAD(CONVERT(VARCHAR(10), [StartDate], 112)) OVER(PARTITION BY acctno
       ORDER BY StartDate), '21991231') AS [EndDate], 
       Rep_ID
INTO [LANDING].[Marketer].[MarketerHistory1]
FROM #Temp
WHERE 1 = 1
--      AND ACTION IN('Imported', 'Duplicate Account No Disc', 'Upgrade')
--and AcctNo ='14418'
--AND AcctNo BETWEEN @CustNo AND @CustNoHigh
ORDER BY AcctNo;

----*******UPDATING BASE POPULATION WITH CORRECT DUPLICATE DATE********--------
---STEP 1
DELETE
--Select *
FROM [LANDING].[Marketer].[MarketerHistory1]
WHERE AcctNo IN
(
    SELECT CustNo
    FROM #TEMP_DUP
    GROUP BY CustNo, 
             SELL_DATE
    HAVING COUNT(CustNo) > 1
);
--   --order by AcctNo

---STEP 2
DROP TABLE IF EXISTS #TEMP1;
SELECT RN = ROW_NUMBER() OVER(PARTITION BY CustNo
       ORDER BY Processed), 
       Sell_Date, 
       Processed, 
       CustNo, 
       Rep_ID, 
       Agent
INTO #TEMP1
FROM raw.cvos.SALESRECORDSALL a
WHERE a.custno IN
(
    SELECT CustNo
    FROM #TEMP_DUP
    GROUP BY CustNo, 
             SELL_DATE
    HAVING COUNT(CustNo) > 1
);
------= 110513
----ORDER BY Sell_Date DESC
--Select*
--From  #TEMP1

DROP TABLE IF EXISTS #TEMP2;
SELECT a.*,
       --,New_StartDate = CASE WHEN RN = 1  
       DATEADD(dd, -1, b.Sell_Date) AS EndDate, 
       DENSE_RANK() OVER(PARTITION BY a.CustNo, 
                                      a.Sell_Date
       ORDER BY a.Processed) AS DN, 
       COUNT(1) OVER(PARTITION BY a.CustNo, 
                                  a.Sell_Date) Thingy
INTO #TEMP2
FROM #TEMP1 a
     LEFT JOIN #TEMP1 b ON a.CustNo = b.CustNo
                           AND a.RN = b.RN - 1
ORDER BY RN;

--Select *
--From #TEMP2

DROP TABLE IF EXISTS #TEMP3;
SELECT *, 
       NEW_START_DATE = CASE
                            WHEN RN = 1
                                 AND Thingy = 1
                            THEN Sell_Date
                            WHEN Thingy = 2
                            THEN DATEADD(dd, DN, SEll_Date)
                            ELSE Sell_Date
                        END
INTO #TEMP3
FROM #TEMP2;

--Select *
--From #TEMP3

DROP TABLE IF EXISTS #TEMP4;
SELECT CustNo AS AcctNo, 
       agent AS CurrentMarketer, 
       CONVERT(VARCHAR(10), NEW_START_DATE, 112) STARTDATE, 
       CONVERT(VARCHAR(10), DATEADD(dd, -1, LEAD(NEW_START_DATE, 1, '2200-01-01') OVER(PARTITION BY custNo
       ORDER BY Rn)), 112) ENDDATE, 
       Rep_ID
INTO #TEMP4
FROM #TEMP3;

---STEP3

INSERT INTO [LANDING].[Marketer].[MarketerHistory1]
       SELECT *
       FROM #TEMP4;

--Select*
--FROM [LANDING].[dbo].[MarketerHistory1]
--WHERE AcctNo = 110513

----------********* ADDING AUDIT TO THE BASE POPULATION*******-------------

INSERT INTO [LANDING].[Marketer].[MarketerHistory1]
       SELECT *
       FROM [LANDING].[dbo].[AuditHistory]
       WHERE 1 = 1
             AND StartDate IS NOT NULL
             AND AcctNo NOT IN
       (
           SELECT DISTINCT
                  (AcctNo)
           FROM [LANDING].[Marketer].[MarketerHistory1]
       );

--SELECT *
--FROM [LANDING].[dbo].[MarketerHistory1]
--where 1=1
--and AcctNo='110513'
--ORDER BY AcctNo, 
--         StartDate, 
--         EndDate;

----------**********BUILDING MARKETER LOGIC******----

---STEP 1

DECLARE @Threshhold INT= 1;
DROP TABLE IF EXISTS [LANDING].[dbo].#Tempo;
SELECT *, 
       ROW_NUMBER() OVER(PARTITION BY AcctNo
       ORDER BY StartDate ASC) AS RN
INTO #Tempo
FROM [LANDING].[Marketer].[MarketerHistory1]
WHERE 1 = 1;
--and AcctNo='14418'
--Select *
--From #Tempo
--where acctno=110513

DROP TABLE IF EXISTS [LANDING].[dbo].#STAGE;
SELECT a.AcctNo, 
       a.CurrentMarketer AS Original, 
       b.CurrentMarketer, 
       b.StartDate,
       CASE
           WHEN b.EndDate = 21991231
           THEN 21991231
           ELSE b.EndDate - 1
       END AS EndDate, 
       'N' AS WinBack, 
       'N' AS [Retention], 
       b.Rep_ID
INTO #STAGE
FROM
(
    SELECT *
    FROM #Tempo
    WHERE rn = 1
) a
LEFT JOIN #Tempo b ON a.AcctNo = b.AcctNo
--AND a.rn = b.rn - 1
LEFT JOIN #Tempo c ON a.AcctNo = c.AcctNo
                      AND a.RN = c.rn + 1
WHERE 1 = 1
--AND a.AcctNo = 14418
ORDER BY a.AcctNo, 
         a.StartDate, 
         a.EndDate;

--Select *
--From #STAGE
--Where acctno=110513

---STEP 2 USING INFO FROM STATUS TABLE TO DETERMINE IF AN ACCOUNT IS DISCONNECTED

DROP TABLE IF EXISTS [LANDING].[dbo].#DISconnectDAYS;
SELECT Acct_nbr as custno, [start_date],End_date, [status],
       DATEDIFF(dd, START_DATE, END_DATE) AS DisconnectDays
INTO #DISconnectDAYS
FROM Edw.Dbo.Dim_Account_Status --[LANDING].[dbo].[ResultsB2]
WHERE 1 = 1
      --and Acct_nbr='336094' 
       AND Flowing_Ind = 'N'
      AND END_DATE <> '21991231'
	  AND [status] like ('Disc%')
	  AND End_date >= [Start_date]
      AND DATEDIFF(dd, START_DATE, END_DATE) >= @Threshhold
ORDER BY Acct_nbr,START_DATE;


--Select *
--From #DISconnectDAYS
--where custno=14418
-- Need Loop Here for update

DROP TABLE IF EXISTS [LANDING].[dbo].#Loop;
SELECT a.AcctNo, 
       a.Original, 
       a.CurrentMarketer, 
       CAST(a.StartDate AS CHAR(8)) AS StartDate, 
       CAST(a.EndDate AS CHAR(8)) AS EndDate, 
       --b.CustNo, 
       --CAST(b.START_DATE AS CHAR(8)) AS START_DATE, 
       --CAST(b.END_DATE AS CHAR(8)) AS END_DATE, 
       --b.STATUS, 
       --b.DisconnectDays, 
       a.winBack, 
       a.[Retention], 
       Rep_ID, 
       RN = ROW_NUMBER() OVER(PARTITION BY AcctNo
       ORDER BY StartDate)
INTO #Loop
FROM #Stage a
     INNER JOIN
(
    SELECT DISTINCT
           (custno)
    FROM #DISconnectDAYS
) b ON b.CustNo = a.AcctNo;--*******
--WHERE 1 = 1
--      --and custno='15070' 
--      AND CAST(a.EndDate AS CHAR(8)) >= CAST(b.START_DATE AS CHAR(8))
--      AND CAST(b.END_DATE AS CHAR(8)) <= CAST(a.EndDate AS CHAR(8));
--Select *
--From #Loop
--where AcctNo = 14418

---STEP 3 UPDATING WINBACK
DECLARE @Max INT=
(
    SELECT MAX(RN)
    FROM #LOOP
);
DECLARE @i INT= 0;
WHILE @i < @Max
    BEGIN
        UPDATE a
          SET 
              a.WinBack = 'Y'
        FROM #Stage a
             INNER JOIN #DISconnectDAYS b ON b.CustNo = a.AcctNo
             INNER JOIN #Loop xx ON a.AcctNo = xx.AcctNo
                                    AND a.StartDate = xx.StartDate
        WHERE 1 = 1
              AND xx.RN > 1
              AND CAST(a.EndDate AS INT) >= CAST(CONVERT(CHAR(8), b.START_DATE, 112) AS INT)
              AND CAST(CONVERT(CHAR(8), b.END_DATE, 112) AS INT) <= CAST(a.EndDate AS INT);
        --and CAST(a.EndDate AS CHAR(8)) <> '21991231'

        SET @i = @i + 1;
    END;
DROP TABLE IF EXISTS [LANDING].[dbo].#MIN;
SELECT AcctNo, 
       MIN(StartDate) MinStartDate
INTO #MIN
FROM #STAGE
GROUP BY AcctNo;
UPDATE #STAGE
  SET 
      [Retention] = 'Y'
FROM #STAGE a
     LEFT JOIN #MIN b ON a.AcctNo = b.AcctNo
WHERE 1 = 1
      AND a.StartDate <> b.MinStartDate
      AND a.WinBack = 'N'
      AND a.[Retention] = 'N';
--and EndDate <> '21991231'
--and rn>1
--DELETE
--Select *
UPDATE #STAGE
  SET 
      EndDate = EndDate + 1
WHERE 1 = 1
      AND EndDate < StartDate;

--Select *
--From #STAGE
--WHERE AcctNo = 162369
--ORDER BY AcctNo, 
--         StartDate, 
--         EndDate
--SElect *
--from #DISconnectDAYS 
--WHERE CustNo = 164847

---STEP 4 CREATING A MARKETER TABLE
DROP TABLE IF EXISTS [LANDING].[Marketer].[Marketer];
SELECT *
INTO [LANDING].[Marketer].[Marketer]
FROM #Stage
--where 1=1
----and CurrentMarketer='Pst'
--and AcctNo= 525770
ORDER BY AcctNo, 
         StartDate, 
         EndDate;

--Select *
--From [LANDING].[dbo].[Marketer]
--where acctno=164847
--order by AcctNo, StartDate

---****** ADDING CUSTOMER MASTER TO THE MARKETER TABLE*******-----------

DROP TABLE IF EXISTS [LANDING].[dbo].#CustMaster;
SELECT DISTINCT
       (cm_CustNo), 
       cm_CurrentStatus, 
       cm_ElectricCompany, 
       cm_AgentInformation, 
       cm_SignUpDate, 
       Case When cm_AgentInformation ='Online' Then cm_HeardAboutBy Else cm_RepID END 
        Rep_ID
INTO [LANDING].[dbo].#CustMaster--count(distinct(cm_CustNo))
FROM ClearviewPrd..CustomerMaster
WHERE 1 = 1
      --and cm_CurrentStatus='Active'
      AND cm_CurrentStatus NOT IN('x-out', 'Info Call', 'X-Out')
--AND cm_SignUpDate > '20120101'
AND cm_CustNo NOT IN
(
    SELECT DISTINCT
           (acctno)
    FROM #STAGE WITH(NOLOCK)
);
--and cm_CustNo=718261;
--Select top(10)*
--From [LANDING].[dbo].[Marketer]
--Select *
--From #CustMaster
--where cm_custno=721888

INSERT INTO [LANDING].[Marketer].[Marketer]
       SELECT cm_CustNo, 
              cm_AgentInformation, 
              cm_AgentInformation, 
              CONVERT(VARCHAR(10), cm_SignUpDate, 112), 
              '21991231', 
              'N', 
              'N', 
              Rep_ID
       FROM #CustMaster;

--Select count(distinct(AcctNo))
--From [LANDING].[dbo].[Marketer]


--SELECT *
--FROM [LANDING].[Marketer].[Marketer]
----where AcctNo=721888
--ORDER BY AcctNo, 
--         StartDate, 
--         EndDate;


END
GO
