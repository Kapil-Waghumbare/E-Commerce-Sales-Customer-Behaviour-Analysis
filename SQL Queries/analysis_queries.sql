-- ============================================================
-- E-COMMERCE SALES ANALYSIS — by Kapil Waghumbare
-- Tools: MySQL | Dataset: 1000 orders | Period: Jan–Dec 2024
-- ============================================================

-- SETUP: Create and load table
CREATE DATABASE IF NOT EXISTS ecommerce_db;
USE ecommerce_db;

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id        VARCHAR(10) PRIMARY KEY,
    customer_id     VARCHAR(10),
    order_date      DATE,
    product_name    VARCHAR(50),
    category        VARCHAR(30),
    quantity        INT,
    unit_price      DECIMAL(10,2),
    discount_pct    INT,
    final_amount    DECIMAL(10,2),
    payment_method  VARCHAR(20),
    device_type     VARCHAR(10),
    city            VARCHAR(20),
    order_status    VARCHAR(15),
    rating          DECIMAL(2,1)
);

-- Load CSV (update path as needed)
LOAD DATA INFILE '/path/to/ecommerce_orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_date, product_name, category,
 quantity, unit_price, discount_pct, final_amount,
 payment_method, device_type, city, order_status, @rating)
SET rating = NULLIF(@rating, '');

-- ============================================================
-- QUERY 1: Overall Business Health Summary
-- Business Question: What is the overall revenue performance
-- and how much revenue is being lost to cancellations/returns?
-- ============================================================
SELECT
    COUNT(*)                                                        AS total_orders,
    SUM(CASE WHEN order_status = 'Delivered'  THEN 1 ELSE 0 END)   AS delivered_orders,
    SUM(CASE WHEN order_status = 'Cancelled'  THEN 1 ELSE 0 END)   AS cancelled_orders,
    SUM(CASE WHEN order_status = 'Returned'   THEN 1 ELSE 0 END)   AS returned_orders,
    ROUND(SUM(CASE WHEN order_status = 'Delivered'  THEN final_amount ELSE 0 END), 2) AS total_revenue,
    ROUND(SUM(CASE WHEN order_status = 'Cancelled'  THEN final_amount ELSE 0 END), 2) AS cancelled_revenue_loss,
    ROUND(SUM(CASE WHEN order_status = 'Returned'   THEN final_amount ELSE 0 END), 2) AS returned_revenue_loss,
    ROUND(
        (SUM(CASE WHEN order_status IN ('Cancelled','Returned') THEN final_amount ELSE 0 END) /
         SUM(final_amount)) * 100, 2)                               AS revenue_loss_pct
FROM orders;

-- ============================================================
-- QUERY 2: Category Performance Analysis
-- Business Question: Which product categories drive the most
-- revenue and which have the highest return/cancellation rates?
-- ============================================================
SELECT
    category,
    COUNT(*)                                                                AS total_orders,
    ROUND(SUM(CASE WHEN order_status='Delivered' THEN final_amount END),2)  AS revenue,
    ROUND(AVG(CASE WHEN order_status='Delivered' THEN final_amount END),2)  AS avg_order_value,
    ROUND(SUM(CASE WHEN order_status='Returned'  THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS return_rate_pct,
    ROUND(SUM(CASE WHEN order_status='Cancelled' THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS cancel_rate_pct,
    ROUND(AVG(CASE WHEN rating IS NOT NULL THEN rating END),2)              AS avg_rating
FROM orders
GROUP BY category
ORDER BY revenue DESC;

-- ============================================================
-- QUERY 3: Monthly Revenue Trend
-- Business Question: How does revenue trend month-over-month?
-- Are there seasonal peaks we can capitalize on?
-- ============================================================
SELECT
    DATE_FORMAT(order_date, '%Y-%m')                                        AS month,
    COUNT(*)                                                                AS total_orders,
    SUM(CASE WHEN order_status='Delivered' THEN 1 ELSE 0 END)               AS delivered,
    ROUND(SUM(CASE WHEN order_status='Delivered' THEN final_amount END),2)  AS monthly_revenue,
    ROUND(AVG(CASE WHEN order_status='Delivered' THEN final_amount END),2)  AS avg_order_value
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;

-- ============================================================
-- QUERY 4: Payment Method & Device Behaviour
-- Business Question: Which payment methods are most popular
-- and do they correlate with cancellation rates?
-- ============================================================
SELECT
    payment_method,
    device_type,
    COUNT(*)                                                                 AS total_orders,
    ROUND(SUM(CASE WHEN order_status='Delivered' THEN final_amount END),2)   AS revenue,
    ROUND(SUM(CASE WHEN order_status='Cancelled' THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS cancel_rate_pct,
    ROUND(SUM(CASE WHEN order_status='Returned'  THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS return_rate_pct
FROM orders
GROUP BY payment_method, device_type
ORDER BY total_orders DESC;

-- ============================================================
-- QUERY 5: City-wise Revenue & Performance
-- Business Question: Which cities are top revenue generators
-- and which cities have high loss rates?
-- ============================================================
SELECT
    city,
    COUNT(*)                                                                  AS total_orders,
    ROUND(SUM(CASE WHEN order_status='Delivered' THEN final_amount END),2)    AS revenue,
    ROUND(SUM(CASE WHEN order_status='Cancelled' THEN final_amount ELSE 0 END),2) AS cancelled_loss,
    ROUND(SUM(CASE WHEN order_status='Returned'  THEN final_amount ELSE 0 END),2) AS returned_loss,
    ROUND(SUM(CASE WHEN order_status IN('Cancelled','Returned') THEN final_amount ELSE 0 END)*100.0
          / SUM(final_amount), 2)                                             AS loss_rate_pct
FROM orders
GROUP BY city
ORDER BY revenue DESC;

-- ============================================================
-- QUERY 6: High Value Customer Segmentation (RFM-style)
-- Business Question: Who are the top customers by spend?
-- Which customers are most valuable to retain?
-- ============================================================
SELECT
    customer_id,
    COUNT(*)                                                                  AS total_orders,
    COUNT(DISTINCT DATE_FORMAT(order_date,'%Y-%m'))                           AS active_months,
    ROUND(SUM(CASE WHEN order_status='Delivered' THEN final_amount END),2)    AS total_spent,
    ROUND(AVG(CASE WHEN order_status='Delivered' THEN final_amount END),2)    AS avg_order_value,
    MAX(order_date)                                                           AS last_order_date,
    ROUND(AVG(CASE WHEN rating IS NOT NULL THEN rating END),1)                AS avg_rating,
    CASE
        WHEN SUM(CASE WHEN order_status='Delivered' THEN final_amount ELSE 0 END) > 50000 THEN 'Platinum'
        WHEN SUM(CASE WHEN order_status='Delivered' THEN final_amount ELSE 0 END) > 20000 THEN 'Gold'
        WHEN SUM(CASE WHEN order_status='Delivered' THEN final_amount ELSE 0 END) > 8000  THEN 'Silver'
        ELSE 'Bronze'
    END AS customer_segment
FROM orders
GROUP BY customer_id
ORDER BY total_spent DESC
LIMIT 20;

