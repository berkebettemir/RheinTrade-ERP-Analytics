USE [RheinTrade Solutions]
GO

-- Business Question: "Which sales employees generate the highest average annual profit, and what is their primary territory?"

WITH EmployeeRawData AS (
    SELECT 
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        e.SeniorityLevel,
        e.HireDate,
        
        -- Find the primary territory name for the employee
        (SELECT TOP 1 co.CountryName 
         FROM [dbo].[EmployeeTerritories] et 
         INNER JOIN [dbo].[Countries] co ON et.CountryID = co.CountryID
         WHERE et.EmployeeID = e.EmployeeID AND et.IsPrimary = 1) AS PrimaryTerritory,
         
        -- Calculate tenure in years
        CASE 
            WHEN DATEDIFF(MONTH, e.HireDate, GETDATE()) < 12 THEN 1.0 
            ELSE DATEDIFF(MONTH, e.HireDate, GETDATE()) / 12.0 
        END AS TenureYears,
        
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        SUM((od.Quantity - ISNULL(r.TotalReturnedQty, 0)) * (od.UnitPrice * (1 - od.DiscountRate))) AS NetRevenue,
        SUM((od.Quantity - ISNULL(r.TotalReturnedQty, 0)) * (od.UnitPrice * (1 - od.DiscountRate) - p.CostPrice)) AS NetProfit
    FROM [dbo].[Employees] e
    INNER JOIN [dbo].[Orders] o ON e.EmployeeID = o.EmployeeID
    INNER JOIN [dbo].[OrderDetails] od ON o.OrderID = od.OrderID
    INNER JOIN [dbo].[Products] p ON od.ProductID = p.ProductID
    OUTER APPLY (
        SELECT SUM(QuantityReturned) AS TotalReturnedQty
        FROM [dbo].[Returns] ret
        WHERE ret.OrderDetailID = od.OrderDetailID
    ) r
    WHERE o.OrderStatus IN ('Shipped', 'Delivered', 'Partially Returned', 'Returned')
    GROUP BY e.EmployeeID, e.FirstName, e.LastName, e.SeniorityLevel, e.HireDate
)
SELECT 
    EmployeeName,
    SeniorityLevel,
    ISNULL(PrimaryTerritory, 'Global/HQ') AS PrimaryTerritory,
    
    -- Format Tenure to 1 decimal place (e.g., 4.5)
    CAST(TenureYears AS DECIMAL(10,1)) AS TenureYears,
    
    TotalOrders,
    FORMAT(NetRevenue, 'C', 'de-DE') AS LifetimeRevenue,
    FORMAT(NetRevenue / TenureYears, 'C', 'de-DE') AS AvgAnnualRevenue,
    FORMAT(NetProfit / TenureYears, 'C', 'de-DE') AS AvgAnnualProfit,
    
    -- Format Profit Margin clean (e.g., 42.00%)
    CAST(CAST(ROUND((NetProfit / NULLIF(NetRevenue, 0)) * 100, 2) AS DECIMAL(5,2)) AS VARCHAR) + '%' AS ProfitMarginPct
FROM EmployeeRawData
ORDER BY (NetProfit / TenureYears) DESC;

