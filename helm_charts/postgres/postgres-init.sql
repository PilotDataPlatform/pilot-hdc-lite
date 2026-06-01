#!/bin/sh
export PGPASSWORD=$POSTGRES_PASSWORD
cat > /tmp/create_databases.sql<<'EOF'
-- Create databases
select 'create database project' where not exists (select from pg_database where datname = 'project')\gexec
select 'create database notifications' where not exists (select from pg_database where datname = 'notifications')\gexec
\c notifications
create schema if not exists notifications;
create schema if not exists announcements;
select 'create database metadata' where not exists (select from pg_database where datname = 'metadata')\gexec
\c metadata
create schema if not exists metadata;
create extension if not exists ltree;
select 'create database dataops' where not exists (select from pg_database where datname = 'dataops')\gexec
select 'create database dataset' where not exists (select from pg_database where datname = 'dataset')\gexec
create extension if not exists pg_cron;
SELECT cron.schedule('expire_REGISTERED_items', '0 */1 * * *', $$DELETE from metadata.items where status='REGISTERED' and last_updated_time < now()  - interval '1 day'$$) where not exists (select from cron.job where jobname = 'expire_REGISTERED_items');
SELECT cron.schedule('expire_job_history', '0 3 */1 * *', $$DELETE FROM cron.job_run_details WHERE end_time < now() - interval '30 days'$$) where not exists (select from cron.job where jobname = 'expire_job_history');
\c dataset
create schema if not exists dataset;
select 'create database approval' where not exists (select from pg_database where datname = 'approval')\gexec
\c approval
create schema if not exists pilot_approval;
select 'create database auth' where not exists (select from pg_database where datname = 'auth')\gexec
\c auth
create schema if not exists pilot_invitation;
create schema if not exists pilot_casbin;
create schema if not exists pilot_event;
create schema if not exists pilot_ldap;

-- Create dedicated service users with least privilege
-- Metadata service user
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'metadata_user') THEN
    CREATE USER metadata_user WITH PASSWORD '${METADATA_DB_PASSWORD}';
  END IF;
END
$$;
GRANT CONNECT ON DATABASE metadata TO metadata_user;
\c metadata
GRANT ALL PRIVILEGES ON SCHEMA metadata TO metadata_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA metadata TO metadata_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA metadata TO metadata_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA metadata GRANT ALL ON TABLES TO metadata_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA metadata GRANT ALL ON SEQUENCES TO metadata_user;
\c postgres
ALTER DATABASE metadata OWNER TO metadata_user;

-- Project service user
\c postgres
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'project_user') THEN
    CREATE USER project_user WITH PASSWORD '${PROJECT_DB_PASSWORD}';
  END IF;
END
$$;
GRANT CONNECT ON DATABASE project TO project_user;
GRANT ALL PRIVILEGES ON DATABASE project TO project_user;
ALTER DATABASE project OWNER TO project_user;

-- Dataops service user
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'dataops_user') THEN
    CREATE USER dataops_user WITH PASSWORD '${DATAOPS_DB_PASSWORD}';
  END IF;
END
$$;
GRANT CONNECT ON DATABASE dataops TO dataops_user;
GRANT ALL PRIVILEGES ON DATABASE dataops TO dataops_user;
ALTER DATABASE dataops OWNER TO dataops_user;

-- Auth service user
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'auth_user') THEN
    CREATE USER auth_user WITH PASSWORD '${AUTH_DB_PASSWORD}';
  END IF;
END
$$;
GRANT CONNECT ON DATABASE auth TO auth_user;
\c auth
GRANT ALL PRIVILEGES ON SCHEMA pilot_invitation TO auth_user;
GRANT ALL PRIVILEGES ON SCHEMA pilot_casbin TO auth_user;
GRANT ALL PRIVILEGES ON SCHEMA pilot_event TO auth_user;
GRANT ALL PRIVILEGES ON SCHEMA pilot_ldap TO auth_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pilot_invitation TO auth_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pilot_casbin TO auth_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pilot_event TO auth_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pilot_ldap TO auth_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA pilot_invitation TO auth_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA pilot_casbin TO auth_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA pilot_event TO auth_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA pilot_ldap TO auth_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA pilot_invitation GRANT ALL ON TABLES TO auth_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA pilot_casbin GRANT ALL ON TABLES TO auth_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA pilot_event GRANT ALL ON TABLES TO auth_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA pilot_ldap GRANT ALL ON TABLES TO auth_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA pilot_invitation GRANT ALL ON SEQUENCES TO auth_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA pilot_casbin GRANT ALL ON SEQUENCES TO auth_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA pilot_event GRANT ALL ON SEQUENCES TO auth_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA pilot_ldap GRANT ALL ON SEQUENCES TO auth_user;
\c postgres
ALTER DATABASE auth OWNER TO auth_user;
EOF
psql -U postgres -f /tmp/create_databases.sql
