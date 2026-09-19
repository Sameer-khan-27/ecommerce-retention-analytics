-- Monthly Customer Cohort Retention Analysis
-- Description: Groups customers by their first purchase month and tracks retention across subsequent months.

WITH customer_first_purchase AS (
    -- Step 1: Identify the initial cohort month for each customer
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date))::DATE AS cohort_month
    FROM raw_transactions
    WHERE customer_id IS NOT NULL 
      AND quantity > 0
    GROUP BY customer_id
),

transaction_activity AS (
    -- Step 2: Extract distinct active months per customer
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', invoice_date)::DATE AS purchase_month
    FROM raw_transactions
    WHERE customer_id IS NOT NULL 
      AND quantity > 0
),

cohort_indexed AS (
    -- Step 3: Calculate the month index (Months elapsed since cohort entry)
    SELECT 
        c.cohort_month,
        t.purchase_month,
        (EXTRACT(YEAR FROM t.purchase_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12 +
        (EXTRACT(MONTH FROM t.purchase_month) - EXTRACT(MONTH FROM c.cohort_month)) AS month_number,
        c.customer_id
    FROM customer_first_purchase c
    JOIN transaction_activity t 
      ON c.customer_id = t.customer_id
),

cohort_sizes AS (
    -- Step 4: Determine initial size of each cohort (Month 0 size)
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_first_purchase
    GROUP BY cohort_month
),

cohort_retention AS (
    -- Step 5: Aggregate active customers per cohort per month index
    SELECT 
        ci.cohort_month,
        cs.cohort_size,
        ci.month_number,
        COUNT(DISTINCT ci.customer_id) AS retained_customers
    FROM cohort_indexed ci
    JOIN cohort_sizes cs 
      ON ci.cohort_month = cs.cohort_month
    GROUP BY ci.cohort_month, cs.cohort_size, ci.month_number
)

-- Final Output: Calculate retention percentage per cohort per month
SELECT 
    cohort_month,
    cohort_size,
    month_number,
    retained_customers,
    ROUND((retained_customers::NUMERIC / cohort_size) * 100, 2) AS retention_rate_pct
FROM cohort_retention
ORDER BY cohort_month, month_number;