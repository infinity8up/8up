-- Reset public schema before re-running 1_1_schema.sql, 1_2_logic.sql, and seed files.

truncate table storage.objects, storage.buckets cascade;

drop schema if exists public cascade;
create schema public;

-- Also clear auth users so fixed seed emails can be reinserted cleanly.
truncate table auth.users cascade;

grant usage on schema public to postgres, anon, authenticated, service_role;
grant create on schema public to postgres, service_role;
grant all on schema public to postgres, service_role;
