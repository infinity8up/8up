-- Reset one admin password by login_id or email.
-- Run this in the Supabase SQL editor or with a privileged connection.
--
-- Fill in:
--   v_identifier: admin login_id or email
--   v_temp_password: temporary password to hand over
--
-- Note:
--   admin_users.must_change_password is set to true,
--   but the current admin web does not yet force a password-change screen.
--   After login, the admin should change the password in "스튜디오 정보 수정".

do $$
declare
  v_identifier text := 'seoul_manager';
  v_temp_password text := 'TempPassword123!';
  v_admin_id uuid;
begin
  v_identifier := lower(trim(coalesce(v_identifier, '')));

  if v_identifier = '' then
    raise exception 'identifier is required';
  end if;

  if trim(coalesce(v_temp_password, '')) = '' then
    raise exception 'temporary password is required';
  end if;

  select admin_user.id
    into v_admin_id
    from public.admin_users admin_user
   where lower(admin_user.login_id) = v_identifier
      or lower(coalesce(admin_user.email, '')) = v_identifier
   limit 1;

  if v_admin_id is null then
    raise exception 'admin account not found for %', v_identifier;
  end if;

  update auth.users
     set encrypted_password = crypt(v_temp_password, gen_salt('bf')),
         updated_at = timezone('utc', now())
   where id = v_admin_id;

  update public.admin_users
     set must_change_password = true,
         updated_at = timezone('utc', now())
   where id = v_admin_id;

  raise notice 'Reset password for admin id=% identifier=%',
    v_admin_id,
    v_identifier;
end;
$$;
