-- Seed data for Expense Document Management Platform

USE `myapp`;

-- Seed users (placeholder for testing)
INSERT INTO `users` (`email`, `display_name`)
VALUES
  ('alice@example.com', 'Alice Example'),
  ('bob@example.com', 'Bob Example')
ON DUPLICATE KEY UPDATE `display_name` = VALUES(`display_name`);

-- Seed categories
INSERT INTO `categories` (`name`, `slug`, `parent_id`, `is_active`)
VALUES
  ('Travel', 'travel', NULL, 1),
  ('Meals', 'meals', NULL, 1),
  ('Supplies', 'supplies', NULL, 1),
  ('Lodging', 'lodging', 1, 1),
  ('Transportation', 'transportation', 1, 1)
ON DUPLICATE KEY UPDATE `is_active` = VALUES(`is_active`);

-- Sample documents
INSERT INTO `documents` (`external_id`, `user_id`, `file_name`, `content_type`, `original_size_bytes`, `storage_path`, `status`)
VALUES
  ('EXT-1001', 1, 'receipt_hotel.pdf', 'application/pdf', 523456, 's3://bucket/docs/receipt_hotel.pdf', 'processed'),
  ('EXT-1002', 2, 'taxi_ride.jpg', 'image/jpeg', 234567, 's3://bucket/docs/taxi_ride.jpg', 'processed')
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`);

-- Link sample categories
-- Get IDs dynamically in case of prior existence
-- Travel children Lodging, Transportation; map documents
INSERT INTO `document_categories` (`document_id`, `category_id`, `source`, `confidence`, `assigned_by_user_id`)
SELECT d.id, c.id, 'auto', 0.92, NULL
FROM documents d
JOIN categories c ON c.slug = 'lodging'
WHERE d.external_id = 'EXT-1001'
ON DUPLICATE KEY UPDATE `confidence` = VALUES(`confidence`);

INSERT INTO `document_categories` (`document_id`, `category_id`, `source`, `confidence`, `assigned_by_user_id`)
SELECT d.id, c.id, 'auto', 0.88, NULL
FROM documents d
JOIN categories c ON c.slug = 'transportation'
WHERE d.external_id = 'EXT-1002'
ON DUPLICATE KEY UPDATE `confidence` = VALUES(`confidence`);

-- Create initial document versions
INSERT INTO `document_versions` (`document_id`, `version_number`, `storage_path`, `content_type`, `size_bytes`)
SELECT id, 1, storage_path, content_type, original_size_bytes FROM documents
ON DUPLICATE KEY UPDATE `size_bytes` = VALUES(`size_bytes`);

-- Add extracted fields for samples
INSERT INTO `extracted_fields` (`document_id`, `version_id`, `vendor`, `amount`, `currency`, `transaction_date`, `raw_json`, `extraction_quality`)
SELECT
  d.id,
  (SELECT dv.id FROM document_versions dv WHERE dv.document_id = d.id AND dv.version_number = 1),
  'Hotel ABC',
  249.99,
  'USD',
  DATE('2024-08-14'),
  JSON_OBJECT('lines', JSON_ARRAY('Hotel ABC', 'Room 2 nights', 'Total 249.99 USD')),
  0.95
FROM documents d
WHERE d.external_id = 'EXT-1001'
ON DUPLICATE KEY UPDATE `amount` = VALUES(`amount`), `transaction_date` = VALUES(`transaction_date`);

INSERT INTO `extracted_fields` (`document_id`, `version_id`, `vendor`, `amount`, `currency`, `transaction_date`, `raw_json`, `extraction_quality`)
SELECT
  d.id,
  (SELECT dv.id FROM document_versions dv WHERE dv.document_id = d.id AND dv.version_number = 1),
  'City Taxi Co.',
  34.50,
  'USD',
  DATE('2024-08-15'),
  JSON_OBJECT('lines', JSON_ARRAY('City Taxi Co.', 'Total 34.50 USD')),
  0.90
FROM documents d
WHERE d.external_id = 'EXT-1002'
ON DUPLICATE KEY UPDATE `amount` = VALUES(`amount`), `transaction_date` = VALUES(`transaction_date`);

-- Seed processing job history example
INSERT INTO `processing_jobs` (`document_id`, `job_type`, `status`, `attempt`, `max_attempts`, `last_error`, `queued_at`, `started_at`, `finished_at`)
SELECT d.id, 'ocr', 'succeeded', 1, 3, NULL, NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 1 DAY
FROM documents d
WHERE d.external_id IN ('EXT-1001', 'EXT-1002');

-- Seed audit logs
INSERT INTO `audit_logs` (`document_id`, `user_id`, `action`, `details`)
SELECT d.id, d.user_id, 'upload', JSON_OBJECT('file_name', d.file_name)
FROM documents d
ON DUPLICATE KEY UPDATE `details` = VALUES(`details`);
