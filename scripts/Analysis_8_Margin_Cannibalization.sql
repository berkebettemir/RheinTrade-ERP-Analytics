USE [RheinTrade Solutions]
GO

-- Business Question: "Compare Discounted vs. Full Price sales to measure margin cannibalization and volume lift."

WITH FlattenedCategories AS (
    -- Grouping into Main Categories for a high-level executive view
    SELECT 
        c.CategoryID,
        COALESCE(L1.CategoryName, L2.CategoryName, c.CategoryName) AS MainCategory
    FROM [dbo].[Categories] c
    LEFT JOIN [dbo].[Categories] L2 ON c.ParentCategoryID = L2.CategoryID
    LEFT JOIN [dbo].[Categories] L1 ON L2.ParentCategoryID = L1.CategoryID
),
DiscountAnalysis AS (
    SELECT 
        fc.MainCategory,
        -- Splitting sales into two strategic buckets
        CASE WHEN od.DiscountRate > 0 THEN 'Discounted' ELSE 'Full Price' END AS PricingStrategy,
        
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        SUM(od.Quantity - ISNULL(r.TotalReturnedQty, 0)) AS NetUnitsSold,
        
        -- Financials (Adjusted for Returns)
        SUM((od.Quantity - ISNULL(r.TotalReturnedQty, 0)) * (od.UnitPrice * (1 - od.DiscountRate))) AS NetRevenue,
        SUM((od.Quantity - ISNULL(r.TotalReturnedQty, 0)) * (od.UnitPrice * (1 - od.DiscountRate) - p.CostPrice)) AS NetProfit,
        
        -- Calculate the average discount given ONLY for the discounted bucket
        AVG(CASE WHEN od.DiscountRate > 0 THEN od.DiscountRate ELSE NULL END) AS AvgDiscountGiven
    FROM [dbo].[Orders] o
    INNER JOIN [dbo].[OrderDetails] od ON o.OrderID = od.OrderID
    INNER JOIN [dbo].[Products] p ON od.ProductID = p.ProductID
    INNER JOIN FlattenedCategories fc ON p.CategoryID = fc.CategoryID
    OUTER APPLY (
        SELECT SUM(QuantityReturned) AS TotalReturnedQty
        FROM [dbo].[Returns] ret
        WHERE ret.OrderDetailID = od.OrderDetailID
    ) r
    WHERE o.OrderStatus IN ('Shipped', 'Delivered', 'Partially Returned', 'Returned')
      -- Ensure we only calculate for items that actually stayed with the customer
      AND (od.Quantity - ISNULL(r.TotalReturnedQty, 0)) > 0
    GROUP BY fc.MainCategory, CASE WHEN od.DiscountRate > 0 THEN 'Discounted' ELSE 'Full Price' END
)
SELECT 
    MainCategory,
    PricingStrategy,
    TotalOrders,
    NetUnitsSold,
    
    -- Clean formatting for percentages
    ISNULL(CAST(CAST(ROUND(AvgDiscountGiven * 100, 2) AS DECIMAL(5,2)) AS VARCHAR) + '%', '0.00%') AS AvgDiscountPct,
    
    FORMAT(NetRevenue, 'C', 'de-DE') AS NetRevenue,
    FORMAT(NetProfit, 'C', 'de-DE') AS NetProfit,
    
    -- True Net Profit Margin for comparison
    CAST(CAST(ROUND((NetProfit / NULLIF(NetRevenue, 0)) * 100, 2) AS DECIMAL(5,2)) AS VARCHAR) + '%' AS ProfitMarginPct
FROM DiscountAnalysis
ORDER BY MainCategory, PricingStrategy DESC;
