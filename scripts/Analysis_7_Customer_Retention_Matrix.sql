USE [RheinTrade Solutions]
GO

-- Business Question: "What is our customer retention rate? Track yearly cohorts to see how many customers return in subsequent years."

WITH CustomerFirstOrder AS (
    -- Step 1: Find the "Cohort Year" (The year of the customer's very first successful order)
    SELECT 
        CustomerID, 
        YEAR(MIN(OrderDate)) AS CohortYear
    FROM [dbo].[Orders]
    WHERE OrderStatus IN ('Shipped', 'Delivered', 'Partially Returned', 'Returned')
    GROUP BY CustomerID
),
CohortActivity AS (
    -- Step 2: Map all subsequent orders to their respective Cohort Year
    SELECT 
        cfo.CohortYear,
        (YEAR(o.OrderDate) - cfo.CohortYear) AS YearIndex, -- Year 0 is the first year, Year 1 is the next year, etc.
        o.CustomerID
    FROM [dbo].[Orders] o
    INNER JOIN CustomerFirstOrder cfo ON o.CustomerID = cfo.CustomerID
    WHERE o.OrderStatus IN ('Shipped', 'Delivered', 'Partially Returned', 'Returned')
),
CohortRetention AS (
    -- Step 3: Count unique active customers for each Cohort and Year Index
    SELECT 
        ca.CohortYear,
        ca.YearIndex,
        COUNT(DISTINCT ca.CustomerID) AS RetainedCustomers
    FROM CohortActivity ca
    GROUP BY ca.CohortYear, ca.YearIndex
),
CohortSizes AS (
    -- Step 4: Calculate the total number of new customers acquired in that Cohort Year
    SELECT 
        CohortYear, 
        COUNT(DISTINCT CustomerID) AS TotalNewCustomers
    FROM CustomerFirstOrder
    GROUP BY CohortYear
)
-- Step 5: Pivot the data into a clean matrix format showing both Counts and Percentages
SELECT 
    cr.CohortYear,
    cs.TotalNewCustomers AS CohortSize,
    
    -- Year 0 is always 100% since it's the year they were acquired
    MAX(CASE WHEN cr.YearIndex = 0 THEN CAST(cr.RetainedCustomers AS VARCHAR) + ' (100%)' ELSE '-' END) AS [Year 0],
    MAX(CASE WHEN cr.YearIndex = 1 THEN CAST(cr.RetainedCustomers AS VARCHAR) + ' (' + CAST(CAST(cr.RetainedCustomers * 100.0 / cs.TotalNewCustomers AS DECIMAL(5,1)) AS VARCHAR) + '%)' ELSE '-' END) AS [Year 1],
    MAX(CASE WHEN cr.YearIndex = 2 THEN CAST(cr.RetainedCustomers AS VARCHAR) + ' (' + CAST(CAST(cr.RetainedCustomers * 100.0 / cs.TotalNewCustomers AS DECIMAL(5,1)) AS VARCHAR) + '%)' ELSE '-' END) AS [Year 2],
    MAX(CASE WHEN cr.YearIndex = 3 THEN CAST(cr.RetainedCustomers AS VARCHAR) + ' (' + CAST(CAST(cr.RetainedCustomers * 100.0 / cs.TotalNewCustomers AS DECIMAL(5,1)) AS VARCHAR) + '%)' ELSE '-' END) AS [Year 3],
    MAX(CASE WHEN cr.YearIndex = 4 THEN CAST(cr.RetainedCustomers AS VARCHAR) + ' (' + CAST(CAST(cr.RetainedCustomers * 100.0 / cs.TotalNewCustomers AS DECIMAL(5,1)) AS VARCHAR) + '%)' ELSE '-' END) AS [Year 4],
    MAX(CASE WHEN cr.YearIndex = 5 THEN CAST(cr.RetainedCustomers AS VARCHAR) + ' (' + CAST(CAST(cr.RetainedCustomers * 100.0 / cs.TotalNewCustomers AS DECIMAL(5,1)) AS VARCHAR) + '%)' ELSE '-' END) AS [Year 5],
    MAX(CASE WHEN cr.YearIndex = 6 THEN CAST(cr.RetainedCustomers AS VARCHAR) + ' (' + CAST(CAST(cr.RetainedCustomers * 100.0 / cs.TotalNewCustomers AS DECIMAL(5,1)) AS VARCHAR) + '%)' ELSE '-' END) AS [Year 6]
    
FROM CohortRetention cr
INNER JOIN CohortSizes cs ON cr.CohortYear = cs.CohortYear
GROUP BY cr.CohortYear, cs.TotalNewCustomers
ORDER BY cr.CohortYear;

