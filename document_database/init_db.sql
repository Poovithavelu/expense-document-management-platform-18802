-- Initialization orchestrator: executes schema and seed scripts
-- Note: startup.sh will run mysql client to execute this file after DB and users are set up.
SOURCE schema.sql;
SOURCE seed.sql;
