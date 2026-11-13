-- ============================================================
-- Migration: alert lifecycle (status, dedup_key, timestamps)
-- Safe to run on an existing AgriSense database — only adds
-- columns/indexes, does not drop or modify existing data.
-- Run with: mysql agrisense < database/migrations/001_alert_lifecycle.sql
-- ============================================================
USE agrisense;

SET @col_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'agrisense' AND TABLE_NAME = 'alerts' AND COLUMN_NAME = 'status'
);

SET @sql = IF(@col_exists = 0,
    'ALTER TABLE alerts
        ADD COLUMN dedup_key VARCHAR(180) NOT NULL DEFAULT '''' AFTER recommended_action,
        ADD COLUMN status ENUM(''active'',''read'',''dismissed'',''resolved'') NOT NULL DEFAULT ''active'' AFTER dedup_key,
        ADD COLUMN read_at TIMESTAMP NULL AFTER created_at,
        ADD COLUMN dismissed_at TIMESTAMP NULL AFTER read_at,
        ADD COLUMN resolved_at TIMESTAMP NULL AFTER dismissed_at,
        ADD INDEX idx_alerts_dedup_active (dedup_key, status)',
    'SELECT ''Migration already applied, skipping'' AS message'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Backfill a usable dedup_key for any pre-existing rows so the unique
-- lookup still works for old alerts (best-effort, not critical).
UPDATE alerts
SET dedup_key = CONCAT(type, ':', IFNULL(farmer_crop_id, 'none'), ':', id)
WHERE dedup_key = '';
