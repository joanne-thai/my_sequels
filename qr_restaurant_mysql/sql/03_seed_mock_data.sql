USE qr_restaurant_mysql;

DROP PROCEDURE IF EXISTS sp_seed_mock_data;
DELIMITER $$
CREATE PROCEDURE sp_seed_mock_data()
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    DROP TEMPORARY TABLE IF EXISTS tmp_order_seed;
    DROP TEMPORARY TABLE IF EXISTS tmp_payment_seed;
    RESIGNAL;
  END;

  START TRANSACTION;

  DELETE FROM audit_events;
  DELETE FROM refunds;
  DELETE FROM payments;
  DELETE FROM order_items;
  DELETE FROM orders;
  DELETE FROM qr_sessions;
  DELETE FROM menu_items;
  DELETE FROM menu_categories;
  DELETE FROM customers;
  DELETE FROM staff;
  DELETE FROM dining_tables;
  DELETE FROM branches;

INSERT INTO branches (
  branch_code,
  name,
  address_line1,
  city,
  state,
  timezone,
  currency_code,
  tax_rate,
  service_charge_rate,
  opened_at,
  is_active
) VALUES
  ('SYD01', 'Circular Quay House', '101 George St', 'Sydney', 'NSW', 'Australia/Sydney', 'AUD', 0.1000, 0.0500, '2018-06-01 09:00:00', 1),
  ('MEL02', 'Southbank Kitchen', '88 Southbank Blvd', 'Melbourne', 'VIC', 'Australia/Melbourne', 'AUD', 0.1000, 0.0500, '2019-03-20 09:00:00', 1),
  ('BNE03', 'Riverside Wharf', '22 Eagle St', 'Brisbane', 'QLD', 'Australia/Brisbane', 'AUD', 0.1000, 0.0400, '2020-09-15 09:00:00', 1);

INSERT INTO dining_tables (
  branch_id,
  table_number,
  zone,
  seat_capacity,
  qr_code_token,
  qr_url,
  is_active,
  last_sanitized_at
)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 24
)
SELECT
  b.branch_id,
  CONCAT('T', LPAD(seq.n, 2, '0')),
  CASE
    WHEN seq.n <= 10 THEN 'MAIN_HALL'
    WHEN seq.n <= 16 THEN 'PATIO'
    WHEN seq.n <= 20 THEN 'BAR'
    ELSE 'PRIVATE_ROOM'
  END AS zone,
  CASE
    WHEN MOD(seq.n, 6) = 0 THEN 8
    WHEN MOD(seq.n, 2) = 0 THEN 4
    ELSE 2
  END AS seat_capacity,
  UUID(),
  CONCAT('https://qr.bigrestaurant.com.au/scan/', b.branch_code, '/T', LPAD(seq.n, 2, '0')),
  1,
  DATE_SUB(NOW(), INTERVAL (seq.n * 4) MINUTE)
FROM branches b
CROSS JOIN seq;

INSERT INTO staff (branch_id, full_name, role, email, phone, hired_at, is_active)
SELECT
  b.branch_id,
  s.full_name,
  s.role,
  s.email,
  s.phone,
  s.hired_at,
  1
FROM (
  SELECT 'SYD01' AS branch_code, 'Isla Murphy' AS full_name, 'MANAGER' AS role, 'isla.murphy@restaurant.com.au' AS email, '+61-2-5550-1001' AS phone, '2019-01-05' AS hired_at
  UNION ALL SELECT 'SYD01', 'Jack Thompson', 'SERVER', 'jack.thompson@restaurant.com.au', '+61-2-5550-1002', '2020-04-10'
  UNION ALL SELECT 'SYD01', 'Chloe Bennett', 'SERVER', 'chloe.bennett@restaurant.com.au', '+61-2-5550-1003', '2021-02-17'
  UNION ALL SELECT 'SYD01', 'Noah Walker', 'CASHIER', 'noah.walker@restaurant.com.au', '+61-2-5550-1004', '2021-08-29'
  UNION ALL SELECT 'SYD01', 'Matilda Evans', 'KITCHEN', 'matilda.evans@restaurant.com.au', '+61-2-5550-1005', '2022-03-13'
  UNION ALL SELECT 'MEL02', 'Oliver Hughes', 'MANAGER', 'oliver.hughes@restaurant.com.au', '+61-3-5550-2001', '2019-09-15'
  UNION ALL SELECT 'MEL02', 'Ruby Collins', 'SERVER', 'ruby.collins@restaurant.com.au', '+61-3-5550-2002', '2020-06-21'
  UNION ALL SELECT 'MEL02', 'Ethan Brooks', 'SERVER', 'ethan.brooks@restaurant.com.au', '+61-3-5550-2003', '2021-11-09'
  UNION ALL SELECT 'MEL02', 'Sophie Ward', 'CASHIER', 'sophie.ward@restaurant.com.au', '+61-3-5550-2004', '2022-01-30'
  UNION ALL SELECT 'MEL02', 'Lachlan Price', 'KITCHEN', 'lachlan.price@restaurant.com.au', '+61-3-5550-2005', '2022-06-11'
  UNION ALL SELECT 'BNE03', 'Charlotte Fraser', 'MANAGER', 'charlotte.fraser@restaurant.com.au', '+61-7-5550-3001', '2020-01-19'
  UNION ALL SELECT 'BNE03', 'Liam Cooper', 'SERVER', 'liam.cooper@restaurant.com.au', '+61-7-5550-3002', '2020-08-08'
  UNION ALL SELECT 'BNE03', 'Mia Sullivan', 'SERVER', 'mia.sullivan@restaurant.com.au', '+61-7-5550-3003', '2021-12-01'
  UNION ALL SELECT 'BNE03', 'Hudson Reed', 'CASHIER', 'hudson.reed@restaurant.com.au', '+61-7-5550-3004', '2022-04-07'
  UNION ALL SELECT 'BNE03', 'Zoe Patterson', 'KITCHEN', 'zoe.patterson@restaurant.com.au', '+61-7-5550-3005', '2022-09-22'
) s
JOIN branches b
  ON b.branch_code = s.branch_code;

INSERT INTO customers (full_name, phone, email, loyalty_points, created_at)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 120
)
SELECT
  CONCAT('Guest ', LPAD(n, 3, '0')),
  CONCAT('+614', LPAD(700000 + n, 6, '0')),
  CONCAT('guest', LPAD(n, 3, '0'), '@example.com.au'),
  MOD(n * 13, 500),
  DATE_SUB(NOW(), INTERVAL (n * 3) DAY)
FROM seq;

DROP TEMPORARY TABLE IF EXISTS tmp_customer_pool;
CREATE TEMPORARY TABLE tmp_customer_pool AS
SELECT
  ROW_NUMBER() OVER (ORDER BY c.customer_id) AS seq_no,
  c.customer_id
FROM customers c;

INSERT INTO menu_categories (branch_id, name, display_order, is_active)
SELECT b.branch_id, c.name, c.display_order, 1
FROM branches b
CROSS JOIN (
  SELECT 'Appetizers' AS name, 1 AS display_order
  UNION ALL SELECT 'Mains', 2
  UNION ALL SELECT 'Woodfire Pizza', 3
  UNION ALL SELECT 'Desserts', 4
  UNION ALL SELECT 'Beverages', 5
  UNION ALL SELECT 'Kids Menu', 6
) c;

INSERT INTO menu_items (
  branch_id,
  category_id,
  sku,
  name,
  description,
  is_vegetarian,
  is_spicy,
  prep_time_minutes,
  base_price,
  food_cost,
  is_available,
  available_from,
  available_to
)
WITH item_templates AS (
  SELECT 'APP-BRUS' AS sku, 'Appetizers' AS category_name, 'Sourdough Bruschetta' AS item_name, 'Toasted sourdough with tomato, basil, and whipped ricotta' AS item_desc, 1 AS is_veg, 0 AS is_spicy, 8 AS prep_time, 13.00 AS base_price, 3.60 AS food_cost
  UNION ALL SELECT 'APP-CALM', 'Appetizers', 'Salt and Pepper Squid', 'Crispy squid with lemon and pepperberry aioli', 0, 0, 10, 17.00, 5.60
  UNION ALL SELECT 'APP-WING', 'Appetizers', 'Bush Spice Chicken Wings', 'Chicken wings glazed with bush tomato and chilli', 0, 1, 12, 18.50, 6.10
  UNION ALL SELECT 'MAIN-SALM', 'Mains', 'Pan-Seared Barramundi', 'Barramundi fillet with charred greens and lemon myrtle butter', 0, 0, 18, 34.00, 12.80
  UNION ALL SELECT 'MAIN-PAST', 'Mains', 'Roast Pumpkin and Sage Pasta', 'Tagliatelle with roast pumpkin, sage, and parmesan', 1, 0, 14, 28.00, 9.40
  UNION ALL SELECT 'MAIN-STEAK', 'Mains', 'Grass-Fed Sirloin 300g', 'Chargrilled sirloin with pepper sauce and chips', 0, 0, 20, 44.00, 18.20
  UNION ALL SELECT 'MAIN-CHKN', 'Mains', 'Lemon Myrtle Chicken Plate', 'Grilled chicken breast with herb rice and broccolini', 0, 0, 15, 27.00, 8.90
  UNION ALL SELECT 'PIZ-MARG', 'Woodfire Pizza', 'Margherita Pizza', 'Fresh mozzarella, basil, pomodoro', 1, 0, 11, 17.00, 5.20
  UNION ALL SELECT 'PIZ-PEPP', 'Woodfire Pizza', 'Pepperoni Pizza', 'Spicy pepperoni and provolone', 0, 1, 12, 19.50, 6.40
  UNION ALL SELECT 'PIZ-FARM', 'Woodfire Pizza', 'Bush Veggie Pizza', 'Roasted vegetables, feta, and native herb oil', 1, 0, 13, 21.00, 6.60
  UNION ALL SELECT 'PIZ-BBQ', 'Woodfire Pizza', 'BBQ Chicken Pizza', 'Smoky bbq sauce, red onion, cilantro', 0, 0, 13, 21.00, 7.30
  UNION ALL SELECT 'DES-CHSC', 'Desserts', 'Lamington Cheesecake', 'Cheesecake with coconut crumb and raspberry coulis', 1, 0, 5, 12.00, 3.60
  UNION ALL SELECT 'DES-BROW', 'Desserts', 'Warm Chocolate Pudding', 'Rich pudding with vanilla bean ice cream', 1, 0, 6, 13.00, 4.00
  UNION ALL SELECT 'DES-TIRA', 'Desserts', 'Classic Pavlova', 'Meringue shell with cream and seasonal fruit', 1, 0, 6, 13.50, 4.10
  UNION ALL SELECT 'BEV-COLD', 'Beverages', 'Flat White', 'Double-shot espresso with steamed milk', 1, 0, 2, 5.50, 1.20
  UNION ALL SELECT 'BEV-LEMN', 'Beverages', 'Sparkling Lemon Myrtle', 'Sparkling citrus with lemon myrtle and mint', 1, 0, 2, 6.80, 1.60
  UNION ALL SELECT 'BEV-KOMB', 'Beverages', 'Ginger Kombucha', 'Small-batch fermented tea', 1, 0, 2, 6.50, 1.70
  UNION ALL SELECT 'BEV-MOCK', 'Beverages', 'Berry Mint Fizz', 'Blueberry, mint, and soda', 1, 0, 3, 8.50, 2.40
  UNION ALL SELECT 'KID-MINI', 'Kids Menu', 'Mini Cheeseburger', 'Beef patty, cheddar, fries', 0, 0, 10, 11.00, 3.60
  UNION ALL SELECT 'KID-PAST', 'Kids Menu', 'Kids Butter Pasta', 'Penne with butter and parmesan', 1, 0, 8, 10.00, 2.80
  UNION ALL SELECT 'KID-NUGT', 'Kids Menu', 'Chicken Nuggets', 'Crispy nuggets and fries', 0, 0, 9, 11.00, 3.20
  UNION ALL SELECT 'KID-PIZA', 'Kids Menu', 'Kids Pizza Slice Set', 'Cheese pizza slice and fruit cup', 1, 0, 9, 10.50, 3.00
)
SELECT
  c.branch_id,
  c.category_id,
  CONCAT(b.branch_code, '-', t.sku) AS sku,
  t.item_name,
  t.item_desc,
  t.is_veg,
  t.is_spicy,
  t.prep_time,
  t.base_price,
  t.food_cost,
  1,
  CASE WHEN t.category_name = 'Desserts' THEN '11:00:00' ELSE NULL END,
  CASE WHEN t.category_name = 'Desserts' THEN '23:00:00' ELSE NULL END
FROM item_templates t
JOIN menu_categories c
  ON c.name = t.category_name
JOIN branches b
  ON b.branch_id = c.branch_id;

INSERT INTO qr_sessions (
  session_token,
  table_id,
  customer_id,
  party_size,
  status,
  started_at,
  last_activity_at,
  closed_at,
  notes
)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 5
)
SELECT
  UUID(),
  dt.table_id,
  CASE
    WHEN MOD(dt.table_id + seq.n, 4) = 0 THEN cp.customer_id
    ELSE NULL
  END AS customer_id,
  MOD(dt.table_id + seq.n, 6) + 1 AS party_size,
  CASE
    WHEN seq.n = 5 THEN 'ACTIVE'
    WHEN seq.n = 4 THEN 'CHECKOUT_PENDING'
    ELSE 'CLOSED'
  END AS status,
  TIMESTAMPADD(MINUTE, -1 * ((CAST(dt.table_id AS SIGNED) * 12) + (seq.n * 95)), NOW()) AS started_at,
  TIMESTAMPADD(MINUTE, -1 * ((CAST(dt.table_id AS SIGNED) * 12) + (seq.n * 70)), NOW()) AS last_activity_at,
  CASE
    WHEN seq.n >= 4 THEN NULL
    ELSE TIMESTAMPADD(MINUTE, -1 * ((CAST(dt.table_id AS SIGNED) * 12) + (seq.n * 40)), NOW())
  END AS closed_at,
  CASE WHEN MOD(dt.table_id + seq.n, 9) = 0 THEN 'Allergy noted in app' ELSE NULL END
FROM dining_tables dt
CROSS JOIN seq
LEFT JOIN tmp_customer_pool cp
  ON cp.seq_no = MOD(dt.table_id * seq.n, 120) + 1;

DROP TEMPORARY TABLE IF EXISTS tmp_customer_pool;

INSERT INTO orders (
  order_number,
  session_id,
  table_id,
  branch_id,
  assigned_staff_id,
  status,
  placed_at,
  accepted_at,
  served_at,
  completed_at,
  discount_amount,
  special_instructions
)
WITH server_pool AS (
  SELECT
    s.staff_id,
    s.branch_id,
    ROW_NUMBER() OVER (PARTITION BY s.branch_id ORDER BY s.staff_id) AS rn,
    COUNT(*) OVER (PARTITION BY s.branch_id) AS cnt
  FROM staff s
  WHERE s.role = 'SERVER'
),
session_orders AS (
  SELECT
    qs.session_id,
    qs.started_at,
    qs.status AS session_status,
    dt.table_id,
    dt.branch_id,
    CASE
      WHEN MOD(qs.session_id, 17) = 0 THEN 'CANCELLED'
      WHEN qs.status = 'ACTIVE' THEN 'IN_PREP'
      WHEN qs.status = 'CHECKOUT_PENDING' THEN 'SERVED'
      ELSE 'COMPLETED'
    END AS order_status,
    TIMESTAMPADD(MINUTE, 5, qs.started_at) AS placed_time
  FROM qr_sessions qs
  JOIN dining_tables dt ON dt.table_id = qs.table_id
)
SELECT
  CONCAT('ORD-', DATE_FORMAT(so.placed_time, '%Y%m%d'), '-', LPAD(so.session_id, 6, '0')),
  so.session_id,
  so.table_id,
  so.branch_id,
  sp.staff_id,
  so.order_status,
  so.placed_time,
  CASE
    WHEN so.order_status = 'CANCELLED' THEN NULL
    ELSE TIMESTAMPADD(MINUTE, 3, so.placed_time)
  END AS accepted_at,
  CASE
    WHEN so.order_status IN ('SERVED', 'COMPLETED') THEN TIMESTAMPADD(MINUTE, 28, so.placed_time)
    ELSE NULL
  END AS served_at,
  CASE
    WHEN so.order_status = 'COMPLETED' THEN TIMESTAMPADD(MINUTE, 55, so.placed_time)
    ELSE NULL
  END AS completed_at,
  CASE WHEN MOD(so.session_id, 10) = 0 THEN 5.00 ELSE 0.00 END AS discount_amount,
  CASE WHEN MOD(so.session_id, 13) = 0 THEN 'Customer requested table-side payment' ELSE NULL END
FROM session_orders so
JOIN server_pool sp
  ON sp.branch_id = so.branch_id
 AND sp.rn = (MOD(so.session_id, sp.cnt) + 1);

DROP TEMPORARY TABLE IF EXISTS tmp_order_seed;
CREATE TEMPORARY TABLE tmp_order_seed AS
SELECT
  o.order_id,
  o.branch_id,
  o.status
FROM orders o;

INSERT INTO order_items (
  order_id,
  menu_item_id,
  quantity,
  unit_price,
  tax_rate,
  item_status,
  special_request
)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 4
),
item_pool AS (
  SELECT
    mi.item_id,
    mi.branch_id,
    ROW_NUMBER() OVER (PARTITION BY mi.branch_id ORDER BY mi.item_id) AS rn,
    COUNT(*) OVER (PARTITION BY mi.branch_id) AS cnt
  FROM menu_items mi
)
SELECT
  os.order_id,
  ip.item_id,
  1 + MOD(os.order_id + seq.n, 2) AS quantity,
  NULL,
  NULL,
  CASE
    WHEN os.status IN ('SERVED', 'COMPLETED') THEN 'SERVED'
    WHEN os.status = 'CANCELLED' THEN 'VOIDED'
    WHEN os.status = 'IN_PREP' THEN 'PREPARING'
    ELSE 'PENDING'
  END AS item_status,
  CASE WHEN MOD(os.order_id + seq.n, 11) = 0 THEN 'Extra sauce on side' ELSE NULL END
FROM tmp_order_seed os
CROSS JOIN seq
JOIN item_pool ip
  ON ip.branch_id = os.branch_id
 AND ip.rn = (MOD(os.order_id + (seq.n * 7), ip.cnt) + 1)
WHERE NOT (seq.n = 4 AND MOD(os.order_id, 3) = 0);

DROP TEMPORARY TABLE IF EXISTS tmp_order_seed;

DROP TEMPORARY TABLE IF EXISTS tmp_payment_seed;
CREATE TEMPORARY TABLE tmp_payment_seed AS
SELECT
  o.order_id,
  o.total_amount AS amount_due,
  o.placed_at,
  o.served_at,
  o.completed_at,
  CASE
    WHEN MOD(o.order_id, 31) = 0 THEN 'FAILED'
    WHEN MOD(o.order_id, 29) = 0 THEN 'REFUNDED'
    WHEN MOD(o.order_id, 23) = 0 THEN 'PARTIALLY_REFUNDED'
    ELSE 'CAPTURED'
  END AS payment_status,
  CASE MOD(o.order_id, 5)
    WHEN 0 THEN 'CARD'
    WHEN 1 THEN 'APPLE_PAY'
    WHEN 2 THEN 'GOOGLE_PAY'
    WHEN 3 THEN 'ONLINE_WALLET'
    ELSE 'CASH'
  END AS method,
  CASE MOD(o.order_id, 4)
    WHEN 0 THEN 'Stripe'
    WHEN 1 THEN 'Adyen'
    WHEN 2 THEN 'Square'
    ELSE 'Worldpay'
  END AS provider,
  CASE
    WHEN MOD(o.order_id, 6) = 0 THEN ROUND(o.total_amount * 0.10, 2)
    WHEN MOD(o.order_id, 6) = 1 THEN ROUND(o.total_amount * 0.05, 2)
    ELSE 0.00
  END AS tip_amount
FROM orders o
WHERE o.status IN ('SERVED', 'COMPLETED')
  AND o.total_amount > 0;

INSERT INTO payments (
  order_id,
  payment_reference,
  method,
  provider,
  provider_transaction_id,
  status,
  amount,
  tip_amount,
  captured_amount,
  idempotency_key,
  failure_reason,
  paid_at
)
SELECT
  ps.order_id,
  CONCAT('PAY-', LPAD(ps.order_id, 8, '0')),
  ps.method,
  CASE WHEN ps.method = 'CASH' THEN 'InternalCashDesk' ELSE ps.provider END AS provider,
  CASE
    WHEN ps.method = 'CASH' OR ps.payment_status = 'FAILED' THEN NULL
    ELSE CONCAT('TXN-', LPAD(ps.order_id, 10, '0'))
  END AS provider_transaction_id,
  ps.payment_status,
  ps.amount_due,
  ps.tip_amount,
  CASE
    WHEN ps.payment_status = 'FAILED' THEN 0.00
    WHEN ps.payment_status = 'PARTIALLY_REFUNDED' THEN ROUND(ps.amount_due * 0.75, 2)
    ELSE ps.amount_due
  END AS captured_amount,
  SHA2(CONCAT('idem-', ps.order_id), 256),
  CASE WHEN ps.payment_status = 'FAILED' THEN 'Issuer declined (mock)' ELSE NULL END,
  CASE
    WHEN ps.payment_status = 'FAILED' THEN NULL
    ELSE COALESCE(ps.completed_at, ps.served_at, TIMESTAMPADD(MINUTE, 45, ps.placed_at))
  END AS paid_at
FROM tmp_payment_seed ps;

DROP TEMPORARY TABLE IF EXISTS tmp_payment_seed;

INSERT INTO refunds (
  payment_id,
  refund_reference,
  amount,
  reason,
  status,
  processed_at
)
SELECT
  p.payment_id,
  CONCAT('RF-', LPAD(p.payment_id, 8, '0')),
  CASE
    WHEN p.status = 'REFUNDED' THEN p.amount
    ELSE ROUND(p.amount - p.captured_amount, 2)
  END AS amount,
  CASE
    WHEN p.status = 'REFUNDED' THEN 'Guest complaint - full goodwill refund'
    ELSE 'Item unavailable - partial refund'
  END AS reason,
  CASE
    WHEN MOD(p.payment_id, 5) = 0 THEN 'PENDING'
    ELSE 'SUCCESS'
  END AS status,
  CASE
    WHEN MOD(p.payment_id, 5) = 0 THEN NULL
    ELSE TIMESTAMPADD(MINUTE, 5, COALESCE(p.paid_at, NOW()))
  END AS processed_at
FROM payments p
WHERE p.status IN ('REFUNDED', 'PARTIALLY_REFUNDED');

INSERT INTO audit_events (
  entity_type,
  entity_id,
  event_type,
  actor_staff_id,
  event_payload,
  created_at
)
SELECT
  'ORDER',
  o.order_id,
  'ORDER_PLACED',
  o.assigned_staff_id,
  JSON_OBJECT(
    'order_number', o.order_number,
    'table_id', o.table_id,
    'status', o.status,
    'total_amount', o.total_amount
  ),
  o.placed_at
FROM orders o;

INSERT INTO audit_events (
  entity_type,
  entity_id,
  event_type,
  actor_staff_id,
  event_payload,
  created_at
)
SELECT
  'PAYMENT',
  p.payment_id,
  CONCAT('PAYMENT_', p.status),
  o.assigned_staff_id,
  JSON_OBJECT(
    'order_id', p.order_id,
    'method', p.method,
    'status', p.status,
    'amount', p.amount,
    'captured_amount', p.captured_amount
  ),
  COALESCE(p.paid_at, p.created_at)
FROM payments p
JOIN orders o ON o.order_id = p.order_id;

  COMMIT;
END$$
DELIMITER ;

CALL sp_seed_mock_data();
DROP PROCEDURE IF EXISTS sp_seed_mock_data;
