USE [RheinTrade Solutions]
GO

-- Business Question: "How has each Main Category's net revenue evolved over the years, and which segments show the strongest growth trends?"

WITH YearlyCategorySales AS (
    SELECT 
        COALESCE(L1.CategoryName, L2.CategoryName, c.CategoryName) AS MainCategory,
        YEAR(o.OrderDate) AS SalesYear,
        -- Calculate True Net Revenue (Orders - Returns)
        SUM((od.Quantity - ISNULL(r.TotalReturnedQty, 0)) * (od.UnitPrice * (1 - od.DiscountRate))) AS NetRevenue
    FROM [dbo].[Orders] o
    INNER JOIN [dbo].[OrderDetails] od ON o.OrderID = od.OrderID
    INNER JOIN [dbo].[Products] p ON od.ProductID = p.ProductID
    INNER JOIN [dbo].[Categories] c ON p.CategoryID = c.CategoryID
    LEFT JOIN [dbo].[Categories] L2 ON c.ParentCategoryID = L2.CategoryID
    LEFT JOIN [dbo].[Categories] L1 ON L2.ParentCategoryID = L1.CategoryID
    OUTER APPLY (
        -- Aggregating returns for the specific order line
        SELECT SUM(QuantityReturned) AS TotalReturnedQty
        FROM [dbo].[Returns] ret
        WHERE ret.OrderDetailID = od.OrderDetailID
    ) r
    WHERE o.OrderStatus IN ('Shipped', 'Delivered', 'Partially Returned', 'Returned')
	AND YEAR(o.OrderDate) < 2026
    GROUP BY COALESCE(L1.CategoryName, L2.CategoryName, c.CategoryName), YEAR(o.OrderDate)
)
SELECT 
    MainCategory,
    SalesYear,
    FORMAT(NetRevenue, 'C', 'de-DE') AS CurrentYearRevenue,
    -- Fetching Previous Year's Revenue using the LAG() window function
    FORMAT(LAG(NetRevenue) OVER (PARTITION BY MainCategory ORDER BY SalesYear), 'C', 'de-DE') AS PriorYearRevenue,
    -- Calculating Growth Percentage
    CAST(ROUND(((NetRevenue - LAG(NetRevenue) OVER (PARTITION BY MainCategory ORDER BY SalesYear)) 
          / NULLIF(LAG(NetRevenue) OVER (PARTITION BY MainCategory ORDER BY SalesYear), 0)) * 100, 2) AS VARCHAR) + '%' AS YoY_Growth_Pct
FROM YearlyCategorySales
ORDER BY MainCategory, SalesYear;

