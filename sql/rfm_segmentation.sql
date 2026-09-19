-- RFM (Recency, Frequency, Monetary) Customer Segmentation Analysis
WITH cleaned_transactions AS (
    SELECT 
        customer_id,
        invoice_no,
        invoice_date,
        (quantity * unit_price) AS line_total
    FROM raw_transactions
    WHERE customer_id IS NOT NULL 
      AND quantity > 0
      AND unit_price > 0
),
reference_date AS (
    SELECT MAX(invoice_date)::DATE + INTERVAL '1 day' AS snapshot_date
    FROM cleaned_transactions
),
rfm_metrics AS (
    SELECT 
        t.customer_id,
        (r.snapshot_date::DATE - MAX(t.invoice_date)::DATE) AS recency_days,
        COUNT(DISTINCT t.invoice_no) AS frequency_orders,
        ROUND(SUM(t.line_total)::NUMERIC, 2) AS monetary_value
    FROM cleaned_transactions t
    CROSS JOIN reference_date r
    GROUP BY t.customer_id, r.snapshot_date
),
rfm_scores AS (
    SELECT 
        customer_id,
        recency_days,
        frequency_orders,
        monetary_value,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency_orders ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM rfm_metrics
),
rfm_composite AS (
    SELECT 
        customer_id,
        recency_days,
        frequency_orders,
        monetary_value,
        r_score,
        f_score,
        m_score,
        (r_score::TEXT || f_score::TEXT || m_score::TEXT) AS rfm_cell
    FROM rfm_scores
)
SELECT 
    customer_id,
    recency_days,
    frequency_orders,
    monetary_value,
    r_score,
    f_score,
    m_score,
    rfm_cell,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent New Customers'
        WHEN r_score >= 3 AND f_score <= 2 THEN 'Promising'
        WHEN r_score = 3 AND f_score = 3 THEN 'Need Attention'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating / Lost'
        ELSE 'Potential Loyalist'
    END AS customer_segment
FROM rfm_composite
ORDER BY monetary_value DESC;