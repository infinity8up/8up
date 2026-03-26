-- Consolidated schema/bootstrap definitions for 8UP.

-- Merged from 1_db_init.sql, 4_1_add_cancel_inquiry_toggle.sql, 4_2_add_in_app_notifications.sql, 4_3_add_user_action_notifications.sql.



-- Extensions, enum types, tables, columns, indexes, and bootstrap data.

-- Source: 1_db_init.sql

create extension if not exists pgcrypto;
create extension if not exists pg_net;
create extension if not exists supabase_vault cascade;

-- Source: 1_db_init.sql

do $$
begin
  if not exists (select 1 from pg_type where typname = 'studio_status') then
    create type public.studio_status as enum ('active', 'inactive');
  end if;

  if not exists (select 1 from pg_type where typname = 'admin_role') then
    create type public.admin_role as enum ('admin', 'staff');
  end if;

  if not exists (select 1 from pg_type where typname = 'membership_status') then
    create type public.membership_status as enum ('active', 'inactive');
  end if;

  if not exists (select 1 from pg_type where typname = 'record_status') then
    create type public.record_status as enum ('active', 'inactive');
  end if;

  if not exists (select 1 from pg_type where typname = 'class_session_status') then
    create type public.class_session_status as enum ('scheduled', 'cancelled', 'completed');
  end if;

  if not exists (select 1 from pg_type where typname = 'user_pass_status') then
    create type public.user_pass_status as enum ('active', 'exhausted', 'expired', 'refunded', 'inactive');
  end if;

  if not exists (select 1 from pg_type where typname = 'cancel_policy_mode') then
    create type public.cancel_policy_mode as enum ('hours_before', 'days_before_time');
  end if;

  if not exists (select 1 from pg_type where typname = 'reservation_status') then
    create type public.reservation_status as enum (
      'reserved',
      'waitlisted',
      'cancel_requested',
      'cancelled',
      'completed',
      'studio_cancelled',
      'studio_rejected'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'ledger_entry_type') then
    create type public.ledger_entry_type as enum (
      'planned',
      'restored',
      'completed',
      'refund_adjustment',
      'manual_adjustment'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'studio_signup_request_status') then
    create type public.studio_signup_request_status as enum (
      'pending',
      'approved',
      'rejected'
    );
  end if;
end $$;

-- Source: 1_db_init.sql

alter type public.reservation_status
add value if not exists 'studio_rejected';

-- Source: 1_db_init.sql

create table if not exists public.studios (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_phone text,
  address text,
  cancel_policy_mode public.cancel_policy_mode not null default 'hours_before',
  cancel_policy_hours_before integer not null default 24,
  cancel_policy_days_before integer not null default 1,
  cancel_policy_cutoff_time time not null default '18:00',
  status public.studio_status not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Source: 1_db_init.sql

alter table public.studios
add column if not exists cancel_policy_mode public.cancel_policy_mode not null default 'hours_before';

-- Source: 1_db_init.sql

alter table public.studios
add column if not exists cancel_policy_hours_before integer not null default 24;

-- Source: 1_db_init.sql

alter table public.studios
add column if not exists cancel_policy_days_before integer not null default 1;

-- Source: 1_db_init.sql

alter table public.studios
add column if not exists cancel_policy_cutoff_time time not null default '18:00';

-- Source: 1_db_init.sql

create table if not exists public.admin_users (
  id uuid primary key references auth.users (id) on delete cascade,
  studio_id uuid not null references public.studios (id) on delete cascade,
  login_id text not null unique,
  name text,
  email text,
  phone text,
  role public.admin_role not null default 'admin',
  must_change_password boolean not null default true,
  status public.record_status not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Source: 1_db_init.sql

create table if not exists public.platform_admin_users (
  id uuid primary key references auth.users (id) on delete cascade,
  login_id text not null unique,
  name text,
  email text,
  phone text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Source: 1_db_init.sql

create table if not exists public.studio_signup_requests (
  id uuid primary key default gen_random_uuid(),
  studio_name text not null,
  studio_phone text not null,
  studio_address text not null,
  representative_name text not null,
  requested_login_id text not null,
  requested_email text not null,
  password_hash text not null,
  status public.studio_signup_request_status not null default 'pending',
  review_comment text,
  reviewed_at timestamptz,
  reviewed_by_platform_admin_id uuid references public.platform_admin_users (id),
  approved_studio_id uuid references public.studios (id),
  approved_admin_user_id uuid references public.admin_users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Source: 1_db_init.sql

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  member_code varchar(5) not null unique,
  image_url text,
  phone text,
  email text,
  name text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint users_member_code_format check (member_code ~ '^[a-z0-9]{5}$')
);

-- Source: 1_db_init.sql

create table if not exists public.studio_user_memberships (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  membership_status public.membership_status not null default 'active',
  joined_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint studio_user_memberships_unique unique (studio_id, user_id)
);

-- Source: 1_db_init.sql

create table if not exists public.instructors (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  name text not null,
  phone text,
  image_url text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Source: 1_db_init.sql

create table if not exists public.class_templates (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  name text not null,
  category text not null,
  default_instructor_id uuid references public.instructors (id) on delete set null,
  description text,
  day_of_week_mask jsonb not null default '[]'::jsonb,
  start_time time not null,
  end_time time not null,
  capacity integer not null,
  status public.record_status not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint class_templates_capacity_positive check (capacity > 0),
  constraint class_templates_time_order check (start_time < end_time),
  constraint class_templates_day_mask_array check (jsonb_typeof(day_of_week_mask) = 'array')
);

-- Source: 1_db_init.sql

create table if not exists public.pass_products (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  name text not null,
  total_count integer not null,
  valid_days integer not null,
  price_amount numeric(12, 2) not null,
  description text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint pass_products_total_count_positive check (total_count > 0),
  constraint pass_products_valid_days_positive check (valid_days > 0),
  constraint pass_products_price_non_negative check (price_amount >= 0)
);

-- Source: 1_db_init.sql

create table if not exists public.pass_product_template_mappings (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  pass_product_id uuid not null references public.pass_products (id) on delete cascade,
  class_template_id uuid not null references public.class_templates (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  constraint pass_product_template_mappings_unique unique (pass_product_id, class_template_id)
);

-- Source: 1_db_init.sql

create table if not exists public.class_sessions (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  class_template_id uuid not null references public.class_templates (id) on delete cascade,
  instructor_id uuid references public.instructors (id) on delete set null,
  session_date date not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  capacity integer not null,
  status public.class_session_status not null default 'scheduled',
  created_by_admin_id uuid references public.admin_users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint class_sessions_capacity_positive check (capacity > 0),
  constraint class_sessions_time_order check (start_at < end_at)
);

-- Source: 1_db_init.sql

create table if not exists public.user_passes (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  pass_product_id uuid not null references public.pass_products (id) on delete restrict,
  name_snapshot text not null,
  total_count integer not null,
  valid_from date not null,
  valid_until date not null,
  paid_amount numeric(12, 2) not null default 0,
  refunded_amount numeric(12, 2) not null default 0,
  status public.user_pass_status not null default 'active',
  created_by_admin_id uuid references public.admin_users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint user_passes_total_positive check (total_count > 0),
  constraint user_passes_amounts_non_negative check (paid_amount >= 0 and refunded_amount >= 0),
  constraint user_passes_date_range check (valid_from <= valid_until)
);

-- Source: 1_db_init.sql

create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  class_session_id uuid not null references public.class_sessions (id) on delete cascade,
  user_pass_id uuid not null references public.user_passes (id) on delete restrict,
  status public.reservation_status not null,
  request_cancel_reason text,
  requested_cancel_at timestamptz,
  approved_cancel_at timestamptz,
  approved_cancel_by_admin_id uuid references public.admin_users (id),
  is_waitlisted boolean not null default false,
  waitlist_order integer,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint reservations_unique_user_session unique (class_session_id, user_id),
  constraint reservations_waitlist_order_non_negative check (waitlist_order is null or waitlist_order > 0)
);

-- Source: 1_db_init.sql

create table if not exists public.pass_usage_ledger (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  user_pass_id uuid not null references public.user_passes (id) on delete cascade,
  reservation_id uuid references public.reservations (id) on delete set null,
  entry_type public.ledger_entry_type not null,
  count_delta integer not null,
  memo text,
  created_at timestamptz not null default timezone('utc', now())
);

-- Source: 1_db_init.sql

create table if not exists public.notices (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  title text not null,
  body text not null,
  is_important boolean not null default false,
  visible_from timestamptz,
  visible_until timestamptz,
  status public.record_status not null default 'active',
  created_by_admin_id uuid references public.admin_users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Source: 1_db_init.sql

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  title text not null,
  body text not null,
  visible_from timestamptz,
  visible_until timestamptz,
  status public.record_status not null default 'active',
  created_by_admin_id uuid references public.admin_users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Source: 1_db_init.sql

create table if not exists public.refund_logs (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  user_pass_id uuid not null references public.user_passes (id) on delete cascade,
  refund_amount numeric(12, 2) not null,
  refund_reason text,
  refunded_by_admin_id uuid references public.admin_users (id),
  refunded_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint refund_logs_amount_non_negative check (refund_amount >= 0)
);

-- Source: 1_db_init.sql

create table if not exists public.user_pass_holds (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  user_pass_id uuid not null references public.user_passes (id) on delete cascade,
  hold_from date not null,
  hold_until date not null,
  created_by_admin_id uuid references public.admin_users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint user_pass_holds_date_range check (hold_from <= hold_until)
);

-- Source: 1_db_init.sql

create table if not exists public.member_consult_notes (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  consulted_on date not null,
  note text not null,
  created_by_admin_id uuid references public.admin_users (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint member_consult_notes_note_not_blank check (char_length(btrim(note)) > 0)
);

-- Source: 1_db_init.sql

create index if not exists idx_admin_users_studio on public.admin_users (studio_id);

-- Source: 1_db_init.sql

create index if not exists idx_platform_admin_users_login on public.platform_admin_users (login_id);

-- Source: 1_db_init.sql

create index if not exists idx_signup_requests_status on public.studio_signup_requests (status, created_at desc);

-- Source: 1_db_init.sql

create index if not exists idx_signup_requests_login on public.studio_signup_requests (lower(requested_login_id));

-- Source: 1_db_init.sql

create index if not exists idx_signup_requests_email on public.studio_signup_requests (lower(requested_email));

-- Source: 1_db_init.sql

create index if not exists idx_users_member_code on public.users (member_code);

-- Source: 1_db_init.sql

create index if not exists idx_memberships_user on public.studio_user_memberships (user_id, membership_status);

-- Source: 1_db_init.sql

create index if not exists idx_memberships_studio on public.studio_user_memberships (studio_id, membership_status);

-- Source: 1_db_init.sql

create index if not exists idx_instructors_studio_name on public.instructors (studio_id, name);

-- Source: 1_db_init.sql

create unique index if not exists idx_instructors_studio_name_unique on public.instructors (studio_id, lower(name));

-- Source: 1_db_init.sql

create index if not exists idx_class_templates_studio on public.class_templates (studio_id, status);

-- Source: 1_db_init.sql

create index if not exists idx_class_templates_default_instructor on public.class_templates (default_instructor_id);

-- Source: 1_db_init.sql

create index if not exists idx_pass_products_studio on public.pass_products (studio_id, status);

-- Source: 1_db_init.sql

create index if not exists idx_pass_template_mappings_product on public.pass_product_template_mappings (pass_product_id);

-- Source: 1_db_init.sql

create index if not exists idx_pass_template_mappings_template on public.pass_product_template_mappings (class_template_id);

-- Source: 1_db_init.sql

create index if not exists idx_class_sessions_studio_date on public.class_sessions (studio_id, session_date);

-- Source: 1_db_init.sql

create index if not exists idx_class_sessions_template_date on public.class_sessions (class_template_id, session_date);

-- Source: 1_db_init.sql

create index if not exists idx_class_sessions_studio_start on public.class_sessions (studio_id, start_at);

-- Source: 1_db_init.sql

create index if not exists idx_class_sessions_instructor on public.class_sessions (instructor_id, session_date);

-- Source: 1_db_init.sql

create index if not exists idx_user_passes_user on public.user_passes (user_id, studio_id, status, valid_until);

-- Source: 1_db_init.sql

create index if not exists idx_user_pass_holds_pass_dates on public.user_pass_holds (user_pass_id, hold_from, hold_until);

-- Source: 1_db_init.sql

create index if not exists idx_reservations_user_status on public.reservations (user_id, status, created_at desc);

-- Source: 1_db_init.sql

create index if not exists idx_reservations_session_status on public.reservations (class_session_id, status, created_at);

-- Source: 1_db_init.sql

create index if not exists idx_pass_usage_ledger_pass on public.pass_usage_ledger (user_pass_id, created_at desc);

-- Source: 1_db_init.sql

create unique index if not exists idx_pass_usage_ledger_reservation_entry on public.pass_usage_ledger (reservation_id, entry_type);

-- Source: 1_db_init.sql

create index if not exists idx_notices_studio_visible on public.notices (studio_id, visible_from, visible_until);

-- Source: 1_db_init.sql

create index if not exists idx_events_studio_visible on public.events (studio_id, visible_from, visible_until);

-- Source: 1_db_init.sql

create index if not exists idx_member_consult_notes_member on public.member_consult_notes (studio_id, user_id, consulted_on desc, created_at desc);

-- Source: 1_db_init.sql

alter table public.users
add column if not exists login_id text;

-- Source: 1_db_init.sql

create unique index if not exists idx_users_login_id_unique
on public.users (lower(login_id))
where login_id is not null;

-- Source: 1_db_init.sql

alter table public.studios
add column if not exists image_url text;

-- Source: 1_db_init.sql

alter table public.users
add column if not exists image_url text;

-- Source: 1_db_init.sql

alter table public.class_templates
add column if not exists default_instructor_id uuid references public.instructors (id) on delete set null;

-- Source: 1_db_init.sql

alter table public.class_sessions
add column if not exists instructor_id uuid references public.instructors (id) on delete set null;

-- Source: 1_db_init.sql

alter table public.notices
add column if not exists is_published boolean not null default true;

-- Source: 1_db_init.sql

alter table public.events
add column if not exists is_published boolean not null default true;

-- Source: 1_db_init.sql

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'app-images',
  'app-images',
  true,
  5242880,
  array['image/jpeg']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Source: 1_db_init.sql

create index if not exists idx_notices_studio_publish_window
on public.notices (studio_id, status, is_published, visible_from, visible_until);

-- Source: 1_db_init.sql

create index if not exists idx_events_studio_publish_window
on public.events (studio_id, status, is_published, visible_from, visible_until);

-- Source: 1_db_init.sql

alter table public.reservations
add column if not exists approved_cancel_comment text;

-- Source: 1_db_init.sql

alter table public.reservations
add column if not exists cancel_request_response_comment text;

-- Source: 1_db_init.sql

alter table public.reservations
add column if not exists cancel_request_processed_at timestamptz;

-- Source: 1_db_init.sql

alter table public.reservations
add column if not exists cancel_request_processed_by_admin_id uuid references public.admin_users (id);

-- Source: 4_1_add_cancel_inquiry_toggle.sql

alter table public.studios
add column if not exists cancel_inquiry_enabled boolean not null default true;

-- Source: 4_2_add_in_app_notifications.sql

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null references public.studios (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  is_important boolean not null default false,
  is_read boolean not null default false,
  related_entity_type text,
  related_entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists id uuid default gen_random_uuid();

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists studio_id uuid references public.studios (id) on delete cascade;

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists user_id uuid references public.users (id) on delete cascade;

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists kind text;

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists title text;

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists body text;

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists is_important boolean not null default false;

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists is_read boolean not null default false;

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists related_entity_type text;

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists related_entity_id uuid;

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists read_at timestamptz;

-- Source: 4_2_add_in_app_notifications.sql

alter table public.notifications
add column if not exists created_at timestamptz not null default timezone('utc', now());

-- Source: 4_2_add_in_app_notifications.sql

update public.notifications
   set id = gen_random_uuid()
 where id is null;

-- Source: 4_2_add_in_app_notifications.sql

do $$
begin
  if not exists (
    select 1
      from pg_constraint
     where conname = 'notifications_pkey'
       and conrelid = 'public.notifications'::regclass
  ) then
    alter table public.notifications
      add constraint notifications_pkey primary key (id);
  end if;
end $$;

-- Source: 4_2_add_in_app_notifications.sql

create index if not exists notifications_user_studio_created_idx
on public.notifications (user_id, studio_id, created_at desc);

-- Source: 4_2_add_in_app_notifications.sql

create index if not exists notifications_user_unread_idx
on public.notifications (user_id, is_read, created_at desc);

-- Source: push_notifications.sql

create table if not exists public.push_notification_devices (
  id uuid primary key default gen_random_uuid(),
  installation_id text not null unique,
  user_id uuid not null references public.users (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  token text not null,
  push_enabled boolean not null default true,
  disabled_at timestamptz,
  last_registered_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Source: push_notifications.sql

create unique index if not exists push_notification_devices_token_key
on public.push_notification_devices (token);

-- Source: push_notifications.sql

create index if not exists push_notification_devices_user_enabled_idx
on public.push_notification_devices (user_id, push_enabled, updated_at desc);

-- Source: push_notifications.sql

create table if not exists public.notification_push_jobs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null unique references public.notifications (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'skipped', 'failed')),
  attempt_count integer not null default 0,
  last_attempt_at timestamptz,
  processed_at timestamptz,
  last_error text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Source: push_notifications.sql

create index if not exists notification_push_jobs_status_created_idx
on public.notification_push_jobs (status, created_at asc);

-- Source: push_notifications.sql

create table if not exists public.notification_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.notification_push_jobs (id) on delete cascade,
  notification_id uuid not null references public.notifications (id) on delete cascade,
  device_id uuid not null references public.push_notification_devices (id) on delete cascade,
  token_snapshot text not null,
  delivery_status text not null check (delivery_status in ('sent', 'failed', 'invalid', 'skipped')),
  response_code integer,
  response_body jsonb,
  error_message text,
  created_at timestamptz not null default timezone('utc', now())
);

-- Source: push_notifications.sql

create unique index if not exists notification_push_deliveries_notification_device_key
on public.notification_push_deliveries (notification_id, device_id);

-- Source: push_notifications.sql

create index if not exists notification_push_deliveries_job_created_idx
on public.notification_push_deliveries (job_id, created_at desc);

-- Source: 4_2_add_in_app_notifications.sql

alter table public.events
add column if not exists is_important boolean not null default false;
