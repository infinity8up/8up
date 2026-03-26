-- Create a brand-new studio and its first admin account.
-- Run this in the Supabase SQL editor or with a privileged connection.
--
-- Fill in the values in the declare block, then execute the whole script.
--
-- Information to receive from the requester:
--   - studio name
--   - studio phone
--   - studio address
--   - admin name
--   - admin email
--   - admin phone
--   - desired login_id
--
-- Information decided by you:
--   - temporary password
--   - role ('admin' or 'staff')
--   - must_change_password (usually true)

do $$
declare
  v_studio_name text := 'SE Studio';
  v_studio_phone text := '02-555-0000';
  v_studio_address text := '위례중앙로 216';

  v_admin_login_id text := 'se_admin';
  v_admin_name text := '김성은';
  v_admin_email text := 'sylvie@hanmail.com';
  v_admin_phone text := '010-4677-7777';
  v_admin_password text := 'TempPassword123!';
  v_admin_role public.admin_role := 'admin';
  v_must_change_password boolean := true;

  v_studio_id uuid := gen_random_uuid();
  v_admin_user_id uuid := gen_random_uuid();
  v_admin_identity_id uuid := gen_random_uuid();
begin
  v_studio_name := trim(coalesce(v_studio_name, ''));
  v_studio_phone := trim(coalesce(v_studio_phone, ''));
  v_studio_address := trim(coalesce(v_studio_address, ''));
  v_admin_login_id := lower(trim(coalesce(v_admin_login_id, '')));
  v_admin_name := trim(coalesce(v_admin_name, ''));
  v_admin_email := lower(trim(coalesce(v_admin_email, '')));
  v_admin_phone := trim(coalesce(v_admin_phone, ''));

  if v_studio_name = '' then
    raise exception 'studio name is required';
  end if;

  if v_studio_phone = '' then
    raise exception 'studio phone is required';
  end if;

  if v_studio_address = '' then
    raise exception 'studio address is required';
  end if;

  if v_admin_login_id = '' then
    raise exception 'admin login_id is required';
  end if;

  if v_admin_login_id !~ '^[a-z0-9][a-z0-9._-]{2,31}$' then
    raise exception 'login_id must match ^[a-z0-9][a-z0-9._-]{2,31}$';
  end if;

  if v_admin_name = '' then
    raise exception 'admin name is required';
  end if;

  if v_admin_email = '' or position('@' in v_admin_email) = 0 then
    raise exception 'valid admin email is required';
  end if;

  if trim(coalesce(v_admin_password, '')) = '' then
    raise exception 'admin password is required';
  end if;

  if exists (
    select 1
      from public.studios studio
     where lower(studio.name) = lower(v_studio_name)
  ) then
    raise exception 'studio name % already exists', v_studio_name;
  end if;

  if exists (
    select 1
      from auth.users auth_user
     where lower(auth_user.email) = v_admin_email
  ) then
    raise exception 'admin email % already exists', v_admin_email;
  end if;

  if exists (
    select 1
      from public.admin_users admin_user
     where lower(admin_user.login_id) = v_admin_login_id
  ) then
    raise exception 'admin login_id % already exists', v_admin_login_id;
  end if;

  insert into public.studios (
    id,
    name,
    contact_phone,
    address,
    status
  ) values (
    v_studio_id,
    v_studio_name,
    v_studio_phone,
    v_studio_address,
    'active'
  );

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_admin_user_id,
    'authenticated',
    'authenticated',
    v_admin_email,
    crypt(v_admin_password, gen_salt('bf')),
    timezone('utc', now()),
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'name', v_admin_name,
      'account_type', 'admin'
    ),
    timezone('utc', now()),
    timezone('utc', now()),
    '',
    '',
    '',
    ''
  );

  insert into auth.identities (
    id,
    user_id,
    provider_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  ) values (
    v_admin_identity_id,
    v_admin_user_id,
    v_admin_email,
    jsonb_build_object(
      'sub', v_admin_user_id::text,
      'email', v_admin_email,
      'email_verified', true
    ),
    'email',
    timezone('utc', now()),
    timezone('utc', now()),
    timezone('utc', now())
  );

  insert into public.admin_users (
    id,
    studio_id,
    login_id,
    name,
    email,
    phone,
    role,
    must_change_password,
    status
  ) values (
    v_admin_user_id,
    v_studio_id,
    v_admin_login_id,
    v_admin_name,
    v_admin_email,
    nullif(v_admin_phone, ''),
    v_admin_role,
    v_must_change_password,
    'active'
  );

  raise notice 'Created studio_id=% / admin login_id=% / admin email=%',
    v_studio_id,
    v_admin_login_id,
    v_admin_email;
end;
$$;
