-- Run from project root:
-- mysql -u <user> -p < setup.sql

SOURCE sql/01_schema.sql;
SOURCE sql/02_routines_and_triggers.sql;
-- Seed script uses START TRANSACTION/COMMIT with exception-driven ROLLBACK.
SOURCE sql/03_seed_mock_data.sql;
SOURCE sql/04_analytics_views.sql;

SELECT 'Setup complete for qr_restaurant_mysql' AS status;
SELECT COUNT(*) AS branches FROM qr_restaurant_mysql.branches;
SELECT COUNT(*) AS dining_tables FROM qr_restaurant_mysql.dining_tables;
SELECT COUNT(*) AS menu_items FROM qr_restaurant_mysql.menu_items;
SELECT COUNT(*) AS qr_sessions FROM qr_restaurant_mysql.qr_sessions;
SELECT COUNT(*) AS orders FROM qr_restaurant_mysql.orders;
SELECT COUNT(*) AS payments FROM qr_restaurant_mysql.payments;
