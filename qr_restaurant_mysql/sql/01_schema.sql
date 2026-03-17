SET NAMES utf8mb4;
SET time_zone = '+00:00';
SET sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE DATABASE IF NOT EXISTS qr_restaurant_mysql
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE qr_restaurant_mysql;

-- MySQL DDL statements perform implicit commits.
-- START TRANSACTION / COMMIT here defines deployment boundaries, while each DDL remains atomic per statement.
SET @previous_autocommit := @@autocommit;
SET autocommit = 0;
START TRANSACTION;

CREATE TABLE IF NOT EXISTS branches (
  branch_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  branch_code VARCHAR(20) NOT NULL,
  name VARCHAR(100) NOT NULL,
  address_line1 VARCHAR(150) NOT NULL,
  city VARCHAR(60) NOT NULL,
  state VARCHAR(60) NOT NULL,
  timezone VARCHAR(64) NOT NULL DEFAULT 'Australia/Sydney',
  currency_code CHAR(3) NOT NULL DEFAULT 'AUD',
  tax_rate DECIMAL(5,4) NOT NULL DEFAULT 0.1000,
  service_charge_rate DECIMAL(5,4) NOT NULL DEFAULT 0.0500,
  opened_at DATETIME NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_branches_branch_code UNIQUE (branch_code),
  CONSTRAINT chk_branches_tax_rate CHECK (tax_rate >= 0 AND tax_rate <= 1),
  CONSTRAINT chk_branches_service_charge CHECK (service_charge_rate >= 0 AND service_charge_rate <= 1)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dining_tables (
  table_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  branch_id BIGINT UNSIGNED NOT NULL,
  table_number VARCHAR(20) NOT NULL,
  zone VARCHAR(40) NOT NULL,
  seat_capacity TINYINT UNSIGNED NOT NULL,
  qr_code_token CHAR(36) NOT NULL,
  qr_url VARCHAR(255) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  last_sanitized_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_dining_tables_branch_table UNIQUE (branch_id, table_number),
  CONSTRAINT uq_dining_tables_qr_code_token UNIQUE (qr_code_token),
  CONSTRAINT chk_dining_tables_seat_capacity CHECK (seat_capacity BETWEEN 1 AND 20),
  CONSTRAINT fk_dining_tables_branch FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX idx_dining_tables_branch_zone (branch_id, zone),
  INDEX idx_dining_tables_active (is_active)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS staff (
  staff_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  branch_id BIGINT UNSIGNED NOT NULL,
  full_name VARCHAR(100) NOT NULL,
  role ENUM('MANAGER', 'SERVER', 'CASHIER', 'KITCHEN', 'ADMIN') NOT NULL,
  email VARCHAR(150) NOT NULL,
  phone VARCHAR(25) NULL,
  hired_at DATE NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_staff_email UNIQUE (email),
  CONSTRAINT fk_staff_branch FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX idx_staff_branch_role (branch_id, role),
  INDEX idx_staff_active (is_active)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS customers (
  customer_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  phone VARCHAR(25) NULL,
  email VARCHAR(150) NULL,
  loyalty_points INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_customers_phone UNIQUE (phone),
  CONSTRAINT uq_customers_email UNIQUE (email)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS menu_categories (
  category_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  branch_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(60) NOT NULL,
  display_order SMALLINT UNSIGNED NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_menu_categories_branch_name UNIQUE (branch_id, name),
  CONSTRAINT fk_menu_categories_branch FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX idx_menu_categories_order (branch_id, display_order)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS menu_items (
  item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  branch_id BIGINT UNSIGNED NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  sku VARCHAR(40) NOT NULL,
  name VARCHAR(120) NOT NULL,
  description VARCHAR(400) NULL,
  is_vegetarian TINYINT(1) NOT NULL DEFAULT 0,
  is_spicy TINYINT(1) NOT NULL DEFAULT 0,
  prep_time_minutes SMALLINT UNSIGNED NOT NULL,
  base_price DECIMAL(10,2) NOT NULL,
  food_cost DECIMAL(10,2) NOT NULL,
  is_available TINYINT(1) NOT NULL DEFAULT 1,
  available_from TIME NULL,
  available_to TIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_menu_items_branch_sku UNIQUE (branch_id, sku),
  CONSTRAINT fk_menu_items_branch FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_menu_items_category FOREIGN KEY (category_id) REFERENCES menu_categories(category_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_menu_items_base_price CHECK (base_price >= 0),
  CONSTRAINT chk_menu_items_food_cost CHECK (food_cost >= 0),
  CONSTRAINT chk_menu_items_prep_time CHECK (prep_time_minutes BETWEEN 1 AND 180),
  INDEX idx_menu_items_branch_category (branch_id, category_id),
  INDEX idx_menu_items_available (is_available)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS qr_sessions (
  session_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  session_token CHAR(36) NOT NULL,
  table_id BIGINT UNSIGNED NOT NULL,
  customer_id BIGINT UNSIGNED NULL,
  party_size TINYINT UNSIGNED NOT NULL,
  status ENUM('ACTIVE', 'CHECKOUT_PENDING', 'CLOSED', 'EXPIRED') NOT NULL DEFAULT 'ACTIVE',
  started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_activity_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  closed_at DATETIME NULL,
  notes VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_qr_sessions_token UNIQUE (session_token),
  CONSTRAINT fk_qr_sessions_table FOREIGN KEY (table_id) REFERENCES dining_tables(table_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_qr_sessions_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT chk_qr_sessions_party_size CHECK (party_size BETWEEN 1 AND 20),
  CONSTRAINT chk_qr_sessions_time_flow CHECK (last_activity_at >= started_at),
  INDEX idx_qr_sessions_table_status (table_id, status),
  INDEX idx_qr_sessions_started_at (started_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orders (
  order_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_number VARCHAR(40) NOT NULL,
  session_id BIGINT UNSIGNED NOT NULL,
  table_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NOT NULL,
  assigned_staff_id BIGINT UNSIGNED NULL,
  status ENUM('PLACED', 'IN_PREP', 'READY', 'SERVED', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'PLACED',
  placed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  accepted_at DATETIME NULL,
  served_at DATETIME NULL,
  completed_at DATETIME NULL,
  discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  subtotal_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  service_charge_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  special_instructions TEXT NULL,
  version_no INT UNSIGNED NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_orders_number UNIQUE (order_number),
  CONSTRAINT fk_orders_session FOREIGN KEY (session_id) REFERENCES qr_sessions(session_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_orders_table FOREIGN KEY (table_id) REFERENCES dining_tables(table_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_orders_branch FOREIGN KEY (branch_id) REFERENCES branches(branch_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_orders_staff FOREIGN KEY (assigned_staff_id) REFERENCES staff(staff_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT chk_orders_amounts CHECK (
    discount_amount >= 0 AND
    subtotal_amount >= 0 AND
    tax_amount >= 0 AND
    service_charge_amount >= 0 AND
    total_amount >= 0
  ),
  INDEX idx_orders_branch_status_placed (branch_id, status, placed_at),
  INDEX idx_orders_session (session_id),
  INDEX idx_orders_table_placed (table_id, placed_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
  order_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  menu_item_id BIGINT UNSIGNED NOT NULL,
  quantity SMALLINT UNSIGNED NOT NULL,
  unit_price DECIMAL(10,2) NULL,
  tax_rate DECIMAL(5,4) NULL,
  line_subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  line_tax DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  line_total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  item_status ENUM('PENDING', 'PREPARING', 'SERVED', 'VOIDED') NOT NULL DEFAULT 'PENDING',
  special_request VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_order_items_menu_item FOREIGN KEY (menu_item_id) REFERENCES menu_items(item_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_order_items_quantity CHECK (quantity BETWEEN 1 AND 100),
  CONSTRAINT chk_order_items_values CHECK (
    (unit_price IS NULL OR unit_price >= 0) AND
    (tax_rate IS NULL OR (tax_rate >= 0 AND tax_rate <= 1)) AND
    line_subtotal >= 0 AND
    line_tax >= 0 AND
    line_total >= 0
  ),
  INDEX idx_order_items_order_status (order_id, item_status),
  INDEX idx_order_items_menu_item (menu_item_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payments (
  payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  payment_reference VARCHAR(50) NOT NULL,
  method ENUM('CARD', 'CASH', 'APPLE_PAY', 'GOOGLE_PAY', 'BANK_TRANSFER', 'ONLINE_WALLET') NOT NULL,
  provider VARCHAR(60) NOT NULL,
  provider_transaction_id VARCHAR(80) NULL,
  status ENUM('INITIATED', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED') NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  tip_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  captured_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  idempotency_key CHAR(64) NOT NULL,
  failure_reason VARCHAR(255) NULL,
  paid_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_payments_reference UNIQUE (payment_reference),
  CONSTRAINT uq_payments_provider_txn UNIQUE (provider_transaction_id),
  CONSTRAINT uq_payments_idempotency UNIQUE (idempotency_key),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_payments_amounts CHECK (
    amount >= 0 AND
    tip_amount >= 0 AND
    captured_amount >= 0
  ),
  INDEX idx_payments_order_status (order_id, status),
  INDEX idx_payments_method_status (method, status),
  INDEX idx_payments_created_at (created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS refunds (
  refund_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  payment_id BIGINT UNSIGNED NOT NULL,
  refund_reference VARCHAR(50) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  reason VARCHAR(255) NOT NULL,
  status ENUM('PENDING', 'SUCCESS', 'FAILED') NOT NULL,
  processed_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_refunds_reference UNIQUE (refund_reference),
  CONSTRAINT fk_refunds_payment FOREIGN KEY (payment_id) REFERENCES payments(payment_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_refunds_amount CHECK (amount > 0),
  INDEX idx_refunds_payment_status (payment_id, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS audit_events (
  audit_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  entity_type VARCHAR(40) NOT NULL,
  entity_id BIGINT UNSIGNED NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  actor_staff_id BIGINT UNSIGNED NULL,
  event_payload JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_audit_events_staff FOREIGN KEY (actor_staff_id) REFERENCES staff(staff_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX idx_audit_events_entity (entity_type, entity_id, created_at),
  INDEX idx_audit_events_actor (actor_staff_id, created_at)
) ENGINE=InnoDB;

COMMIT;
SET autocommit = @previous_autocommit;
