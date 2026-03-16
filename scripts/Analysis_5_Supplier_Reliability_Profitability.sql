USE [RheinTrade Solutions]
GO

-- Business Question: "Which suppliers generate the highest net profit, and how do their product return rates (quality indicators) affect our bottom line?"

WITH SupplierProductStats AS (
    SELECT 
        s.SupplierID,
        s.SupplierName,
        s.Country,
        s.IsPreferredSupplier,
        od.Quantity AS OrderedQty,
        ISNULL(r.QuantityReturned, 0) AS ReturnedQty,
        
        -- Calculate True Net Revenue (Ordered minus Returned)
        (od.Quantity - ISNULL(r.QuantityReturned, 0)) * (od.UnitPrice * (1 - od.DiscountRate)) AS NetRevenue,
        
        -- Calculate True Net Profit
        (od.Quantity - ISNULL(r.QuantityReturned, 0)) * (od.UnitPrice * (1 - od.DiscountRate) - p.CostPrice) AS NetProfit
    FROM [dbo].[Suppliers] s
    INNER JOIN [dbo].[Products] p ON s.SupplierID = p.SupplierID
    INNER JOIN [dbo].[OrderDetails] od ON p.ProductID = od.ProductID
    INNER JOIN [dbo].[Orders] o ON od.OrderID = o.OrderID
    
    -- Fetch the exact returned quantity for this specific order line
    OUTER APPLY (
        SELECT SUM(QuantityReturned) AS QuantityReturned
        FROM [dbo].[Returns] ret
        WHERE ret.OrderDetailID = od.OrderDetailID
    ) r
    
    -- Include all orders that physically shipped
    WHERE o.OrderStatus IN ('Shipped', 'Delivered', 'Partially Returned', 'Returned')
)
SELECT 
    SupplierName,
    Country,
    -- Clearly flag if they are a VIP partner
    CASE WHEN IsPreferredSupplier = 1 THEN 'Yes (Preferred)' ELSE 'No' END AS PreferredStatus,
    
    SUM(OrderedQty) AS TotalUnitsSold,
    SUM(ReturnedQty) AS TotalUnitsReturned,
    
    -- Quality Metric: Return Rate Percentage
    CAST(CAST(ROUND((SUM(CAST(ReturnedQty AS FLOAT)) / NULLIF(SUM(OrderedQty), 0)) * 100, 2) AS DECIMAL(5,2)) AS VARCHAR) + '%' AS ReturnRatePct,
    
    FORMAT(SUM(NetRevenue), 'C', 'de-DE') AS NetRevenue,
    FORMAT(SUM(NetProfit), 'C', 'de-DE') AS NetProfit,
    
    -- Financial Metric: True Net Profit Margin
    CAST(CAST(ROUND((SUM(NetProfit) / NULLIF(SUM(NetRevenue), 0)) * 100, 2) AS DECIMAL(5,2)) AS VARCHAR) + '%' AS ProfitMarginPct
    
FROM SupplierProductStats
GROUP BY SupplierID, SupplierName, Country, IsPreferredSupplier
ORDER BY SUM(NetProfit) DESC; -- Sort by the ones making us the most money

