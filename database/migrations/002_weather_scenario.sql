-- ============================================================
-- Migration: per-crop weather demo scenario selector
-- Lets a tester/demo deterministically choose which fallback weather
-- scenario (dry / normal / rain) applies to a crop, instead of the
-- fallback always being one fixed dataset. Only affects behavior when
-- no live OPENWEATHER_API_KEY is configured.
-- Run with: mysql agrisense < database/migrations/002_weather_scenario.sql
-- ============================================================
USE agrisense;

SET @col_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'agrisense' AND TABLE_NAME = 'farmer_crops' AND COLUMN_NAME = 'weather_scenario'
);

SET @sql = IF(@col_exists = 0,
    'ALTER TABLE farmer_crops
        ADD COLUMN weather_scenario ENUM(''dry'',''normal'',''rain'') NOT NULL DEFAULT ''normal'' AFTER growth_stage',
    'SELECT ''Migration already applied, skipping'' AS message'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
