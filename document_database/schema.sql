-- Expense Document Management Platform - MySQL Schema
-- Schema: myapp (configured by startup.sh)
-- This schema contains core tables for documents, extracted fields, versions, categories, and audit logs.

-- Use the target database (created by startup.sh)
USE `myapp`;

-- Set SQL mode for consistency
SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- TABLE: users (optional placeholder for foreign keys; can be integrated later by auth service)
-- Keeping minimal fields to avoid circular dependencies; can be replaced by external auth later.
CREATE TABLE IF NOT EXISTS `users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `email` VARCHAR(255) NOT NULL UNIQUE,
  `display_name` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_users_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLE: documents
-- Stores metadata about uploaded documents (receipt, invoice, pdf, image)
CREATE TABLE IF NOT EXISTS `documents` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `external_id` VARCHAR(64) NULL UNIQUE, -- for cross-system reference
  `user_id` BIGINT UNSIGNED NULL, -- uploader/owner
  `file_name` VARCHAR(512) NOT NULL,
  `content_type` VARCHAR(128) NOT NULL,
  `original_size_bytes` BIGINT UNSIGNED NOT NULL,
  `storage_path` VARCHAR(1024) NOT NULL, -- path or URL to object storage
  `status` ENUM('uploaded','processing','processed','failed') NOT NULL DEFAULT 'uploaded',
  `processing_error` TEXT NULL,
  `uploaded_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_documents_user_id` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  INDEX `idx_documents_user_id` (`user_id`),
  INDEX `idx_documents_status_uploaded_at` (`status`, `uploaded_at`),
  INDEX `idx_documents_uploaded_at` (`uploaded_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLE: document_versions
-- Keeps versions of a document as it is reprocessed or improved OCR
CREATE TABLE IF NOT EXISTS `document_versions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `document_id` BIGINT UNSIGNED NOT NULL,
  `version_number` INT UNSIGNED NOT NULL,
  `storage_path` VARCHAR(1024) NOT NULL, -- version-specific path or URL
  `content_type` VARCHAR(128) NOT NULL,
  `size_bytes` BIGINT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_document_version` (`document_id`, `version_number`),
  CONSTRAINT `fk_document_versions_document_id`
    FOREIGN KEY (`document_id`) REFERENCES `documents`(`id`) ON DELETE CASCADE,
  INDEX `idx_document_versions_document_id` (`document_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLE: categories
-- Expense categories, with an optional hierarchical parent
CREATE TABLE IF NOT EXISTS `categories` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(128) NOT NULL,
  `slug` VARCHAR(128) NOT NULL UNIQUE,
  `parent_id` BIGINT UNSIGNED NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_categories_parent_id` FOREIGN KEY (`parent_id`) REFERENCES `categories`(`id`) ON DELETE SET NULL,
  UNIQUE KEY `uq_categories_name_parent` (`name`, `parent_id`),
  INDEX `idx_categories_parent_id` (`parent_id`),
  INDEX `idx_categories_is_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLE: document_categories
-- Many-to-many relationship between documents and categories (final or proposed classification)
CREATE TABLE IF NOT EXISTS `document_categories` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `document_id` BIGINT UNSIGNED NOT NULL,
  `category_id` BIGINT UNSIGNED NOT NULL,
  `source` ENUM('auto','manual') NOT NULL DEFAULT 'auto',
  `confidence` DECIMAL(5,4) NULL, -- model confidence 0..1
  `assigned_by_user_id` BIGINT UNSIGNED NULL, -- if manual
  `assigned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_document_category` (`document_id`, `category_id`),
  CONSTRAINT `fk_doc_categories_document_id`
    FOREIGN KEY (`document_id`) REFERENCES `documents`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_doc_categories_category_id`
    FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_doc_categories_assigned_by_user_id`
    FOREIGN KEY (`assigned_by_user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL,
  INDEX `idx_doc_categories_document_id` (`document_id`),
  INDEX `idx_doc_categories_category_id` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLE: extracted_fields
-- Normalized storage of extracted OCR key fields per document version
CREATE TABLE IF NOT EXISTS `extracted_fields` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `document_id` BIGINT UNSIGNED NOT NULL,
  `version_id` BIGINT UNSIGNED NULL, -- which version produced these fields
  `vendor` VARCHAR(512) NULL,
  `amount` DECIMAL(12,2) NULL,
  `currency` CHAR(3) NULL,
  `transaction_date` DATE NULL,
  `raw_json` JSON NULL, -- raw OCR output as JSON for traceability
  `extraction_quality` DECIMAL(5,4) NULL, -- 0..1
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_extracted_fields_doc_version` (`document_id`, `version_id`),
  CONSTRAINT `fk_extracted_fields_document_id`
    FOREIGN KEY (`document_id`) REFERENCES `documents`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_extracted_fields_version_id`
    FOREIGN KEY (`version_id`) REFERENCES `document_versions`(`id`) ON DELETE SET NULL,
  INDEX `idx_extracted_fields_vendor` (`vendor`),
  INDEX `idx_extracted_fields_amount` (`amount`),
  INDEX `idx_extracted_fields_date` (`transaction_date`),
  INDEX `idx_extracted_fields_search_compound` (`vendor`, `transaction_date`, `amount`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLE: audit_logs
-- Auditing user and system actions on documents and categories
CREATE TABLE IF NOT EXISTS `audit_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `document_id` BIGINT UNSIGNED NULL,
  `user_id` BIGINT UNSIGNED NULL,
  `action` VARCHAR(128) NOT NULL, -- e.g., upload, ocr_started, ocr_completed, categorize, recategorize, delete
  `details` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_audit_logs_document_id_created_at` (`document_id`, `created_at`),
  INDEX `idx_audit_logs_user_id_created_at` (`user_id`, `created_at`),
  CONSTRAINT `fk_audit_logs_document_id`
    FOREIGN KEY (`document_id`) REFERENCES `documents`(`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_audit_logs_user_id`
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- TABLE: processing_jobs
-- Track asynchronous OCR jobs and retries for admin monitoring
CREATE TABLE IF NOT EXISTS `processing_jobs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `document_id` BIGINT UNSIGNED NOT NULL,
  `job_type` ENUM('ocr','categorization') NOT NULL DEFAULT 'ocr',
  `status` ENUM('queued','running','succeeded','failed','retrying') NOT NULL DEFAULT 'queued',
  `attempt` INT UNSIGNED NOT NULL DEFAULT 1,
  `max_attempts` INT UNSIGNED NOT NULL DEFAULT 3,
  `last_error` TEXT NULL,
  `queued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `started_at` TIMESTAMP NULL DEFAULT NULL,
  `finished_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_processing_jobs_status` (`status`),
  INDEX `idx_processing_jobs_document_id` (`document_id`),
  CONSTRAINT `fk_processing_jobs_document_id`
    FOREIGN KEY (`document_id`) REFERENCES `documents`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- VIEW: v_document_search
-- A helper view to facilitate search across key fields
DROP VIEW IF EXISTS `v_document_search`;
CREATE VIEW `v_document_search` AS
SELECT
  d.id AS document_id,
  d.file_name,
  d.content_type,
  d.uploaded_at,
  d.status,
  ef.vendor,
  ef.amount,
  ef.currency,
  ef.transaction_date
FROM documents d
LEFT JOIN extracted_fields ef ON ef.document_id = d.id;

-- Recommended grants are handled by startup.sh (appuser on myapp.*)

-- Done.
