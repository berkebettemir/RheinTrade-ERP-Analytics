USE [RheinTrade Solutions]
GO

-- Business Question: "Identify top 30 customers by True Net Revenue, including their segment, region, and tenure (time since registration)."

WITH CustomerReturns AS (
    -- Calculate total returned quantities per order detail
    SELECT 
        od.OrderDetailID,
        ISNULL(SUM(r.QuantityReturned), 0) AS TotalReturnedQty
    FROM [dbo].[OrderDetails] od
    LEFT JOIN [dbo].[Returns] r ON od.OrderDetailID = r.OrderDetailID
    GROUP BY od.OrderDetailID
),
CustomerBase AS (
    SELECT 
        c.CustomerID,
        c.CompanyName,
        c.CustomerType,
        c.CreatedDate,
        co.CountryName,
        co.Region,
        s.SegmentName,
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        -- Net Revenue: (Ordered - Returned) * Discounted Price
        SUM((od.Quantity - cr.TotalReturnedQty) * (od.UnitPrice * (1 - od.DiscountRate))) AS TrueNetRevenue
    FROM [dbo].[Customers] c
    INNER JOIN [dbo].[Countries] co ON c.CountryID = co.CountryID
    LEFT JOIN [dbo].[CustomerSegments] s ON c.SegmentID = s.SegmentID
    INNER JOIN [dbo].[Orders] o ON c.CustomerID = o.CustomerID
    INNER JOIN [dbo].[OrderDetails] od ON o.OrderID = od.OrderID
    INNER JOIN CustomerReturns cr ON od.OrderDetailID = cr.OrderDetailID
    WHERE o.OrderStatus IN ('Shipped', 'Delivered', 'Partially Returned', 'Returned')
    GROUP BY c.CustomerID, c.CompanyName, c.CustomerType, c.CreatedDate, co.CountryName, co.Region, s.SegmentName
)
SELECT TOP 30    -- Change the "30" if you want to see more customers
    CompanyName,
    CustomerType,
    CountryName,
    Region,
    ISNULL(SegmentName, 'No Segment') AS CurrentSegment,
    CreatedDate AS CustomerSince,
    -- Calculate how many days they have been in our system
    DATEDIFF(DAY, CreatedDate, GETDATE()) AS TenureInDays,
    TotalOrders,
    FORMAT(TrueNetRevenue, 'C', 'de-DE') AS LifetimeValue,
    CASE 
        WHEN TrueNetRevenue > 250000 THEN 'Platinum Whale'
        WHEN TrueNetRevenue BETWEEN 150000 AND 250000 THEN 'Gold Whale'
        ELSE 'Silver Tier'
    END AS InternalTier
FROM CustomerBase
ORDER BY TrueNetRevenue DESC;
