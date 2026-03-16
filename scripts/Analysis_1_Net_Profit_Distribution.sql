USE [RheinTrade Solutions]
GO

-- Business Question: "What is our true net profitability across the 3-tier product hierarchy after strictly accounting for product returns and refunds?"

WITH FlattenedCategories AS (
    -- Handling ragged hierarchy (3 levels) using Self-Joins
    SELECT 
        c.CategoryID AS ProductCategoryID,
        COALESCE(L1.CategoryName, L2.CategoryName, c.CategoryName) AS MainCategory,
        CASE 
            WHEN L1.CategoryName IS NOT NULL THEN L2.CategoryName
            WHEN L2.CategoryName IS NOT NULL THEN c.CategoryName
            ELSE 'N/A'
        END AS SubCategory,
        CASE 
            WHEN L1.CategoryName IS NOT NULL THEN c.CategoryName
            ELSE 'N/A'
        END AS LeafCategory
    FROM [dbo].[Categories] c
    LEFT JOIN [dbo].[Categories] L2 ON c.ParentCategoryID = L2.CategoryID
    LEFT JOIN [dbo].[Categories] L1 ON L2.ParentCategoryID = L1.CategoryID
),
BaseData AS (
    SELECT 
        fc.MainCategory,
        fc.SubCategory,
        fc.LeafCategory,
        o.OrderID,
        
        -- Calculate Net Quantity (Ordered Quantity minus Returned Quantity)
        (od.Quantity - ISNULL(r.TotalReturnedQty, 0)) AS NetQuantity,
        
        -- True Net Revenue: Calculated only on items that stayed with the customer
        ((od.Quantity - ISNULL(r.TotalReturnedQty, 0)) * (od.UnitPrice * (1 - od.DiscountRate))) AS TrueNetRevenue,
        
        -- True Net Cost: Calculated only on items that stayed with the customer
        ((od.Quantity - ISNULL(r.TotalReturnedQty, 0)) * p.CostPrice) AS TrueTotalCost
        
    FROM [dbo].[Orders] o
    INNER JOIN [dbo].[OrderDetails] od ON o.OrderID = od.OrderID
    INNER JOIN [dbo].[Products] p ON od.ProductID = p.ProductID
    INNER JOIN FlattenedCategories fc ON p.CategoryID = fc.ProductCategoryID
    
    -- Using OUTER APPLY to fetch the exact returned quantity for each specific order detail
    OUTER APPLY (
        SELECT SUM(QuantityReturned) AS TotalReturnedQty
        FROM [dbo].[Returns] ret
        WHERE ret.OrderDetailID = od.OrderDetailID
    ) r
    
    -- Filter to include orders that physically reached the customer (even if partially/fully returned later)
    WHERE o.OrderStatus IN ('Shipped', 'Delivered', 'Partially Returned', 'Returned')
)
SELECT 
    MainCategory,
    -- Display a clean label for the summary rows
    ISNULL(SubCategory, CASE WHEN GROUPING(SubCategory) = 1 THEN '[ MAIN CATEGORY SUMMARY ]' ELSE SubCategory END) AS SubCategory,
    ISNULL(LeafCategory, '') AS LeafCategory,
    
    COUNT(DISTINCT OrderID) AS TotalOrdersProcessed,
    SUM(NetQuantity) AS NetUnitsSold,
    
    FORMAT(SUM(TrueNetRevenue), 'C', 'de-DE') AS TrueNetRevenue,
    FORMAT(SUM(TrueTotalCost), 'C', 'de-DE') AS TrueTotalCost,
    FORMAT((SUM(TrueNetRevenue) - SUM(TrueTotalCost)), 'C', 'de-DE') AS TrueNetProfit,
    
    -- Profit Margin Percentage (Safeguarded against divide-by-zero if everything was returned)
    CAST(ROUND((ISNULL((SUM(TrueNetRevenue) - SUM(TrueTotalCost)) / NULLIF(SUM(TrueNetRevenue), 0), 0)) * 100, 2) AS VARCHAR) + '%' AS TrueProfitMarginPct

FROM BaseData
GROUP BY 
    -- GROUPING SETS for Drill-Down functionality
    GROUPING SETS (
        (MainCategory),                                  
        (MainCategory, SubCategory, LeafCategory)        
    )
ORDER BY 
    MainCategory, 
    GROUPING(SubCategory) DESC, 
    SUM(TrueNetRevenue) DESC;

