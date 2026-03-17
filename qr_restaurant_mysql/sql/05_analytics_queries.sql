USE qr_restaurant_mysql;

-- 1) Executive KPI board: last 7 business dates by branch.
SELECT
  business_date,
  branch_code,
  total_orders,
  cancelled_orders,
  gross_order_value,
  cash_collected,
  tips_collected,
  avg_ticket_size,
  payment_issue_rate_pct
FROM v_daily_branch_sales
WHERE business_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
ORDER BY business_date DESC, branch_code;

-- 2) Peak operating windows by branch (where extra staffing has highest leverage).
SELECT
  branch_code,
  hour_of_day,
  SUM(qr_scans) AS scans,
  SUM(orders_created) AS orders,
  ROUND(SUM(order_value), 2) AS revenue
FROM v_hourly_demand
GROUP BY branch_code, hour_of_day
ORDER BY branch_code, revenue DESC;

-- 3) Menu engineering shortlist: high revenue but low margin items to reprice/rework.
SELECT
  branch_code,
  category_name,
  item_name,
  units_sold,
  gross_sales,
  gross_margin,
  revenue_mix_pct,
  sales_rank_in_branch
FROM v_menu_item_performance
WHERE revenue_mix_pct >= 3.0
  AND gross_margin / NULLIF(gross_sales, 0) < 0.58
ORDER BY branch_code, gross_sales DESC;

-- 4) "Star items": high volume + high margin contribution.
SELECT
  branch_code,
  item_name,
  units_sold,
  gross_sales,
  gross_margin,
  ROUND(gross_margin / NULLIF(gross_sales, 0) * 100, 2) AS margin_pct
FROM v_menu_item_performance
WHERE units_sold >= 30
  AND gross_margin / NULLIF(gross_sales, 0) >= 0.62
ORDER BY branch_code, gross_margin DESC;

-- 5) Payment reliability by method/provider, last 30 days.
SELECT
  method,
  provider,
  SUM(payment_attempts) AS attempts,
  SUM(failed_count) AS failures,
  ROUND(100 * SUM(failed_count) / NULLIF(SUM(payment_attempts), 0), 2) AS fail_rate_pct,
  ROUND(SUM(net_collected_amount), 2) AS net_collected
FROM v_payment_funnel
WHERE business_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY method, provider
ORDER BY fail_rate_pct DESC, attempts DESC;

-- 6) Table productivity: identify top and underperforming tables.
SELECT
  branch_code,
  table_number,
  zone,
  sessions_count,
  avg_session_minutes,
  total_revenue,
  revenue_per_session
FROM v_table_turnover
ORDER BY branch_code, revenue_per_session DESC, sessions_count DESC;

-- 7) Repeat customer signal for loyalty strategy.
SELECT
  c.customer_id,
  c.full_name,
  COUNT(qs.session_id) AS visit_count,
  ROUND(AVG(o.total_amount), 2) AS avg_order_value,
  ROUND(SUM(o.total_amount), 2) AS lifetime_value
FROM customers c
JOIN qr_sessions qs ON qs.customer_id = c.customer_id
JOIN orders o ON o.session_id = qs.session_id AND o.status <> 'CANCELLED'
GROUP BY c.customer_id, c.full_name
HAVING COUNT(qs.session_id) >= 3
ORDER BY lifetime_value DESC
LIMIT 25;

-- 8) Session-to-order conversion by branch.
SELECT
  b.branch_code,
  COUNT(qs.session_id) AS sessions,
  COUNT(DISTINCT o.session_id) AS sessions_with_order,
  ROUND(100 * COUNT(DISTINCT o.session_id) / NULLIF(COUNT(qs.session_id), 0), 2) AS conversion_rate_pct
FROM branches b
JOIN dining_tables dt ON dt.branch_id = b.branch_id
JOIN qr_sessions qs ON qs.table_id = dt.table_id
LEFT JOIN (
  SELECT DISTINCT session_id
  FROM orders
) o ON o.session_id = qs.session_id
GROUP BY b.branch_code
ORDER BY conversion_rate_pct DESC;
