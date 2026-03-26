-- Functions and procedures.


create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;


create or replace function public.calculate_session_cancel_cutoff(
  p_session_date date,
  p_session_start timestamptz,
  p_policy_mode public.cancel_policy_mode,
  p_hours_before integer,
  p_days_before integer,
  p_cutoff_time time
)
returns timestamptz
language sql
immutable
as $$
  select case
    when p_policy_mode = 'days_before_time' then
      (
        ((p_session_date - greatest(coalesce(p_days_before, 1), 0))::timestamp)
        + coalesce(p_cutoff_time, '18:00'::time)
      ) at time zone 'Asia/Seoul'
    else
      p_session_start - make_interval(hours => greatest(coalesce(p_hours_before, 24), 0))
  end;
$$;


create or replace function public.validate_template_default_instructor()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_instructor_studio_id uuid;
begin
  if new.default_instructor_id is null then
    return new;
  end if;

  select instructor.studio_id
    into v_instructor_studio_id
    from public.instructors instructor
   where instructor.id = new.default_instructor_id;

  if v_instructor_studio_id is null then
    raise exception '유효한 강사를 선택하세요';
  end if;

  if v_instructor_studio_id <> new.studio_id then
    raise exception '같은 스튜디오의 강사만 지정할 수 있습니다';
  end if;

  return new;
end;
$$;


create or replace function public.validate_session_instructor()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_instructor_studio_id uuid;
begin
  if new.instructor_id is null then
    return new;
  end if;

  select instructor.studio_id
    into v_instructor_studio_id
    from public.instructors instructor
   where instructor.id = new.instructor_id;

  if v_instructor_studio_id is null then
    raise exception '유효한 강사를 선택하세요';
  end if;

  if v_instructor_studio_id <> new.studio_id then
    raise exception '같은 스튜디오의 강사만 지정할 수 있습니다';
  end if;

  return new;
end;
$$;


create or replace function public.generate_member_code()
returns varchar(5)
language plpgsql
set search_path = public
as $$
declare
  v_candidate text;
begin
  loop
    select string_agg(substr('abcdefghijklmnopqrstuvwxyz0123456789', (floor(random() * 36)::integer) + 1, 1), '')
      into v_candidate
      from generate_series(1, 5);

    exit when not exists (
      select 1
      from public.users
      where member_code = v_candidate
    );
  end loop;

  return v_candidate::varchar(5);
end;
$$;


create or replace function public.apply_member_defaults()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.member_code is null or new.member_code = '' then
    new.member_code = public.generate_member_code();
  end if;

  if new.status is null then
    new.status = 'active';
  end if;

  return new;
end;
$$;


create or replace function public.prevent_member_code_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.member_code <> new.member_code then
    raise exception 'member_code cannot be changed once issued';
  end if;

  return new;
end;
$$;


create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.raw_user_meta_data ->> 'account_type', 'member') in ('admin', 'admin_pending', 'platform_admin') then
    return new;
  end if;

  insert into public.users (
    id,
    email,
    phone,
    name
  ) values (
    new.id,
    new.email,
    new.phone,
    coalesce(new.raw_user_meta_data ->> 'name', split_part(coalesce(new.email, ''), '@', 1))
  )
  on conflict (id) do update
    set email = excluded.email,
        phone = excluded.phone,
        name = coalesce(excluded.name, public.users.name);

  return new;
end;
$$;


create or replace function public.handle_updated_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.raw_user_meta_data ->> 'account_type', old.raw_user_meta_data ->> 'account_type', 'member') in ('admin', 'admin_pending', 'platform_admin') then
    return new;
  end if;

  update public.users
     set email = new.email,
         phone = new.phone,
         name = coalesce(new.raw_user_meta_data ->> 'name', public.users.name)
   where id = new.id;

  return new;
end;
$$;


create or replace function public.is_active_member_of_studio(p_studio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.studio_user_memberships membership
     where membership.studio_id = p_studio_id
       and membership.user_id = auth.uid()
       and membership.membership_status = 'active'
  );
$$;


create or replace function public.is_member_of_studio(p_studio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.studio_user_memberships membership
     where membership.studio_id = p_studio_id
       and membership.user_id = auth.uid()
  );
$$;


create or replace function public.get_user_pass_balance(p_user_pass_id uuid)
returns table (
  planned_count integer,
  completed_count integer,
  remaining_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(count(*) filter (
      where reservation.status in ('reserved', 'studio_rejected')
        and session.start_at > timezone('utc', now())
    ), 0)::integer as planned_count,
    coalesce(count(*) filter (
      where reservation.status = 'completed'
         or (
           reservation.status in ('reserved', 'studio_rejected')
           and session.start_at <= timezone('utc', now())
         )
    ), 0)::integer as completed_count,
    (
      user_pass.total_count
      - coalesce(count(*) filter (
        where reservation.status in ('reserved', 'studio_rejected')
          and session.start_at > timezone('utc', now())
      ), 0)
      - coalesce(count(*) filter (
        where reservation.status = 'completed'
           or (
             reservation.status in ('reserved', 'studio_rejected')
             and session.start_at <= timezone('utc', now())
           )
      ), 0)
    )::integer as remaining_count
  from public.user_passes user_pass
  left join public.reservations reservation
    on reservation.user_pass_id = user_pass.id
  left join public.class_sessions session
    on session.id = reservation.class_session_id
  where user_pass.id = p_user_pass_id
  group by user_pass.id, user_pass.total_count;
$$;


create or replace function public.is_user_pass_held_on(
  p_user_pass_id uuid,
  p_session_date date
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.user_pass_holds hold
     where hold.user_pass_id = p_user_pass_id
       and p_session_date between hold.hold_from and hold.hold_until
  );
$$;


create or replace function public.can_use_pass_for_session(
  p_user_pass_id uuid,
  p_session_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_pass public.user_passes%rowtype;
  v_session public.class_sessions%rowtype;
  v_allowed boolean;
  v_remaining integer;
begin
  select *
    into v_user_pass
    from public.user_passes
   where id = p_user_pass_id;

  if not found then
    return false;
  end if;

  select *
    into v_session
    from public.class_sessions
   where id = p_session_id;

  if not found then
    return false;
  end if;

  if v_user_pass.user_id <> auth.uid() then
    return false;
  end if;

  if v_user_pass.studio_id <> v_session.studio_id then
    return false;
  end if;

  if v_user_pass.status <> 'active' then
    return false;
  end if;

  if v_session.session_date < v_user_pass.valid_from or v_session.session_date > v_user_pass.valid_until then
    return false;
  end if;

  if public.is_user_pass_held_on(v_user_pass.id, v_session.session_date) then
    return false;
  end if;

  select exists (
    select 1
      from public.pass_product_template_mappings mapping
     where mapping.pass_product_id = v_user_pass.pass_product_id
       and mapping.class_template_id = v_session.class_template_id
  )
    into v_allowed;

  if not coalesce(v_allowed, false) then
    return false;
  end if;

  select balance.remaining_count
    into v_remaining
    from public.get_user_pass_balance(p_user_pass_id) balance;

  return coalesce(v_remaining, 0) > 0;
end;
$$;


create or replace function public.promote_next_waitlisted_reservation(p_session_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_candidate public.reservations%rowtype;
begin
  select reservation.*
    into v_candidate
    from public.reservations reservation
   where reservation.class_session_id = p_session_id
     and reservation.status = 'waitlisted'
   order by reservation.waitlist_order asc nulls last, reservation.created_at asc
   limit 1
   for update;

  if not found then
    return null;
  end if;

  if not public.can_use_pass_for_session(v_candidate.user_pass_id, p_session_id) then
    return null;
  end if;

  update public.reservations
     set status = 'reserved',
         is_waitlisted = false,
         waitlist_order = null
   where id = v_candidate.id;

  insert into public.pass_usage_ledger (
    studio_id,
    user_pass_id,
    reservation_id,
    entry_type,
    count_delta,
    memo
  ) values (
    v_candidate.studio_id,
    v_candidate.user_pass_id,
    v_candidate.id,
    'planned',
    -1,
    'Waitlist auto-promotion'
  )
  on conflict (reservation_id, entry_type) do nothing;

  return v_candidate.id;
end;
$$;


create or replace function public.reserve_class_session(
  p_session_id uuid,
  p_user_pass_id uuid
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.class_sessions%rowtype;
  v_user_pass public.user_passes%rowtype;
  v_existing_reservation public.reservations%rowtype;
  v_overlap_exists boolean;
  v_reserved_count integer;
  v_waitlist_order integer;
  v_reservation public.reservations%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
    into v_session
    from public.class_sessions
   where id = p_session_id
   for update;

  if not found then
    raise exception 'Session not found';
  end if;

  if v_session.status <> 'scheduled' then
    raise exception 'Session is not reservable';
  end if;

  if v_session.start_at <= timezone('utc', now()) then
    raise exception 'Session has already started';
  end if;

  if not public.is_active_member_of_studio(v_session.studio_id) then
    raise exception 'You are not a member of this studio';
  end if;

  select reservation.*
    into v_existing_reservation
   from public.reservations reservation
   where reservation.class_session_id = p_session_id
     and reservation.user_id = auth.uid()
   for update;

  if found then
    if v_existing_reservation.status in (
      'reserved',
      'waitlisted',
      'cancel_requested',
      'studio_rejected'
    ) then
      raise exception 'Reservation already exists for this session';
    end if;

    if v_existing_reservation.status = 'completed' then
      raise exception 'Completed reservation already exists for this session';
    end if;

    if v_existing_reservation.status = 'cancelled'
       and v_existing_reservation.approved_cancel_at is null then
      delete from public.reservations
       where id = v_existing_reservation.id;
    else
      raise exception 'Reservation already exists for this session';
    end if;
  end if;

  select exists (
    select 1
      from public.reservations reservation
      join public.class_sessions existing_session
        on existing_session.id = reservation.class_session_id
     where reservation.user_id = auth.uid()
       and reservation.status in (
         'reserved',
         'waitlisted',
         'cancel_requested',
         'studio_rejected'
       )
       and tstzrange(existing_session.start_at, existing_session.end_at, '[)') &&
           tstzrange(v_session.start_at, v_session.end_at, '[)')
  )
    into v_overlap_exists;

  if v_overlap_exists then
    raise exception 'Overlapping reservation already exists';
  end if;

  select *
    into v_user_pass
    from public.user_passes
   where id = p_user_pass_id
   for update;

  if not found then
    raise exception 'Pass not found';
  end if;

  if not public.can_use_pass_for_session(p_user_pass_id, p_session_id) then
    raise exception 'Selected pass cannot reserve this session';
  end if;

  select count(*)
    into v_reserved_count
   from public.reservations reservation
   where reservation.class_session_id = p_session_id
     and reservation.status in (
       'reserved',
       'cancel_requested',
       'studio_rejected'
     );

  if v_reserved_count < v_session.capacity then
    insert into public.reservations (
      studio_id,
      user_id,
      class_session_id,
      user_pass_id,
      status,
      is_waitlisted
    ) values (
      v_session.studio_id,
      auth.uid(),
      p_session_id,
      p_user_pass_id,
      'reserved',
      false
    )
    returning *
      into v_reservation;

    insert into public.pass_usage_ledger (
      studio_id,
      user_pass_id,
      reservation_id,
      entry_type,
      count_delta,
      memo
    ) values (
      v_session.studio_id,
      p_user_pass_id,
      v_reservation.id,
      'planned',
      -1,
      '예약 생성'
    )
    on conflict (reservation_id, entry_type) do nothing;
  else
    select coalesce(max(waitlist_order), 0) + 1
      into v_waitlist_order
      from public.reservations
     where class_session_id = p_session_id
       and status = 'waitlisted';

    insert into public.reservations (
      studio_id,
      user_id,
      class_session_id,
      user_pass_id,
      status,
      is_waitlisted,
      waitlist_order
    ) values (
      v_session.studio_id,
      auth.uid(),
      p_session_id,
      p_user_pass_id,
      'waitlisted',
      true,
      v_waitlist_order
    )
    returning *
      into v_reservation;
  end if;

  return v_reservation;
end;
$$;


create or replace function public.cancel_class_reservation(p_reservation_id uuid)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_session public.class_sessions%rowtype;
  v_studio public.studios%rowtype;
  v_cutoff timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.user_id <> auth.uid() then
    raise exception 'You cannot cancel another member reservation';
  end if;

  select *
    into v_session
    from public.class_sessions
   where id = v_reservation.class_session_id
   for update;

  select *
    into v_studio
    from public.studios
   where id = v_session.studio_id;

  if v_reservation.status = 'waitlisted' then
    update public.reservations
       set status = 'cancelled',
           is_waitlisted = false,
           waitlist_order = null
     where id = v_reservation.id
     returning *
      into v_reservation;

    return v_reservation;
  end if;

  if v_reservation.status <> 'reserved' then
    raise exception 'Only active reservations or waitlisted reservations can be cancelled';
  end if;

  if v_session.start_at <= now() then
    raise exception 'Past sessions cannot be cancelled';
  end if;

  v_cutoff := public.calculate_session_cancel_cutoff(
    v_session.session_date,
    v_session.start_at,
    v_studio.cancel_policy_mode,
    v_studio.cancel_policy_hours_before,
    v_studio.cancel_policy_days_before,
    v_studio.cancel_policy_cutoff_time
  );

  if now() >= v_cutoff then
    raise exception 'Direct cancel is no longer available for this studio policy';
  end if;

  update public.reservations
     set status = 'cancelled'
   where id = v_reservation.id
   returning *
    into v_reservation;

  insert into public.pass_usage_ledger (
    studio_id,
    user_pass_id,
    reservation_id,
    entry_type,
    count_delta,
    memo
  ) values (
    v_reservation.studio_id,
    v_reservation.user_pass_id,
    v_reservation.id,
    'restored',
    1,
    '취소 기한 내 직접 취소'
  )
  on conflict (reservation_id, entry_type) do nothing;

  perform public.promote_next_waitlisted_reservation(v_reservation.class_session_id);

  return v_reservation;
end;
$$;


create or replace function public.request_class_reservation_cancel(
  p_reservation_id uuid,
  p_reason text
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_session public.class_sessions%rowtype;
  v_studio public.studios%rowtype;
  v_cutoff timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.user_id <> auth.uid() then
    raise exception 'You cannot request cancel for another member reservation';
  end if;

  if v_reservation.status <> 'reserved' then
    raise exception 'Only active reservations can be sent to cancel review';
  end if;

  select *
    into v_session
    from public.class_sessions
   where id = v_reservation.class_session_id;

  select *
    into v_studio
    from public.studios
   where id = v_session.studio_id;

  if v_session.start_at <= now() then
    raise exception 'Past sessions cannot be cancelled';
  end if;

  v_cutoff := public.calculate_session_cancel_cutoff(
    v_session.session_date,
    v_session.start_at,
    v_studio.cancel_policy_mode,
    v_studio.cancel_policy_hours_before,
    v_studio.cancel_policy_days_before,
    v_studio.cancel_policy_cutoff_time
  );

  if now() < v_cutoff then
    raise exception 'Direct cancel is still available, request is not needed';
  end if;

  update public.reservations
     set status = 'cancel_requested',
         request_cancel_reason = p_reason,
         requested_cancel_at = timezone('utc', now())
   where id = v_reservation.id
   returning *
    into v_reservation;

  return v_reservation;
end;
$$;


create or replace function public.complete_finished_sessions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_changed integer := 0;
begin
  with finished_reservations as (
    update public.reservations reservation
       set status = 'completed'
     from public.class_sessions session
     where reservation.class_session_id = session.id
       and session.status = 'scheduled'
       and session.end_at < timezone('utc', now())
       and reservation.status in (
         'reserved',
         'cancel_requested',
         'studio_rejected'
       )
    returning reservation.*
  )
  insert into public.pass_usage_ledger (
    studio_id,
    user_pass_id,
    reservation_id,
    entry_type,
    count_delta,
    memo
  )
  select
    reservation.studio_id,
    reservation.user_pass_id,
    reservation.id,
    'completed',
    0,
    'Session completed'
  from finished_reservations reservation
  on conflict (reservation_id, entry_type) do nothing;

  get diagnostics v_changed = row_count;

  update public.class_sessions
     set status = 'completed'
   where status = 'scheduled'
     and end_at < timezone('utc', now());

  return v_changed;
end;
$$;


create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.raw_user_meta_data ->> 'account_type', 'member') in ('admin', 'admin_pending', 'platform_admin') then
    return new;
  end if;

  insert into public.users (
    id,
    member_code,
    login_id,
    email,
    phone,
    name
  ) values (
    new.id,
    nullif(lower(new.raw_user_meta_data ->> 'member_code'), '')::varchar(5),
    nullif(lower(new.raw_user_meta_data ->> 'login_id'), ''),
    new.email,
    new.phone,
    coalesce(new.raw_user_meta_data ->> 'name', split_part(coalesce(new.email, ''), '@', 1))
  )
  on conflict (id) do update
    set email = excluded.email,
        phone = excluded.phone,
        name = coalesce(excluded.name, public.users.name),
        login_id = coalesce(excluded.login_id, public.users.login_id);

  return new;
end;
$$;


create or replace function public.handle_updated_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.raw_user_meta_data ->> 'account_type', old.raw_user_meta_data ->> 'account_type', 'member') in ('admin', 'admin_pending', 'platform_admin') then
    return new;
  end if;

  update public.users
     set email = new.email,
         phone = new.phone,
         name = coalesce(new.raw_user_meta_data ->> 'name', public.users.name),
         login_id = coalesce(
           nullif(lower(new.raw_user_meta_data ->> 'login_id'), ''),
           public.users.login_id
         )
   where id = new.id;

  return new;
end;
$$;


create or replace function public.finalize_confirmed_admin_signup(
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_auth_user auth.users%rowtype;
  v_studio_id uuid;
  v_studio_name text;
  v_studio_phone text;
  v_studio_address text;
  v_login_id text;
  v_admin_name text;
  v_admin_phone text;
  v_admin_role public.admin_role := 'admin';
begin
  if p_user_id is null then
    return;
  end if;

  select *
    into v_auth_user
    from auth.users
   where id = p_user_id;

  if not found then
    return;
  end if;

  if coalesce(v_auth_user.raw_user_meta_data ->> 'account_type', '') <> 'admin_pending' then
    return;
  end if;

  if v_auth_user.email_confirmed_at is null then
    return;
  end if;

  if exists (
    select 1
      from public.admin_users admin_user
     where admin_user.id = v_auth_user.id
  ) then
    return;
  end if;

  v_studio_name := nullif(btrim(v_auth_user.raw_user_meta_data ->> 'studio_name'), '');
  v_studio_phone := nullif(btrim(v_auth_user.raw_user_meta_data ->> 'studio_phone'), '');
  v_studio_address := nullif(btrim(v_auth_user.raw_user_meta_data ->> 'studio_address'), '');
  v_login_id := nullif(lower(btrim(v_auth_user.raw_user_meta_data ->> 'admin_login_id')), '');
  v_admin_name := nullif(btrim(v_auth_user.raw_user_meta_data ->> 'name'), '');
  v_admin_phone := nullif(btrim(v_auth_user.raw_user_meta_data ->> 'admin_phone'), '');

  if lower(coalesce(v_auth_user.raw_user_meta_data ->> 'admin_role', 'admin')) = 'staff' then
    v_admin_role := 'staff';
  end if;

  if v_studio_name is null or v_login_id is null then
    raise exception 'Pending admin signup metadata is incomplete';
  end if;

  if exists (
    select 1
      from public.studios studio
     where lower(studio.name) = lower(v_studio_name)
  ) then
    raise exception 'A studio with the same name already exists';
  end if;

  if exists (
    select 1
      from public.admin_users admin_user
     where lower(admin_user.login_id) = v_login_id
  ) then
    raise exception 'An admin with the same login ID already exists';
  end if;

  delete
    from public.users app_user
   where app_user.id = v_auth_user.id;

  insert into public.studios (
    name,
    contact_phone,
    address
  ) values (
    v_studio_name,
    v_studio_phone,
    v_studio_address
  )
  returning id into v_studio_id;

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
    v_auth_user.id,
    v_studio_id,
    v_login_id,
    coalesce(v_admin_name, split_part(coalesce(v_auth_user.email, ''), '@', 1)),
    lower(v_auth_user.email),
    v_admin_phone,
    v_admin_role,
    false,
    'active'
  );
end;
$$;


create or replace function public.handle_new_admin_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  perform public.finalize_confirmed_admin_signup(new.id);
  return new;
end;
$$;


create or replace function public.handle_confirmed_admin_signup()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if old.email_confirmed_at is not null or new.email_confirmed_at is null then
    return new;
  end if;

  perform public.finalize_confirmed_admin_signup(new.id);
  return new;
end;
$$;


create or replace function public.resolve_sign_in_email(p_identifier text)
returns text
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_identifier text := lower(trim(coalesce(p_identifier, '')));
  v_email text;
begin
  if v_identifier = '' then
    return null;
  end if;

  if position('@' in v_identifier) > 0 then
    return v_identifier;
  end if;

  select auth_user.email
    into v_email
    from public.users app_user
    join auth.users auth_user
      on auth_user.id = app_user.id
   where app_user.login_id = v_identifier
     and app_user.status = 'active'
   limit 1;

  return lower(v_email);
end;
$$;


create or replace function public.generate_temporary_password()
returns text
language sql
volatile
as $$
  select 'Tmp-' || upper(substr(md5(gen_random_uuid()::text || clock_timestamp()::text), 1, 8)) || '!';
$$;


drop function if exists public.resolve_user_password_reset_email(text, text);
drop function if exists public.issue_user_temporary_password(text);
drop function if exists public.issue_user_temporary_password(text, text);


create or replace function public.register_member_account(
  p_name text,
  p_email text,
  p_password text,
  p_login_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_email text := lower(trim(coalesce(p_email, '')));
  v_password text := coalesce(p_password, '');
  v_login_id text := nullif(lower(trim(coalesce(p_login_id, ''))), '');
  v_user_id uuid := gen_random_uuid();
  v_identity_id uuid := gen_random_uuid();
begin
  if v_name = '' then
    raise exception '이름을 입력해 주세요.';
  end if;

  if v_email = '' or position('@' in v_email) = 0 then
    raise exception '올바른 이메일을 입력해 주세요.';
  end if;

  if length(v_password) < 6 then
    raise exception '비밀번호는 6자 이상이어야 합니다.';
  end if;

  if v_login_id is not null and v_login_id !~ '^[a-z0-9][a-z0-9._-]{2,31}$' then
    raise exception '로그인 ID 형식이 올바르지 않습니다.';
  end if;

  if exists (
    select 1
      from auth.users auth_user
     where lower(coalesce(auth_user.email, '')) = v_email
  ) then
    raise exception '이미 사용 중인 이메일입니다.';
  end if;

  if v_login_id is not null and exists (
    select 1
      from public.users app_user
     where lower(coalesce(app_user.login_id, '')) = v_login_id
  ) then
    raise exception '이미 사용 중인 로그인 ID입니다.';
  end if;

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
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
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    extensions.crypt(v_password, extensions.gen_salt('bf')),
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'name', v_name,
      'account_type', 'member'
    ) || case
      when v_login_id is null then '{}'::jsonb
      else jsonb_build_object('login_id', v_login_id)
    end,
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
    v_identity_id,
    v_user_id,
    v_email,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', v_email,
      'email_verified', true
    ),
    'email',
    timezone('utc', now()),
    timezone('utc', now()),
    timezone('utc', now())
  );

  return v_user_id;
end;
$$;


create or replace function public.current_admin_studio_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select admin_user.studio_id
    from public.admin_users admin_user
   where admin_user.id = auth.uid()
     and admin_user.status = 'active'
   limit 1;
$$;


create or replace function public.current_member_code()
returns varchar(5)
language sql
stable
security definer
set search_path = public
as $$
  select app_user.member_code
    from public.users app_user
   where app_user.id = auth.uid()
     and app_user.status = 'active'
   limit 1;
$$;


create or replace function public.is_current_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_admin_studio_id() is not null;
$$;


create or replace function public.is_admin_of_studio(p_studio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_admin_studio_id() = p_studio_id;
$$;


create or replace function public.current_platform_admin_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select platform_admin.id
    from public.platform_admin_users platform_admin
   where platform_admin.id = auth.uid()
     and platform_admin.status = 'active'
   limit 1;
$$;


create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_platform_admin_id() is not null;
$$;


create or replace function public.resolve_admin_sign_in_context(p_identifier text)
returns table (
  email text,
  sign_in_state text,
  account_kind text,
  message text
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_identifier text := lower(trim(coalesce(p_identifier, '')));
begin
  if v_identifier = '' then
    return;
  end if;

  return query
  select
    lower(auth_user.email) as email,
    'active'::text as sign_in_state,
    'platform_admin'::text as account_kind,
    null::text as message
  from public.platform_admin_users platform_admin
  join auth.users auth_user
    on auth_user.id = platform_admin.id
  where (
      lower(platform_admin.login_id) = v_identifier
      or lower(coalesce(auth_user.email, '')) = v_identifier
    )
    and platform_admin.status = 'active'
  limit 1;

  if found then
    return;
  end if;

  return query
  select
    lower(auth_user.email) as email,
    'active'::text as sign_in_state,
    'studio_admin'::text as account_kind,
    null::text as message
  from public.admin_users admin_user
  join auth.users auth_user
    on auth_user.id = admin_user.id
  where (
      lower(admin_user.login_id) = v_identifier
      or lower(coalesce(auth_user.email, '')) = v_identifier
    )
    and admin_user.status = 'active'
  limit 1;

  if found then
    return;
  end if;

  return query
  select
    lower(requested_email) as email,
    request.status::text as sign_in_state,
    'studio_request'::text as account_kind,
    case
      when request.status = 'pending'
        then '8UP 관리자가 등록 진행중입니다.'
      when nullif(btrim(coalesce(request.review_comment, '')), '') is not null
        then request.review_comment
      else '스튜디오 등록 요청이 반려되었습니다.'
    end as message
  from public.studio_signup_requests request
  where (
      lower(request.requested_login_id) = v_identifier
      or lower(request.requested_email) = v_identifier
    )
    and request.status in ('pending', 'rejected')
  order by request.created_at desc
  limit 1;
end;
$$;


create or replace function public.resolve_admin_sign_in_email(p_identifier text)
returns text
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_email text;
begin
  select context.email
    into v_email
    from public.resolve_admin_sign_in_context(p_identifier) context
   where context.sign_in_state = 'active'
   limit 1;

  return lower(v_email);
end;
$$;


drop function if exists public.resolve_admin_password_reset_email(text, text);
drop function if exists public.issue_admin_temporary_password(text);
drop function if exists public.issue_admin_temporary_password(text, text, text, text);


create or replace function public.validate_admin_signup_request(
  p_studio_name text,
  p_login_id text,
  p_email text,
  p_exclude_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_studio_name text := btrim(coalesce(p_studio_name, ''));
  v_login_id text := lower(trim(coalesce(p_login_id, '')));
  v_email text := lower(trim(coalesce(p_email, '')));
begin
  if v_studio_name = '' or v_login_id = '' or v_email = '' then
    raise exception 'Studio name, login ID, and email are required';
  end if;

  if exists (
    select 1
      from public.studios studio
     where lower(studio.name) = lower(v_studio_name)
  ) or exists (
    select 1
      from public.studio_signup_requests request
     where lower(request.studio_name) = lower(v_studio_name)
       and request.status = 'pending'
       and (p_exclude_request_id is null or request.id <> p_exclude_request_id)
  ) or exists (
    select 1
      from auth.users auth_user
     where coalesce(auth_user.raw_user_meta_data ->> 'account_type', '') = 'admin_pending'
       and lower(coalesce(auth_user.raw_user_meta_data ->> 'studio_name', '')) = lower(v_studio_name)
  ) then
    raise exception '이미 등록된 스튜디오명입니다.';
  end if;

  if exists (
    select 1
      from public.admin_users admin_user
     where lower(admin_user.login_id) = v_login_id
  ) or exists (
    select 1
      from public.platform_admin_users platform_admin
     where lower(platform_admin.login_id) = v_login_id
  ) or exists (
    select 1
      from public.studio_signup_requests request
     where lower(request.requested_login_id) = v_login_id
       and request.status = 'pending'
       and (p_exclude_request_id is null or request.id <> p_exclude_request_id)
  ) or exists (
    select 1
      from auth.users auth_user
     where coalesce(auth_user.raw_user_meta_data ->> 'account_type', '') = 'admin_pending'
       and lower(coalesce(auth_user.raw_user_meta_data ->> 'admin_login_id', '')) = v_login_id
  ) then
    raise exception '이미 사용 중인 관리자 로그인 ID입니다.';
  end if;

  if exists (
    select 1
      from auth.users auth_user
     where lower(coalesce(auth_user.email, '')) = v_email
  ) or exists (
    select 1
      from public.platform_admin_users platform_admin
     where lower(coalesce(platform_admin.email, '')) = v_email
  ) or exists (
    select 1
      from public.studio_signup_requests request
     where lower(request.requested_email) = v_email
       and request.status = 'pending'
       and (p_exclude_request_id is null or request.id <> p_exclude_request_id)
  ) then
    raise exception '이미 사용 중인 이메일입니다.';
  end if;
end;
$$;


create or replace function public.validate_admin_signup_request(
  p_studio_name text,
  p_login_id text,
  p_email text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  perform public.validate_admin_signup_request(
    p_studio_name,
    p_login_id,
    p_email,
    null
  );
end;
$$;


create or replace function public.submit_studio_signup_request(
  p_studio_name text,
  p_studio_phone text,
  p_studio_address text,
  p_representative_name text,
  p_requested_login_id text,
  p_requested_email text,
  p_password text
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request_id uuid := gen_random_uuid();
  v_studio_name text := btrim(coalesce(p_studio_name, ''));
  v_studio_phone text := btrim(coalesce(p_studio_phone, ''));
  v_studio_address text := btrim(coalesce(p_studio_address, ''));
  v_representative_name text := btrim(coalesce(p_representative_name, ''));
  v_requested_login_id text := lower(trim(coalesce(p_requested_login_id, '')));
  v_requested_email text := lower(trim(coalesce(p_requested_email, '')));
  v_password text := coalesce(p_password, '');
begin
  perform public.validate_admin_signup_request(
    v_studio_name,
    v_requested_login_id,
    v_requested_email
  );

  if v_studio_phone = '' then
    raise exception '스튜디오 전화번호를 입력해 주세요.';
  end if;

  if v_studio_address = '' then
    raise exception '스튜디오 주소를 입력해 주세요.';
  end if;

  if v_representative_name = '' then
    raise exception '스튜디오 대표를 입력해 주세요.';
  end if;

  if length(v_password) < 6 then
    raise exception '비밀번호는 6자 이상이어야 합니다.';
  end if;

  insert into public.studio_signup_requests (
    id,
    studio_name,
    studio_phone,
    studio_address,
    representative_name,
    requested_login_id,
    requested_email,
    password_hash,
    status
  ) values (
    v_request_id,
    v_studio_name,
    v_studio_phone,
    v_studio_address,
    v_representative_name,
    v_requested_login_id,
    v_requested_email,
    extensions.crypt(v_password, extensions.gen_salt('bf')),
    'pending'
  );

  return v_request_id;
end;
$$;


create or replace function public.approve_studio_signup_request(
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_platform_admin_id uuid := public.current_platform_admin_id();
  v_request public.studio_signup_requests%rowtype;
  v_studio_id uuid := gen_random_uuid();
  v_user_id uuid := gen_random_uuid();
  v_identity_id uuid := gen_random_uuid();
begin
  if v_platform_admin_id is null then
    raise exception '8UP 관리자 권한이 필요합니다.';
  end if;

  select *
    into v_request
    from public.studio_signup_requests request
   where request.id = p_request_id
   for update;

  if not found then
    raise exception '등록 요청을 찾을 수 없습니다.';
  end if;

  if v_request.status <> 'pending' then
    raise exception '이미 처리된 등록 요청입니다.';
  end if;

  perform public.validate_admin_signup_request(
    v_request.studio_name,
    v_request.requested_login_id,
    v_request.requested_email,
    v_request.id
  );

  insert into public.studios (
    id,
    name,
    contact_phone,
    address,
    status
  ) values (
    v_studio_id,
    v_request.studio_name,
    v_request.studio_phone,
    v_request.studio_address,
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
    v_user_id,
    'authenticated',
    'authenticated',
    v_request.requested_email,
    v_request.password_hash,
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'name', v_request.representative_name,
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
    v_identity_id,
    v_user_id,
    v_request.requested_email,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', v_request.requested_email,
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
    role,
    must_change_password,
    status
  ) values (
    v_user_id,
    v_studio_id,
    v_request.requested_login_id,
    v_request.representative_name,
    v_request.requested_email,
    'admin',
    false,
    'active'
  );

  update public.studio_signup_requests
     set status = 'approved',
         reviewed_at = timezone('utc', now()),
         reviewed_by_platform_admin_id = v_platform_admin_id,
         approved_studio_id = v_studio_id,
         approved_admin_user_id = v_user_id
   where id = v_request.id;

  return v_user_id;
end;
$$;


create or replace function public.reject_studio_signup_request(
  p_request_id uuid,
  p_review_comment text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_platform_admin_id uuid := public.current_platform_admin_id();
begin
  if v_platform_admin_id is null then
    raise exception '8UP 관리자 권한이 필요합니다.';
  end if;

  update public.studio_signup_requests request
     set status = 'rejected',
         reviewed_at = timezone('utc', now()),
         reviewed_by_platform_admin_id = v_platform_admin_id,
         review_comment = nullif(btrim(coalesce(p_review_comment, '')), '')
   where request.id = p_request_id
     and request.status = 'pending';

  if not found then
    raise exception '처리 가능한 등록 요청을 찾을 수 없습니다.';
  end if;
end;
$$;


create or replace function public.fetch_pending_studio_signup_requests()
returns table (
  id uuid,
  studio_name text,
  studio_phone text,
  studio_address text,
  representative_name text,
  requested_login_id text,
  requested_email text,
  status text,
  review_comment text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if public.current_platform_admin_id() is null then
    raise exception '8UP 관리자 권한이 필요합니다.';
  end if;

  return query
  select
    request.id,
    request.studio_name,
    request.studio_phone,
    request.studio_address,
    request.representative_name,
    request.requested_login_id,
    request.requested_email,
    request.status::text,
    request.review_comment,
    request.created_at
  from public.studio_signup_requests request
  where request.status = 'pending'
  order by request.created_at asc;
end;
$$;


create or replace function public.fetch_platform_studio_overview()
returns table (
  studio_id uuid,
  studio_name text,
  studio_phone text,
  studio_address text,
  studio_login_id text,
  representative_name text,
  representative_email text,
  template_count integer,
  month_session_count integer,
  instructor_count integer,
  member_count integer,
  issued_pass_count integer,
  month_sales_amount numeric(12, 2)
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_month_start date := date_trunc('month', timezone('Asia/Seoul', now()))::date;
  v_next_month_start date := (date_trunc('month', timezone('Asia/Seoul', now())) + interval '1 month')::date;
begin
  if public.current_platform_admin_id() is null then
    raise exception '8UP 관리자 권한이 필요합니다.';
  end if;

  return query
  with primary_admin as (
    select distinct on (admin_user.studio_id)
      admin_user.studio_id,
      admin_user.login_id,
      admin_user.name,
      admin_user.email
    from public.admin_users admin_user
    where admin_user.status = 'active'
    order by admin_user.studio_id, admin_user.created_at asc
  )
  select
    studio.id,
    studio.name,
    studio.contact_phone,
    studio.address,
    coalesce(primary_admin.login_id, '') as studio_login_id,
    primary_admin.name as representative_name,
    primary_admin.email as representative_email,
    coalesce((
      select count(*)::integer
      from public.class_templates template
      where template.studio_id = studio.id
        and template.status = 'active'
    ), 0) as template_count,
    coalesce((
      select count(*)::integer
      from public.class_sessions session
      where session.studio_id = studio.id
        and session.session_date >= v_month_start
        and session.session_date < v_next_month_start
        and session.status in ('scheduled', 'completed')
    ), 0) as month_session_count,
    coalesce((
      select count(*)::integer
      from public.instructors instructor
      where instructor.studio_id = studio.id
    ), 0) as instructor_count,
    coalesce((
      select count(*)::integer
      from public.studio_user_memberships membership
      where membership.studio_id = studio.id
        and membership.membership_status = 'active'
    ), 0) as member_count,
    coalesce((
      select count(*)::integer
      from public.user_passes user_pass
      where user_pass.studio_id = studio.id
    ), 0) as issued_pass_count,
    coalesce((
      select sum(user_pass.paid_amount)
      from public.user_passes user_pass
      where user_pass.studio_id = studio.id
        and (user_pass.created_at at time zone 'Asia/Seoul')::date >= v_month_start
        and (user_pass.created_at at time zone 'Asia/Seoul')::date < v_next_month_start
    ), 0)::numeric(12, 2) as month_sales_amount
  from public.studios studio
  left join primary_admin
    on primary_admin.studio_id = studio.id
  where studio.status = 'active'
  order by studio.name;
end;
$$;


create or replace function public.register_studio_admin_account(
  p_studio_name text,
  p_studio_phone text,
  p_studio_address text,
  p_admin_name text,
  p_login_id text,
  p_email text,
  p_password text
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_studio_name text := btrim(coalesce(p_studio_name, ''));
  v_studio_phone text := btrim(coalesce(p_studio_phone, ''));
  v_studio_address text := btrim(coalesce(p_studio_address, ''));
  v_admin_name text := btrim(coalesce(p_admin_name, ''));
  v_login_id text := lower(trim(coalesce(p_login_id, '')));
  v_email text := lower(trim(coalesce(p_email, '')));
  v_password text := coalesce(p_password, '');
  v_studio_id uuid := gen_random_uuid();
  v_user_id uuid := gen_random_uuid();
  v_identity_id uuid := gen_random_uuid();
begin
  perform public.validate_admin_signup_request(
    v_studio_name,
    v_login_id,
    v_email
  );

  if v_studio_phone = '' then
    raise exception '스튜디오 전화번호를 입력해 주세요.';
  end if;

  if v_studio_address = '' then
    raise exception '스튜디오 주소를 입력해 주세요.';
  end if;

  if v_admin_name = '' then
    raise exception '관리자 이름을 입력해 주세요.';
  end if;

  if length(v_password) < 6 then
    raise exception '비밀번호는 6자 이상이어야 합니다.';
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
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    extensions.crypt(v_password, extensions.gen_salt('bf')),
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
    v_identity_id,
    v_user_id,
    v_email,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', v_email,
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
    role,
    must_change_password,
    status
  ) values (
    v_user_id,
    v_studio_id,
    v_login_id,
    v_admin_name,
    v_email,
    'admin',
    false,
    'active'
  );

  return v_user_id;
end;
$$;


create or replace function public.find_user_by_member_code(p_member_code text)
returns table (
  id uuid,
  member_code varchar(5),
  name text,
  email text,
  phone text,
  is_active_member boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  return query
  select
    app_user.id,
    app_user.member_code,
    app_user.name,
    app_user.email,
    app_user.phone,
    exists (
      select 1
        from public.studio_user_memberships membership
       where membership.studio_id = v_studio_id
         and membership.user_id = app_user.id
         and membership.membership_status = 'active'
    ) as is_active_member
  from public.users app_user
  where lower(app_user.member_code) = lower(trim(coalesce(p_member_code, '')))
    and app_user.status = 'active'
  limit 1;
end;
$$;


create or replace function public.add_member_to_studio_admin(p_user_id uuid)
returns public.studio_user_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_user public.users%rowtype;
  v_membership public.studio_user_memberships%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_user
    from public.users app_user
   where app_user.id = p_user_id
     and app_user.status = 'active';

  if not found then
    raise exception 'User not found';
  end if;

  insert into public.studio_user_memberships (
    studio_id,
    user_id,
    membership_status,
    joined_at
  ) values (
    v_studio_id,
    v_user.id,
    'active',
    timezone('utc', now())
  )
  on conflict (studio_id, user_id) do update
     set membership_status = 'active',
         joined_at = excluded.joined_at,
         updated_at = timezone('utc', now())
  returning *
    into v_membership;

  return v_membership;
end;
$$;


create or replace function public.create_member_consult_note_admin(
  p_user_id uuid,
  p_consulted_on date,
  p_note text
)
returns public.member_consult_notes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_result public.member_consult_notes%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  if p_consulted_on is null then
    raise exception '상담 날짜를 선택하세요';
  end if;

  if nullif(btrim(coalesce(p_note, '')), '') is null then
    raise exception '상담 내용을 입력하세요';
  end if;

  if not exists (
    select 1
      from public.studio_user_memberships membership
     where membership.studio_id = v_studio_id
       and membership.user_id = p_user_id
  ) then
    raise exception 'Member not found';
  end if;

  insert into public.member_consult_notes (
    studio_id,
    user_id,
    consulted_on,
    note,
    created_by_admin_id
  ) values (
    v_studio_id,
    p_user_id,
    p_consulted_on,
    btrim(p_note),
    auth.uid()
  )
  returning *
    into v_result;

  return v_result;
end;
$$;


create or replace function public.delete_member_consult_note_admin(
  p_note_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  delete
    from public.member_consult_notes consult_note
   where consult_note.id = p_note_id
     and consult_note.studio_id = v_studio_id;

  if not found then
    raise exception 'Consult note not found';
  end if;
end;
$$;


create or replace function public.set_own_membership_status(
  p_membership_id uuid,
  p_membership_status public.membership_status
)
returns public.studio_user_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  v_membership public.studio_user_memberships%rowtype;
begin
  update public.studio_user_memberships membership
     set membership_status = p_membership_status,
         updated_at = timezone('utc', now())
   where membership.id = p_membership_id
     and membership.user_id = auth.uid()
  returning *
    into v_membership;

  if not found then
    raise exception 'Membership not found';
  end if;

  return v_membership;
end;
$$;


create or replace function public.issue_user_pass_admin(
  p_user_id uuid,
  p_pass_product_id uuid,
  p_valid_from date default timezone('Asia/Seoul', now())::date,
  p_paid_amount numeric default null
)
returns public.user_passes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_product public.pass_products%rowtype;
  v_result public.user_passes%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_product
    from public.pass_products
   where id = p_pass_product_id
     and studio_id = v_studio_id
     and status = 'active';

  if not found then
    raise exception 'Pass product not found';
  end if;

  if not exists (
    select 1
      from public.studio_user_memberships membership
     where membership.studio_id = v_studio_id
       and membership.user_id = p_user_id
       and membership.membership_status = 'active'
  ) then
    raise exception 'User is not an active member of this studio';
  end if;

  insert into public.user_passes (
    studio_id,
    user_id,
    pass_product_id,
    name_snapshot,
    total_count,
    valid_from,
    valid_until,
    paid_amount,
    refunded_amount,
    status,
    created_by_admin_id
  ) values (
    v_studio_id,
    p_user_id,
    v_product.id,
    v_product.name,
    v_product.total_count,
    p_valid_from,
    (p_valid_from + greatest(v_product.valid_days - 1, 0)),
    coalesce(p_paid_amount, v_product.price_amount),
    0,
    'active',
    auth.uid()
  )
  returning *
    into v_result;

  return v_result;
end;
$$;


create or replace function public.update_user_pass_admin(
  p_user_pass_id uuid,
  p_total_count integer,
  p_paid_amount numeric,
  p_valid_from date,
  p_valid_until date
)
returns public.user_passes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_user_pass public.user_passes%rowtype;
  v_balance record;
  v_today_local date := timezone('Asia/Seoul', now())::date;
  v_next_status public.user_pass_status;
  v_result public.user_passes%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  if p_total_count is null or p_total_count <= 0 then
    raise exception '총 횟수는 1회 이상이어야 합니다';
  end if;

  if p_paid_amount is null or p_paid_amount < 0 then
    raise exception '결제 금액은 0 이상이어야 합니다';
  end if;

  if p_valid_from is null or p_valid_until is null then
    raise exception '시작일과 종료일을 입력하세요';
  end if;

  if p_valid_until < p_valid_from then
    raise exception '종료일은 시작일보다 빠를 수 없습니다';
  end if;

  select *
    into v_user_pass
    from public.user_passes user_pass
   where user_pass.id = p_user_pass_id
     and user_pass.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '수정할 수강권을 찾을 수 없습니다';
  end if;

  select *
    into v_balance
    from public.get_user_pass_balance(p_user_pass_id);

  if p_total_count < coalesce(v_balance.planned_count, 0) + coalesce(v_balance.completed_count, 0) then
    raise exception '총 횟수는 예정/완료된 수업 수보다 작을 수 없습니다';
  end if;

  v_next_status := case
    when v_user_pass.status = 'refunded' then 'refunded'::public.user_pass_status
    when v_user_pass.status = 'inactive' then 'inactive'::public.user_pass_status
    when p_valid_until < v_today_local then 'expired'::public.user_pass_status
    when p_total_count - coalesce(v_balance.planned_count, 0) - coalesce(v_balance.completed_count, 0) <= 0 then 'exhausted'::public.user_pass_status
    else 'active'::public.user_pass_status
  end;

  update public.user_passes
     set total_count = p_total_count,
         paid_amount = p_paid_amount,
         valid_from = p_valid_from,
         valid_until = p_valid_until,
         status = v_next_status
   where id = v_user_pass.id
   returning *
    into v_result;

  return v_result;
end;
$$;


create or replace function public.refund_user_pass_admin(
  p_user_pass_id uuid,
  p_refund_amount numeric,
  p_refund_reason text default null
)
returns public.user_passes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_user_pass public.user_passes%rowtype;
  v_balance record;
  v_today_local date := timezone('Asia/Seoul', now())::date;
  v_refund_reason text := nullif(btrim(p_refund_reason), '');
  v_effective_valid_from date;
  v_result public.user_passes%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  if p_refund_amount is null or p_refund_amount <= 0 then
    raise exception '환불 금액은 0보다 커야 합니다';
  end if;

  select *
    into v_user_pass
    from public.user_passes user_pass
   where user_pass.id = p_user_pass_id
     and user_pass.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '환불할 수강권을 찾을 수 없습니다';
  end if;

  if v_user_pass.status = 'refunded' or coalesce(v_user_pass.refunded_amount, 0) > 0 then
    raise exception '이미 환불 처리된 수강권입니다';
  end if;

  if p_refund_amount > coalesce(v_user_pass.paid_amount, 0) then
    raise exception '환불 금액은 결제 금액을 초과할 수 없습니다';
  end if;

  select *
    into v_balance
    from public.get_user_pass_balance(p_user_pass_id);

  if coalesce(v_balance.planned_count, 0) > 0 then
    raise exception '예정된 예약이 있는 수강권은 환불 처리할 수 없습니다';
  end if;

  v_effective_valid_from := least(v_user_pass.valid_from, v_today_local);

  update public.user_passes
     set refunded_amount = p_refund_amount,
         valid_from = v_effective_valid_from,
         valid_until = v_today_local,
         status = 'refunded'
   where id = v_user_pass.id
   returning *
    into v_result;

  insert into public.refund_logs (
    studio_id,
    user_pass_id,
    refund_amount,
    refund_reason,
    refunded_by_admin_id,
    refunded_at
  ) values (
    v_result.studio_id,
    v_result.id,
    p_refund_amount,
    v_refund_reason,
    auth.uid(),
    timezone('utc', now())
  );

  return v_result;
end;
$$;


create or replace function public.create_user_pass_hold_admin(
  p_user_pass_id uuid,
  p_hold_from date,
  p_hold_until date
)
returns public.user_passes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_user_pass public.user_passes%rowtype;
  v_hold_days integer;
  v_existing_hold_days integer := 0;
  v_today_local date := timezone('Asia/Seoul', now())::date;
  v_result public.user_passes%rowtype;
  v_existing_hold_id uuid;
  v_base_valid_until date;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  if p_hold_from is null or p_hold_until is null then
    raise exception '홀딩 시작일과 종료일을 선택하세요';
  end if;

  if p_hold_until < p_hold_from then
    raise exception '홀딩 종료일은 시작일보다 빠를 수 없습니다';
  end if;

  select *
    into v_user_pass
    from public.user_passes user_pass
   where user_pass.id = p_user_pass_id
     and user_pass.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '홀딩할 수강권을 찾을 수 없습니다';
  end if;

  if v_user_pass.status <> 'active' then
    raise exception '사용 중인 수강권만 홀딩할 수 있습니다';
  end if;

  select hold.id
    into v_existing_hold_id
    from public.user_pass_holds hold
   where hold.user_pass_id = v_user_pass.id
   order by hold.updated_at desc, hold.created_at desc
   limit 1
   for update;

  select coalesce(sum((hold.hold_until - hold.hold_from + 1)), 0)::integer
    into v_existing_hold_days
    from public.user_pass_holds hold
   where hold.user_pass_id = v_user_pass.id;

  if p_hold_from < v_today_local and v_existing_hold_id is null then
    raise exception '홀딩 시작일은 오늘 또는 이후여야 합니다';
  end if;

  v_base_valid_until := greatest(
    v_user_pass.valid_from,
    v_user_pass.valid_until - v_existing_hold_days
  );

  if p_hold_from < v_user_pass.valid_from or p_hold_until > v_base_valid_until then
    raise exception '홀딩 기간은 현재 수강권 사용 기간 안에서만 선택할 수 있습니다';
  end if;

  if exists (
    select 1
      from public.reservations reservation
      join public.class_sessions session
        on session.id = reservation.class_session_id
     where reservation.user_pass_id = v_user_pass.id
       and reservation.status in (
         'reserved',
         'waitlisted',
         'cancel_requested',
         'studio_rejected'
       )
       and session.session_date between p_hold_from and p_hold_until
  ) then
    raise exception '홀딩 기간 안에 예정된 예약이 있어 먼저 정리해야 합니다';
  end if;

  v_hold_days := (p_hold_until - p_hold_from) + 1;

  if v_existing_hold_id is null then
    insert into public.user_pass_holds (
      studio_id,
      user_id,
      user_pass_id,
      hold_from,
      hold_until,
      created_by_admin_id
    ) values (
      v_user_pass.studio_id,
      v_user_pass.user_id,
      v_user_pass.id,
      p_hold_from,
      p_hold_until,
      auth.uid()
    );
  else
    update public.user_pass_holds
       set hold_from = p_hold_from,
           hold_until = p_hold_until
     where id = v_existing_hold_id;

    delete from public.user_pass_holds
     where user_pass_id = v_user_pass.id
       and id <> v_existing_hold_id;
  end if;

  update public.user_passes
     set valid_until = v_base_valid_until + v_hold_days
   where id = v_user_pass.id
   returning *
    into v_result;

  return v_result;
end;
$$;


create or replace function public.cancel_user_pass_hold_admin(
  p_user_pass_id uuid
)
returns public.user_passes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_user_pass public.user_passes%rowtype;
  v_hold public.user_pass_holds%rowtype;
  v_today_local date := timezone('Asia/Seoul', now())::date;
  v_effective_from date;
  v_days_to_remove integer := 0;
  v_result public.user_passes%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_user_pass
    from public.user_passes user_pass
   where user_pass.id = p_user_pass_id
     and user_pass.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '홀딩을 취소할 수강권을 찾을 수 없습니다';
  end if;

  select *
    into v_hold
    from public.user_pass_holds hold
   where hold.user_pass_id = v_user_pass.id
     and hold.hold_until >= v_today_local
   order by hold.hold_until desc, hold.hold_from desc
   limit 1
   for update;

  if not found then
    raise exception '취소할 홀딩 정보가 없습니다';
  end if;

  v_effective_from := greatest(v_today_local, v_hold.hold_from);
  if v_effective_from <= v_hold.hold_until then
    v_days_to_remove := (v_hold.hold_until - v_effective_from) + 1;
  end if;

  delete from public.user_pass_holds
   where id = v_hold.id;

  update public.user_passes
     set valid_until = greatest(valid_from, valid_until - v_days_to_remove)
   where id = v_user_pass.id
   returning *
    into v_result;

  return v_result;
end;
$$;


create or replace function public.cancel_user_passs_hold_admin(
  p_user_pass_id uuid
)
returns public.user_passes
language sql
security definer
set search_path = public
as $$
  select public.cancel_user_pass_hold_admin(p_user_pass_id);
$$;


create or replace function public.add_member_to_session_admin(
  p_session_id uuid,
  p_member_code text
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_session public.class_sessions%rowtype;
  v_user public.users%rowtype;
  v_user_pass public.user_passes%rowtype;
  v_existing_reservation public.reservations%rowtype;
  v_overlap_exists boolean;
  v_reserved_count integer;
  v_waitlist_order integer;
  v_reservation public.reservations%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_session
    from public.class_sessions session
   where session.id = p_session_id
     and session.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Session not found';
  end if;

  if v_session.status <> 'scheduled' then
    raise exception 'Session is not reservable';
  end if;

  if v_session.start_at <= timezone('utc', now()) then
    raise exception 'Started sessions cannot accept new attendees';
  end if;

  select *
    into v_user
    from public.users app_user
   where lower(app_user.member_code) = lower(trim(coalesce(p_member_code, '')))
     and app_user.status = 'active'
   limit 1;

  if not found then
    raise exception 'Member not found';
  end if;

  if not exists (
    select 1
      from public.studio_user_memberships membership
     where membership.studio_id = v_studio_id
       and membership.user_id = v_user.id
       and membership.membership_status = 'active'
  ) then
    raise exception 'User is not an active member of this studio';
  end if;

  select *
    into v_existing_reservation
    from public.reservations reservation
   where reservation.class_session_id = p_session_id
     and reservation.user_id = v_user.id
   for update;

  if found then
    if v_existing_reservation.status in (
      'reserved',
      'waitlisted',
      'cancel_requested',
      'studio_rejected'
    ) then
      raise exception 'Reservation already exists for this member';
    end if;

    if v_existing_reservation.status = 'completed' then
      raise exception 'Completed reservation already exists for this member';
    end if;

    delete from public.reservations
     where id = v_existing_reservation.id;
  end if;

  select exists (
    select 1
      from public.reservations reservation
      join public.class_sessions existing_session
        on existing_session.id = reservation.class_session_id
     where reservation.user_id = v_user.id
       and reservation.status in (
         'reserved',
         'waitlisted',
         'cancel_requested',
         'studio_rejected'
       )
       and tstzrange(existing_session.start_at, existing_session.end_at, '[)') &&
           tstzrange(v_session.start_at, v_session.end_at, '[)')
  )
    into v_overlap_exists;

  if v_overlap_exists then
    raise exception 'Member already has an overlapping reservation';
  end if;

  select user_pass.*
    into v_user_pass
    from public.user_passes user_pass
   where user_pass.user_id = v_user.id
     and user_pass.studio_id = v_studio_id
     and user_pass.status = 'active'
     and v_session.session_date between user_pass.valid_from and user_pass.valid_until
     and not public.is_user_pass_held_on(user_pass.id, v_session.session_date)
     and exists (
       select 1
         from public.pass_product_template_mappings mapping
        where mapping.pass_product_id = user_pass.pass_product_id
          and mapping.class_template_id = v_session.class_template_id
     )
     and coalesce((
       select balance.remaining_count
         from public.get_user_pass_balance(user_pass.id) balance
     ), 0) > 0
   order by user_pass.valid_until asc, user_pass.created_at asc
   limit 1
   for update;

  if not found then
    raise exception '해당 회원은 사용 가능한 수강권이 없습니다';
  end if;

  select count(*)
    into v_reserved_count
   from public.reservations reservation
   where reservation.class_session_id = p_session_id
     and reservation.status in (
       'reserved',
       'cancel_requested',
       'studio_rejected'
     );

  if v_reserved_count < v_session.capacity then
    insert into public.reservations (
      studio_id,
      user_id,
      class_session_id,
      user_pass_id,
      status,
      is_waitlisted
    ) values (
      v_studio_id,
      v_user.id,
      p_session_id,
      v_user_pass.id,
      'reserved',
      false
    )
    returning *
      into v_reservation;

    insert into public.pass_usage_ledger (
      studio_id,
      user_pass_id,
      reservation_id,
      entry_type,
      count_delta,
      memo
    ) values (
      v_studio_id,
      v_user_pass.id,
      v_reservation.id,
      'planned',
      -1,
      'Admin added member to session'
    )
    on conflict (reservation_id, entry_type) do nothing;
  else
    select coalesce(max(waitlist_order), 0) + 1
      into v_waitlist_order
      from public.reservations
     where class_session_id = p_session_id
       and status = 'waitlisted';

    insert into public.reservations (
      studio_id,
      user_id,
      class_session_id,
      user_pass_id,
      status,
      is_waitlisted,
      waitlist_order
    ) values (
      v_studio_id,
      v_user.id,
      p_session_id,
      v_user_pass.id,
      'waitlisted',
      true,
      v_waitlist_order
    )
    returning *
      into v_reservation;
  end if;

  return v_reservation;
end;
$$;


create or replace function public.remove_member_from_session_admin(
  p_reservation_id uuid,
  p_comment text default null
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_reservation public.reservations%rowtype;
  v_previous_status public.reservation_status;
  v_comment text := nullif(trim(coalesce(p_comment, '')), '');
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  if v_comment is null then
    raise exception '취소 사유를 입력하세요';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
     and reservation.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '예약 정보를 찾을 수 없습니다';
  end if;

  if v_reservation.status not in (
    'reserved',
    'waitlisted',
    'cancel_requested',
    'studio_rejected'
  ) then
    raise exception '이 예약은 스튜디오 취소 처리할 수 없습니다';
  end if;

  v_previous_status := v_reservation.status;

  update public.reservations
     set status = 'studio_cancelled',
         is_waitlisted = false,
         waitlist_order = null,
         approved_cancel_at = timezone('utc', now()),
         approved_cancel_by_admin_id = auth.uid(),
         approved_cancel_comment = v_comment,
         cancel_request_response_comment = case
           when v_reservation.status = 'cancel_requested' then v_comment
           else cancel_request_response_comment
         end,
         cancel_request_processed_at = case
           when v_reservation.status = 'cancel_requested' then timezone('utc', now())
           else cancel_request_processed_at
         end,
         cancel_request_processed_by_admin_id = case
           when v_reservation.status = 'cancel_requested' then auth.uid()
           else cancel_request_processed_by_admin_id
         end
   where id = v_reservation.id
   returning *
    into v_reservation;

  if v_previous_status in ('reserved', 'cancel_requested', 'studio_rejected') then
    insert into public.pass_usage_ledger (
      studio_id,
      user_pass_id,
      reservation_id,
      entry_type,
      count_delta,
      memo
    ) values (
      v_reservation.studio_id,
      v_reservation.user_pass_id,
      v_reservation.id,
      'restored',
      1,
      'Admin removed member from session'
    )
    on conflict (reservation_id, entry_type) do nothing;

    perform public.promote_next_waitlisted_reservation(v_reservation.class_session_id);
  end if;

  return v_reservation;
end;
$$;


create or replace function public.create_class_session_from_template_admin(
  p_class_template_id uuid,
  p_session_date date,
  p_capacity integer default null
)
returns public.class_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_template public.class_templates%rowtype;
  v_result public.class_sessions%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_template
    from public.class_templates
   where id = p_class_template_id
     and studio_id = v_studio_id
     and status = 'active';

  if not found then
    raise exception 'Class template not found';
  end if;

  if exists (
    select 1
      from public.class_sessions session
     where session.studio_id = v_studio_id
       and session.class_template_id = p_class_template_id
       and session.session_date = p_session_date
  ) then
    raise exception 'Session already exists for this template and date';
  end if;

  insert into public.class_sessions (
    studio_id,
    class_template_id,
    instructor_id,
    session_date,
    start_at,
    end_at,
    capacity,
    status,
    created_by_admin_id
  ) values (
    v_studio_id,
    p_class_template_id,
    v_template.default_instructor_id,
    p_session_date,
    (p_session_date::timestamp + v_template.start_time) at time zone 'Asia/Seoul',
    (p_session_date::timestamp + v_template.end_time) at time zone 'Asia/Seoul',
    coalesce(p_capacity, v_template.capacity),
    'scheduled',
    auth.uid()
  )
  returning *
    into v_result;

  return v_result;
end;
$$;


create or replace function public.create_class_sessions_from_template_admin(
  p_class_template_id uuid,
  p_start_date date,
  p_end_date date,
  p_capacity integer default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_template public.class_templates%rowtype;
  v_inserted_count integer := 0;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  if p_start_date is null or p_end_date is null then
    raise exception 'Start date and end date are required';
  end if;

  if p_end_date < p_start_date then
    raise exception 'End date must be on or after start date';
  end if;

  select *
    into v_template
    from public.class_templates
   where id = p_class_template_id
     and studio_id = v_studio_id
     and status = 'active';

  if not found then
    raise exception 'Class template not found';
  end if;

  with candidate_dates as (
    select generate_series(p_start_date, p_end_date, interval '1 day')::date as session_date
  ),
  matched_dates as (
    select candidate.session_date
      from candidate_dates candidate
     where exists (
       select 1
         from jsonb_array_elements_text(v_template.day_of_week_mask) as weekday(code)
        where case weekday.code
          when 'mon' then 1
          when 'tue' then 2
          when 'wed' then 3
          when 'thu' then 4
          when 'fri' then 5
          when 'sat' then 6
          when 'sun' then 7
          else null
        end = extract(isodow from candidate.session_date)::integer
     )
  )
  insert into public.class_sessions (
    studio_id,
    class_template_id,
    instructor_id,
    session_date,
    start_at,
    end_at,
    capacity,
    status,
    created_by_admin_id
  )
  select
    v_studio_id,
    p_class_template_id,
    v_template.default_instructor_id,
    matched.session_date,
    (matched.session_date::timestamp + v_template.start_time) at time zone 'Asia/Seoul',
    (matched.session_date::timestamp + v_template.end_time) at time zone 'Asia/Seoul',
    coalesce(p_capacity, v_template.capacity),
    'scheduled',
    auth.uid()
  from matched_dates matched
  where not exists (
    select 1
      from public.class_sessions session
     where session.studio_id = v_studio_id
       and session.class_template_id = p_class_template_id
       and session.session_date = matched.session_date
  );

  get diagnostics v_inserted_count = row_count;

  return v_inserted_count;
end;
$$;


create or replace function public.create_one_off_class_session_admin(
  p_name text,
  p_description text default null,
  p_session_date date default null,
  p_start_time time default null,
  p_end_time time default null,
  p_capacity integer default null,
  p_pass_product_ids uuid[] default null,
  p_instructor_id uuid default null
)
returns public.class_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_template_id uuid;
  v_result public.class_sessions%rowtype;
  v_weekday_code text;
  v_pass_product_ids uuid[];
  v_valid_product_count integer := 0;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  if nullif(trim(coalesce(p_name, '')), '') is null then
    raise exception '수업명을 입력하세요';
  end if;

  if p_session_date is null then
    raise exception '날짜를 선택하세요';
  end if;

  if p_start_time is null or p_end_time is null then
    raise exception '시작 시간과 종료 시간을 입력하세요';
  end if;

  if p_end_time <= p_start_time then
    raise exception '종료 시간은 시작 시간보다 늦어야 합니다';
  end if;

  if p_capacity is null or p_capacity <= 0 then
    raise exception '정원은 1명 이상이어야 합니다';
  end if;

  select coalesce(array_agg(distinct product_id), '{}'::uuid[])
    into v_pass_product_ids
    from unnest(coalesce(p_pass_product_ids, '{}'::uuid[])) as product_id;

  if coalesce(array_length(v_pass_product_ids, 1), 0) = 0 then
    raise exception '수강권 상품을 한 개 이상 선택하세요';
  end if;

  select count(*)
    into v_valid_product_count
    from public.pass_products product
   where product.studio_id = v_studio_id
     and product.id = any(v_pass_product_ids);

  if v_valid_product_count <> array_length(v_pass_product_ids, 1) then
    raise exception '유효하지 않은 수강권 상품이 포함되어 있습니다';
  end if;

  v_weekday_code := case extract(isodow from p_session_date)::integer
    when 1 then 'mon'
    when 2 then 'tue'
    when 3 then 'wed'
    when 4 then 'thu'
    when 5 then 'fri'
    when 6 then 'sat'
    else 'sun'
  end;

  insert into public.class_templates (
    studio_id,
    name,
    category,
    default_instructor_id,
    description,
    day_of_week_mask,
    start_time,
    end_time,
    capacity,
    status
  ) values (
    v_studio_id,
    trim(p_name),
    '일회성',
    p_instructor_id,
    nullif(trim(coalesce(p_description, '')), ''),
    jsonb_build_array(v_weekday_code),
    p_start_time,
    p_end_time,
    p_capacity,
    'active'
  )
  returning id
    into v_template_id;

  insert into public.pass_product_template_mappings (
    studio_id,
    pass_product_id,
    class_template_id
  )
  select
    v_studio_id,
    pass_product_id,
    v_template_id
  from unnest(v_pass_product_ids) as pass_product_id;

  insert into public.class_sessions (
    studio_id,
    class_template_id,
    instructor_id,
    session_date,
    start_at,
    end_at,
    capacity,
    status,
    created_by_admin_id
  ) values (
    v_studio_id,
    v_template_id,
    p_instructor_id,
    p_session_date,
    (p_session_date::timestamp + p_start_time) at time zone 'Asia/Seoul',
    (p_session_date::timestamp + p_end_time) at time zone 'Asia/Seoul',
    p_capacity,
    'scheduled',
    auth.uid()
  )
  returning *
    into v_result;

  return v_result;
end;
$$;


create or replace function public.delete_class_session_admin(
  p_session_id uuid
)
returns public.class_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_session public.class_sessions%rowtype;
  v_has_reservations boolean := false;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_session
    from public.class_sessions session
   where session.id = p_session_id
     and session.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '수업 정보를 찾을 수 없습니다';
  end if;

  if v_session.status = 'completed' then
    raise exception '완료된 수업은 삭제할 수 없습니다';
  end if;

  select exists(
    select 1
      from public.reservations reservation
     where reservation.class_session_id = v_session.id
  )
    into v_has_reservations;

  if v_has_reservations then
    raise exception '예약 내역이 있는 수업은 삭제할 수 없습니다';
  end if;

  delete from public.class_sessions
   where id = v_session.id;

  delete from public.class_templates template
   where template.id = v_session.class_template_id
     and template.studio_id = v_studio_id
     and template.category = '일회성'
     and not exists (
       select 1
         from public.class_sessions remaining_session
        where remaining_session.class_template_id = template.id
     );

  return v_session;
end;
$$;


create or replace function public.cancel_class_session_admin(
  p_session_id uuid
)
returns public.class_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_session public.class_sessions%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_session
    from public.class_sessions session
   where session.id = p_session_id
     and session.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Session not found';
  end if;

  if v_session.status = 'completed' then
    raise exception 'Completed session cannot be cancelled';
  end if;

  if v_session.status = 'cancelled' then
    return v_session;
  end if;

  insert into public.pass_usage_ledger (
    studio_id,
    user_pass_id,
    reservation_id,
    entry_type,
    count_delta,
    memo
  )
  select
    reservation.studio_id,
    reservation.user_pass_id,
    reservation.id,
    'restored',
    1,
    'Studio cancelled class session'
  from public.reservations reservation
  where reservation.class_session_id = v_session.id
    and reservation.status in (
      'reserved',
      'cancel_requested',
      'studio_rejected'
    )
  on conflict (reservation_id, entry_type) do nothing;

   update public.reservations
      set status = 'studio_cancelled',
         is_waitlisted = false,
         waitlist_order = null
   where class_session_id = v_session.id
     and status in (
       'reserved',
       'waitlisted',
       'cancel_requested',
       'studio_rejected'
     );

  update public.class_sessions
     set status = 'cancelled'
   where id = v_session.id
   returning *
    into v_session;

  return v_session;
end;
$$;


create or replace function public.approve_reservation_cancel_request_admin(
  p_reservation_id uuid,
  p_comment text default null
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_reservation public.reservations%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
     and reservation.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'cancel_requested' then
    raise exception 'Reservation is not awaiting cancel approval';
  end if;

  update public.reservations
     set status = 'cancelled',
         approved_cancel_at = timezone('utc', now()),
         approved_cancel_by_admin_id = auth.uid(),
         approved_cancel_comment = nullif(trim(coalesce(p_comment, '')), ''),
         cancel_request_response_comment = nullif(trim(coalesce(p_comment, '')), ''),
         cancel_request_processed_at = timezone('utc', now()),
         cancel_request_processed_by_admin_id = auth.uid()
   where id = v_reservation.id
   returning *
    into v_reservation;

  insert into public.pass_usage_ledger (
    studio_id,
    user_pass_id,
    reservation_id,
    entry_type,
    count_delta,
    memo
  ) values (
    v_reservation.studio_id,
    v_reservation.user_pass_id,
    v_reservation.id,
    'restored',
    1,
    coalesce(nullif(trim(coalesce(p_comment, '')), ''), '관리자 취소 승인')
  )
  on conflict (reservation_id, entry_type) do nothing;

  perform public.promote_next_waitlisted_reservation(v_reservation.class_session_id);

  return v_reservation;
end;
$$;


create or replace function public.reject_reservation_cancel_request_admin(
  p_reservation_id uuid,
  p_comment text
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_reservation public.reservations%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
     and reservation.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'cancel_requested' then
    raise exception 'Reservation is not awaiting cancel approval';
  end if;

  update public.reservations
     set status = 'studio_rejected',
         cancel_request_response_comment = nullif(trim(coalesce(p_comment, '')), ''),
         cancel_request_processed_at = timezone('utc', now()),
         cancel_request_processed_by_admin_id = auth.uid()
   where id = v_reservation.id
   returning *
    into v_reservation;

  return v_reservation;
end;
$$;


create or replace function public.request_class_reservation_cancel(
  p_reservation_id uuid,
  p_reason text
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_session public.class_sessions%rowtype;
  v_studio public.studios%rowtype;
  v_cutoff timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.user_id <> auth.uid() then
    raise exception 'You cannot request cancel for another member reservation';
  end if;

  if v_reservation.status <> 'reserved' then
    raise exception 'Only active reservations can be sent to cancel review';
  end if;

  select *
    into v_session
    from public.class_sessions
   where id = v_reservation.class_session_id;

  select *
    into v_studio
    from public.studios
   where id = v_session.studio_id;

  if v_session.start_at <= now() then
    raise exception 'Past sessions cannot be cancelled';
  end if;

  v_cutoff := public.calculate_session_cancel_cutoff(
    v_session.session_date,
    v_session.start_at,
    v_studio.cancel_policy_mode,
    v_studio.cancel_policy_hours_before,
    v_studio.cancel_policy_days_before,
    v_studio.cancel_policy_cutoff_time
  );

  if now() < v_cutoff then
    raise exception 'Direct cancel is still available, request is not needed';
  end if;

  if not v_studio.cancel_inquiry_enabled then
    raise exception '취소 정책 불가 기간입니다. 스튜디오에 직접 문의하세요.';
  end if;

  update public.reservations
     set status = 'cancel_requested',
         request_cancel_reason = p_reason,
         requested_cancel_at = timezone('utc', now())
   where id = v_reservation.id
   returning *
    into v_reservation;

  return v_reservation;
end;
$$;


create or replace function public.create_studio_notifications(
  p_studio_id uuid,
  p_kind text,
  p_title text,
  p_body text,
  p_is_important boolean default false,
  p_related_entity_type text default null,
  p_related_entity_id uuid default null,
  p_user_ids uuid[] default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer := 0;
begin
  insert into public.notifications (
    studio_id,
    user_id,
    kind,
    title,
    body,
    is_important,
    related_entity_type,
    related_entity_id
  )
  select
    p_studio_id,
    membership.user_id,
    coalesce(nullif(trim(p_kind), ''), 'general'),
    coalesce(nullif(trim(p_title), ''), '알림'),
    coalesce(nullif(trim(p_body), ''), '새 알림이 도착했습니다.'),
    coalesce(p_is_important, false),
    nullif(trim(coalesce(p_related_entity_type, '')), ''),
    p_related_entity_id
  from public.studio_user_memberships membership
  where membership.studio_id = p_studio_id
    and membership.membership_status = 'active'
    and (p_user_ids is null or membership.user_id = any(p_user_ids))
  group by membership.user_id;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;


create or replace function public.handle_notice_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'active' or not coalesce(new.is_published, true) then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and coalesce(old.status, 'inactive') = 'active'
     and coalesce(old.is_published, false) then
    return new;
  end if;

  perform public.create_studio_notifications(
    p_studio_id => new.studio_id,
    p_kind => 'notice',
    p_title => new.title,
    p_body => new.body,
    p_is_important => coalesce(new.is_important, false),
    p_related_entity_type => 'notice',
    p_related_entity_id => new.id
  );

  return new;
end;
$$;


create or replace function public.handle_event_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'active' or not coalesce(new.is_published, true) then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and coalesce(old.status, 'inactive') = 'active'
     and coalesce(old.is_published, false) then
    return new;
  end if;

  perform public.create_studio_notifications(
    p_studio_id => new.studio_id,
    p_kind => 'event',
    p_title => new.title,
    p_body => new.body,
    p_is_important => coalesce(new.is_important, false),
    p_related_entity_type => 'event',
    p_related_entity_id => new.id
  );

  return new;
end;
$$;


create or replace function public.assign_session_instructor_admin(
  p_session_id uuid,
  p_instructor_id uuid default null
)
returns public.class_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_session public.class_sessions%rowtype;
  v_result public.class_sessions%rowtype;
  v_class_name text;
  v_old_instructor_name text := '강사 미정';
  v_new_instructor_name text := '강사 미정';
  v_target_user_ids uuid[];
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_session
    from public.class_sessions session
   where session.id = p_session_id
     and session.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '수업 정보를 찾을 수 없습니다';
  end if;

  if v_session.instructor_id is not distinct from p_instructor_id then
    return v_session;
  end if;

  if v_session.instructor_id is not null then
    select instructor.name
      into v_old_instructor_name
      from public.instructors instructor
     where instructor.id = v_session.instructor_id;
    v_old_instructor_name := coalesce(v_old_instructor_name, '강사 미정');
  end if;

  if p_instructor_id is not null then
    select instructor.name
      into v_new_instructor_name
      from public.instructors instructor
     where instructor.id = p_instructor_id
       and instructor.studio_id = v_studio_id;

    if not found then
      raise exception '강사 정보를 찾을 수 없습니다';
    end if;
  end if;

  select template.name
    into v_class_name
    from public.class_templates template
   where template.id = v_session.class_template_id;

  select coalesce(array_agg(distinct reservation.user_id), '{}'::uuid[])
    into v_target_user_ids
    from public.reservations reservation
   where reservation.class_session_id = v_session.id
     and reservation.status in (
       'reserved',
       'waitlisted',
       'cancel_requested',
       'studio_rejected'
     );

  update public.class_sessions
     set instructor_id = p_instructor_id
   where id = v_session.id
   returning *
    into v_result;

  if coalesce(array_length(v_target_user_ids, 1), 0) > 0 then
    perform public.create_studio_notifications(
      p_studio_id => v_studio_id,
      p_kind => 'session_instructor_changed',
      p_title => '강사 변경 안내',
      p_body => format(
        '%s %s 수업 강사가 %s에서 %s로 변경되었습니다.',
        to_char(
          timezone('Asia/Seoul', v_result.start_at),
          'FMMM"월" FMDD"일" HH24:MI'
        ),
        coalesce(v_class_name, '수업'),
        coalesce(v_old_instructor_name, '강사 미정'),
        coalesce(v_new_instructor_name, '강사 미정')
      ),
      p_is_important => true,
      p_related_entity_type => 'class_session',
      p_related_entity_id => v_result.id,
      p_user_ids => v_target_user_ids
    );
  end if;

  return v_result;
end;
$$;


create or replace function public.cancel_class_session_admin(
  p_session_id uuid
)
returns public.class_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_session public.class_sessions%rowtype;
  v_class_name text;
  v_target_user_ids uuid[];
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_session
    from public.class_sessions session
   where session.id = p_session_id
     and session.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Session not found';
  end if;

  if v_session.status = 'completed' then
    raise exception 'Completed session cannot be cancelled';
  end if;

  if v_session.status = 'cancelled' then
    return v_session;
  end if;

  select template.name
    into v_class_name
    from public.class_templates template
   where template.id = v_session.class_template_id;

  select coalesce(array_agg(distinct reservation.user_id), '{}'::uuid[])
    into v_target_user_ids
    from public.reservations reservation
   where reservation.class_session_id = v_session.id
     and reservation.status in (
       'reserved',
       'waitlisted',
       'cancel_requested',
       'studio_rejected'
     );

  insert into public.pass_usage_ledger (
    studio_id,
    user_pass_id,
    reservation_id,
    entry_type,
    count_delta,
    memo
  )
  select
    reservation.studio_id,
    reservation.user_pass_id,
    reservation.id,
    'restored',
    1,
    'Studio cancelled class session'
  from public.reservations reservation
  where reservation.class_session_id = v_session.id
    and reservation.status in (
      'reserved',
      'cancel_requested',
      'studio_rejected'
    )
  on conflict (reservation_id, entry_type) do nothing;

  update public.reservations
     set status = 'studio_cancelled',
         is_waitlisted = false,
         waitlist_order = null
   where class_session_id = v_session.id
     and status in (
       'reserved',
       'waitlisted',
       'cancel_requested',
       'studio_rejected'
     );

  update public.class_sessions
     set status = 'cancelled'
   where id = v_session.id
   returning *
    into v_session;

  if coalesce(array_length(v_target_user_ids, 1), 0) > 0 then
    perform public.create_studio_notifications(
      p_studio_id => v_studio_id,
      p_kind => 'session_cancelled',
      p_title => '수업 취소 안내',
      p_body => format(
        '%s %s 수업이 스튜디오 사정으로 취소되었습니다.',
        to_char(
          timezone('Asia/Seoul', v_session.start_at),
          'FMMM"월" FMDD"일" HH24:MI'
        ),
        coalesce(v_class_name, '수업')
      ),
      p_is_important => true,
      p_related_entity_type => 'class_session',
      p_related_entity_id => v_session.id,
      p_user_ids => v_target_user_ids
    );
  end if;

  return v_session;
end;
$$;


create or replace function public.approve_reservation_cancel_request_admin(
  p_reservation_id uuid,
  p_comment text default null
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_reservation public.reservations%rowtype;
  v_class_name text;
  v_session_start timestamptz;
  v_comment text := nullif(trim(coalesce(p_comment, '')), '');
  v_body text;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
     and reservation.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'cancel_requested' then
    raise exception 'Reservation is not awaiting cancel approval';
  end if;

  select template.name, session.start_at
    into v_class_name, v_session_start
    from public.class_sessions session
    join public.class_templates template
      on template.id = session.class_template_id
   where session.id = v_reservation.class_session_id;

  update public.reservations
     set status = 'cancelled',
         approved_cancel_at = timezone('utc', now()),
         approved_cancel_by_admin_id = auth.uid(),
         approved_cancel_comment = v_comment,
         cancel_request_response_comment = v_comment,
         cancel_request_processed_at = timezone('utc', now()),
         cancel_request_processed_by_admin_id = auth.uid()
   where id = v_reservation.id
   returning *
    into v_reservation;

  insert into public.pass_usage_ledger (
    studio_id,
    user_pass_id,
    reservation_id,
    entry_type,
    count_delta,
    memo
  ) values (
    v_reservation.studio_id,
    v_reservation.user_pass_id,
    v_reservation.id,
    'restored',
    1,
    coalesce(v_comment, '관리자 취소 승인')
  )
  on conflict (reservation_id, entry_type) do nothing;

  perform public.promote_next_waitlisted_reservation(v_reservation.class_session_id);

  v_body := format(
    '%s %s 수업 취소 요청이 승인되었습니다.',
    to_char(
      timezone('Asia/Seoul', v_session_start),
      'FMMM"월" FMDD"일" HH24:MI'
    ),
    coalesce(v_class_name, '수업')
  );

  if v_comment is not null then
    v_body := format('%s 관리자 메모: %s', v_body, v_comment);
  end if;

  perform public.create_studio_notifications(
    p_studio_id => v_reservation.studio_id,
    p_kind => 'cancel_request_approved',
    p_title => '취소 요청 승인',
    p_body => v_body,
    p_is_important => false,
    p_related_entity_type => 'reservation',
    p_related_entity_id => v_reservation.id,
    p_user_ids => array[v_reservation.user_id]
  );

  return v_reservation;
end;
$$;


create or replace function public.reject_reservation_cancel_request_admin(
  p_reservation_id uuid,
  p_comment text
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_reservation public.reservations%rowtype;
  v_class_name text;
  v_session_start timestamptz;
  v_comment text := nullif(trim(coalesce(p_comment, '')), '');
  v_body text;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
     and reservation.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'cancel_requested' then
    raise exception 'Reservation is not awaiting cancel approval';
  end if;

  select template.name, session.start_at
    into v_class_name, v_session_start
    from public.class_sessions session
    join public.class_templates template
      on template.id = session.class_template_id
   where session.id = v_reservation.class_session_id;

  update public.reservations
     set status = 'studio_rejected',
         cancel_request_response_comment = v_comment,
         cancel_request_processed_at = timezone('utc', now()),
         cancel_request_processed_by_admin_id = auth.uid()
   where id = v_reservation.id
   returning *
    into v_reservation;

  v_body := format(
    '%s %s 수업 취소 요청이 거절되었습니다.',
    to_char(
      timezone('Asia/Seoul', v_session_start),
      'FMMM"월" FMDD"일" HH24:MI'
    ),
    coalesce(v_class_name, '수업')
  );

  if v_comment is not null then
    v_body := format('%s 관리자 메모: %s', v_body, v_comment);
  end if;

  perform public.create_studio_notifications(
    p_studio_id => v_reservation.studio_id,
    p_kind => 'cancel_request_rejected',
    p_title => '취소 요청 거절',
    p_body => v_body,
    p_is_important => false,
    p_related_entity_type => 'reservation',
    p_related_entity_id => v_reservation.id,
    p_user_ids => array[v_reservation.user_id]
  );

  return v_reservation;
end;
$$;


create or replace function public.create_user_notification(
  p_studio_id uuid,
  p_user_id uuid,
  p_kind text,
  p_title text,
  p_body text,
  p_is_important boolean default false,
  p_related_entity_type text default null,
  p_related_entity_id uuid default null,
  p_skip_if_exists boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_kind text := coalesce(nullif(trim(p_kind), ''), 'general');
  v_title text := coalesce(nullif(trim(p_title), ''), '알림');
  v_body text := coalesce(nullif(trim(p_body), ''), '새 알림이 도착했습니다.');
  v_related_entity_type text := nullif(trim(coalesce(p_related_entity_type, '')), '');
  v_notification_id uuid;
begin
  if p_studio_id is null or p_user_id is null then
    return null;
  end if;

  if coalesce(p_skip_if_exists, false) and exists (
    select 1
      from public.notifications notification
     where notification.studio_id = p_studio_id
       and notification.user_id = p_user_id
       and notification.kind = v_kind
       and notification.related_entity_type is not distinct from v_related_entity_type
       and notification.related_entity_id is not distinct from p_related_entity_id
  ) then
    return null;
  end if;

  insert into public.notifications (
    studio_id,
    user_id,
    kind,
    title,
    body,
    is_important,
    related_entity_type,
    related_entity_id
  ) values (
    p_studio_id,
    p_user_id,
    v_kind,
    v_title,
    v_body,
    coalesce(p_is_important, false),
    v_related_entity_type,
    p_related_entity_id
  )
  returning id
    into v_notification_id;

  return v_notification_id;
end;
$$;


create or replace function public.upsert_push_notification_device(
  p_installation_id text,
  p_token text,
  p_platform text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_installation_id text := nullif(trim(coalesce(p_installation_id, '')), '');
  v_token text := nullif(trim(coalesce(p_token, '')), '');
  v_platform text := lower(trim(coalesce(p_platform, '')));
  v_device_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if v_installation_id is null then
    raise exception 'Installation id is required';
  end if;

  if v_token is null then
    raise exception 'Push token is required';
  end if;

  if v_platform not in ('android', 'ios') then
    raise exception 'Unsupported push platform';
  end if;

  delete from public.push_notification_devices
   where token = v_token
     and installation_id <> v_installation_id;

  insert into public.push_notification_devices (
    installation_id,
    user_id,
    platform,
    token,
    push_enabled,
    disabled_at,
    last_registered_at,
    updated_at
  ) values (
    v_installation_id,
    v_user_id,
    v_platform,
    v_token,
    true,
    null,
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (installation_id) do update
     set user_id = excluded.user_id,
         platform = excluded.platform,
         token = excluded.token,
         push_enabled = true,
         disabled_at = null,
         last_registered_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
  returning id
    into v_device_id;

  return v_device_id;
end;
$$;


create or replace function public.disable_push_notification_device(
  p_installation_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_installation_id text := nullif(trim(coalesce(p_installation_id, '')), '');
  v_updated integer := 0;
begin
  if v_installation_id is null then
    return false;
  end if;

  update public.push_notification_devices
     set push_enabled = false,
         disabled_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
   where installation_id = v_installation_id
     and push_enabled = true;

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;


create or replace function public.should_send_notification_push(
  p_kind text,
  p_is_important boolean default false
)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_kind text := coalesce(nullif(trim(coalesce(p_kind, '')), ''), '');
begin
  if v_kind in (
    'session_cancelled',
    'session_instructor_changed',
    'session_reservation_removed',
    'waitlist_promoted',
    'cancel_request_approved',
    'cancel_request_rejected',
    'session_reminder_day_before',
    'session_reminder_hour_before'
  ) then
    return true;
  end if;

  if v_kind in ('notice', 'event') and coalesce(p_is_important, false) then
    return true;
  end if;

  return false;
end;
$$;


create or replace function public.enqueue_notification_push_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.should_send_notification_push(new.kind, new.is_important) then
    return new;
  end if;

  insert into public.notification_push_jobs (
    notification_id,
    status
  ) values (
    new.id,
    'pending'
  )
  on conflict (notification_id) do nothing;

  return new;
end;
$$;


create or replace function public.invoke_push_notification_dispatcher(
  p_batch_size integer default 10
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project_url text;
  v_anon_key text;
  v_request_id bigint;
begin
  select secret.decrypted_secret
    into v_project_url
    from vault.decrypted_secrets secret
   where secret.name = 'supabase_project_url'
   limit 1;

  select secret.decrypted_secret
    into v_anon_key
    from vault.decrypted_secrets secret
   where secret.name = 'supabase_anon_key'
   limit 1;

  if v_project_url is null or v_anon_key is null then
    raise notice 'Push notification dispatcher secrets are not configured.';
    return null;
  end if;

  select net.http_post(
    url := rtrim(v_project_url, '/') || '/functions/v1/dispatch-push-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_anon_key
    ),
    body := jsonb_build_object(
      'batch_size', greatest(coalesce(p_batch_size, 10), 1)
    ),
    timeout_milliseconds := 30000
  )
    into v_request_id;

  return v_request_id;
end;
$$;


create or replace function public.setup_push_notification_dispatch_job()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if to_regnamespace('cron') is null then
    return;
  end if;

  perform cron.schedule(
    'eightup-push-dispatch',
    '* * * * *',
    $job$select public.invoke_push_notification_dispatcher();$job$
  );
exception
  when unique_violation then
    null;
  when undefined_function or invalid_schema_name then
    null;
end;
$$;


create or replace function public.cleanup_notification_push_history(
  p_retention interval default interval '30 days'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted integer := 0;
  v_retention interval := greatest(
    coalesce(p_retention, interval '30 days'),
    interval '1 day'
  );
begin
  delete from public.notification_push_jobs job
   where job.status in ('sent', 'skipped', 'failed')
     and coalesce(job.processed_at, job.last_attempt_at, job.updated_at, job.created_at)
         < timezone('utc', now()) - v_retention;

  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;


create or replace function public.setup_notification_push_cleanup_job()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if to_regnamespace('cron') is null then
    return;
  end if;

  perform cron.schedule(
    'eightup-push-cleanup',
    '30 18 * * *',
    $job$select public.cleanup_notification_push_history();$job$
  );
exception
  when unique_violation then
    null;
  when undefined_function or invalid_schema_name then
    null;
end;
$$;


create or replace function public.get_user_pass_notification_context(
  p_user_pass_id uuid
)
returns table (
  studio_id uuid,
  user_id uuid,
  pass_name text,
  total_count integer,
  remaining_count integer,
  valid_from date,
  valid_until date,
  status public.user_pass_status
)
language sql
stable
security definer
set search_path = public
as $$
  select
    user_pass.studio_id,
    user_pass.user_id,
    coalesce(nullif(user_pass.name_snapshot, ''), '수강권') as pass_name,
    user_pass.total_count,
    coalesce(balance.remaining_count, user_pass.total_count)::integer as remaining_count,
    user_pass.valid_from,
    user_pass.valid_until,
    user_pass.status
  from public.user_passes user_pass
  left join public.get_user_pass_balance(user_pass.id) balance
    on true
  where user_pass.id = p_user_pass_id;
$$;


create or replace function public.promote_next_waitlisted_reservation(p_session_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  return null;
end;
$$;


create or replace function public.get_session_reserved_count(p_session_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_studio_id uuid;
begin
  select session.studio_id
    into v_studio_id
    from public.class_sessions session
   where session.id = p_session_id;

  if v_studio_id is null then
    return 0;
  end if;

  if not public.is_active_member_of_studio(v_studio_id)
     and not public.is_admin_of_studio(v_studio_id) then
    raise exception 'Not authorized to inspect session counts';
  end if;

  return (
    select coalesce(count(*), 0)::integer
      from public.reservations reservation
     where reservation.class_session_id = p_session_id
       and reservation.status in (
         'reserved',
         'completed',
         'cancel_requested',
         'studio_rejected'
       )
  );
end;
$$;


create or replace function public.get_session_waitlist_count(p_session_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_studio_id uuid;
begin
  select session.studio_id
    into v_studio_id
    from public.class_sessions session
   where session.id = p_session_id;

  if v_studio_id is null then
    return 0;
  end if;

  if not public.is_active_member_of_studio(v_studio_id)
     and not public.is_admin_of_studio(v_studio_id) then
    raise exception 'Not authorized to inspect session counts';
  end if;

  return (
    select coalesce(count(*), 0)::integer
      from public.reservations reservation
     where reservation.class_session_id = p_session_id
       and reservation.status = 'waitlisted'
  );
end;
$$;


create or replace function public.reserve_class_session(
  p_session_id uuid,
  p_user_pass_id uuid
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.class_sessions%rowtype;
  v_user_pass public.user_passes%rowtype;
  v_existing_reservation public.reservations%rowtype;
  v_overlap_exists boolean;
  v_reserved_count integer;
  v_has_waitlisted_members boolean;
  v_waitlist_order integer;
  v_reservation public.reservations%rowtype;
  v_class_name text;
  v_pass_name text := '수강권';
  v_remaining_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
    into v_session
    from public.class_sessions
   where id = p_session_id
   for update;

  if not found then
    raise exception 'Session not found';
  end if;

  if v_session.status <> 'scheduled' then
    raise exception 'Session is not reservable';
  end if;

  if v_session.start_at <= timezone('utc', now()) then
    raise exception 'Session has already started';
  end if;

  if not public.is_active_member_of_studio(v_session.studio_id) then
    raise exception 'You are not a member of this studio';
  end if;

  select reservation.*
    into v_existing_reservation
   from public.reservations reservation
   where reservation.class_session_id = p_session_id
     and reservation.user_id = auth.uid()
   for update;

  if found then
    if v_existing_reservation.status in (
      'reserved',
      'waitlisted',
      'cancel_requested',
      'studio_rejected'
    ) then
      raise exception 'Reservation already exists for this session';
    end if;

    if v_existing_reservation.status = 'completed' then
      raise exception 'Completed reservation already exists for this session';
    end if;

    if v_existing_reservation.status = 'cancelled'
       and v_existing_reservation.approved_cancel_at is null then
      delete from public.reservations
       where id = v_existing_reservation.id;
    else
      raise exception 'Reservation already exists for this session';
    end if;
  end if;

  select exists (
    select 1
      from public.reservations reservation
      join public.class_sessions existing_session
        on existing_session.id = reservation.class_session_id
     where reservation.user_id = auth.uid()
       and reservation.status in (
         'reserved',
         'waitlisted',
         'cancel_requested',
         'studio_rejected'
       )
       and tstzrange(existing_session.start_at, existing_session.end_at, '[)') &&
           tstzrange(v_session.start_at, v_session.end_at, '[)')
  )
    into v_overlap_exists;

  if v_overlap_exists then
    raise exception 'Overlapping reservation already exists';
  end if;

  select *
    into v_user_pass
    from public.user_passes
   where id = p_user_pass_id
   for update;

  if not found then
    raise exception 'Pass not found';
  end if;

  if not public.can_use_pass_for_session(p_user_pass_id, p_session_id) then
    raise exception 'Selected pass cannot reserve this session';
  end if;

  select template.name
    into v_class_name
    from public.class_templates template
   where template.id = v_session.class_template_id;

  select count(*)
    into v_reserved_count
   from public.reservations reservation
   where reservation.class_session_id = p_session_id
     and reservation.status in (
       'reserved',
       'cancel_requested',
       'studio_rejected'
     );

  select exists (
    select 1
      from public.reservations reservation
     where reservation.class_session_id = p_session_id
       and reservation.status = 'waitlisted'
  )
    into v_has_waitlisted_members;

  if v_reserved_count < v_session.capacity and not v_has_waitlisted_members then
    insert into public.reservations (
      studio_id,
      user_id,
      class_session_id,
      user_pass_id,
      status,
      is_waitlisted
    ) values (
      v_session.studio_id,
      auth.uid(),
      p_session_id,
      p_user_pass_id,
      'reserved',
      false
    )
    returning *
      into v_reservation;

    insert into public.pass_usage_ledger (
      studio_id,
      user_pass_id,
      reservation_id,
      entry_type,
      count_delta,
      memo
    ) values (
      v_session.studio_id,
      p_user_pass_id,
      v_reservation.id,
      'planned',
      -1,
      '예약 생성'
    )
    on conflict (reservation_id, entry_type) do nothing;

    select context.pass_name, context.remaining_count
      into v_pass_name, v_remaining_count
      from public.get_user_pass_notification_context(p_user_pass_id) context;

    perform public.create_user_notification(
      p_studio_id => v_session.studio_id,
      p_user_id => auth.uid(),
      p_kind => 'reservation_created',
      p_title => '예약 완료',
      p_body => format(
        '%s %s 수업 예약이 완료되었습니다. 현재 %s 잔여 횟수는 %s회입니다.',
        to_char(
          timezone('Asia/Seoul', v_session.start_at),
          'FMMM"월" FMDD"일" HH24:MI'
        ),
        coalesce(v_class_name, '수업'),
        coalesce(v_pass_name, '수강권'),
        coalesce(v_remaining_count, 0)
      ),
      p_related_entity_type => 'reservation',
      p_related_entity_id => v_reservation.id
    );
  else
    select coalesce(max(waitlist_order), 0) + 1
      into v_waitlist_order
      from public.reservations
     where class_session_id = p_session_id
       and status = 'waitlisted';

    insert into public.reservations (
      studio_id,
      user_id,
      class_session_id,
      user_pass_id,
      status,
      is_waitlisted,
      waitlist_order
    ) values (
      v_session.studio_id,
      auth.uid(),
      p_session_id,
      p_user_pass_id,
      'waitlisted',
      true,
      v_waitlist_order
    )
    returning *
      into v_reservation;

    select context.pass_name, context.remaining_count
      into v_pass_name, v_remaining_count
      from public.get_user_pass_notification_context(p_user_pass_id) context;

    perform public.create_user_notification(
      p_studio_id => v_session.studio_id,
      p_user_id => auth.uid(),
      p_kind => 'waitlist_registered',
      p_title => '대기 예약 등록',
      p_body => format(
        '%s %s 수업이 대기 예약으로 등록되었습니다. 현재 %s 잔여 횟수는 %s회입니다.',
        to_char(
          timezone('Asia/Seoul', v_session.start_at),
          'FMMM"월" FMDD"일" HH24:MI'
        ),
        coalesce(v_class_name, '수업'),
        coalesce(v_pass_name, '수강권'),
        coalesce(v_remaining_count, 0)
      ),
      p_related_entity_type => 'reservation',
      p_related_entity_id => v_reservation.id
    );
  end if;

  return v_reservation;
end;
$$;


create or replace function public.cancel_class_reservation(p_reservation_id uuid)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_session public.class_sessions%rowtype;
  v_studio public.studios%rowtype;
  v_cutoff timestamptz;
  v_class_name text;
  v_pass_name text := '수강권';
  v_remaining_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.user_id <> auth.uid() then
    raise exception 'You cannot cancel another member reservation';
  end if;

  select *
    into v_session
    from public.class_sessions
   where id = v_reservation.class_session_id
   for update;

  select *
    into v_studio
    from public.studios
   where id = v_session.studio_id;

  if v_reservation.status = 'waitlisted' then
    update public.reservations
       set status = 'cancelled',
           is_waitlisted = false,
           waitlist_order = null
     where id = v_reservation.id
     returning *
      into v_reservation;

    return v_reservation;
  end if;

  if v_reservation.status <> 'reserved' then
    raise exception 'Only active reservations or waitlisted reservations can be cancelled';
  end if;

  if v_session.start_at <= now() then
    raise exception 'Past sessions cannot be cancelled';
  end if;

  v_cutoff := public.calculate_session_cancel_cutoff(
    v_session.session_date,
    v_session.start_at,
    v_studio.cancel_policy_mode,
    v_studio.cancel_policy_hours_before,
    v_studio.cancel_policy_days_before,
    v_studio.cancel_policy_cutoff_time
  );

  if now() >= v_cutoff then
    raise exception 'Direct cancel is no longer available for this studio policy';
  end if;

  select template.name
    into v_class_name
    from public.class_templates template
   where template.id = v_session.class_template_id;

  update public.reservations
     set status = 'cancelled'
   where id = v_reservation.id
   returning *
    into v_reservation;

  insert into public.pass_usage_ledger (
    studio_id,
    user_pass_id,
    reservation_id,
    entry_type,
    count_delta,
    memo
  ) values (
    v_reservation.studio_id,
    v_reservation.user_pass_id,
    v_reservation.id,
    'restored',
    1,
    '취소 기한 내 직접 취소'
  )
  on conflict (reservation_id, entry_type) do nothing;

  select context.pass_name, context.remaining_count
    into v_pass_name, v_remaining_count
    from public.get_user_pass_notification_context(v_reservation.user_pass_id) context;

  perform public.create_user_notification(
    p_studio_id => v_reservation.studio_id,
    p_user_id => v_reservation.user_id,
    p_kind => 'reservation_cancelled',
    p_title => '예약 취소 완료',
    p_body => format(
      '%s %s 수업 예약이 취소되었습니다. 현재 %s 잔여 횟수는 %s회입니다.',
      to_char(
        timezone('Asia/Seoul', v_session.start_at),
        'FMMM"월" FMDD"일" HH24:MI'
      ),
      coalesce(v_class_name, '수업'),
      coalesce(v_pass_name, '수강권'),
      coalesce(v_remaining_count, 0)
    ),
    p_related_entity_type => 'reservation',
    p_related_entity_id => v_reservation.id
  );

  return v_reservation;
end;
$$;


create or replace function public.approve_reservation_cancel_request_admin(
  p_reservation_id uuid,
  p_comment text default null
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_reservation public.reservations%rowtype;
  v_class_name text;
  v_session_start timestamptz;
  v_comment text := nullif(trim(coalesce(p_comment, '')), '');
  v_body text;
  v_pass_name text := '수강권';
  v_remaining_count integer := 0;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
     and reservation.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'cancel_requested' then
    raise exception 'Reservation is not awaiting cancel approval';
  end if;

  select template.name, session.start_at
    into v_class_name, v_session_start
    from public.class_sessions session
    join public.class_templates template
      on template.id = session.class_template_id
   where session.id = v_reservation.class_session_id;

  update public.reservations
     set status = 'cancelled',
         approved_cancel_at = timezone('utc', now()),
         approved_cancel_by_admin_id = auth.uid(),
         approved_cancel_comment = v_comment,
         cancel_request_response_comment = v_comment,
         cancel_request_processed_at = timezone('utc', now()),
         cancel_request_processed_by_admin_id = auth.uid()
   where id = v_reservation.id
   returning *
    into v_reservation;

  insert into public.pass_usage_ledger (
    studio_id,
    user_pass_id,
    reservation_id,
    entry_type,
    count_delta,
    memo
  ) values (
    v_reservation.studio_id,
    v_reservation.user_pass_id,
    v_reservation.id,
    'restored',
    1,
    coalesce(v_comment, '관리자 취소 승인')
  )
  on conflict (reservation_id, entry_type) do nothing;

  select context.pass_name, context.remaining_count
    into v_pass_name, v_remaining_count
    from public.get_user_pass_notification_context(v_reservation.user_pass_id) context;

  v_body := format(
    '%s %s 수업 취소 요청이 승인되었습니다. 현재 %s 잔여 횟수는 %s회입니다.',
    to_char(
      timezone('Asia/Seoul', v_session_start),
      'FMMM"월" FMDD"일" HH24:MI'
    ),
    coalesce(v_class_name, '수업'),
    coalesce(v_pass_name, '수강권'),
    coalesce(v_remaining_count, 0)
  );

  if v_comment is not null then
    v_body := format('%s 관리자 메모: %s', v_body, v_comment);
  end if;

  perform public.create_user_notification(
    p_studio_id => v_reservation.studio_id,
    p_user_id => v_reservation.user_id,
    p_kind => 'cancel_request_approved',
    p_title => '취소 요청 승인',
    p_body => v_body,
    p_is_important => true,
    p_related_entity_type => 'reservation',
    p_related_entity_id => v_reservation.id
  );

  return v_reservation;
end;
$$;


create or replace function public.reject_reservation_cancel_request_admin(
  p_reservation_id uuid,
  p_comment text
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_reservation public.reservations%rowtype;
  v_class_name text;
  v_session_start timestamptz;
  v_comment text := nullif(trim(coalesce(p_comment, '')), '');
  v_body text;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
     and reservation.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'cancel_requested' then
    raise exception 'Reservation is not awaiting cancel approval';
  end if;

  select template.name, session.start_at
    into v_class_name, v_session_start
    from public.class_sessions session
    join public.class_templates template
      on template.id = session.class_template_id
   where session.id = v_reservation.class_session_id;

  update public.reservations
     set status = 'studio_rejected',
         cancel_request_response_comment = v_comment,
         cancel_request_processed_at = timezone('utc', now()),
         cancel_request_processed_by_admin_id = auth.uid()
   where id = v_reservation.id
   returning *
    into v_reservation;

  v_body := format(
    '%s %s 수업 취소 요청이 거절되었습니다.',
    to_char(
      timezone('Asia/Seoul', v_session_start),
      'FMMM"월" FMDD"일" HH24:MI'
    ),
    coalesce(v_class_name, '수업')
  );

  if v_comment is not null then
    v_body := format('%s 관리자 메모: %s', v_body, v_comment);
  end if;

  perform public.create_user_notification(
    p_studio_id => v_reservation.studio_id,
    p_user_id => v_reservation.user_id,
    p_kind => 'cancel_request_rejected',
    p_title => '취소 요청 거절',
    p_body => v_body,
    p_is_important => true,
    p_related_entity_type => 'reservation',
    p_related_entity_id => v_reservation.id
  );

  return v_reservation;
end;
$$;


create or replace function public.add_member_to_studio_admin(p_user_id uuid)
returns public.studio_user_memberships
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_user public.users%rowtype;
  v_membership public.studio_user_memberships%rowtype;
  v_existing_membership public.studio_user_memberships%rowtype;
  v_studio_name text := '스튜디오';
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select studio.name
    into v_studio_name
    from public.studios studio
   where studio.id = v_studio_id;

  select *
    into v_user
    from public.users app_user
   where app_user.id = p_user_id
     and app_user.status = 'active';

  if not found then
    raise exception 'User not found';
  end if;

  select *
    into v_existing_membership
    from public.studio_user_memberships membership
   where membership.studio_id = v_studio_id
     and membership.user_id = p_user_id;

  insert into public.studio_user_memberships (
    studio_id,
    user_id,
    membership_status,
    joined_at
  ) values (
    v_studio_id,
    v_user.id,
    'active',
    timezone('utc', now())
  )
  on conflict (studio_id, user_id) do update
     set membership_status = 'active',
         joined_at = excluded.joined_at,
         updated_at = timezone('utc', now())
  returning *
    into v_membership;

  if v_existing_membership.id is null then
    perform public.create_user_notification(
      p_studio_id => v_studio_id,
      p_user_id => v_user.id,
      p_kind => 'studio_membership_approved',
      p_title => '스튜디오 등록 완료',
      p_body => format(
        '%s 스튜디오 회원으로 등록되었습니다. 이제 수업 예약과 공지 확인이 가능합니다.',
        coalesce(v_studio_name, '스튜디오')
      ),
      p_related_entity_type => 'membership',
      p_related_entity_id => v_membership.id
    );
  elsif v_existing_membership.membership_status <> 'active' then
    perform public.create_user_notification(
      p_studio_id => v_studio_id,
      p_user_id => v_user.id,
      p_kind => 'studio_membership_reactivated',
      p_title => '스튜디오 이용 재개',
      p_body => format(
        '%s 스튜디오 이용이 다시 활성화되었습니다.',
        coalesce(v_studio_name, '스튜디오')
      ),
      p_related_entity_type => 'membership',
      p_related_entity_id => v_membership.id
    );
  end if;

  return v_membership;
end;
$$;


create or replace function public.issue_user_pass_admin(
  p_user_id uuid,
  p_pass_product_id uuid,
  p_valid_from date default timezone('Asia/Seoul', now())::date,
  p_paid_amount numeric default null
)
returns public.user_passes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_product public.pass_products%rowtype;
  v_result public.user_passes%rowtype;
  v_pass_name text := '수강권';
  v_remaining_count integer := 0;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_product
    from public.pass_products
   where id = p_pass_product_id
     and studio_id = v_studio_id
     and status = 'active';

  if not found then
    raise exception 'Pass product not found';
  end if;

  if not exists (
    select 1
      from public.studio_user_memberships membership
     where membership.studio_id = v_studio_id
       and membership.user_id = p_user_id
       and membership.membership_status = 'active'
  ) then
    raise exception 'User is not an active member of this studio';
  end if;

  insert into public.user_passes (
    studio_id,
    user_id,
    pass_product_id,
    name_snapshot,
    total_count,
    valid_from,
    valid_until,
    paid_amount,
    refunded_amount,
    status,
    created_by_admin_id
  ) values (
    v_studio_id,
    p_user_id,
    v_product.id,
    v_product.name,
    v_product.total_count,
    p_valid_from,
    (p_valid_from + greatest(v_product.valid_days - 1, 0)),
    coalesce(p_paid_amount, v_product.price_amount),
    0,
    'active',
    auth.uid()
  )
  returning *
    into v_result;

  select context.pass_name, context.remaining_count
    into v_pass_name, v_remaining_count
    from public.get_user_pass_notification_context(v_result.id) context;

  perform public.create_user_notification(
    p_studio_id => v_result.studio_id,
    p_user_id => v_result.user_id,
    p_kind => 'pass_issued',
    p_title => '수강권 발급',
    p_body => format(
      '%s이 발급되었습니다. 사용 기간은 %s부터 %s까지이며 현재 잔여 횟수는 %s회입니다.',
      coalesce(v_pass_name, '수강권'),
      to_char(v_result.valid_from, 'YYYY"년" MM"월" DD"일"'),
      to_char(v_result.valid_until, 'YYYY"년" MM"월" DD"일"'),
      coalesce(v_remaining_count, 0)
    ),
    p_related_entity_type => 'user_pass',
    p_related_entity_id => v_result.id
  );

  return v_result;
end;
$$;


create or replace function public.refund_user_pass_admin(
  p_user_pass_id uuid,
  p_refund_amount numeric,
  p_refund_reason text default null
)
returns public.user_passes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_user_pass public.user_passes%rowtype;
  v_balance record;
  v_today_local date := timezone('Asia/Seoul', now())::date;
  v_refund_reason text := nullif(btrim(p_refund_reason), '');
  v_effective_valid_from date;
  v_result public.user_passes%rowtype;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  if p_refund_amount is null or p_refund_amount <= 0 then
    raise exception '환불 금액은 0보다 커야 합니다';
  end if;

  select *
    into v_user_pass
    from public.user_passes user_pass
   where user_pass.id = p_user_pass_id
     and user_pass.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '환불할 수강권을 찾을 수 없습니다';
  end if;

  if v_user_pass.status = 'refunded' or coalesce(v_user_pass.refunded_amount, 0) > 0 then
    raise exception '이미 환불 처리된 수강권입니다';
  end if;

  if p_refund_amount > coalesce(v_user_pass.paid_amount, 0) then
    raise exception '환불 금액은 결제 금액을 초과할 수 없습니다';
  end if;

  select *
    into v_balance
    from public.get_user_pass_balance(p_user_pass_id);

  if coalesce(v_balance.planned_count, 0) > 0 then
    raise exception '예정된 예약이 있는 수강권은 환불 처리할 수 없습니다';
  end if;

  v_effective_valid_from := least(v_user_pass.valid_from, v_today_local);

  update public.user_passes
     set refunded_amount = p_refund_amount,
         valid_from = v_effective_valid_from,
         valid_until = v_today_local,
         status = 'refunded'
   where id = v_user_pass.id
   returning *
    into v_result;

  insert into public.refund_logs (
    studio_id,
    user_pass_id,
    refund_amount,
    refund_reason,
    refunded_by_admin_id,
    refunded_at
  ) values (
    v_result.studio_id,
    v_result.id,
    p_refund_amount,
    v_refund_reason,
    auth.uid(),
    timezone('utc', now())
  );

  perform public.create_user_notification(
    p_studio_id => v_result.studio_id,
    p_user_id => v_result.user_id,
    p_kind => 'pass_refunded',
    p_title => '수강권 환불',
    p_body => case
      when v_refund_reason is not null then format(
        '%s이 환불 처리되었습니다. 사유: %s',
        coalesce(v_result.name_snapshot, '수강권'),
        v_refund_reason
      )
      else format(
        '%s이 환불 처리되었습니다.',
        coalesce(v_result.name_snapshot, '수강권')
      )
    end,
    p_related_entity_type => 'user_pass',
    p_related_entity_id => v_result.id
  );

  return v_result;
end;
$$;


create or replace function public.create_user_pass_hold_admin(
  p_user_pass_id uuid,
  p_hold_from date,
  p_hold_until date
)
returns public.user_passes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_user_pass public.user_passes%rowtype;
  v_hold_days integer;
  v_existing_hold_days integer := 0;
  v_today_local date := timezone('Asia/Seoul', now())::date;
  v_result public.user_passes%rowtype;
  v_existing_hold_id uuid;
  v_base_valid_until date;
  v_title text;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  if p_hold_from is null or p_hold_until is null then
    raise exception '홀딩 시작일과 종료일을 선택하세요';
  end if;

  if p_hold_until < p_hold_from then
    raise exception '홀딩 종료일은 시작일보다 빠를 수 없습니다';
  end if;

  select *
    into v_user_pass
    from public.user_passes user_pass
   where user_pass.id = p_user_pass_id
     and user_pass.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '홀딩할 수강권을 찾을 수 없습니다';
  end if;

  if v_user_pass.status <> 'active' then
    raise exception '사용 중인 수강권만 홀딩할 수 있습니다';
  end if;

  select hold.id
    into v_existing_hold_id
    from public.user_pass_holds hold
   where hold.user_pass_id = v_user_pass.id
   order by hold.updated_at desc, hold.created_at desc
   limit 1
   for update;

  select coalesce(sum((hold.hold_until - hold.hold_from + 1)), 0)::integer
    into v_existing_hold_days
    from public.user_pass_holds hold
   where hold.user_pass_id = v_user_pass.id;

  if p_hold_from < v_today_local and v_existing_hold_id is null then
    raise exception '홀딩 시작일은 오늘 또는 이후여야 합니다';
  end if;

  v_base_valid_until := greatest(
    v_user_pass.valid_from,
    v_user_pass.valid_until - v_existing_hold_days
  );

  if p_hold_from < v_user_pass.valid_from or p_hold_until > v_base_valid_until then
    raise exception '홀딩 기간은 현재 수강권 사용 기간 안에서만 선택할 수 있습니다';
  end if;

  if exists (
    select 1
      from public.reservations reservation
      join public.class_sessions session
        on session.id = reservation.class_session_id
     where reservation.user_pass_id = v_user_pass.id
       and reservation.status in (
         'reserved',
         'waitlisted',
         'cancel_requested',
         'studio_rejected'
       )
       and session.session_date between p_hold_from and p_hold_until
  ) then
    raise exception '홀딩 기간 안에 예정된 예약이 있어 먼저 정리해야 합니다';
  end if;

  v_hold_days := (p_hold_until - p_hold_from) + 1;

  if v_existing_hold_id is null then
    insert into public.user_pass_holds (
      studio_id,
      user_id,
      user_pass_id,
      hold_from,
      hold_until,
      created_by_admin_id
    ) values (
      v_user_pass.studio_id,
      v_user_pass.user_id,
      v_user_pass.id,
      p_hold_from,
      p_hold_until,
      auth.uid()
    );
    v_title := '수강권 홀딩 등록';
  else
    update public.user_pass_holds
       set hold_from = p_hold_from,
           hold_until = p_hold_until
     where id = v_existing_hold_id;

    delete from public.user_pass_holds
     where user_pass_id = v_user_pass.id
       and id <> v_existing_hold_id;

    v_title := '수강권 홀딩 변경';
  end if;

  update public.user_passes
     set valid_until = v_base_valid_until + v_hold_days
   where id = v_user_pass.id
   returning *
    into v_result;

  perform public.create_user_notification(
    p_studio_id => v_result.studio_id,
    p_user_id => v_result.user_id,
    p_kind => 'pass_hold_registered',
    p_title => v_title,
    p_body => format(
      '%s 홀딩이 %s부터 %s까지 등록되었습니다.',
      coalesce(v_result.name_snapshot, '수강권'),
      to_char(p_hold_from, 'YYYY"년" MM"월" DD"일"'),
      to_char(p_hold_until, 'YYYY"년" MM"월" DD"일"')
    ),
    p_related_entity_type => 'user_pass',
    p_related_entity_id => v_result.id
  );

  return v_result;
end;
$$;


create or replace function public.cancel_user_pass_hold_admin(
  p_user_pass_id uuid
)
returns public.user_passes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_user_pass public.user_passes%rowtype;
  v_hold public.user_pass_holds%rowtype;
  v_today_local date := timezone('Asia/Seoul', now())::date;
  v_effective_from date;
  v_days_to_remove integer := 0;
  v_result public.user_passes%rowtype;
  v_title text;
  v_body text;
  v_kind text;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_user_pass
    from public.user_passes user_pass
   where user_pass.id = p_user_pass_id
     and user_pass.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '홀딩을 취소할 수강권을 찾을 수 없습니다';
  end if;

  select *
    into v_hold
    from public.user_pass_holds hold
   where hold.user_pass_id = v_user_pass.id
     and hold.hold_until >= v_today_local
   order by hold.hold_until desc, hold.hold_from desc
   limit 1
   for update;

  if not found then
    raise exception '취소할 홀딩 정보가 없습니다';
  end if;

  v_effective_from := greatest(v_today_local, v_hold.hold_from);
  if v_effective_from <= v_hold.hold_until then
    v_days_to_remove := (v_hold.hold_until - v_effective_from) + 1;
  end if;

  delete from public.user_pass_holds
   where id = v_hold.id;

  update public.user_passes
     set valid_until = greatest(valid_from, valid_until - v_days_to_remove)
   where id = v_user_pass.id
   returning *
    into v_result;

  if v_today_local < v_hold.hold_from then
    v_kind := 'pass_hold_cancelled';
    v_title := '수강권 홀딩 취소';
    v_body := format(
      '%s에 등록된 %s부터 %s까지의 홀딩 일정이 취소되었습니다.',
      coalesce(v_result.name_snapshot, '수강권'),
      to_char(v_hold.hold_from, 'YYYY"년" MM"월" DD"일"'),
      to_char(v_hold.hold_until, 'YYYY"년" MM"월" DD"일"')
    );
  else
    v_kind := 'pass_hold_ended';
    v_title := '수강권 홀딩 종료';
    v_body := format(
      '%s 홀딩이 조기 종료되어 다시 예약할 수 있습니다.',
      coalesce(v_result.name_snapshot, '수강권')
    );
  end if;

  perform public.create_user_notification(
    p_studio_id => v_result.studio_id,
    p_user_id => v_result.user_id,
    p_kind => v_kind,
    p_title => v_title,
    p_body => v_body,
    p_related_entity_type => 'user_pass',
    p_related_entity_id => v_result.id
  );

  return v_result;
end;
$$;


create or replace function public.add_member_to_session_admin(
  p_session_id uuid,
  p_member_code text
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_session public.class_sessions%rowtype;
  v_user public.users%rowtype;
  v_user_pass public.user_passes%rowtype;
  v_existing_reservation public.reservations%rowtype;
  v_overlap_exists boolean;
  v_reserved_count integer;
  v_has_waitlisted_members boolean;
  v_waitlist_order integer;
  v_reservation public.reservations%rowtype;
  v_class_name text;
  v_pass_name text := '수강권';
  v_remaining_count integer := 0;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select *
    into v_session
    from public.class_sessions session
   where session.id = p_session_id
     and session.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Session not found';
  end if;

  if v_session.status <> 'scheduled' then
    raise exception 'Session is not reservable';
  end if;

  if v_session.start_at <= timezone('utc', now()) then
    raise exception 'Started sessions cannot accept new attendees';
  end if;

  select template.name
    into v_class_name
    from public.class_templates template
   where template.id = v_session.class_template_id;

  select *
    into v_user
    from public.users app_user
   where lower(app_user.member_code) = lower(trim(coalesce(p_member_code, '')))
     and app_user.status = 'active'
   limit 1;

  if not found then
    raise exception 'Member not found';
  end if;

  if not exists (
    select 1
      from public.studio_user_memberships membership
     where membership.studio_id = v_studio_id
       and membership.user_id = v_user.id
       and membership.membership_status = 'active'
  ) then
    raise exception 'User is not an active member of this studio';
  end if;

  select *
    into v_existing_reservation
    from public.reservations reservation
   where reservation.class_session_id = p_session_id
     and reservation.user_id = v_user.id
   for update;

  if found then
    if v_existing_reservation.status in (
      'reserved',
      'waitlisted',
      'cancel_requested',
      'studio_rejected'
    ) then
      raise exception 'Reservation already exists for this member';
    end if;

    if v_existing_reservation.status = 'completed' then
      raise exception 'Completed reservation already exists for this member';
    end if;

    delete from public.reservations
     where id = v_existing_reservation.id;
  end if;

  select exists (
    select 1
      from public.reservations reservation
      join public.class_sessions existing_session
        on existing_session.id = reservation.class_session_id
     where reservation.user_id = v_user.id
       and reservation.status in (
         'reserved',
         'waitlisted',
         'cancel_requested',
         'studio_rejected'
       )
       and tstzrange(existing_session.start_at, existing_session.end_at, '[)') &&
           tstzrange(v_session.start_at, v_session.end_at, '[)')
  )
    into v_overlap_exists;

  if v_overlap_exists then
    raise exception 'Member already has an overlapping reservation';
  end if;

  select user_pass.*
    into v_user_pass
    from public.user_passes user_pass
   where user_pass.user_id = v_user.id
     and user_pass.studio_id = v_studio_id
     and user_pass.status = 'active'
     and v_session.session_date between user_pass.valid_from and user_pass.valid_until
     and not public.is_user_pass_held_on(user_pass.id, v_session.session_date)
     and exists (
       select 1
         from public.pass_product_template_mappings mapping
        where mapping.pass_product_id = user_pass.pass_product_id
          and mapping.class_template_id = v_session.class_template_id
     )
     and coalesce((
       select balance.remaining_count
         from public.get_user_pass_balance(user_pass.id) balance
     ), 0) > 0
   order by user_pass.valid_until asc, user_pass.created_at asc
   limit 1
   for update;

  if not found then
    raise exception '해당 회원은 사용 가능한 수강권이 없습니다';
  end if;

  select count(*)
    into v_reserved_count
   from public.reservations reservation
   where reservation.class_session_id = p_session_id
     and reservation.status in (
       'reserved',
       'cancel_requested',
       'studio_rejected'
     );

  select exists (
    select 1
      from public.reservations reservation
     where reservation.class_session_id = p_session_id
       and reservation.status = 'waitlisted'
  )
    into v_has_waitlisted_members;

  if v_reserved_count < v_session.capacity and not v_has_waitlisted_members then
    insert into public.reservations (
      studio_id,
      user_id,
      class_session_id,
      user_pass_id,
      status,
      is_waitlisted
    ) values (
      v_studio_id,
      v_user.id,
      p_session_id,
      v_user_pass.id,
      'reserved',
      false
    )
    returning *
      into v_reservation;

    insert into public.pass_usage_ledger (
      studio_id,
      user_pass_id,
      reservation_id,
      entry_type,
      count_delta,
      memo
    ) values (
      v_studio_id,
      v_user_pass.id,
      v_reservation.id,
      'planned',
      -1,
      'Admin added member to session'
    )
    on conflict (reservation_id, entry_type) do nothing;

    select context.pass_name, context.remaining_count
      into v_pass_name, v_remaining_count
      from public.get_user_pass_notification_context(v_user_pass.id) context;

    perform public.create_user_notification(
      p_studio_id => v_studio_id,
      p_user_id => v_user.id,
      p_kind => 'reservation_created',
      p_title => '예약 완료 안내',
      p_body => format(
        '%s %s 수업 예약이 등록되었습니다. 현재 %s 잔여 횟수는 %s회입니다.',
        to_char(
          timezone('Asia/Seoul', v_session.start_at),
          'FMMM"월" FMDD"일" HH24:MI'
        ),
        coalesce(v_class_name, '수업'),
        coalesce(v_pass_name, '수강권'),
        coalesce(v_remaining_count, 0)
      ),
      p_related_entity_type => 'reservation',
      p_related_entity_id => v_reservation.id
    );
  else
    select coalesce(max(waitlist_order), 0) + 1
      into v_waitlist_order
      from public.reservations
     where class_session_id = p_session_id
       and status = 'waitlisted';

    insert into public.reservations (
      studio_id,
      user_id,
      class_session_id,
      user_pass_id,
      status,
      is_waitlisted,
      waitlist_order
    ) values (
      v_studio_id,
      v_user.id,
      p_session_id,
      v_user_pass.id,
      'waitlisted',
      true,
      v_waitlist_order
    )
    returning *
      into v_reservation;

    select context.pass_name, context.remaining_count
      into v_pass_name, v_remaining_count
      from public.get_user_pass_notification_context(v_user_pass.id) context;

    perform public.create_user_notification(
      p_studio_id => v_studio_id,
      p_user_id => v_user.id,
      p_kind => 'waitlist_registered',
      p_title => '대기 예약 등록',
      p_body => format(
        '%s %s 수업이 대기 예약으로 등록되었습니다. 현재 %s 잔여 횟수는 %s회입니다.',
        to_char(
          timezone('Asia/Seoul', v_session.start_at),
          'FMMM"월" FMDD"일" HH24:MI'
        ),
        coalesce(v_class_name, '수업'),
        coalesce(v_pass_name, '수강권'),
        coalesce(v_remaining_count, 0)
      ),
      p_related_entity_type => 'reservation',
      p_related_entity_id => v_reservation.id
    );
  end if;

  return v_reservation;
end;
$$;


create or replace function public.remove_member_from_session_admin(
  p_reservation_id uuid,
  p_comment text default null
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_reservation public.reservations%rowtype;
  v_previous_status public.reservation_status;
  v_comment text := nullif(trim(coalesce(p_comment, '')), '');
  v_class_name text;
  v_session_start timestamptz;
  v_pass_name text := '수강권';
  v_remaining_count integer := 0;
  v_title text;
  v_body text;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  if v_comment is null then
    raise exception '취소 사유를 입력하세요';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
     and reservation.studio_id = v_studio_id
   for update;

  if not found then
    raise exception '예약 정보를 찾을 수 없습니다';
  end if;

  if v_reservation.status not in (
    'reserved',
    'waitlisted',
    'cancel_requested',
    'studio_rejected'
  ) then
    raise exception '이 예약은 스튜디오 취소 처리할 수 없습니다';
  end if;

  select template.name, session.start_at
    into v_class_name, v_session_start
    from public.class_sessions session
    join public.class_templates template
      on template.id = session.class_template_id
   where session.id = v_reservation.class_session_id;

  v_previous_status := v_reservation.status;

  update public.reservations
     set status = 'studio_cancelled',
         is_waitlisted = false,
         waitlist_order = null,
         approved_cancel_at = timezone('utc', now()),
         approved_cancel_by_admin_id = auth.uid(),
         approved_cancel_comment = v_comment,
         cancel_request_response_comment = case
           when v_reservation.status = 'cancel_requested' then v_comment
           else cancel_request_response_comment
         end,
         cancel_request_processed_at = case
           when v_reservation.status = 'cancel_requested' then timezone('utc', now())
           else cancel_request_processed_at
         end,
         cancel_request_processed_by_admin_id = case
           when v_reservation.status = 'cancel_requested' then auth.uid()
           else cancel_request_processed_by_admin_id
         end
   where id = v_reservation.id
   returning *
    into v_reservation;

  if v_previous_status in ('reserved', 'cancel_requested', 'studio_rejected') then
    insert into public.pass_usage_ledger (
      studio_id,
      user_pass_id,
      reservation_id,
      entry_type,
      count_delta,
      memo
    ) values (
      v_reservation.studio_id,
      v_reservation.user_pass_id,
      v_reservation.id,
      'restored',
      1,
      'Admin removed member from session'
    )
    on conflict (reservation_id, entry_type) do nothing;

  end if;

  select context.pass_name, context.remaining_count
    into v_pass_name, v_remaining_count
    from public.get_user_pass_notification_context(v_reservation.user_pass_id) context;

  if v_previous_status = 'waitlisted' then
    v_title := '대기 예약 취소 안내';
    v_body := format(
      '%s %s 대기 예약이 스튜디오에 의해 취소되었습니다. 관리자 메모: %s 현재 %s 잔여 횟수는 %s회입니다.',
      to_char(
        timezone('Asia/Seoul', v_session_start),
        'FMMM"월" FMDD"일" HH24:MI'
      ),
      coalesce(v_class_name, '수업'),
      v_comment,
      coalesce(v_pass_name, '수강권'),
      coalesce(v_remaining_count, 0)
    );
  else
    v_title := '수업 예약 취소 안내';
    v_body := format(
      '%s %s 예약이 스튜디오에 의해 취소되었습니다. 관리자 메모: %s 현재 %s 잔여 횟수는 %s회입니다.',
      to_char(
        timezone('Asia/Seoul', v_session_start),
        'FMMM"월" FMDD"일" HH24:MI'
      ),
      coalesce(v_class_name, '수업'),
      v_comment,
      coalesce(v_pass_name, '수강권'),
      coalesce(v_remaining_count, 0)
    );
  end if;

  perform public.create_user_notification(
    p_studio_id => v_reservation.studio_id,
    p_user_id => v_reservation.user_id,
    p_kind => 'session_reservation_removed',
    p_title => v_title,
    p_body => v_body,
    p_is_important => true,
    p_related_entity_type => 'reservation',
    p_related_entity_id => v_reservation.id
  );

  return v_reservation;
end;
$$;


create or replace function public.approve_waitlisted_reservation_admin(
  p_reservation_id uuid
)
returns public.reservations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_studio_id uuid := public.current_admin_studio_id();
  v_reservation public.reservations%rowtype;
  v_session public.class_sessions%rowtype;
  v_top_waitlist_id uuid;
  v_reserved_count integer;
  v_pass_is_usable boolean;
  v_class_name text;
  v_pass_name text := '수강권';
  v_remaining_count integer := 0;
begin
  if v_studio_id is null then
    raise exception 'Admin authentication required';
  end if;

  select reservation.*
    into v_reservation
    from public.reservations reservation
   where reservation.id = p_reservation_id
     and reservation.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'waitlisted' then
    raise exception 'Reservation is not waitlisted';
  end if;

  select session.*
    into v_session
    from public.class_sessions session
   where session.id = v_reservation.class_session_id
     and session.studio_id = v_studio_id
   for update;

  if not found then
    raise exception 'Session not found';
  end if;

  if v_session.status <> 'scheduled' then
    raise exception 'Session is not reservable';
  end if;

  if v_session.start_at <= timezone('utc', now()) then
    raise exception 'Started sessions cannot accept waitlist approval';
  end if;

  select reservation.id
    into v_top_waitlist_id
    from public.reservations reservation
   where reservation.class_session_id = v_reservation.class_session_id
     and reservation.status = 'waitlisted'
   order by reservation.waitlist_order asc nulls last, reservation.created_at asc
   limit 1
   for update;

  if v_top_waitlist_id is distinct from v_reservation.id then
    raise exception 'Top waitlisted member must be processed first';
  end if;

  select count(*)
    into v_reserved_count
    from public.reservations reservation
   where reservation.class_session_id = v_reservation.class_session_id
     and reservation.status in (
       'reserved',
       'cancel_requested',
       'studio_rejected'
     );

  if v_reserved_count >= v_session.capacity then
    raise exception 'No seats available for waitlist approval';
  end if;

  select exists (
    select 1
      from public.user_passes user_pass
     where user_pass.id = v_reservation.user_pass_id
       and user_pass.user_id = v_reservation.user_id
       and user_pass.studio_id = v_session.studio_id
       and user_pass.status = 'active'
       and v_session.session_date between user_pass.valid_from and user_pass.valid_until
       and not public.is_user_pass_held_on(user_pass.id, v_session.session_date)
       and exists (
         select 1
           from public.pass_product_template_mappings mapping
          where mapping.pass_product_id = user_pass.pass_product_id
            and mapping.class_template_id = v_session.class_template_id
       )
       and coalesce((
         select balance.remaining_count
           from public.get_user_pass_balance(user_pass.id) balance
       ), 0) > 0
  )
    into v_pass_is_usable;

  if not v_pass_is_usable then
    raise exception '해당 회원은 현재 이 수업에 사용할 수 있는 수강권이 없습니다';
  end if;

  update public.reservations
     set status = 'reserved',
         is_waitlisted = false,
         waitlist_order = null
   where id = v_reservation.id
   returning *
    into v_reservation;

  insert into public.pass_usage_ledger (
    studio_id,
    user_pass_id,
    reservation_id,
    entry_type,
    count_delta,
    memo
  ) values (
    v_reservation.studio_id,
    v_reservation.user_pass_id,
    v_reservation.id,
    'planned',
    -1,
    '관리자 대기 승인'
  )
  on conflict (reservation_id, entry_type) do nothing;

  select template.name
    into v_class_name
    from public.class_templates template
   where template.id = v_session.class_template_id;

  select context.pass_name, context.remaining_count
    into v_pass_name, v_remaining_count
    from public.get_user_pass_notification_context(v_reservation.user_pass_id) context;

  perform public.create_user_notification(
    p_studio_id => v_reservation.studio_id,
    p_user_id => v_reservation.user_id,
    p_kind => 'waitlist_promoted',
    p_title => '대기 예약 확정',
    p_body => format(
      '%s %s 수업이 스튜디오 확인 후 예약으로 확정되었습니다. 현재 %s 잔여 횟수는 %s회입니다.',
      to_char(
        timezone('Asia/Seoul', v_session.start_at),
        'FMMM"월" FMDD"일" HH24:MI'
      ),
      coalesce(v_class_name, '수업'),
      coalesce(v_pass_name, '수강권'),
      coalesce(v_remaining_count, 0)
    ),
    p_related_entity_type => 'reservation',
    p_related_entity_id => v_reservation.id
  );

  return v_reservation;
end;
$$;


create or replace function public.dispatch_scheduled_user_notifications()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer := 0;
  v_now timestamptz := now();
  v_notification_id uuid;
  v_row record;
begin
  for v_row in
    select
      reservation.id as reservation_id,
      reservation.studio_id,
      reservation.user_id,
      template.name as class_name,
      session.start_at
    from public.reservations reservation
    join public.class_sessions session
      on session.id = reservation.class_session_id
    join public.class_templates template
      on template.id = session.class_template_id
    where reservation.status in ('reserved', 'cancel_requested', 'studio_rejected')
      and session.status = 'scheduled'
      and session.start_at > v_now + interval '23 hours 45 minutes'
      and session.start_at <= v_now + interval '24 hours'
  loop
    v_notification_id := public.create_user_notification(
      p_studio_id => v_row.studio_id,
      p_user_id => v_row.user_id,
      p_kind => 'session_reminder_day_before',
      p_title => '수업 하루 전 안내',
      p_body => format(
        '내일 %s %s 수업이 예정되어 있습니다.',
        to_char(
          timezone('Asia/Seoul', v_row.start_at),
          'HH24:MI'
        ),
        coalesce(v_row.class_name, '수업')
      ),
      p_related_entity_type => 'reservation',
      p_related_entity_id => v_row.reservation_id,
      p_skip_if_exists => true
    );

    if v_notification_id is not null then
      v_inserted := v_inserted + 1;
    end if;
  end loop;

  for v_row in
    select
      reservation.id as reservation_id,
      reservation.studio_id,
      reservation.user_id,
      template.name as class_name,
      session.start_at
    from public.reservations reservation
    join public.class_sessions session
      on session.id = reservation.class_session_id
    join public.class_templates template
      on template.id = session.class_template_id
    where reservation.status in ('reserved', 'cancel_requested', 'studio_rejected')
      and session.status = 'scheduled'
      and session.start_at > v_now + interval '45 minutes'
      and session.start_at <= v_now + interval '60 minutes'
  loop
    v_notification_id := public.create_user_notification(
      p_studio_id => v_row.studio_id,
      p_user_id => v_row.user_id,
      p_kind => 'session_reminder_hour_before',
      p_title => '수업 1시간 전 안내',
      p_body => format(
        '잠시 후 %s %s 수업이 시작됩니다.',
        to_char(
          timezone('Asia/Seoul', v_row.start_at),
          'HH24:MI'
        ),
        coalesce(v_row.class_name, '수업')
      ),
      p_related_entity_type => 'reservation',
      p_related_entity_id => v_row.reservation_id,
      p_skip_if_exists => true
    );

    if v_notification_id is not null then
      v_inserted := v_inserted + 1;
    end if;
  end loop;

  return v_inserted;
end;
$$;


create or replace function public.setup_scheduled_user_notification_jobs()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if to_regnamespace('cron') is null then
    return;
  end if;

  perform cron.schedule(
    'eightup-user-notifications',
    '*/15 * * * *',
    $job$select public.dispatch_scheduled_user_notifications();$job$
  );
exception
  when undefined_function or invalid_schema_name then
    null;
end;
$$;
