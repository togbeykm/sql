SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
--CREATE TABLE LANDING..ResultsB
--(
--	CustNo INT,
--	START_DATE DATE,
--	END_DATE DATE,
--	STATUS CHAR(1)
--)
--TRUNCATE TABLE LANDING..ResultsB;

IF OBJECT_ID('tempdb..#CustNoStg') IS NOT NULL
    DROP TABLE #CustNoStg;
SELECT DISTINCT 
       cm_CustNo
INTO #CustNoStg
FROM ClearviewPrd..CustomerMaster a WITH(NOLOCK)
WHERE NOT EXISTS
(
    SELECT *
    FROM LANDING..ResultsB b WITH(NOLOCK)
    WHERE a.cm_CustNo = b.CustNo
);
IF OBJECT_ID('tempdb..#CustNo') IS NOT NULL
    DROP TABLE #CustNo;
SELECT cm_CustNo, 
       BatchNo = NTILE(1000) OVER(
       ORDER BY cm_CustNo DESC)
INTO #CustNo
FROM #CustNoStg;

DECLARE @i INT= 1;
WHILE @i < 1001
    BEGIN
        DECLARE @STARTTIME DATETIME= GETDATE();
        IF OBJECT_ID('tempdb..#STAGE') IS NOT NULL
            DROP TABLE #STAGE;
        SELECT DISTINCT 
               [CustNo], 
               [ServicePeriodStart], 
               [ServicePeriodEnd], 
               StartDate = MIN(ServicePeriodStart) OVER(PARTITION BY CustNo), 
               EndDate = MAX(ServicePeriodEnd) OVER(PARTITION BY CustNo)
        INTO #STAGE
        FROM [ClearviewPrd].[dbo].[tbl810DetailData] a WITH(NOLOCK)
             INNER JOIN #CustNo b ON a.CustNo = b.cm_CustNo
        WHERE CustNo IS NOT NULL
              AND b.BatchNo = @i;
        --AND [ServicePeriodStart]> DATEADD(yy,-2,DATEADD(yy,DATEDIFF(yy,0,GETDATE()),0))
        --CREATE NONCLUSTERED INDEX ixdaterange ON #STAGE([ServicePeriodStart], [ServicePeriodEnd], CustNo)

        IF OBJECT_ID('tempDB..#ACTIVEDAYS') IS NOT NULL
            DROP TABLE #ACTIVEDAYS;
        SELECT b.Date, 
               a.CustNo, 
               a.EndDate, 
               a.StartDate
        INTO #ACTIVEDAYS
        FROM #STAGE a
             INNER JOIN #CustNo c ON a.CustNo = c.cm_CustNo
                                     AND c.BatchNo = @i
             INNER JOIN EDW.dbo.Dim_Date b ON b.Date BETWEEN a.ServicePeriodStart AND a.ServicePeriodEnd
        WHERE 1 = 1
              AND c.BatchNo = @i;
        --and DATE >='20100101'
        --CREATE NONCLUSTERED INDEX ixdaterange ON #ACTIVEDAYS(StartDate, EndDate, CustNo, date)

        PRINT('INTO #ALLDAYS' + CAST(DATEDIFF(s, @STARTTIME, GETDATE()) AS VARCHAR));
        IF OBJECT_ID('tempDB..#ALLDAYS') IS NOT NULL
            DROP TABLE #ALLDAYS;
        SELECT b.Date, 
               a.CustNo, 
               a.EndDate, 
               a.StartDate
        INTO #ALLDAYS
        FROM #STAGE a
             INNER JOIN #CustNo c ON a.CustNo = c.cm_CustNo
                                     AND c.BatchNo = @i
             INNER JOIN EDW.dbo.Dim_Date b ON b.Date BETWEEN a.StartDate AND a.EndDate
        WHERE 1 = 1
              AND c.BatchNo = @i
              AND DATE >= '20100101';
        --CREATE NONCLUSTERED INDEX ixdaterange ON #ALLDAYS(StartDate, EndDate, CustNo, date)

        IF OBJECT_ID('tempDB..#FINAL') IS NOT NULL
            DROP TABLE #FINAL;
        PRINT('INTO #FINAL' + CAST(DATEDIFF(s, @STARTTIME, GETDATE()) AS VARCHAR));
        SELECT DISTINCT 
               a.CustNo, 
               a.Date, 
               STATUS = CASE
                            WHEN b.CustNo IS NULL
                            THEN CAST('D' AS CHAR(1))
                            ELSE CAST('A' AS CHAR(1))
                        END
        INTO #FINAL
        FROM #ALLDAYS A
             LEFT JOIN #ACTIVEDAYS B ON a.CustNo = b.CustNo
                                        AND a.Date = b.Date;
        --WHERE 1=1
        --AND b.CustNo IS NULL
        --AND A.DATE> GETDATE() -6
        --CREATE NONCLUSTERED INDEX ixdaterange ON #FINAL(CustNo, date)

        PRINT('INSERT RESULTS' + CAST(DATEDIFF(s, @STARTTIME, GETDATE()) AS VARCHAR));

        --SELECT *
        --FROM #FINAL

        WITH CTE_STEP1
             AS (SELECT *, 
                        rnt = ROW_NUMBER() OVER(PARTITION BY CUSTNO
                        ORDER BY DATE), 
                        RNV = ROW_NUMBER() OVER(PARTITION BY CUSTNO, 
                                                             STATUS
                        ORDER BY DATE)
                 FROM #FINAL
                 WHERE 1 = 1),
             CTE_STEP2
             AS (SELECT *, 
                        GROUPIN = RNT - RNV
                 FROM CTE_STEP1)
             INSERT INTO LANDING..ResultsB WITH(TABLOCK)
                    SELECT CUSTNO, 
                           MIN(DATE) START_DATE, 
                           MAX(DATE) END_DATE, 
                           STATUS
                    FROM CTE_STEP2
                    --WHERE 1=1
                    --AND CustNo='600677' 
                    --AND STATUSISH = 'D'
                    GROUP BY CUSTNO, 
                             STATUS, 
                             GROUPIN;
        --ORDER BY CUSTNO, START_DATE DESC

        PRINT('INSERT COMPLETE' + CAST(DATEDIFF(s, @STARTTIME, GETDATE()) AS VARCHAR));
        SET @i = @i + 1;
    END;