SELECT Marketeraccountnumber
     , Servicestatus
     , Start_Date = MIN(CAST(Filepath AS DATE))
     , End_Date = MAX(CAST(Filepath AS DATE))
     , Cluster = Rn - New_Rn
INTO Staging.Dbo.Powwr_Appan_Run
FROM
(
    SELECT Marketeraccountnumber
         , Filepath = CAST(Filepath AS DATE)
         , Rn = ROW_NUMBER() OVER(
           ORDER BY Filepath)
         , New_Rn = ROW_NUMBER() OVER(PARTITION BY Marketeraccountnumber
                                                 , Servicestatus
           ORDER BY Filepath)
         , Servicestatus
    FROM Staging.Dbo.Powwr
) A
GROUP BY Marketeraccountnumber
       , Servicestatus
       , Rn - New_Rn
ORDER BY Start_Date
