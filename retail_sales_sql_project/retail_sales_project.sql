CREATE DATABASE IF NOT EXISTS retail_project;
USE retail_project;

-- =========================================================
-- PROJECT: Retail Sales Performance Analysis in MySQL
-- GOAL:
-- Analyze sales trends, discount impact, customer segment
-- profitability, and employee performance using SQL.
-- =========================================================

-- =========================================================
-- 1. DATA VALIDATION (RAW DATA CHECK)
-- Understand data quality before cleaning
-- =========================================================

-- Check total records
SELECT COUNT(*) AS total_orders FROM orders;

-- Check missing dates
SELECT COUNT(*) AS null_order_dates
FROM orders
WHERE ORDER_DATE IS NULL;

-- Check category distribution
SELECT CATEGORY, COUNT(*) AS num_products
FROM product
GROUP BY CATEGORY;

-- =========================================================
-- 2. DATA CLEANING
-- Standardise date fields in the orders table
-- =========================================================
UPDATE orders 
SET 
    ORDER_DATE = CASE
        WHEN STR_TO_DATE(ORDER_DATE, '%m/%d/%Y') IS NOT NULL THEN STR_TO_DATE(ORDER_DATE, '%m/%d/%Y')
        WHEN STR_TO_DATE(ORDER_DATE, '%m/%d/%Y') IS NULL THEN STR_TO_DATE(ORDER_DATE, '%Y/%d/%m')
    END
;

UPDATE orders 
SET 
    SHIP_DATE = CASE
        WHEN STR_TO_DATE(SHIP_DATE, '%m/%d/%Y') IS NOT NULL THEN STR_TO_DATE(SHIP_DATE, '%m/%d/%Y')
        WHEN STR_TO_DATE(SHIP_DATE, '%m/%d/%Y') IS NULL THEN STR_TO_DATE(SHIP_DATE, '%Y/%d/%m')
    END
;

-- =========================================================
-- 3. QUARTERLY SALES TREND
-- Analyze quarterly sales performance for the Furniture category
-- =========================================================

SELECT CONCAT('Q', QUARTER(ORDER_DATE),'-', YEAR(ORDER_DATE)) AS 'QUARTER', 
		ROUND(SUM(SALES),2) AS TOTAL_SALES 
FROM orders o
JOIN product p ON o.PRODUCT_ID = p.ID
WHERE p.CATEGORY = 'Furnishings'
GROUP BY CONCAT('Q', QUARTER(ORDER_DATE),'-', YEAR(ORDER_DATE)), YEAR(ORDER_DATE), QUARTER(ORDER_DATE)
ORDER BY YEAR(ORDER_DATE), QUARTER(ORDER_DATE);

-- =========================================================
-- 4. DISCOUNT IMPACT ANALYSIS
-- Evaluate how discount levels affect order volume and profit
-- across product categories
-- =========================================================

WITH discount_classified AS 
(
SELECT p.CATEGORY, o.ORDER_ID, o.PROFIT,
	CASE 
		WHEN o.DISCOUNT = 0 THEN 'No Discount'
        WHEN o.DISCOUNT > 0 AND o.DISCOUNT <= 0.2 THEN 'Low Discount'
        WHEN o.DISCOUNT > 0.2 AND o.DISCOUNT <= 0.5 THEN 'Medium Discount'
        ELSE 'High Discount'
	END AS DISCOUNT_LEVEL
FROM orders o
JOIN product p ON o.PRODUCT_ID = p.ID
)
SELECT CATEGORY, DISCOUNT_LEVEL, COUNT(DISTINCT ORDER_ID) AS NUM_ORDER, ROUND(SUM(PROFIT),2) AS TOTAL_PROFIT
FROM discount_classified
GROUP BY CATEGORY, DISCOUNT_LEVEL
ORDER BY CATEGORY;

-- =========================================================
-- 5. CUSTOMER SEGMENT PROFITABILITY
-- Identify the top 2 most profitable product categories
-- within each customer segment
-- =========================================================

WITH segment_rank AS
(
SELECT c.SEGMENT, p.CATEGORY, 
	SUM(SALES) AS TOTAL_SALES, 
	SUM(PROFIT) AS TOTAL_PROFIT,
	DENSE_RANK() OVER(PARTITION BY SEGMENT ORDER BY SUM(SALES) DESC) AS SALES_RANK,
	DENSE_RANK() OVER(PARTITION BY SEGMENT ORDER BY SUM(PROFIT) DESC) AS PROFIT_RANK
FROM orders o
JOIN customer c ON o.CUSTOMER_ID = c.ID
JOIN product p ON o.PRODUCT_ID = p.ID
GROUP BY c.SEGMENT, p.CATEGORY
)
SELECT SEGMENT, CATEGORY, SALES_RANK, PROFIT_RANK
FROM segment_rank
WHERE PROFIT_RANK <= 2
GROUP BY SEGMENT, CATEGORY, PROFIT_RANK
;

-- =========================================================
-- 6. EMPLOYEE CATEGORY CONTRIBUTION
-- Show each employee's profit by category and the share
-- each category contributes to their total profit
-- =========================================================

WITH employee_profit AS 
(
SELECT o.ID_EMPLOYEE, CATEGORY, 
		ROUND(SUM(o.PROFIT), 2) AS ROUNDED_TOTAL_PROFIT
FROM orders o
JOIN product p
	ON o.PRODUCT_ID = p.ID
GROUP BY o.ID_EMPLOYEE, CATEGORY
)
SELECT ID_EMPLOYEE, CATEGORY, ROUNDED_TOTAL_PROFIT, 
		ROUND(ROUNDED_TOTAL_PROFIT/SUM(ROUNDED_TOTAL_PROFIT) OVER(PARTITION BY ID_EMPLOYEE)*100, 2) AS PROFIT_PERCENTAGE
FROM employee_profit
ORDER BY ID_EMPLOYEE ASC, PROFIT_PERCENTAGE DESC
;

-- =========================================================
-- 7. USER-DEFINED FUNCTION
-- Return profit ratio for a given employee and category
-- =========================================================

DELIMITER $$
DROP FUNCTION IF EXISTS get_employee_profit;
CREATE FUNCTION get_employee_profit (p_ID_EMPLOYEE INT, p_CATEGORY VARCHAR(50))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
	DECLARE PROFITABILITY_RATIO DECIMAL(10,2);
    
    SELECT 
		CASE
			WHEN SUM(o.SALES) = 0 THEN 0
            ELSE SUM(o.PROFIT) / SUM(SALES)
		END
	INTO PROFITABILITY_RATIO
    FROM orders o
    JOIN product p ON o.PRODUCT_ID = p.ID
    WHERE o.ID_EMPLOYEE = p_ID_EMPLOYEE
	AND p.CATEGORY = p_CATEGORY;
    
	RETURN PROFITABILITY_RATIO;
END $$
DELIMITER ;

-- Apply the function in a reporting query
WITH employee_category AS (
	SELECT o.ID_EMPLOYEE, p.CATEGORY, 
			ROUND(SUM(SALES),2) AS TOTAL_SALES,
            ROUND(SUM(PROFIT),2) AS TOTAL_PROFIT
	FROM orders o
    JOIN product p ON o.PRODUCT_ID = p.ID
    GROUP BY o.ID_EMPLOYEE, p.CATEGORY
)
SELECT ec.ID_EMPLOYEE, ec.CATEGORY, ec.TOTAL_SALES, ec.TOTAL_PROFIT, 
		get_employee_profit(ID_EMPLOYEE, CATEGORY) AS PROFITABILITY_RATIO
FROM employee_category ec
ORDER BY ID_EMPLOYEE, PROFITABILITY_RATIO DESC;

-- =========================================================
-- 8. STORED PROCEDURE
-- Return employee sales and profit for a selected date range
-- =========================================================

DELIMITER $$
DROP PROCEDURE IF EXISTS CalculateTotalRevenue;
CREATE PROCEDURE CalculateTotalRevenue (EMPLOYEE_ID INT,
StartDate VARCHAR(50),
EndDate VARCHAR(50))
BEGIN 
SELECT
	ROUND(SUM(o.SALES),2) 'TotalSales',
	ROUND(SUM(o.PROFIT),2) 'TotalProfit'
FROM
	orders o
WHERE
	o.ID_EMPLOYEE = EMPLOYEE_ID
	AND o.ORDER_DATE BETWEEN StartDate AND EndDate;
END ;$$
DELIMITER ;

CALL CalculateTotalRevenue(3, '2016-12-01', '2016-12-31');


