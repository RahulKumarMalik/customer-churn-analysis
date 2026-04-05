-- ============================================================
-- PROJECT : Customer Retention, Revenue Leakage & Churn Analysis
-- File    : analysis_queries.sql
-- Author  : Rahul Kumar Malik
-- Tool    : MySQL 8.0+
-- ============================================================
USE churn_analysis_db;


-- ============================================================
-- SECTION 1 — PORTFOLIO OVERVIEW
-- ============================================================

-- 1.1  Customer base summary
SELECT
    plan_type,
    COUNT(*)                                        AS total_customers,
    SUM(is_churned)                                 AS churned,
    ROUND(SUM(is_churned) * 100.0 / COUNT(*), 2)   AS churn_rate_pct,
    ROUND(AVG(monthly_spend_inr), 2)                AS avg_monthly_spend,
    ROUND(SUM(monthly_spend_inr) / 1e5, 2)          AS total_mrr_lakh
FROM customers
GROUP BY plan_type
ORDER BY churn_rate_pct DESC;


-- 1.2  Churn by acquisition channel
SELECT
    acquisition_channel,
    COUNT(*)                                        AS total,
    SUM(is_churned)                                 AS churned,
    ROUND(SUM(is_churned) * 100.0 / COUNT(*), 2)   AS churn_rate_pct
FROM customers
GROUP BY acquisition_channel
ORDER BY churn_rate_pct DESC;


-- ============================================================
-- SECTION 2 — RFM SEGMENTATION
-- Recency, Frequency, Monetary scoring using window functions
-- ============================================================

-- 2.1  Compute raw RFM values per customer
WITH rfm_raw AS (
    SELECT
        c.customer_id,
        c.full_name,
        c.plan_type,
        c.is_churned,
        DATEDIFF('2024-12-31', MAX(t.transaction_date))    AS recency_days,
        COUNT(t.transaction_id)                             AS frequency,
        ROUND(SUM(t.amount_inr), 2)                        AS monetary_value
    FROM customers c
    JOIN transactions t ON c.customer_id = t.customer_id
    WHERE t.order_status = 'Delivered'
    GROUP BY c.customer_id, c.full_name, c.plan_type, c.is_churned
),

-- 2.2  Score each dimension 1-5 using NTILE
rfm_scored AS (
    SELECT *,
        -- Lower recency = more recent = better score
        6 - NTILE(5) OVER (ORDER BY recency_days ASC)   AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)           AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC)      AS m_score
    FROM rfm_raw
),

-- 2.3  Combine into RFM segment
rfm_final AS (
    SELECT *,
        CONCAT(r_score, f_score, m_score)                AS rfm_code,
        ROUND((r_score + f_score + m_score) / 3.0, 2)   AS rfm_avg,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3
                THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2
                THEN 'Recent Customers'
            WHEN f_score >= 3 AND r_score <= 2
                THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2
                THEN 'Lost Customers'
            WHEN m_score >= 4 AND f_score >= 3
                THEN 'Big Spenders'
            ELSE 'Needs Attention'
        END                                              AS rfm_segment
    FROM rfm_scored
)
SELECT * FROM rfm_final
ORDER BY monetary_value DESC
LIMIT 500;


-- 2.4  RFM segment summary (revenue + churn by segment)
WITH rfm_raw AS (
    SELECT
        c.customer_id, c.is_churned,
        DATEDIFF('2024-12-31', MAX(t.transaction_date)) AS recency_days,
        COUNT(t.transaction_id)                          AS frequency,
        ROUND(SUM(t.amount_inr), 2)                      AS monetary_value
    FROM customers c
    JOIN transactions t ON c.customer_id = t.customer_id
    WHERE t.order_status = 'Delivered'
    GROUP BY c.customer_id, c.is_churned
),
rfm_scored AS (
    SELECT *,
        6 - NTILE(5) OVER (ORDER BY recency_days ASC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)          AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC)     AS m_score
    FROM rfm_raw
),
rfm_seg AS (
    SELECT *,
        CASE
            WHEN r_score>=4 AND f_score>=4 AND m_score>=4 THEN 'Champions'
            WHEN r_score>=3 AND f_score>=3                 THEN 'Loyal Customers'
            WHEN r_score>=4 AND f_score<=2                 THEN 'Recent Customers'
            WHEN f_score>=3 AND r_score<=2                 THEN 'At Risk'
            WHEN r_score<=2 AND f_score<=2 AND m_score<=2  THEN 'Lost Customers'
            WHEN m_score>=4 AND f_score>=3                 THEN 'Big Spenders'
            ELSE 'Needs Attention'
        END AS rfm_segment
    FROM rfm_scored
)
SELECT
    rfm_segment,
    COUNT(*)                                                AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)     AS pct_of_base,
    ROUND(SUM(monetary_value) / 1e5, 2)                     AS total_revenue_lakh,
    ROUND(SUM(monetary_value) * 100.0 /
          SUM(SUM(monetary_value)) OVER (), 1)              AS revenue_share_pct,
    ROUND(AVG(monetary_value), 0)                           AS avg_clv,
    ROUND(SUM(is_churned) * 100.0 / COUNT(*), 1)            AS churn_rate_pct
FROM rfm_seg
GROUP BY rfm_segment
ORDER BY total_revenue_lakh DESC;


-- ============================================================
-- SECTION 3 — PARETO ANALYSIS
-- Top 20% customers driving 72%+ of revenue
-- ============================================================

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.plan_type,
        c.is_churned,
        ROUND(SUM(t.amount_inr), 2) AS total_revenue
    FROM customers c
    JOIN transactions t ON c.customer_id = t.customer_id
    WHERE t.order_status = 'Delivered'
    GROUP BY c.customer_id, c.plan_type, c.is_churned
),
ranked AS (
    SELECT *,
        ROUND(PERCENT_RANK() OVER (ORDER BY total_revenue DESC) * 100, 2)
                                            AS percentile_rank,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                            AS cumulative_revenue,
        SUM(total_revenue) OVER ()          AS grand_total_revenue
    FROM customer_revenue
)
SELECT
    CASE
        WHEN percentile_rank <= 20  THEN 'Top 20%'
        WHEN percentile_rank <= 50  THEN 'Mid 30%'
        ELSE                             'Bottom 50%'
    END                                             AS customer_tier,
    COUNT(*)                                        AS customer_count,
    ROUND(SUM(total_revenue) / 1e5, 2)              AS revenue_lakh,
    ROUND(SUM(total_revenue) * 100.0
          / MAX(grand_total_revenue), 1)            AS revenue_share_pct,
    ROUND(SUM(is_churned) * 100.0 / COUNT(*), 1)    AS churn_rate_pct
FROM ranked
GROUP BY customer_tier
ORDER BY revenue_share_pct DESC;


-- ============================================================
-- SECTION 4 — CHURN EARLY WARNING
-- 45+ day inactivity pattern in churned customers
-- ============================================================

-- 4.1  Average days inactive before churn
SELECT
    is_churned,
    ROUND(AVG(
        DATEDIFF(
            COALESCE(churn_date, '2024-12-31'),
            (SELECT MAX(t2.transaction_date)
             FROM transactions t2
             WHERE t2.customer_id = c.customer_id)
        )
    ), 1)                                           AS avg_days_inactive_before_event,
    COUNT(*)                                        AS customers
FROM customers c
GROUP BY is_churned;


-- 4.2  Inactivity band distribution for churned vs active
WITH last_txn AS (
    SELECT
        c.customer_id,
        c.is_churned,
        c.churn_date,
        MAX(t.transaction_date) AS last_purchase
    FROM customers c
    JOIN transactions t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id, c.is_churned, c.churn_date
),
inactivity AS (
    SELECT *,
        DATEDIFF(
            COALESCE(churn_date, '2024-12-31'),
            last_purchase
        ) AS days_inactive
    FROM last_txn
)
SELECT
    is_churned,
    CASE
        WHEN days_inactive < 15   THEN '< 15 days'
        WHEN days_inactive < 30   THEN '15-30 days'
        WHEN days_inactive < 45   THEN '30-45 days'
        WHEN days_inactive < 90   THEN '45-90 days'
        ELSE                           '90+ days'
    END                                             AS inactivity_band,
    COUNT(*)                                        AS customers,
    ROUND(COUNT(*) * 100.0
          / SUM(COUNT(*)) OVER (PARTITION BY is_churned), 1)
                                                    AS pct_in_group
FROM inactivity
GROUP BY is_churned, inactivity_band
ORDER BY is_churned, days_inactive;


-- ============================================================
-- SECTION 5 — COHORT RETENTION ANALYSIS
-- Monthly acquisition cohorts tracked over 12 months
-- ============================================================

WITH cohorts AS (
    SELECT
        customer_id,
        DATE_FORMAT(acquisition_date, '%Y-%m')          AS cohort_month,
        acquisition_date
    FROM customers
),
cohort_txns AS (
    SELECT
        co.customer_id,
        co.cohort_month,
        TIMESTAMPDIFF(MONTH, co.acquisition_date, t.transaction_date)
                                                        AS months_since_join
    FROM cohorts co
    JOIN transactions t ON co.customer_id = t.customer_id
    WHERE t.order_status != 'Cancelled'
      AND months_since_join BETWEEN 0 AND 11
)
SELECT
    cohort_month,
    months_since_join                                   AS month_number,
    COUNT(DISTINCT customer_id)                         AS active_customers
FROM cohort_txns
GROUP BY cohort_month, months_since_join
ORDER BY cohort_month, months_since_join
LIMIT 200;


-- ============================================================
-- SECTION 6 — SUPPORT TICKET IMPACT ON CHURN
-- ============================================================

-- 6.1  Churn rate by number of support tickets
WITH ticket_counts AS (
    SELECT
        c.customer_id,
        c.is_churned,
        COUNT(s.ticket_id)                              AS ticket_count,
        ROUND(AVG(s.satisfaction_score), 2)             AS avg_satisfaction
    FROM customers c
    LEFT JOIN support_tickets s ON c.customer_id = s.customer_id
    GROUP BY c.customer_id, c.is_churned
)
SELECT
    CASE
        WHEN ticket_count = 0 THEN '0 tickets'
        WHEN ticket_count = 1 THEN '1 ticket'
        WHEN ticket_count BETWEEN 2 AND 3 THEN '2-3 tickets'
        WHEN ticket_count BETWEEN 4 AND 6 THEN '4-6 tickets'
        ELSE '7+ tickets'
    END                                                 AS ticket_band,
    COUNT(*)                                            AS customers,
    ROUND(SUM(is_churned) * 100.0 / COUNT(*), 1)        AS churn_rate_pct,
    ROUND(AVG(avg_satisfaction), 2)                     AS avg_csat
FROM ticket_counts
GROUP BY ticket_band
ORDER BY churn_rate_pct DESC;


-- 6.2  Unresolved high-severity tickets linked to churn
SELECT
    s.issue_type,
    s.severity,
    COUNT(*)                                            AS total_tickets,
    SUM(c.is_churned)                                   AS churned_customers,
    ROUND(SUM(c.is_churned) * 100.0 / COUNT(*), 1)      AS churn_rate_pct,
    ROUND(AVG(s.satisfaction_score), 2)                 AS avg_csat,
    ROUND(AVG(s.resolution_days), 1)                    AS avg_resolution_days
FROM support_tickets s
JOIN customers c ON s.customer_id = c.customer_id
GROUP BY s.issue_type, s.severity
ORDER BY churn_rate_pct DESC
LIMIT 20;


-- ============================================================
-- SECTION 7 — CLV & REVENUE RECOVERY PROJECTION
-- ============================================================

-- 7.1  Customer Lifetime Value by plan and churn status
WITH customer_clv AS (
    SELECT
        c.customer_id,
        c.plan_type,
        c.is_churned,
        c.monthly_spend_inr,
        TIMESTAMPDIFF(MONTH, c.acquisition_date,
            COALESCE(c.churn_date, '2024-12-31'))       AS tenure_months,
        ROUND(SUM(t.amount_inr), 2)                     AS actual_revenue
    FROM customers c
    JOIN transactions t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id, c.plan_type, c.is_churned,
             c.monthly_spend_inr, c.acquisition_date, c.churn_date
)
SELECT
    plan_type,
    is_churned,
    COUNT(*)                                            AS customers,
    ROUND(AVG(tenure_months), 1)                        AS avg_tenure_months,
    ROUND(AVG(actual_revenue), 0)                       AS avg_clv_inr,
    ROUND(SUM(actual_revenue) / 1e5, 2)                 AS total_revenue_lakh
FROM customer_clv
GROUP BY plan_type, is_churned
ORDER BY plan_type, is_churned;


-- 7.2  Revenue leakage from churn (monthly)
SELECT
    DATE_FORMAT(churn_date, '%Y-%m')                    AS churn_month,
    COUNT(*)                                            AS churned_customers,
    ROUND(SUM(monthly_spend_inr), 0)                    AS mrr_lost_inr,
    ROUND(SUM(monthly_spend_inr) * 12 / 1e5, 2)         AS annualised_loss_lakh
FROM customers
WHERE is_churned = 1
  AND churn_date IS NOT NULL
GROUP BY churn_month
ORDER BY churn_month;


-- 7.3  Churn score per customer (resume finding: 12% reduction target)
WITH churn_signals AS (
    SELECT
        c.customer_id,
        c.full_name,
        c.plan_type,
        c.monthly_spend_inr,
        c.is_churned,
        -- Recency signal
        DATEDIFF('2024-12-31',
            MAX(t.transaction_date))                    AS days_since_last_purchase,
        -- Frequency signal
        COUNT(t.transaction_id)                         AS total_orders,
        -- Support signal
        COUNT(s.ticket_id)                              AS total_tickets,
        COALESCE(AVG(s.satisfaction_score), 5)          AS avg_csat,
        -- Return rate
        ROUND(SUM(t.order_status = 'Returned') * 100.0
              / COUNT(t.transaction_id), 1)             AS return_rate_pct
    FROM customers c
    LEFT JOIN transactions    t ON c.customer_id = t.customer_id
    LEFT JOIN support_tickets s ON c.customer_id = s.customer_id
    GROUP BY c.customer_id, c.full_name, c.plan_type,
             c.monthly_spend_inr, c.is_churned
),
scored AS (
    SELECT *,
        -- Weighted churn risk score (higher = more at risk)
        ROUND(
            CASE WHEN days_since_last_purchase > 90 THEN 0.40
                 WHEN days_since_last_purchase > 45 THEN 0.25
                 WHEN days_since_last_purchase > 30 THEN 0.15
                 ELSE 0.05 END                          -- recency weight 40%
          + CASE WHEN total_orders < 3  THEN 0.25
                 WHEN total_orders < 6  THEN 0.15
                 WHEN total_orders < 10 THEN 0.08
                 ELSE 0.02 END                          -- frequency weight 25%
          + CASE WHEN total_tickets >= 5 THEN 0.20
                 WHEN total_tickets >= 3 THEN 0.12
                 WHEN total_tickets >= 1 THEN 0.06
                 ELSE 0.02 END                          -- support weight 20%
          + CASE WHEN avg_csat <= 2 THEN 0.10
                 WHEN avg_csat <= 3 THEN 0.06
                 WHEN avg_csat <= 4 THEN 0.03
                 ELSE 0.01 END                          -- CSAT weight 10%
          + return_rate_pct / 100.0 * 0.05              -- return rate weight 5%
        , 4)                                            AS churn_risk_score
    FROM churn_signals
)
SELECT
    customer_id, full_name, plan_type, monthly_spend_inr,
    days_since_last_purchase, total_orders, total_tickets,
    ROUND(avg_csat, 2) AS avg_csat,
    churn_risk_score,
    CASE
        WHEN churn_risk_score >= 0.60 THEN 'Critical — Immediate Outreach'
        WHEN churn_risk_score >= 0.40 THEN 'High — Priority Campaign'
        WHEN churn_risk_score >= 0.25 THEN 'Medium — Monitor Closely'
        ELSE 'Low — Healthy'
    END                                                 AS retention_action,
    is_churned                                          AS actual_churn
FROM scored
ORDER BY churn_risk_score DESC
LIMIT 300;
