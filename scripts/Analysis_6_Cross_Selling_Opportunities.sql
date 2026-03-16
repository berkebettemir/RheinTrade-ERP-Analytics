USE [RheinTrade Solutions]
GO

-- Business Question: "Which product pairs are most frequently bought together, and what categories do they belong to?"

WITH ValidOrders AS (
    -- Filter only finalized orders to analyze actual customer purchasing behavior
    SELECT OrderID
    FROM [dbo].[Orders]
    WHERE OrderStatus IN ('Shipped', 'Delivered', 'Partially Returned', 'Returned')
),
ProductPairs AS (
    -- SELF-JOIN: Match items within the same order
    SELECT 
        od1.ProductID AS Product1_ID,
        od2.ProductID AS Product2_ID,
        -- Count how many unique orders contain this exact pair
        COUNT(DISTINCT od1.OrderID) AS Frequency
    FROM [dbo].[OrderDetails] od1
    INNER JOIN [dbo].[OrderDetails] od2 
        ON od1.OrderID = od2.OrderID 
        -- The "<" operator is crucial here: 
        -- 1. Prevents matching a product with itself (A-A)
        -- 2. Prevents duplicate pairs (Counting A-B and B-A as two different things)
        AND od1.ProductID < od2.ProductID 
    INNER JOIN ValidOrders vo ON od1.OrderID = vo.OrderID
    GROUP BY od1.ProductID, od2.ProductID
)
SELECT TOP 20
    p1.ProductName AS ProductA,
    c1.CategoryName AS CategoryA,
    '        +  ' AS [Bought With], -- Visual separator for the report
    p2.ProductName AS ProductB,
    c2.CategoryName AS CategoryB,
    pp.Frequency AS TimesBoughtTogether
FROM ProductPairs pp
INNER JOIN [dbo].[Products] p1 ON pp.Product1_ID = p1.ProductID
INNER JOIN [dbo].[Products] p2 ON pp.Product2_ID = p2.ProductID
-- Joining categories to see if cross-selling happens within the same category or across different ones
INNER JOIN [dbo].[Categories] c1 ON p1.CategoryID = c1.CategoryID
INNER JOIN [dbo].[Categories] c2 ON p2.CategoryID = c2.CategoryID
ORDER BY pp.Frequency DESC;

