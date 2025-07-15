CREATE TABLE Store (
    Store_ID VARCHAR(10),
    Region VARCHAR(15)
);

CREATE TABLE Product (
    Product_ID VARCHAR(10),
    Category VARCHAR(20),
    Price DECIMAL(7 , 2 )
);

CREATE TABLE Weather (
    Date VARCHAR(10),
    Store_ID VARCHAR(10),
    Weather_Condition VARCHAR(15),
    Seasonality VARCHAR(15)
);

CREATE TABLE Inventory_Fact (
    Date VARCHAR(10),
    Store_ID VARCHAR(10),
    Product_ID VARCHAR(10),
    Inventory_Level INT,
    Units_Sold INT,
    Units_Ordered INT,
    Demand_Forecast DECIMAL(7 , 2 )
);




INSERT INTO Store (Store_ID, Region)
SELECT DISTINCT Store_ID, Region
FROM inventory_forecasting;


INSERT INTO Product (Product_ID, Category,Price)
SELECT DISTINCT Product_ID, Category , Price
FROM inventory_forecasting;


INSERT INTO Weather (Date, Store_ID, Weather_Condition, Seasonality)
SELECT DISTINCT Date, Store_ID, Weather_Condition, Seasonality
FROM inventory_forecasting;


INSERT INTO Inventory_Fact (
    Date,
    Store_ID,
    Product_ID,
    Inventory_Level,
    Units_Sold,
    Units_Ordered,
    Demand_Forecast
)
SELECT
    Date,
    Store_ID,
    Product_ID,
    Inventory_Level,
    Units_Sold,
    Units_Ordered,
    Demand_Forecast
FROM inventory_forecasting;


---------------------------------------------------------------------------------------------------------------------------------
-- Store + Region" = Unique Logical Store

-- Fast Moving products 
-- Identify products that sell the most

CREATE INDEX idx_inventory_main_sales ON inventory_main(Product_ID, Units_Sold);

WITH ProductSales AS (
    SELECT 
        CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
        I.Product_ID,
        SUM(I.Units_Sold) AS Total_Sales
    FROM 
        inventory_main I
    JOIN 
        Store S ON I.Store_ID = S.Store_ID
    GROUP BY 
        S.Store_ID, S.Region, I.Product_ID
),
RankedSales AS (
    SELECT 
        Store_Region_ID,
        Product_ID,
        Total_Sales,
        RANK() OVER (PARTITION BY Store_Region_ID ORDER BY Total_Sales DESC) AS rnk
    FROM 
        ProductSales
)
SELECT 
    Store_Region_ID,
    Product_ID,
    Total_Sales
FROM 
    RankedSales
WHERE 
    rnk <= 5;


----------------------------------------------------------------------------------------------

-- Slow Moving products 
-- Identify products that sell the least

WITH ProductSales AS (
    SELECT 
        CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
        I.Product_ID,
        SUM(I.Units_Sold) AS Total_Sales
    FROM 
        inventory_main I
    JOIN 
        Store S ON I.Store_ID = S.Store_ID
    GROUP BY 
        S.Store_ID, S.Region, I.Product_ID
),
RankedSales AS (
    SELECT 
        Store_Region_ID,
        Product_ID,
        Total_Sales,
        RANK() OVER (PARTITION BY Store_Region_ID ORDER BY Total_Sales ASC) AS rnk
    FROM 
        ProductSales
)
SELECT 
    Store_Region_ID,
    Product_ID,
    Total_Sales
FROM 
    RankedSales
WHERE 
    rnk <= 5;

-----------------------------------------------------------------------------------------------

-- Stock Level Calculations across Store-Regions

SELECT 
    CONCAT(I.Store_ID, '-', S.Region) AS Store_Region_ID,
    I.Product_ID,
    MAX(I.Inventory_Level) AS Current_Stock
FROM 
    Inventory_main I
JOIN 
    Store S ON I.Store_ID = S.Store_ID
GROUP BY 
    I.Store_ID, S.Region, I.Product_ID;

----------------------------------------------------------------------------------------------------------------------------

-- Reorder Point Estimation Using Historical Sales 
-- helps estimate when to reorder a product based on actual sales trends. 

SELECT 
    I.Product_ID,
    CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,  
    ROUND(SUM(I.Units_Sold) * 1.0 / COUNT(DISTINCT STR_TO_DATE(I.Date, '%Y-%m-%d')), 2) AS Avg_Daily_Sales,  -- Avg sold per day
    3 AS Lead_Time_Days,  -- Assuming it takes 3 days to restock
    ROUND((SUM(I.Units_Sold) * 1.0 / COUNT(DISTINCT STR_TO_DATE(I.Date, '%Y-%m-%d'))) * 3, 2) AS Reorder_Point  -- ROP = Avg x Lead time
FROM 
    inventory_main I
JOIN 
    Store S ON I.Store_ID = S.Store_ID
WHERE 
    STR_TO_DATE(I.Date, '%Y-%m-%d') IS NOT NULL
GROUP BY 
    I.Product_ID, S.Store_ID, S.Region
ORDER BY 
    Reorder_Point DESC;

-----------------------------------------------------------------------------------------------------------------------------

-- Low Inventory Detection based on reorder point`
-- Daily Sales per Product per Store_Region

WITH DailySales AS (
    SELECT 
        I.Product_ID,
        CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
        COUNT(DISTINCT I.Date) AS Active_Days,                 -- Unique dates with sales
        SUM(I.Units_Sold) AS Total_Sales,                      -- Total units sold
        AVG(I.Inventory_Level) AS Avg_Stock                    -- Average stock for context
    FROM 
        inventory_main I
    JOIN 
        Store S ON I.Store_ID = S.Store_ID
    GROUP BY 
        I.Product_ID, S.Store_ID, S.Region
),

-- Reorder Point = Avg Daily Sales × Lead Time
-- we use a fixed Lead Time = 3 days
ReorderPointCalc AS (
    SELECT 
        Product_ID,
        Store_Region_ID,
        ROUND(Total_Sales * 1.0 / NULLIF(Active_Days, 0), 2) AS Avg_Daily_Sales,
        ROUND((Total_Sales * 1.0 / NULLIF(Active_Days, 0)) * 3, 2) AS Estimated_Reorder_Point
    FROM 
        DailySales
),

LatestStock AS (
    SELECT 
        I.Product_ID,
        CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
        MAX(I.Inventory_Level) AS Current_Inventory            -- Latest stock info
    FROM 
        inventory_main I
    JOIN 
        Store S ON I.Store_ID = S.Store_ID
    GROUP BY 
        I.Product_ID, S.Store_ID, S.Region
)

SELECT 
    R.Product_ID,
    R.Store_Region_ID,
    R.Avg_Daily_Sales,
    R.Estimated_Reorder_Point,
    L.Current_Inventory,
    CASE 
        WHEN L.Current_Inventory < R.Estimated_Reorder_Point 
            THEN 'Low Inventory - Needs Reorder'
        ELSE 'Sufficient'
    END AS Status
FROM 
    ReorderPointCalc R
JOIN 
    LatestStock L 
ON 
    R.Product_ID = L.Product_ID AND R.Store_Region_ID = L.Store_Region_ID
ORDER BY 
    Status DESC;


-----------------------------------------------------------------------------------------------------------------------------

-- Inventory Turnover Analysis
-- Measure how fast inventory is sold and replaced.

CREATE INDEX idx_product_inventory ON Inventory_main(Product_ID, Units_Sold, Inventory_Level);

WITH Aggregated AS (
    SELECT 
        Product_ID,
        SUM(Units_Sold) AS Total_Sales,
        AVG(Inventory_Level) AS Avg_Inventory
    FROM 
        Inventory_main
    GROUP BY 
        Product_ID
)
SELECT 
    Product_ID,
    Total_Sales * 1.0 / NULLIF(Avg_Inventory, 0) AS Inventory_Turnover_Rate
FROM 
    Aggregated
WHERE 
    Avg_Inventory IS NOT NULL;
    
------------------------------------------------------------------------------------------------------------------

-- Average Inventory Level : Mean stock available over time
-- Helps balance between overstocking (waste) and understocking (missed sales).

SELECT 
    CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
    I.Product_ID,
    ROUND(AVG(I.Inventory_Level), 2) AS Avg_Inventory_Level
FROM 
    inventory_main I
JOIN 
    Store S ON I.Store_ID = S.Store_ID
GROUP BY 
    Store_Region_ID, I.Product_ID;
    
    
-------------------------------------------------------------------------------------------------------------------

-- Inventory Age (Average Days Inventory is Held)
-- Shows how slow a product is moving based on stock-to-sale ratio.

WITH SalesSummary AS (
    SELECT 
        I.Product_ID,
        CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
        SUM(I.Units_Sold) AS Total_Sales,
        AVG(I.Inventory_Level) AS Avg_Stock
    FROM 
        inventory_main I
    JOIN 
        Store S ON I.Store_ID = S.Store_ID
    GROUP BY 
        I.Product_ID, Store_Region_ID
)

SELECT 
    Store_Region_ID,
    Product_ID,
    ROUND(Avg_Stock / NULLIF(Total_Sales, 0), 4) AS Inventory_Age_Ratio
FROM 
    SalesSummary;

----------------------------------------------------------------------------------------------------------------

-- Top 10 Best (Low Inventory Age Ratio)

WITH SalesSummary AS (
    SELECT 
        I.Product_ID,
        CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
        SUM(I.Units_Sold) AS Total_Sales,
        AVG(I.Inventory_Level) AS Avg_Stock,
        ROUND(AVG(I.Inventory_Level) / NULLIF(SUM(I.Units_Sold), 0), 4) AS Inventory_Age_Ratio
    FROM 
        inventory_main I
    JOIN 
        Store S ON I.Store_ID = S.Store_ID
    GROUP BY 
        I.Product_ID, Store_Region_ID
)

SELECT 
    Product_ID,
    Store_Region_ID,
    Total_Sales,
    Avg_Stock,
    Inventory_Age_Ratio
FROM 
    SalesSummary
WHERE 
    Total_Sales > 0  
ORDER BY 
    Inventory_Age_Ratio ASC
LIMIT 10;

-----------------------------------------------------------------------------------------------------------------

-- Top 10 Worst (High Inventory Age Ratio)

WITH SalesSummary AS (
    SELECT 
        I.Product_ID,
        CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
        SUM(I.Units_Sold) AS Total_Sales,
        AVG(I.Inventory_Level) AS Avg_Stock,
        ROUND(AVG(I.Inventory_Level) / NULLIF(SUM(I.Units_Sold), 0), 4) AS Inventory_Age_Ratio
    FROM 
        inventory_main I
    JOIN 
        Store S ON I.Store_ID = S.Store_ID
    GROUP BY 
        I.Product_ID, Store_Region_ID
)

SELECT 
    Product_ID,
    Store_Region_ID,
    Total_Sales,
    Avg_Stock,
    Inventory_Age_Ratio
FROM 
    SalesSummary
WHERE 
    Total_Sales > 0 
ORDER BY 
    Inventory_Age_Ratio DESC
LIMIT 10;

--------------------------------------------------------------------------------------------------------------------------------

-- Fast & Slow-Moving Product Ratio
-- Helps stores decide which products to prioritize, clear, or promote.

WITH ProductSales AS (
    SELECT 
        I.Product_ID,
        CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
        SUM(I.Units_Sold) AS Total_Sales
    FROM 
        inventory_main I
    JOIN 
        Store S ON I.Store_ID = S.Store_ID
    GROUP BY 
        I.Product_ID, Store_Region_ID
),

RankedProducts AS (                     -- Percentile-Based Thresholds (Top 20%)
    SELECT *,
           NTILE(5) OVER (PARTITION BY Store_Region_ID ORDER BY Total_Sales DESC) AS Sales_Tier
    FROM ProductSales
)

SELECT 
    Store_Region_ID,
    COUNT(CASE WHEN Sales_Tier = 1 THEN 1 END) AS Fast_Movers,  -- fast-moving products as those in the top 20% of total sales.
    COUNT(CASE WHEN Sales_Tier >= 4 THEN 1 END) AS Slow_Movers   -- Bottom 40%
FROM 
    RankedProducts
GROUP BY 
    Store_Region_ID;

-----------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------

-- Supplier Performance Analysis 

WITH ProductPerformance AS (
    SELECT 
        I.Product_ID,
        CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
        SUM(I.Units_Sold) AS Total_Sales,
        AVG(I.Inventory_Level) AS Avg_Stock,
        ROUND(AVG(I.Inventory_Level) / NULLIF(SUM(I.Units_Sold), 1), 4) AS Inventory_Age_Ratio
    FROM 
        inventory_main I
    JOIN 
        Store S ON I.Store_ID = S.Store_ID
    GROUP BY 
        I.Product_ID, Store_Region_ID
),

DynamicThresholds AS (
    SELECT 
        AVG(Inventory_Age_Ratio) AS avg_ratio,
        STDDEV(Inventory_Age_Ratio) AS std_dev_ratio
    FROM ProductPerformance
)

SELECT 
    PP.Product_ID,
    PP.Store_Region_ID,
    Total_Sales,
    Avg_Stock,
    Inventory_Age_Ratio,
    ROUND(DT.avg_ratio, 4) AS Avg_Threshold,
    ROUND(DT.std_dev_ratio, 4) AS Std_Dev,
    CASE 
        WHEN PP.Inventory_Age_Ratio > DT.avg_ratio + DT.std_dev_ratio THEN 'Inefficient - Overstocked & Slow'
        WHEN PP.Inventory_Age_Ratio < DT.avg_ratio - DT.std_dev_ratio THEN 'Efficient - Fast-Moving'
        ELSE 'Moderate'
    END AS Performance_Flag
FROM 
    ProductPerformance PP,
    DynamicThresholds DT
ORDER BY 
    Inventory_Age_Ratio DESC;

---------------------------------------------------------------------------------------------------------------------------------

-- Monthly Sales Trend (Seasonal Pattern)
-- Detect high-demand months : Prepare stock early based on historical peak months

SELECT 
    I.Product_ID,
    CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
    MONTHNAME(STR_TO_DATE(I.Date, '%Y-%m-%d')) AS Sale_Month,
    SUM(I.Units_Sold) AS Total_Monthly_Sales
FROM
    inventory_main I
        JOIN
    Store S ON I.Store_ID = S.Store_ID
WHERE
    STR_TO_DATE(I.Date, '%Y-%m-%d') IS NOT NULL
GROUP BY I.Product_ID , Store_Region_ID , Sale_Month
ORDER BY I.Product_ID , Store_Region_ID , Sale_Month;

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Top-Selling Product per Month with Store Info
-- Helps in understanding seasonal bestsellers and top-performing store-regions

WITH MonthlySales AS (
    SELECT 
        I.Product_ID,
        CONCAT(S.Store_ID, '-', S.Region) AS Store_Region_ID,
        MONTHNAME(STR_TO_DATE(I.Date, '%Y-%m-%d')) AS Sale_Month,
        MONTH(STR_TO_DATE(I.Date, '%Y-%m-%d')) AS Month_Number,
        SUM(I.Units_Sold) AS Total_Sales
    FROM 
        inventory_main I
    JOIN 
        Store S ON I.Store_ID = S.Store_ID
    WHERE 
        STR_TO_DATE(I.Date, '%Y-%m-%d') IS NOT NULL
    GROUP BY 
        I.Product_ID, Store_Region_ID, Sale_Month, Month_Number
),
RankedSales AS (
    SELECT 
        Product_ID,
        Store_Region_ID,
        Sale_Month,
        Month_Number,
        Total_Sales,
        RANK() OVER (PARTITION BY Sale_Month ORDER BY Total_Sales DESC) AS rnk
    FROM 
        MonthlySales
)
SELECT 
    Sale_Month,
    Product_ID,
    Store_Region_ID,
    Total_Sales
FROM 
    RankedSales
WHERE 
    rnk = 1
ORDER BY 
    Month_Number;

---------------------------------------------------------------------------------------------------------------------------------

-- Total Sales by Weather Condition
-- Helps to identify which weather drives the most product sales.


SELECT 
    W.Weather_Condition, SUM(I.Units_Sold) AS Total_Units_Sold
FROM
    Inventory_main I
        JOIN
    Weather W ON I.Store_ID = W.Store_ID
        AND I.Date = W.Date
GROUP BY W.Weather_Condition
ORDER BY Total_Units_Sold DESC;

-------------------------------------------------------------------------------------------------------------------

-- Average Inventory by Season
-- Helps in understanding if inventory is being over/under-stocked during different seasons.

SELECT 
    W.Seasonality,
    ROUND(AVG(I.Inventory_Level), 2) AS Avg_Inventory_Level
FROM
    Inventory_main I
        JOIN
    Weather W ON I.Store_ID = W.Store_ID
        AND I.Date = W.Date
GROUP BY W.Seasonality
ORDER BY Avg_Inventory_Level DESC;

-------------------------------------------------------------------------------------------------------------------------------

-- Store Performance by Weather Condition
-- Helps to find out which stores perform well during specific weather.

SELECT 
    I.Store_ID,
    W.Weather_Condition,
    SUM(I.Units_Sold) AS Total_Sales
FROM
    Inventory_main I
        JOIN
    Weather W ON I.Store_ID = W.Store_ID
        AND I.Date = W.Date
GROUP BY I.Store_ID , W.Weather_Condition
ORDER BY Total_Sales DESC;

-----------------------------------------------------------------------------------------------------------------------------------

-- Seasonal Demand Trends per Product Category
-- Understand which product categories peak in each season.

SELECT 
    P.Category,
    W.Seasonality,
    SUM(I.Units_Sold) AS Total_Units_Sold
FROM
    Inventory_main I
        JOIN
    Product P ON I.Product_ID = P.Product_ID
        JOIN
    Weather W ON I.Store_ID = W.Store_ID
        AND I.Date = W.Date
GROUP BY P.Category , W.Seasonality
ORDER BY P.Category , Total_Units_Sold DESC;

------------------------------------------------------------------------------------------------------------------

--  Revenue Generated per Category
--  Measure profitability by category.

SELECT 
    P.Category,
    ROUND(SUM(I.Units_Sold * P.Price), 2) AS Total_Revenue
FROM
    Inventory_Fact I
        JOIN
    Product P ON I.Product_ID = P.Product_ID
GROUP BY P.Category
ORDER BY Total_Revenue DESC;

---------------------------------------------------------------------------------------------------------------------

-- Average Daily Sales per Store
-- Identify high-performing stores.

SELECT 
    Store_ID,
    ROUND(SUM(Units_Sold) * 1.0 / COUNT(DISTINCT Date),
            2) AS Avg_Daily_Sales
FROM
    Inventory_Fact
GROUP BY Store_ID
ORDER BY Avg_Daily_Sales DESC;

--------------------------------------------------------------------------------------------------------------------------
