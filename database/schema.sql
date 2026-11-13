-- ============================================================
-- AgriSense Database Schema (MySQL 8.0)
-- ============================================================
CREATE DATABASE IF NOT EXISTS agrisense
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE agrisense;

-- ---------------------------------------------------------------
-- USERS (farmers)
-- ---------------------------------------------------------------
CREATE TABLE users (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(120) NOT NULL,
    email           VARCHAR(120) UNIQUE,
    mobile          VARCHAR(20) UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    location        VARCHAR(120),
    state           VARCHAR(80),
    district        VARCHAR(80),
    preferred_language VARCHAR(20) DEFAULT 'en',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_contact CHECK (email IS NOT NULL OR mobile IS NOT NULL)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- FARMS
-- ---------------------------------------------------------------
CREATE TABLE farms (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    farm_name       VARCHAR(120) NOT NULL,
    farm_size_acres DECIMAL(8,2),
    latitude        DECIMAL(10,7),
    longitude       DECIMAL(10,7),
    location_text   VARCHAR(150),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_farms_user (user_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- CROPS (master catalog)
-- ---------------------------------------------------------------
CREATE TABLE crops (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(80) NOT NULL,
    category        VARCHAR(50),
    typical_duration_days INT,
    ideal_soil_moisture_min DECIMAL(5,2),
    ideal_soil_moisture_max DECIMAL(5,2),
    ideal_temp_min  DECIMAL(5,2),
    ideal_temp_max  DECIMAL(5,2),
    UNIQUE KEY uq_crop_name (name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- FARMER_CROPS (a farmer's planted crop instance)
-- ---------------------------------------------------------------
CREATE TABLE farmer_crops (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    farm_id         INT NOT NULL,
    crop_id         INT NOT NULL,
    variety         VARCHAR(80),
    sowing_date     DATE,
    farm_size_acres DECIMAL(8,2),
    growth_stage    ENUM('sowing','germination','vegetative','flowering','fruiting','maturity','harvested') DEFAULT 'sowing',
    -- Selects which fallback weather scenario (dry/normal/rain) applies to
    -- this crop when no live weather API key is configured. Lets a demo
    -- deterministically show the decision engine responding to different
    -- conditions instead of always seeing one fixed fallback dataset.
    weather_scenario ENUM('dry','normal','rain') NOT NULL DEFAULT 'normal',
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (farm_id) REFERENCES farms(id) ON DELETE CASCADE,
    FOREIGN KEY (crop_id) REFERENCES crops(id),
    INDEX idx_fc_user (user_id),
    INDEX idx_fc_active (user_id, is_active)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- FIELD_READINGS (soil/field sensor-style data)
-- ---------------------------------------------------------------
CREATE TABLE field_readings (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    farmer_crop_id  INT NOT NULL,
    soil_moisture_pct DECIMAL(5,2),
    soil_temperature_c DECIMAL(5,2),
    air_temperature_c DECIMAL(5,2),
    humidity_pct    DECIMAL(5,2),
    rainfall_mm     DECIMAL(6,2),
    light_intensity_lux DECIMAL(10,2),
    recorded_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source          ENUM('demo','manual','sensor') DEFAULT 'demo',
    FOREIGN KEY (farmer_crop_id) REFERENCES farmer_crops(id) ON DELETE CASCADE,
    INDEX idx_fr_crop_time (farmer_crop_id, recorded_at)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- WEATHER_RECORDS (cached weather pulls / fallback data)
-- ---------------------------------------------------------------
CREATE TABLE weather_records (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    location_text   VARCHAR(150) NOT NULL,
    latitude        DECIMAL(10,7),
    longitude       DECIMAL(10,7),
    temperature_c   DECIMAL(5,2),
    feels_like_c    DECIMAL(5,2),
    humidity_pct    DECIMAL(5,2),
    wind_speed_kmh  DECIMAL(6,2),
    rainfall_mm     DECIMAL(6,2),
    weather_condition VARCHAR(80),
    rain_probability_pct DECIMAL(5,2),
    forecast_json   JSON,
    is_fallback     BOOLEAN DEFAULT FALSE,
    fetched_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_weather_loc_time (location_text, fetched_at)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- PESTS
-- ---------------------------------------------------------------
CREATE TABLE pests (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    affected_crops  VARCHAR(255) COMMENT 'comma-separated crop names',
    favorable_temp_min DECIMAL(5,2),
    favorable_temp_max DECIMAL(5,2),
    favorable_humidity_min DECIMAL(5,2),
    description     TEXT,
    preventive_action TEXT
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- DISEASES
-- ---------------------------------------------------------------
CREATE TABLE diseases (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    crop_id         INT,
    description     TEXT,
    treatment       TEXT,
    class_label     VARCHAR(100) COMMENT 'label used by the CV model',
    FOREIGN KEY (crop_id) REFERENCES crops(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- PEST_PREDICTIONS (history of pest-risk engine outputs)
-- ---------------------------------------------------------------
CREATE TABLE pest_predictions (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    farmer_crop_id  INT NOT NULL,
    pest_id         INT,
    probability_pct DECIMAL(5,2) NOT NULL,
    risk_level      ENUM('low','moderate','high','critical') NOT NULL,
    contributing_factors JSON,
    predicted_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (farmer_crop_id) REFERENCES farmer_crops(id) ON DELETE CASCADE,
    FOREIGN KEY (pest_id) REFERENCES pests(id),
    INDEX idx_pp_crop_time (farmer_crop_id, predicted_at)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- DISEASE_PREDICTIONS (history of CV predictions)
-- ---------------------------------------------------------------
CREATE TABLE disease_predictions (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    farmer_crop_id  INT NOT NULL,
    disease_id      INT,
    image_path      VARCHAR(255),
    confidence_pct  DECIMAL(5,2),
    predicted_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (farmer_crop_id) REFERENCES farmer_crops(id) ON DELETE CASCADE,
    FOREIGN KEY (disease_id) REFERENCES diseases(id),
    INDEX idx_dp_crop_time (farmer_crop_id, predicted_at)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- MARKET_PRICES
-- ---------------------------------------------------------------
CREATE TABLE market_prices (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    crop_id         INT NOT NULL,
    market_name     VARCHAR(120) NOT NULL,
    price_per_quintal DECIMAL(10,2) NOT NULL,
    recorded_date   DATE NOT NULL,
    is_demo         BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (crop_id) REFERENCES crops(id),
    INDEX idx_mp_crop_date (crop_id, recorded_date)
) ENGINE=InnoDB;

CREATE TABLE target_prices (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    crop_id         INT NOT NULL,
    target_price    DECIMAL(10,2) NOT NULL,
    achieved         BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (crop_id) REFERENCES crops(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- RECOMMENDATIONS
-- ---------------------------------------------------------------
CREATE TABLE recommendations (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    farmer_crop_id  INT NOT NULL,
    category        ENUM('irrigation','pest_management','disease_management','crop_protection','harvesting','market_selection') NOT NULL,
    title           VARCHAR(150) NOT NULL,
    explanation     TEXT NOT NULL,
    action          TEXT NOT NULL,
    priority        ENUM('low','medium','high') DEFAULT 'medium',
    generated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (farmer_crop_id) REFERENCES farmer_crops(id) ON DELETE CASCADE,
    INDEX idx_rec_crop_time (farmer_crop_id, generated_at)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- ALERTS
-- ---------------------------------------------------------------
CREATE TABLE alerts (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    farmer_crop_id  INT,
    type            ENUM('weather','pest','disease','market','irrigation','general') NOT NULL,
    severity        ENUM('informational','low','moderate','high','critical') NOT NULL,
    title           VARCHAR(150) NOT NULL,
    message         TEXT NOT NULL,
    recommended_action TEXT,
    -- Stable fingerprint of "this kind of alert, for this crop" (e.g.
    -- "weather:heavy_rain:farmer_crop:12"). Used to prevent creating a
    -- duplicate active alert every time the engine re-evaluates.
    dedup_key       VARCHAR(180) NOT NULL,
    status          ENUM('active','read','dismissed','resolved') NOT NULL DEFAULT 'active',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at         TIMESTAMP NULL,
    dismissed_at    TIMESTAMP NULL,
    resolved_at     TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (farmer_crop_id) REFERENCES farmer_crops(id) ON DELETE SET NULL,
    INDEX idx_alerts_user_time (user_id, created_at),
    INDEX idx_alerts_dedup_active (dedup_key, status)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- NOTIFICATIONS (delivered/read history, derived from alerts)
-- ---------------------------------------------------------------
CREATE TABLE notifications (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    alert_id        INT NOT NULL,
    is_read         BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at         TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (alert_id) REFERENCES alerts(id) ON DELETE CASCADE,
    INDEX idx_notif_user_read (user_id, is_read)
) ENGINE=InnoDB;
