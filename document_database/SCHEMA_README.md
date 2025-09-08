# Document Database Schema (MySQL)

This directory contains the MySQL schema and initialization scripts for the Expense Document Management Platform.

Contents:
- schema.sql: DDL for core tables:
  - users: Minimal stub to support foreign keys (email, display_name)
  - documents: Uploaded documents metadata
  - document_versions: Versioned artifacts of documents
  - categories: Expense categories (supports hierarchy via parent_id)
  - document_categories: Many-to-many mapping with source (auto/manual) and confidence
  - extracted_fields: OCR outputs (vendor, amount, currency, transaction_date) plus raw_json and quality
  - audit_logs: Event logging for actions across the system
  - processing_jobs: Tracks OCR/categorization job status and retries
  - v_document_search: Helper view for search queries across key fields
- seed.sql: Seed data for categories, sample users, sample documents, categories mappings, and example OCR fields.
- init_db.sql: Orchestrates schema and seed application via `SOURCE`.

Initialization flow:
1. startup.sh starts the MySQL server (port 5000 by default), configures root and appuser, and creates the database `myapp`.
2. startup.sh subsequently applies `init_db.sql` which sources `schema.sql` and `seed.sql`.
3. A connection command is saved to `db_connection.txt`.
4. MySQL environment variables for the DB viewer are saved to `db_visualizer/mysql.env`.

Indexes and performance:
- documents: indexes on (status, uploaded_at) and uploaded_at for list and admin screens.
- extracted_fields: indexes on vendor, amount, transaction_date, and a compound index (vendor, transaction_date, amount) for common searches.
- document_versions, document_categories: indexes on foreign keys for fast joins.
- audit_logs: compound indexes on (document_id, created_at) and (user_id, created_at).
- processing_jobs: status and document_id indexes for dashboards and retries.

Environment variables expected (already handled by startup.sh for viewer):
- MYSQL_URL
- MYSQL_USER
- MYSQL_PASSWORD
- MYSQL_DB
- MYSQL_PORT

Notes:
- Do not hardcode credentials in application code. Backend should read from environment variables provided by the deployment environment.
- The `users` table is a placeholder; integration with a dedicated auth service can replace it or sync into it.
