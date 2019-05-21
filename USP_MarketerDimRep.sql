USE LANDING;
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Kodjovi Togbey
-- Create date: 05/15/2019
-- Description:	To update a the marketer Dim_Rep
-- Exec USP_MarketerDimRep
-- =============================================
ALTER PROCEDURE USP_MarketerDimRep 
	-- Add the parameters for the stored procedure here

AS
BEGIN

	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DROP TABLE IF EXISTS #TEMP;
SELECT DISTINCT
       (Agent) AS Marketer, 
       Rep_ID
INTO #TEMP
FROM ClearviewPrd..SalesRecords WITH(NOLOCK)
WHERE 1 = 1
      AND [KEY] IN
(
    SELECT KEY1
    FROM [Audit].[dbo].[AUDIT_UNDO] WITH(NOLOCK)
    WHERE TABLE_NAME = 'SalesRecords'
          AND COL_NAME = 'CustNo'
          AND ACTION_NAME = 'Update'
          AND OLD_VALUE = '0'
)
      AND agent IS NOT NULL
UNION
SELECT DISTINCT
       (cm_AgentInformation) AS Marketer, Case When cm_AgentInformation ='Online' Then cm_HeardAboutBy Else cm_RepID END 
        Rep_ID
FROM ClearviewPrd..CustomerMaster WITH(NOLOCK)
WHERE 1 = 1
      AND cm_AgentInformation IS NOT NULL;
DROP TABLE IF EXISTS #TEMP1;
SELECT *, 
       CONCAT(marketer, Rep_ID) AS value
INTO #temp1
FROM #TeMP
WHERE Rep_ID IS NOT NULL;

--Select  rep_id,b.Marketer_ID
--From #temp1 a
--left join edw..Marketer b on a.Marketer=b.Marketer
--where value not in (
--Select concat(marketer,Repvalue)
--From edw..uvwTEMPdimmarketerhier)

INSERT INTO EDW.Marketer.DIM_Rep
(RepValue, 
 Marketer_ID
)
       SELECT rep_id, 
              b.Marketer_ID
       FROM #temp1 a
            LEFT JOIN EDW.Marketer.DIM_Marketer b ON a.Marketer = b.Marketer
       WHERE value NOT IN
       (
           SELECT concat(marketer, Repvalue)
           FROM edw.MARKETER.uvwTEMPdimmarketerhier
       )
       ORDER BY Rep_ID;

Delete 
--Select *
From EDW.Marketer.DIM_Rep
where marketer_id is null

--SELECT *
--FROM EDW.Marketer.DIM_Rep
--ORDER BY Rep_ID DESC;

END
GO
