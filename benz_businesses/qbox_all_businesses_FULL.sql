-- =========================================================
-- QBOX ALL BUSINESSES - MERGED SQL FILE
-- =========================================================
-- This file contains ALL SQL tables required by:
-- - Business Accounts
-- - Employee Management
-- - Supply/Delivery System
-- - Dynamic Admin-Created Businesses
-- =========================================================



-- =========================================================
-- SOURCE: qbox_business_menus.sql
-- =========================================================

CREATE TABLE IF NOT EXISTS `qbox_business_menus` (
  `business` VARCHAR(50) NOT NULL,
  `station` VARCHAR(50) NOT NULL,
  `items` LONGTEXT NOT NULL,
  PRIMARY KEY (`business`, `station`)
);


-- =========================================================
-- SOURCE: qbox_business_accounts.sql
-- =========================================================

CREATE TABLE IF NOT EXISTS `qbox_business_accounts` (
  `business` VARCHAR(50) NOT NULL PRIMARY KEY,
  `balance` INT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `qbox_business_transactions` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `business` VARCHAR(50) NOT NULL,
  `citizenid` VARCHAR(100) NULL,
  `player_name` VARCHAR(100) NULL,
  `action` VARCHAR(50) NOT NULL,
  `amount` INT NOT NULL,
  `note` VARCHAR(255) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- =========================================================
-- SOURCE: qbox_business_supply_orders.sql
-- =========================================================

CREATE TABLE IF NOT EXISTS `qbox_business_supply_orders` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `business` VARCHAR(50) NOT NULL,
  `ordered_by` VARCHAR(100) NULL,
  `ordered_name` VARCHAR(100) NULL,
  `status` VARCHAR(30) NOT NULL DEFAULT 'pending',
  `total` INT NOT NULL DEFAULT 0,
  `items` LONGTEXT NOT NULL,
  `delivery_ready_at` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- =========================================================
-- SOURCE: qbox_dynamic_businesses.sql
-- =========================================================

CREATE TABLE IF NOT EXISTS `qbox_dynamic_businesses` (
  `id` VARCHAR(50) NOT NULL PRIMARY KEY,
  `label` VARCHAR(100) NOT NULL,
  `type` VARCHAR(50) NOT NULL DEFAULT 'business',
  `job` VARCHAR(50) NOT NULL,
  `ui` LONGTEXT NULL,
  `blip` LONGTEXT NULL,
  `created_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

ALTER TABLE `qbox_dynamic_businesses` ADD COLUMN IF NOT EXISTS `blip` LONGTEXT NULL AFTER `ui`;
ALTER TABLE `qbox_dynamic_businesses` ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

CREATE TABLE IF NOT EXISTS `qbox_dynamic_business_stations` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `business` VARCHAR(50) NOT NULL,
  `job` VARCHAR(50) NULL,
  `station_id` VARCHAR(50) NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `coords` LONGTEXT NOT NULL,
  `size` LONGTEXT NULL,
  `rotation` FLOAT NOT NULL DEFAULT 0,
  `settings` LONGTEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS `qbox_business_dj_booths` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `business` VARCHAR(50) NOT NULL,
  `booth_id` VARCHAR(80) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `coords` LONGTEXT NOT NULL,
  `rotation` FLOAT NOT NULL DEFAULT 0,
  `use_radius` FLOAT NOT NULL DEFAULT 2.0,
  `hear_radius` FLOAT NOT NULL DEFAULT 45.0,
  `created_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS `qbox_business_stations` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `business` VARCHAR(50) NOT NULL,
  `job` VARCHAR(50) NULL,
  `station_id` VARCHAR(80) NOT NULL,
  `type` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `coords` LONGTEXT NOT NULL,
  `rotation` FLOAT NOT NULL DEFAULT 0,
  `settings` LONGTEXT NULL,
  `created_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Existing installs: add job column for placed station job locking.
ALTER TABLE `qbox_business_stations` ADD COLUMN `job` VARCHAR(50) NULL AFTER `business`;


CREATE TABLE IF NOT EXISTS `qbox_business_supply_items` (
  `item` VARCHAR(100) NOT NULL PRIMARY KEY,
  `label` VARCHAR(100) NOT NULL,
  `price` INT NOT NULL DEFAULT 0,
  `amount` INT NOT NULL DEFAULT 1,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS `qbox_business_supply_store_items` (
  `business` VARCHAR(50) NOT NULL,
  `item` VARCHAR(100) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `price` INT NOT NULL DEFAULT 0,
  `amount` INT NOT NULL DEFAULT 1,
  `enabled` TINYINT NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`business`, `item`)
);
