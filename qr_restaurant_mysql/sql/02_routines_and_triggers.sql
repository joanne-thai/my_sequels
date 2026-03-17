USE qr_restaurant_mysql;

DROP TRIGGER IF EXISTS trg_order_items_before_insert;
DROP TRIGGER IF EXISTS trg_order_items_before_update;
DROP TRIGGER IF EXISTS trg_order_items_after_insert;
DROP TRIGGER IF EXISTS trg_order_items_after_update;
DROP TRIGGER IF EXISTS trg_order_items_after_delete;
DROP TRIGGER IF EXISTS trg_payments_after_insert;
DROP TRIGGER IF EXISTS trg_payments_after_update;
DROP TRIGGER IF EXISTS trg_payments_after_delete;

DROP PROCEDURE IF EXISTS sp_recalculate_order_totals;
DROP PROCEDURE IF EXISTS sp_refresh_order_payment_status;

DELIMITER $$

CREATE PROCEDURE sp_recalculate_order_totals(IN p_order_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_subtotal DECIMAL(12,2) DEFAULT 0.00;
  DECLARE v_tax DECIMAL(12,2) DEFAULT 0.00;
  DECLARE v_discount DECIMAL(12,2) DEFAULT 0.00;
  DECLARE v_service_rate DECIMAL(5,4) DEFAULT 0.0000;
  DECLARE v_service_charge DECIMAL(12,2) DEFAULT 0.00;
  DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;

  SELECT
    COALESCE(SUM(oi.line_subtotal), 0),
    COALESCE(SUM(oi.line_tax), 0)
  INTO v_subtotal, v_tax
  FROM order_items oi
  WHERE oi.order_id = p_order_id
    AND oi.item_status <> 'VOIDED';

  SELECT
    COALESCE(o.discount_amount, 0),
    COALESCE(b.service_charge_rate, 0)
  INTO v_discount, v_service_rate
  FROM orders o
  JOIN branches b ON b.branch_id = o.branch_id
  WHERE o.order_id = p_order_id;

  SET v_service_charge = ROUND(v_subtotal * v_service_rate, 2);
  SET v_total = GREATEST(ROUND(v_subtotal + v_tax + v_service_charge - v_discount, 2), 0);

  UPDATE orders
  SET subtotal_amount = v_subtotal,
      tax_amount = v_tax,
      service_charge_amount = v_service_charge,
      total_amount = v_total,
      version_no = version_no + 1
  WHERE order_id = p_order_id;
END$$

CREATE PROCEDURE sp_refresh_order_payment_status(IN p_order_id BIGINT UNSIGNED)
BEGIN
  DECLARE v_captured DECIMAL(12,2) DEFAULT 0.00;
  DECLARE v_total DECIMAL(12,2) DEFAULT 0.00;

  SELECT COALESCE(SUM(p.captured_amount + p.tip_amount), 0)
  INTO v_captured
  FROM payments p
  WHERE p.order_id = p_order_id
    AND p.status IN ('CAPTURED', 'PARTIALLY_REFUNDED', 'REFUNDED');

  SELECT COALESCE(o.total_amount, 0)
  INTO v_total
  FROM orders o
  WHERE o.order_id = p_order_id;

  IF v_total > 0 AND v_captured >= v_total THEN
    UPDATE orders
    SET status = CASE WHEN status = 'CANCELLED' THEN status ELSE 'COMPLETED' END,
        completed_at = COALESCE(completed_at, CURRENT_TIMESTAMP)
    WHERE order_id = p_order_id;
  END IF;
END$$

CREATE TRIGGER trg_order_items_before_insert
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
  IF NEW.unit_price IS NULL THEN
    SET NEW.unit_price = (
      SELECT mi.base_price
      FROM menu_items mi
      WHERE mi.item_id = NEW.menu_item_id
    );
  END IF;

  IF NEW.tax_rate IS NULL THEN
    SET NEW.tax_rate = (
      SELECT b.tax_rate
      FROM orders o
      JOIN branches b ON b.branch_id = o.branch_id
      WHERE o.order_id = NEW.order_id
    );
  END IF;

  SET NEW.line_subtotal = ROUND(COALESCE(NEW.unit_price, 0) * NEW.quantity, 2);
  SET NEW.line_tax = ROUND(NEW.line_subtotal * COALESCE(NEW.tax_rate, 0), 2);
  SET NEW.line_total = ROUND(NEW.line_subtotal + NEW.line_tax, 2);
END$$

CREATE TRIGGER trg_order_items_before_update
BEFORE UPDATE ON order_items
FOR EACH ROW
BEGIN
  IF NEW.unit_price IS NULL THEN
    SET NEW.unit_price = COALESCE(OLD.unit_price, 0);
  END IF;

  IF NEW.tax_rate IS NULL THEN
    SET NEW.tax_rate = COALESCE(OLD.tax_rate, 0);
  END IF;

  SET NEW.line_subtotal = ROUND(COALESCE(NEW.unit_price, 0) * NEW.quantity, 2);
  SET NEW.line_tax = ROUND(NEW.line_subtotal * COALESCE(NEW.tax_rate, 0), 2);
  SET NEW.line_total = ROUND(NEW.line_subtotal + NEW.line_tax, 2);
END$$

CREATE TRIGGER trg_order_items_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  CALL sp_recalculate_order_totals(NEW.order_id);
END$$

CREATE TRIGGER trg_order_items_after_update
AFTER UPDATE ON order_items
FOR EACH ROW
BEGIN
  CALL sp_recalculate_order_totals(NEW.order_id);
END$$

CREATE TRIGGER trg_order_items_after_delete
AFTER DELETE ON order_items
FOR EACH ROW
BEGIN
  CALL sp_recalculate_order_totals(OLD.order_id);
END$$

CREATE TRIGGER trg_payments_after_insert
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
  CALL sp_refresh_order_payment_status(NEW.order_id);
END$$

CREATE TRIGGER trg_payments_after_update
AFTER UPDATE ON payments
FOR EACH ROW
BEGIN
  CALL sp_refresh_order_payment_status(NEW.order_id);
END$$

CREATE TRIGGER trg_payments_after_delete
AFTER DELETE ON payments
FOR EACH ROW
BEGIN
  CALL sp_refresh_order_payment_status(OLD.order_id);
END$$

DELIMITER ;
