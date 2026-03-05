-- ============================================================
-- REVENUE QUALITY & MARGIN INTELLIGENCE MODEL
-- Dataset: Olist Brazilian E-Commerce
-- Phases 1-6: Full SQL Implementation
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- PHASE 1 — DATA FOUNDATION: Master Orders Dataset
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW master_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    oi.seller_id,
    oi.total_price,
    oi.total_freight,
    oi.item_count,
    p.payment_value,
    p.payment_type,
    p.payment_installments,
    c.customer_state,
    c.customer_city,
    s.seller_state,
    s.seller_city,
    r.review_score
FROM orders o
INNER JOIN (
    SELECT
        order_id,
        SUM(price)          AS total_price,
        SUM(freight_value)  AS total_freight,
        COUNT(*)            AS item_count,
        MIN(seller_id)      AS seller_id
    FROM order_items
    GROUP BY order_id
) oi ON o.order_id = oi.order_id
LEFT JOIN (
    SELECT
        order_id,
        SUM(payment_value)          AS payment_value,
        MAX(payment_installments)   AS payment_installments,
        MIN(payment_type)           AS payment_type
    FROM order_payments
    GROUP BY order_id
) p ON o.order_id = p.order_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN sellers   s ON oi.seller_id  = s.seller_id
LEFT JOIN (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
) r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;

-- Validation
SELECT
    COUNT(*)                        AS total_orders,
    COUNT(DISTINCT seller_id)       AS unique_sellers,
    COUNT(DISTINCT customer_id)     AS unique_customers,
    SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END) AS null_payments
FROM master_orders;


-- ────────────────────────────────────────────────────────────
-- PHASE 2 — FINANCIAL MODELING
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW financial_metrics AS
SELECT
    *,
    -- Revenue
    COALESCE(payment_value, total_price + total_freight)            AS revenue,
    -- Cost simulation: 70% of product price + full freight
    (total_price * 0.70) + total_freight                            AS total_cost,
    total_price * 0.70                                              AS estimated_cogs,
    total_freight                                                    AS freight_cost,
    -- Profit
    COALESCE(payment_value, total_price + total_freight)
        - ((total_price * 0.70) + total_freight)                   AS profit,
    -- Contribution Margin %
    CASE
        WHEN COALESCE(payment_value, total_price + total_freight) > 0
        THEN (
            COALESCE(payment_value, total_price + total_freight)
            - ((total_price * 0.70) + total_freight)
        ) / COALESCE(payment_value, total_price + total_freight) * 100
        ELSE 0
    END                                                              AS contribution_margin_pct,
    -- Time dimensions
    DATE_TRUNC('month', order_purchase_timestamp)                   AS order_month,
    EXTRACT(YEAR  FROM order_purchase_timestamp)                    AS order_year,
    EXTRACT(QUARTER FROM order_purchase_timestamp)                  AS order_quarter,
    -- Delivery delay
    order_delivered_customer_date - order_estimated_delivery_date   AS delivery_delay_interval,
    EXTRACT(EPOCH FROM (
        order_delivered_customer_date - order_estimated_delivery_date
    )) / 86400.0                                                     AS delivery_delay_days,
    CASE
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1
        ELSE 0
    END                                                              AS is_delayed
FROM master_orders;

-- Monthly financial summary
SELECT
    order_month,
    SUM(revenue)                        AS total_revenue,
    SUM(total_cost)                     AS total_cost,
    SUM(profit)                         AS total_profit,
    AVG(contribution_margin_pct)        AS avg_cm_pct,
    COUNT(*)                            AS order_count,
    AVG(revenue)                        AS avg_order_value
FROM financial_metrics
GROUP BY order_month
ORDER BY order_month;


-- ────────────────────────────────────────────────────────────
-- PHASE 3 — SELLER PROFITABILITY INTELLIGENCE
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW seller_profitability AS
WITH seller_agg AS (
    SELECT
        seller_id,
        seller_state,
        seller_city,
        SUM(revenue)                AS total_revenue,
        SUM(total_cost)             AS total_cost,
        SUM(profit)                 AS total_profit,
        AVG(contribution_margin_pct) AS avg_cm_pct,
        COUNT(*)                    AS order_count,
        AVG(review_score)           AS avg_review_score,
        SUM(revenue) / SUM(SUM(revenue)) OVER () AS revenue_share
    FROM financial_metrics
    GROUP BY seller_id, seller_state, seller_city
),
medians AS (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_revenue) AS median_revenue,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_cm_pct)    AS median_cm_pct
    FROM seller_agg
)
SELECT
    sa.*,
    RANK() OVER (ORDER BY total_revenue DESC)   AS revenue_rank,
    RANK() OVER (ORDER BY avg_cm_pct DESC)      AS margin_rank,
    CASE
        WHEN sa.total_revenue >= m.median_revenue
         AND sa.avg_cm_pct    >= m.median_cm_pct
        THEN 'Star (High Rev, High Margin)'
        WHEN sa.total_revenue >= m.median_revenue
         AND sa.avg_cm_pct    <  m.median_cm_pct
        THEN 'Risk (High Rev, Low Margin)'
        WHEN sa.total_revenue <  m.median_revenue
         AND sa.avg_cm_pct    >= m.median_cm_pct
        THEN 'Growth (Low Rev, High Margin)'
        ELSE 'Exit (Low Rev, Low Margin)'
    END AS seller_segment
FROM seller_agg sa, medians m;

-- Renegotiation candidate list
SELECT *
FROM seller_profitability
WHERE seller_segment = 'Risk (High Rev, Low Margin)'
ORDER BY total_revenue DESC;


-- ────────────────────────────────────────────────────────────
-- PHASE 4 — OPERATIONAL IMPACT ANALYSIS
-- ────────────────────────────────────────────────────────────
-- Seller-level delay analysis
CREATE OR REPLACE VIEW seller_operations AS
SELECT
    seller_id,
    seller_state,
    AVG(delivery_delay_days)                                AS avg_delay_days,
    SUM(is_delayed)::FLOAT / COUNT(*)                       AS delay_frequency,
    COUNT(*)                                                AS total_orders,
    SUM(is_delayed)                                         AS delayed_orders,
    AVG(revenue)                                            AS avg_revenue,
    SUM(revenue)                                            AS total_revenue,
    -- Estimated revenue at risk: delayed orders × avg revenue × 5% churn factor
    SUM(CASE WHEN is_delayed = 1 THEN revenue ELSE 0 END)
        * 0.05                                              AS estimated_revenue_at_risk
FROM financial_metrics
GROUP BY seller_id, seller_state;

-- Regional delay analysis
CREATE OR REPLACE VIEW regional_delay AS
SELECT
    seller_state,
    AVG(delivery_delay_days)                    AS avg_delay_days,
    SUM(is_delayed)::FLOAT / COUNT(*)           AS delay_rate,
    COUNT(*)                                    AS total_orders,
    SUM(is_delayed)                             AS delayed_orders,
    AVG(revenue)                                AS avg_revenue,
    SUM(revenue)                                AS total_revenue,
    AVG(review_score)                           AS avg_review_score,
    CASE
        WHEN AVG(delivery_delay_days) > 7  THEN 'CRITICAL'
        WHEN AVG(delivery_delay_days) > 3  THEN 'HIGH'
        WHEN AVG(delivery_delay_days) > 0  THEN 'MEDIUM'
        ELSE 'LOW'
    END AS delay_risk_level
FROM financial_metrics
GROUP BY seller_state
ORDER BY avg_delay_days DESC;

-- Delay vs margin correlation analysis
SELECT
    CASE
        WHEN delivery_delay_days <= 0  THEN 'On Time'
        WHEN delivery_delay_days <= 3  THEN '1–3 Days Late'
        WHEN delivery_delay_days <= 7  THEN '4–7 Days Late'
        ELSE '7+ Days Late'
    END AS delay_bucket,
    COUNT(*)                        AS orders,
    AVG(contribution_margin_pct)    AS avg_margin_pct,
    AVG(review_score)               AS avg_review_score,
    AVG(revenue)                    AS avg_revenue
FROM financial_metrics
GROUP BY 1
ORDER BY 1;


-- ────────────────────────────────────────────────────────────
-- PHASE 5 — REVENUE STABILITY & RISK
-- ────────────────────────────────────────────────────────────
-- Monthly revenue trend
CREATE OR REPLACE VIEW monthly_revenue_trend AS
SELECT
    order_month,
    SUM(revenue)                                            AS monthly_revenue,
    COUNT(*)                                                AS order_count,
    AVG(revenue)                                            AS avg_order_value,
    SUM(revenue) - LAG(SUM(revenue)) OVER (ORDER BY order_month)
                                                            AS mom_change,
    (SUM(revenue) - LAG(SUM(revenue)) OVER (ORDER BY order_month))
        / NULLIF(LAG(SUM(revenue)) OVER (ORDER BY order_month), 0) * 100
                                                            AS mom_growth_pct,
    SUM(SUM(revenue)) OVER (ORDER BY order_month)           AS cumulative_revenue,
    AVG(SUM(revenue)) OVER (
        ORDER BY order_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    )                                                       AS rolling_3m_avg
FROM financial_metrics
GROUP BY order_month
ORDER BY order_month;

-- Revenue volatility index
CREATE OR REPLACE VIEW revenue_volatility AS
SELECT
    COUNT(DISTINCT order_month)                             AS months_analyzed,
    AVG(monthly_revenue)                                    AS mean_monthly_revenue,
    STDDEV(monthly_revenue)                                 AS stddev_monthly_revenue,
    STDDEV(monthly_revenue) / NULLIF(AVG(monthly_revenue), 0) AS coefficient_of_variation,
    MIN(monthly_revenue)                                    AS min_monthly_revenue,
    MAX(monthly_revenue)                                    AS max_monthly_revenue,
    MAX(monthly_revenue) - MIN(monthly_revenue)             AS revenue_range,
    CASE
        WHEN STDDEV(monthly_revenue)/NULLIF(AVG(monthly_revenue),0) < 0.3 THEN 'Stable'
        WHEN STDDEV(monthly_revenue)/NULLIF(AVG(monthly_revenue),0) < 0.6 THEN 'Moderate'
        ELSE 'Volatile'
    END AS stability_rating
FROM monthly_revenue_trend;

-- Revenue concentration analysis
WITH seller_rev AS (
    SELECT
        seller_id,
        SUM(revenue) AS seller_revenue
    FROM financial_metrics
    GROUP BY seller_id
),
total AS (SELECT SUM(seller_revenue) AS total FROM seller_rev)
SELECT
    seller_id,
    seller_revenue,
    seller_revenue / t.total * 100                          AS revenue_share_pct,
    SUM(seller_revenue / t.total * 100) OVER (
        ORDER BY seller_revenue DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                       AS cumulative_share_pct,
    RANK() OVER (ORDER BY seller_revenue DESC)              AS revenue_rank
FROM seller_rev, total t
ORDER BY seller_revenue DESC;


-- ────────────────────────────────────────────────────────────
-- PHASE 6 — MARGIN RISK SCORING MODEL
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW margin_risk_scores AS
WITH base AS (
    SELECT
        sp.seller_id,
        sp.seller_state,
        sp.seller_segment,
        sp.total_revenue,
        sp.total_profit,
        sp.avg_cm_pct,
        sp.order_count,
        sp.avg_review_score,
        sp.revenue_share,
        COALESCE(so.avg_delay_days, 0)    AS avg_delay_days,
        COALESCE(so.delay_frequency, 0)   AS delay_frequency
    FROM seller_profitability sp
    LEFT JOIN seller_operations so USING (seller_id)
),
stats AS (
    SELECT
        MIN(avg_cm_pct)       AS min_cm,  MAX(avg_cm_pct)       AS max_cm,
        MIN(delay_frequency)  AS min_df,  MAX(delay_frequency)  AS max_df,
        MIN(revenue_share)    AS min_rs,  MAX(revenue_share)    AS max_rs
    FROM base
),
normalized AS (
    SELECT
        b.*,
        -- Margin risk: low margin = high risk (inverted)
        CASE WHEN s.max_cm = s.min_cm THEN 0
             ELSE 1 - (b.avg_cm_pct - s.min_cm) / (s.max_cm - s.min_cm)
        END AS risk_margin_norm,
        -- Delay risk: high delay = high risk
        CASE WHEN s.max_df = s.min_df THEN 0
             ELSE (b.delay_frequency - s.min_df) / (s.max_df - s.min_df)
        END AS risk_delay_norm,
        -- Concentration risk: high share = high risk
        CASE WHEN s.max_rs = s.min_rs THEN 0
             ELSE (b.revenue_share - s.min_rs) / (s.max_rs - s.min_rs)
        END AS risk_conc_norm
    FROM base b, stats s
)
SELECT
    *,
    -- Weighted composite score (0–100)
    (0.40 * risk_margin_norm + 0.35 * risk_delay_norm + 0.25 * risk_conc_norm) * 100
                                                            AS margin_risk_score,
    CASE
        WHEN (0.40 * risk_margin_norm + 0.35 * risk_delay_norm + 0.25 * risk_conc_norm) * 100 >= 70
        THEN 'Critical'
        WHEN (0.40 * risk_margin_norm + 0.35 * risk_delay_norm + 0.25 * risk_conc_norm) * 100 >= 50
        THEN 'High'
        WHEN (0.40 * risk_margin_norm + 0.35 * risk_delay_norm + 0.25 * risk_conc_norm) * 100 >= 30
        THEN 'Medium'
        ELSE 'Low'
    END AS risk_category,
    RANK() OVER (
        ORDER BY (0.40 * risk_margin_norm + 0.35 * risk_delay_norm + 0.25 * risk_conc_norm) DESC
    ) AS risk_rank
FROM normalized;

-- Final ranked output for leadership review
SELECT
    risk_rank,
    seller_id,
    seller_state,
    seller_segment,
    ROUND(margin_risk_score, 1)     AS margin_risk_score,
    risk_category,
    ROUND(avg_cm_pct, 1)            AS margin_pct,
    ROUND(delay_frequency * 100, 1) AS delay_rate_pct,
    ROUND(revenue_share * 100, 2)   AS revenue_share_pct,
    ROUND(total_revenue, 0)         AS total_revenue,
    ROUND(total_profit, 0)          AS total_profit,
    CASE risk_category
        WHEN 'Critical' THEN 'EXIT or immediate renegotiation'
        WHEN 'High'     THEN 'Urgent margin review within 30 days'
        WHEN 'Medium'   THEN 'Quarterly business review'
        ELSE                 'Standard monitoring'
    END AS recommended_action
FROM margin_risk_scores
ORDER BY risk_rank
LIMIT 100;

-- ============================================================
-- END OF SQL MODEL
-- Revenue Quality & Margin Intelligence — Olist E-Commerce
-- ============================================================
