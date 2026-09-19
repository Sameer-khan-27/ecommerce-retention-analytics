-- Customer Purchase Velocity & Inter-Purchase Cycle Analysis
WITH distinct_orders AS (
    SELECT DISTINCT
        customer_id,
        invoice_no,
        invoice_date::DATE AS order_date
    FROM raw_transactions
    WHERE customer_id IS NOT NULL 
      AND quantity > 0
),
order_lags AS (
    -- Use LAG() window function to find the previous order date
    SELECT 
        customer_id,
        invoice_no,
        order_date,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS prev_order_date
    FROM distinct_orders
),
inter_purchase_intervals AS (
    -- Compute the elapsed days between sequential orders
    SELECT 
        customer_id,
        invoice_no,
        order_date,
        prev_order_date,
        (order_date - prev_order_date) AS days_since_last_order
    FROM order_lags
    WHERE prev_order_date IS NOT NULL
)
-- Aggregate average velocity and consistency metrics per repeat customer
SELECT 
    customer_id,
    COUNT(*) AS repeat_orders_count,
    ROUND(AVG(days_since_last_order), 1) AS avg_days_between_orders,
    MIN(days_since_last_order) AS min_days_between_orders,
    MAX(days_since_last_order) AS max_days_between_orders,
    CASE 
        WHEN AVG(days_since_last_order) <= 15 THEN 'High Velocity (< 15 Days)'
        WHEN AVG(days_since_last_order) <= 45 THEN 'Medium Velocity (15-45 Days)'
        ELSE 'Low Velocity (> 45 Days)'
    END AS velocity_tier
FROM inter_purchase_intervals
GROUP BY customer_id
ORDER BY repeat_orders_count DESC, avg_days_between_orders ASC;