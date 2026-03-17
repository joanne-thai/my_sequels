USE qr_restaurant_mysql;

CREATE OR REPLACE VIEW v_daily_branch_sales AS
SELECT
  b.branch_id,
  b.branch_code,
  b.name AS branch_name,
  DATE(o.placed_at) AS business_date,
  COUNT(*) AS total_orders,
  SUM(CASE WHEN o.status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_orders,
  ROUND(SUM(CASE WHEN o.status <> 'CANCELLED' THEN o.subtotal_amount ELSE 0 END), 2) AS net_subtotal,
  ROUND(SUM(CASE WHEN o.status <> 'CANCELLED' THEN o.tax_amount + o.service_charge_amount ELSE 0 END), 2) AS taxes_and_service,
  ROUND(SUM(CASE WHEN o.status <> 'CANCELLED' THEN o.total_amount ELSE 0 END), 2) AS gross_order_value,
  ROUND(AVG(CASE WHEN o.status <> 'CANCELLED' THEN o.total_amount END), 2) AS avg_ticket_size,
  ROUND(SUM(COALESCE(pay.captured_total, 0)), 2) AS cash_collected,
  ROUND(SUM(COALESCE(pay.tip_total, 0)), 2) AS tips_collected,
  ROUND(100 * SUM(CASE WHEN COALESCE(pay.failed_count, 0) > 0 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS payment_issue_rate_pct
FROM orders o
JOIN branches b
  ON b.branch_id = o.branch_id
LEFT JOIN (
  SELECT
    p.order_id,
    SUM(CASE WHEN p.status IN ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED') THEN p.captured_amount ELSE 0 END) AS captured_total,
    SUM(CASE WHEN p.status IN ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED') THEN p.tip_amount ELSE 0 END) AS tip_total,
    SUM(CASE WHEN p.status = 'FAILED' THEN 1 ELSE 0 END) AS failed_count
  FROM payments p
  GROUP BY p.order_id
) pay
  ON pay.order_id = o.order_id
GROUP BY
  b.branch_id,
  b.branch_code,
  b.name,
  DATE(o.placed_at);

CREATE OR REPLACE VIEW v_menu_item_performance AS
SELECT
  x.branch_id,
  x.branch_code,
  x.branch_name,
  x.category_name,
  x.item_id,
  x.sku,
  x.item_name,
  x.units_sold,
  x.gross_sales,
  x.gross_margin,
  x.avg_selling_price,
  ROUND(
    100 * x.gross_sales
    / NULLIF(SUM(x.gross_sales) OVER (PARTITION BY x.branch_id), 0),
    2
  ) AS revenue_mix_pct,
  DENSE_RANK() OVER (
    PARTITION BY x.branch_id
    ORDER BY x.gross_sales DESC
  ) AS sales_rank_in_branch
FROM (
  SELECT
    b.branch_id,
    b.branch_code,
    b.name AS branch_name,
    mc.name AS category_name,
    mi.item_id,
    mi.sku,
    mi.name AS item_name,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.line_subtotal), 2) AS gross_sales,
    ROUND(SUM((oi.unit_price - mi.food_cost) * oi.quantity), 2) AS gross_margin,
    ROUND(AVG(oi.unit_price), 2) AS avg_selling_price
  FROM order_items oi
  JOIN orders o
    ON o.order_id = oi.order_id
  JOIN menu_items mi
    ON mi.item_id = oi.menu_item_id
  JOIN menu_categories mc
    ON mc.category_id = mi.category_id
  JOIN branches b
    ON b.branch_id = o.branch_id
  WHERE o.status <> 'CANCELLED'
    AND oi.item_status <> 'VOIDED'
  GROUP BY
    b.branch_id,
    b.branch_code,
    b.name,
    mc.name,
    mi.item_id,
    mi.sku,
    mi.name
) x;

CREATE OR REPLACE VIEW v_hourly_demand AS
SELECT
  b.branch_id,
  b.branch_code,
  b.name AS branch_name,
  DATE(qs.started_at) AS business_date,
  HOUR(qs.started_at) AS hour_of_day,
  COUNT(*) AS qr_scans,
  SUM(CASE WHEN qs.status = 'ACTIVE' THEN 1 ELSE 0 END) AS currently_active_sessions,
  SUM(COALESCE(os.orders_created, 0)) AS orders_created,
  ROUND(SUM(COALESCE(os.order_value, 0)), 2) AS order_value
FROM qr_sessions qs
JOIN dining_tables dt
  ON dt.table_id = qs.table_id
JOIN branches b
  ON b.branch_id = dt.branch_id
LEFT JOIN (
  SELECT
    o.session_id,
    COUNT(*) AS orders_created,
    SUM(CASE WHEN o.status <> 'CANCELLED' THEN o.total_amount ELSE 0 END) AS order_value
  FROM orders o
  GROUP BY o.session_id
) os
  ON os.session_id = qs.session_id
GROUP BY
  b.branch_id,
  b.branch_code,
  b.name,
  DATE(qs.started_at),
  HOUR(qs.started_at);

CREATE OR REPLACE VIEW v_table_turnover AS
SELECT
  b.branch_id,
  b.branch_code,
  dt.table_id,
  dt.table_number,
  dt.zone,
  COUNT(qs.session_id) AS sessions_count,
  ROUND(AVG(TIMESTAMPDIFF(MINUTE, qs.started_at, COALESCE(qs.closed_at, NOW()))), 1) AS avg_session_minutes,
  ROUND(MAX(TIMESTAMPDIFF(MINUTE, qs.started_at, COALESCE(qs.closed_at, NOW()))), 1) AS max_session_minutes,
  ROUND(SUM(COALESCE(os.session_revenue, 0)), 2) AS total_revenue,
  ROUND(SUM(COALESCE(os.session_revenue, 0)) / NULLIF(COUNT(qs.session_id), 0), 2) AS revenue_per_session
FROM dining_tables dt
JOIN branches b
  ON b.branch_id = dt.branch_id
LEFT JOIN qr_sessions qs
  ON qs.table_id = dt.table_id
LEFT JOIN (
  SELECT
    o.session_id,
    SUM(CASE WHEN o.status <> 'CANCELLED' THEN o.total_amount ELSE 0 END) AS session_revenue
  FROM orders o
  GROUP BY o.session_id
) os
  ON os.session_id = qs.session_id
GROUP BY
  b.branch_id,
  b.branch_code,
  dt.table_id,
  dt.table_number,
  dt.zone;

CREATE OR REPLACE VIEW v_payment_funnel AS
SELECT
  DATE(p.created_at) AS business_date,
  p.method,
  p.provider,
  COUNT(*) AS payment_attempts,
  SUM(CASE WHEN p.status = 'CAPTURED' THEN 1 ELSE 0 END) AS captured_count,
  SUM(CASE WHEN p.status = 'PARTIALLY_REFUNDED' THEN 1 ELSE 0 END) AS partially_refunded_count,
  SUM(CASE WHEN p.status = 'REFUNDED' THEN 1 ELSE 0 END) AS refunded_count,
  SUM(CASE WHEN p.status = 'FAILED' THEN 1 ELSE 0 END) AS failed_count,
  ROUND(
    SUM(CASE WHEN p.status IN ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED') THEN p.captured_amount + p.tip_amount ELSE 0 END),
    2
  ) AS net_collected_amount,
  ROUND(100 * SUM(CASE WHEN p.status = 'FAILED' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct
FROM payments p
GROUP BY
  DATE(p.created_at),
  p.method,
  p.provider;
