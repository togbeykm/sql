USE LANDING;
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Kodjovi Togbey
-- Create date: 05/15/2019
-- Description:	To generate Marketer Audit History
-- Exec USP_MarketerAuditHistory 
-- =============================================
CREATE PROCEDURE USP_MarketerAuditHistory 
	-- Add the parameters for the stored procedure here

AS
BEGIN

	SET NOCOUNT ON;

    -- Insert statements for procedure here
DROP TABLE IF EXISTS #TEMP;
SELECT [AUDIT_LOG_TRANSACTION_ID], 
       [TABLE_NAME], 
       [TABLE_SCHEMA], 
       [ACTION_NAME], 
       [HOST_NAME], 
       [APP_NAME], 
       [MODIFIED_BY], 
       [MODIFIED_DATE], 
       [AFFECTED_ROWS], 
       [AUDIT_LOG_DATA_ID], 
       [PRIMARY_KEY], 
       [COL_NAME], 
       [OLD_VALUE], 
       [NEW_VALUE], 
       [DATA_TYPE], 
       replace([PRIMARY_KEY], '[cm_CustNo]=', '') AS AcctNo, 
       CAST(CONVERT(VARCHAR(10), [MODIFIED_DATE], 112) AS INT) AS Moddate, 
       RN = ROW_NUMBER() OVER(PARTITION BY replace([PRIMARY_KEY], '[cm_CustNo]=', ''), 
                                           COL_NAME
       ORDER BY [MODIFIED_DATE] ASC)
INTO #TEMP
FROM [Audit].[dbo].[AUDIT_UNDO] WITH(NOLOCK)
WHERE TABLE_NAME = 'CustomerMaster'
--AND [PRIMARY_KEY] = '[cm_CustNo]=584977'
      AND COL_NAME IN('cm_AgentInformation')
ORDER BY MODIFIED_DATE;

DROP TABLE IF EXISTS #FINAL;
SELECT a.AcctNo, 
       a.OLD_VALUE AS CurrentMarketer, 
       d.Moddate StartDate,
       --ISNULL(d.Moddate,cast(s.Sell_Date as varchar(10))) StartDate, 
       a.Moddate [EndDate]
	   ,Case When c.cm_AgentInformation ='Online' Then c.cm_HeardAboutBy Else c.cm_RepID END 
         as RepID
INTO #FINAL
FROM #TEMP a
     LEFT JOIN #TEMP b ON a.RN = b.RN - 1
                          AND a.AcctNo = b.AcctNo
                          AND a.[COL_NAME] = 'cm_AgentInformation'
     INNER JOIN [ClearviewPrd]..CustomerMaster c WITH(NOLOCK) ON a.AcctNo = c.cm_CustNo
     LEFT JOIN #TEMP d ON a.RN = d.RN + 1
                          AND a.AcctNo = d.AcctNo
                          AND a.[COL_NAME] = 'cm_AgentInformation'
WHERE a.[COL_NAME] = 'cm_AgentInformation'
and c.cm_CurrentStatus not in('x-out', 'Info Call','X-Out')
UNION
SELECT cm_CustNo, 
       cm_AgentInformation, 
       MAX(moddate), 
       '21991231'
	   ,Case When c.cm_AgentInformation ='Online' Then c.cm_HeardAboutBy Else c.cm_RepID END as REPID
FROM [ClearviewPrd]..CustomerMaster c WITH(NOLOCK)
     INNER JOIN #TEMP t ON c.cm_CustNo = t.AcctNo
	WHERE --a.[COL_NAME] = 'cm_AgentInformation'
c.cm_CurrentStatus not in('x-out', 'Info Call','X-Out')
GROUP BY cm_CustNo, 
         cm_AgentInformation 
         ,cm_RepID
		 ,c.cm_AgentInformation
		 ,c.cm_HeardAboutBy
ORDER BY a.AcctNo, 
         StartDate, 
         [EndDate];

--Select *
--FROM #Final
----where acctno=54
DROP TABLE IF EXISTS [LANDING].[dbo].[AuditHistory];
SELECT DISTINCT
       (AcctNo), 
       CurrentMarketer, 
       --StartDate, 
       ISNULL(StartDate, CONVERT(VARCHAR(10), MIN(s.Sell_Date), 112)) StartDate, 
       --s.Sell_Date,
       [EndDate]
	   ,s.Rep_ID
INTO [LANDING].[dbo].[AuditHistory]
FROM #FINAL a
     LEFT JOIN Raw.cvos.SalesRecordsAll s WITH(NOLOCK) ON a.AcctNo = s.CustNo
                                                          --AND s.Channel = a.CurrentMarketer
                                                          AND CONVERT(VARCHAR(10), s.Sell_Date, 112) <= EndDate
WHERE 1 = 1
      AND CurrentMarketer IS NOT NULL
	  --and AcctNo='362115'
GROUP BY AcctNo, 
         CurrentMarketer, 
         StartDate, 
         [EndDate]
		 ,s.Rep_ID
ORDER BY a.AcctNo, 
         StartDate, 
         [EndDate];

--Select * 
--From [LANDING].[dbo].[AuditHistory]
----where AcctNo=110513


END
GO
