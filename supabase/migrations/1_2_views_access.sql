-- Views, triggers, runtime/bootstrap blocks, RLS/policies, and grants.

-- Views.

drop view if exists public.v_admin_cancel_request_details;
drop view if exists public.v_admin_pass_product_details;
drop view if exists public.v_admin_operating_pass_details;
drop view if exists public.v_admin_expiring_pass_details;
drop view if exists public.v_admin_member_consult_notes;
drop view if exists public.v_admin_member_pass_histories;
drop view if exists public.v_admin_member_directory;
drop view if exists public.v_admin_monthly_financial_metrics;
drop view if exists public.v_admin_session_reservation_summary;
drop view if exists public.v_admin_monthly_class_metrics;
drop view if exists public.v_admin_dashboard_metrics;
drop view if exists public.v_admin_class_session_feed;
drop view if exists public.v_class_session_feed;
drop view if exists public.v_user_reservation_details;
drop view if exists public.v_user_pass_usage_entries;
drop view if exists public.v_user_pass_summaries;


create or replace view public.v_user_pass_summaries
with (security_invoker = true)
as
select
  user_pass.id,
  user_pass.studio_id,
  user_pass.user_id,
  user_pass.pass_product_id,
  user_pass.name_snapshot,
  user_pass.total_count,
  user_pass.valid_from,
  user_pass.valid_until,
  user_pass.paid_amount,
  user_pass.refunded_amount,
  user_pass.status,
  coalesce(balance.planned_count, 0) as planned_count,
  coalesce(balance.completed_count, 0) as completed_count,
  (user_pass.total_count - coalesce(balance.planned_count, 0) - coalesce(balance.completed_count, 0))::integer as remaining_count,
  coalesce(holds.hold_periods, '[]'::jsonb) as hold_periods,
  coalesce(allowed.allowed_class_template_ids, '{}'::uuid[]) as allowed_class_template_ids,
  coalesce(allowed.allowed_class_template_names, '{}'::text[]) as allowed_class_template_names
from public.user_passes user_pass
  left join lateral (
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
    ), 0)::integer as completed_count
  from public.reservations reservation
  left join public.class_sessions session
    on session.id = reservation.class_session_id
  where reservation.user_pass_id = user_pass.id
) balance on true
left join lateral (
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'hold_from', hold.hold_from,
          'hold_until', hold.hold_until
        )
        order by hold.hold_from
      ),
      '[]'::jsonb
    ) as hold_periods
  from public.user_pass_holds hold
  where hold.user_pass_id = user_pass.id
) holds on true
left join lateral (
  select
    coalesce(array_agg(distinct class_template.id), '{}'::uuid[]) as allowed_class_template_ids,
    coalesce(array_agg(distinct class_template.name), '{}'::text[]) as allowed_class_template_names
  from public.pass_product_template_mappings mapping
  join public.class_templates class_template
    on class_template.id = mapping.class_template_id
  where mapping.pass_product_id = user_pass.pass_product_id
) allowed on true;


create or replace view public.v_user_pass_usage_entries
with (security_invoker = true)
as
select
  ledger.id,
  ledger.studio_id,
  ledger.user_pass_id,
  ledger.reservation_id,
  ledger.entry_type,
  ledger.count_delta,
  ledger.memo,
  ledger.created_at,
  reservation.status as reservation_status,
  reservation.class_session_id,
  session.start_at as session_start_at,
  session.end_at as session_end_at,
  class_template.name as class_name
from public.pass_usage_ledger ledger
left join public.reservations reservation
  on reservation.id = ledger.reservation_id
left join public.class_sessions session
  on session.id = reservation.class_session_id
left join public.class_templates class_template
  on class_template.id = session.class_template_id;


create or replace view public.v_user_reservation_details
with (security_invoker = true)
as
select
  reservation.id,
  reservation.studio_id,
  reservation.user_id,
  reservation.class_session_id,
  reservation.user_pass_id,
  reservation.status,
  reservation.request_cancel_reason,
  reservation.requested_cancel_at,
  reservation.approved_cancel_at,
  reservation.is_waitlisted,
  reservation.waitlist_order,
  reservation.created_at,
  reservation.updated_at,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status as session_status,
  class_template.id as class_template_id,
  class_template.name as class_name,
  class_template.category,
  class_template.description,
  (
    session.capacity
    - coalesce(count(*) filter (
      where sibling_reservation.status in (
        'reserved',
        'cancel_requested',
        'studio_rejected'
      )
    ), 0)
  )::integer as spots_left,
  coalesce(count(*) filter (
    where sibling_reservation.status = 'waitlisted'
  ), 0)::integer as waitlist_count,
  user_pass.name_snapshot as pass_name,
  case
    when reservation.status = 'reserved'
      and session.start_at > now()
      and now() < public.calculate_session_cancel_cutoff(
        session.session_date,
        session.start_at,
        studio.cancel_policy_mode,
        studio.cancel_policy_hours_before,
        studio.cancel_policy_days_before,
        studio.cancel_policy_cutoff_time
      )
    then true
    else false
  end as can_cancel_directly,
  case
    when reservation.status = 'reserved'
      and session.start_at > now()
      and now() >= public.calculate_session_cancel_cutoff(
        session.session_date,
        session.start_at,
        studio.cancel_policy_mode,
        studio.cancel_policy_hours_before,
        studio.cancel_policy_days_before,
        studio.cancel_policy_cutoff_time
      )
    then true
    else false
  end as can_request_cancel
from public.reservations reservation
join public.class_sessions session
  on session.id = reservation.class_session_id
left join public.reservations sibling_reservation
  on sibling_reservation.class_session_id = session.id
join public.studios studio
  on studio.id = reservation.studio_id
join public.class_templates class_template
  on class_template.id = session.class_template_id
join public.user_passes user_pass
  on user_pass.id = reservation.user_pass_id
group by
  reservation.id,
  session.id,
  class_template.id,
  user_pass.id,
  studio.cancel_policy_mode,
  studio.cancel_policy_hours_before,
  studio.cancel_policy_days_before,
  studio.cancel_policy_cutoff_time;


create or replace view public.v_class_session_feed
with (security_invoker = true)
as
select
  session.id,
  session.studio_id,
  session.class_template_id,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status,
  class_template.name as class_name,
  class_template.category,
  class_template.description,
  instructor.name as instructor_name,
  instructor.image_url as instructor_image_url,
  (
    session.capacity
    - coalesce(count(*) filter (
      where reservation.status in (
        'reserved',
        'cancel_requested',
        'studio_rejected'
      )
    ), 0)
  )::integer as spots_left,
  coalesce(count(*) filter (
    where reservation.status = 'waitlisted'
  ), 0)::integer as waitlist_count,
  current_reservation.id as my_reservation_id,
  current_reservation.status as my_reservation_status,
  coalesce(current_reservation.can_cancel_directly, false) as can_cancel_directly,
  coalesce(current_reservation.can_request_cancel, false) as can_request_cancel
from public.class_sessions session
join public.class_templates class_template
  on class_template.id = session.class_template_id
join public.studios studio
  on studio.id = session.studio_id
left join public.instructors instructor
  on instructor.id = session.instructor_id
left join lateral (
  select
    reservation.id,
    reservation.status,
    case
      when reservation.status = 'reserved'
        and session.start_at > now()
        and now() < public.calculate_session_cancel_cutoff(
          session.session_date,
          session.start_at,
          studio.cancel_policy_mode,
          studio.cancel_policy_hours_before,
          studio.cancel_policy_days_before,
          studio.cancel_policy_cutoff_time
        )
      then true
      when reservation.status = 'waitlisted'
      then true
      else false
    end as can_cancel_directly,
    case
      when reservation.status = 'reserved'
        and session.start_at > now()
        and now() >= public.calculate_session_cancel_cutoff(
          session.session_date,
          session.start_at,
          studio.cancel_policy_mode,
          studio.cancel_policy_hours_before,
          studio.cancel_policy_days_before,
          studio.cancel_policy_cutoff_time
        )
      then true
      else false
    end as can_request_cancel
  from public.reservations reservation
  where reservation.class_session_id = session.id
    and reservation.user_id = auth.uid()
    and (
      reservation.status in (
        'reserved',
        'waitlisted',
        'cancel_requested',
        'completed',
        'studio_cancelled',
        'studio_rejected'
      )
      or (
        reservation.status = 'cancelled'
        and reservation.approved_cancel_at is not null
      )
    )
  order by reservation.created_at desc
  limit 1
) current_reservation
  on true
left join public.reservations reservation
  on reservation.class_session_id = session.id
group by
  session.id,
  session.studio_id,
  session.class_template_id,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status,
  class_template.name,
  class_template.category,
  class_template.description,
  instructor.name,
  instructor.image_url,
  studio.cancel_policy_mode,
  studio.cancel_policy_hours_before,
  studio.cancel_policy_days_before,
  studio.cancel_policy_cutoff_time,
  current_reservation.id,
  current_reservation.status,
  current_reservation.can_cancel_directly,
  current_reservation.can_request_cancel;


create or replace view public.v_admin_class_session_feed
with (security_invoker = true)
as
select
  session.id,
  session.studio_id,
  session.class_template_id,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status,
  session.instructor_id,
  class_template.name as class_name,
  class_template.category,
  class_template.description,
  instructor.name as instructor_name,
  instructor.image_url as instructor_image_url,
  (
    session.capacity
    - coalesce(count(*) filter (
      where reservation.status in (
        'reserved',
        'completed',
        'cancel_requested',
        'studio_rejected'
      )
    ), 0)
  )::integer as spots_left,
  coalesce(count(*) filter (
    where reservation.status = 'waitlisted'
  ), 0)::integer as waitlist_count
from public.class_sessions session
join public.class_templates class_template
  on class_template.id = session.class_template_id
left join public.instructors instructor
  on instructor.id = session.instructor_id
left join public.reservations reservation
  on reservation.class_session_id = session.id
group by
  session.id,
  session.studio_id,
  session.class_template_id,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status,
  session.instructor_id,
  class_template.name,
  class_template.category,
  class_template.description,
  instructor.name,
  instructor.image_url;


drop view if exists public.v_user_reservation_details;


create or replace view public.v_user_reservation_details
with (security_invoker = true)
as
select
  reservation.id,
  reservation.studio_id,
  reservation.user_id,
  reservation.class_session_id,
  reservation.user_pass_id,
  reservation.status,
  reservation.request_cancel_reason,
  reservation.requested_cancel_at,
  reservation.approved_cancel_at,
  reservation.approved_cancel_comment,
  admin_user.name as approved_cancel_admin_name,
  reservation.is_waitlisted,
  reservation.waitlist_order,
  reservation.created_at,
  reservation.updated_at,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status as session_status,
  session.instructor_id,
  class_template.id as class_template_id,
  class_template.name as class_name,
  class_template.category,
  class_template.description,
  instructor.name as instructor_name,
  instructor.image_url as instructor_image_url,
  (
    session.capacity
    - coalesce(count(*) filter (
      where sibling_reservation.status in (
        'reserved',
        'completed',
        'cancel_requested',
        'studio_rejected'
      )
    ), 0)
  )::integer as spots_left,
  coalesce(count(*) filter (
    where sibling_reservation.status = 'waitlisted'
  ), 0)::integer as waitlist_count,
  user_pass.name_snapshot as pass_name,
  case
    when reservation.status = 'reserved'
      and session.start_at > now()
      and now() < public.calculate_session_cancel_cutoff(
        session.session_date,
        session.start_at,
        studio.cancel_policy_mode,
        studio.cancel_policy_hours_before,
        studio.cancel_policy_days_before,
        studio.cancel_policy_cutoff_time
      )
    then true
    else false
  end as can_cancel_directly,
  case
    when reservation.status = 'reserved'
      and session.start_at > now()
      and now() >= public.calculate_session_cancel_cutoff(
        session.session_date,
        session.start_at,
        studio.cancel_policy_mode,
        studio.cancel_policy_hours_before,
        studio.cancel_policy_days_before,
        studio.cancel_policy_cutoff_time
      )
    then true
    else false
  end as can_request_cancel
from public.reservations reservation
join public.class_sessions session
  on session.id = reservation.class_session_id
left join public.reservations sibling_reservation
  on sibling_reservation.class_session_id = session.id
join public.studios studio
  on studio.id = reservation.studio_id
join public.class_templates class_template
  on class_template.id = session.class_template_id
left join public.instructors instructor
  on instructor.id = session.instructor_id
join public.user_passes user_pass
  on user_pass.id = reservation.user_pass_id
left join public.admin_users admin_user
  on admin_user.id = reservation.approved_cancel_by_admin_id
group by
  reservation.id,
  session.id,
  class_template.id,
  user_pass.id,
  session.capacity,
  session.instructor_id,
  studio.cancel_policy_mode,
  studio.cancel_policy_hours_before,
  studio.cancel_policy_days_before,
  studio.cancel_policy_cutoff_time,
  admin_user.name,
  instructor.name,
  instructor.image_url;


drop view if exists public.v_user_reservation_details;


create or replace view public.v_user_reservation_details
with (security_invoker = true)
as
select
  reservation.id,
  reservation.studio_id,
  reservation.user_id,
  reservation.class_session_id,
  reservation.user_pass_id,
  reservation.status,
  reservation.request_cancel_reason,
  reservation.requested_cancel_at,
  reservation.approved_cancel_at,
  reservation.approved_cancel_comment,
  approving_admin.name as approved_cancel_admin_name,
  reservation.cancel_request_response_comment,
  reservation.cancel_request_processed_at,
  processed_admin.name as cancel_request_processed_admin_name,
  reservation.is_waitlisted,
  reservation.waitlist_order,
  reservation.created_at,
  reservation.updated_at,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status as session_status,
  session.instructor_id,
  class_template.id as class_template_id,
  class_template.name as class_name,
  class_template.category,
  class_template.description,
  instructor.name as instructor_name,
  instructor.image_url as instructor_image_url,
  (
    session.capacity
    - coalesce(count(*) filter (
      where sibling_reservation.status in (
        'reserved',
        'completed',
        'cancel_requested',
        'studio_rejected'
      )
    ), 0)
  )::integer as spots_left,
  coalesce(count(*) filter (
    where sibling_reservation.status = 'waitlisted'
  ), 0)::integer as waitlist_count,
  user_pass.name_snapshot as pass_name,
  case
    when reservation.status = 'reserved'
      and session.start_at > now()
      and now() < public.calculate_session_cancel_cutoff(
        session.session_date,
        session.start_at,
        studio.cancel_policy_mode,
        studio.cancel_policy_hours_before,
        studio.cancel_policy_days_before,
        studio.cancel_policy_cutoff_time
      )
    then true
    else false
  end as can_cancel_directly,
  case
    when reservation.status = 'reserved'
      and session.start_at > now()
      and now() >= public.calculate_session_cancel_cutoff(
        session.session_date,
        session.start_at,
        studio.cancel_policy_mode,
        studio.cancel_policy_hours_before,
        studio.cancel_policy_days_before,
        studio.cancel_policy_cutoff_time
      )
    then true
    else false
  end as can_request_cancel
from public.reservations reservation
join public.class_sessions session
  on session.id = reservation.class_session_id
left join public.reservations sibling_reservation
  on sibling_reservation.class_session_id = session.id
join public.studios studio
  on studio.id = reservation.studio_id
join public.class_templates class_template
  on class_template.id = session.class_template_id
left join public.instructors instructor
  on instructor.id = session.instructor_id
join public.user_passes user_pass
  on user_pass.id = reservation.user_pass_id
left join public.admin_users approving_admin
  on approving_admin.id = reservation.approved_cancel_by_admin_id
left join public.admin_users processed_admin
  on processed_admin.id = reservation.cancel_request_processed_by_admin_id
group by
  reservation.id,
  session.id,
  class_template.id,
  user_pass.id,
  session.capacity,
  session.instructor_id,
  studio.cancel_policy_mode,
  studio.cancel_policy_hours_before,
  studio.cancel_policy_days_before,
  studio.cancel_policy_cutoff_time,
  approving_admin.name,
  processed_admin.name,
  instructor.name,
  instructor.image_url;


create or replace view public.v_admin_dashboard_metrics
with (security_invoker = true)
as
with context as (
  select public.current_admin_studio_id() as studio_id,
         timezone('Asia/Seoul', now())::date as today_local,
         (date_trunc('month', timezone('Asia/Seoul', now())) - interval '1 month') as previous_month_start,
         date_trunc('month', timezone('Asia/Seoul', now())) as month_start,
         (date_trunc('month', timezone('Asia/Seoul', now())) + interval '1 month') as month_end
)
select
  context.studio_id,
  coalesce((
    select count(*)
      from public.class_sessions session
     where session.studio_id = context.studio_id
       and session.session_date = context.today_local
  ), 0)::integer as today_session_count,
  coalesce((
    select count(*)
      from public.reservations reservation
     join public.class_sessions session
       on session.id = reservation.class_session_id
     where reservation.studio_id = context.studio_id
       and reservation.status in (
         'reserved',
         'cancel_requested',
         'studio_rejected'
       )
       and session.session_date = context.today_local
  ), 0)::integer as today_reserved_count,
  coalesce((
    select sum(user_pass.paid_amount)
      from public.user_passes user_pass
     where user_pass.studio_id = context.studio_id
       and user_pass.created_at >= context.month_start
       and user_pass.created_at < context.month_end
  ), 0)::numeric(12, 2) as month_sales_amount,
  coalesce((
    select sum(user_pass.paid_amount)
      from public.user_passes user_pass
     where user_pass.studio_id = context.studio_id
       and user_pass.created_at >= context.previous_month_start
       and user_pass.created_at < context.month_start
  ), 0)::numeric(12, 2) as previous_month_sales_amount,
  coalesce((
    select sum(refund_log.refund_amount)
      from public.refund_logs refund_log
     where refund_log.studio_id = context.studio_id
       and refund_log.created_at >= context.month_start
       and refund_log.created_at < context.month_end
  ), 0)::numeric(12, 2) as month_refund_amount,
  coalesce((
    select count(*)
      from public.user_passes user_pass
     where user_pass.studio_id = context.studio_id
       and user_pass.status = 'active'
       and context.today_local between user_pass.valid_from and user_pass.valid_until
  ), 0)::integer as operating_pass_count,
  coalesce((
    select count(*)
      from public.user_passes user_pass
      left join lateral (
        select
          coalesce(count(*) filter (
            where reservation.status in (
              'reserved',
              'cancel_requested',
              'studio_rejected'
            )
              and session.start_at > timezone('utc', now())
          ), 0)::integer as planned_count,
          coalesce(count(*) filter (
            where reservation.status = 'completed'
          ), 0)::integer as completed_count
        from public.reservations reservation
        left join public.class_sessions session
          on session.id = reservation.class_session_id
        where reservation.user_pass_id = user_pass.id
      ) balance on true
     where user_pass.studio_id = context.studio_id
       and user_pass.status = 'active'
       and user_pass.valid_until >= context.month_start::date
       and user_pass.valid_until < context.month_end::date
       and (user_pass.total_count - coalesce(balance.planned_count, 0) - coalesce(balance.completed_count, 0)) > 0
  ), 0)::integer as expiring_pass_count,
  coalesce((
    select count(*)
      from public.reservations reservation
     where reservation.studio_id = context.studio_id
       and reservation.status = 'cancel_requested'
       and reservation.requested_cancel_at is not null
  ), 0)::integer as pending_cancel_request_count,
  coalesce((
    select sum(refund_log.refund_amount)
      from public.refund_logs refund_log
     where refund_log.studio_id = context.studio_id
       and refund_log.created_at >= context.previous_month_start
       and refund_log.created_at < context.month_start
  ), 0)::numeric(12, 2) as previous_month_refund_amount
from context
where context.studio_id is not null;


create or replace view public.v_admin_monthly_class_metrics
with (security_invoker = true)
as
with context as (
  select public.current_admin_studio_id() as studio_id,
         date_trunc('month', timezone('Asia/Seoul', now()))::date as month_start,
         (date_trunc('month', timezone('Asia/Seoul', now())) + interval '1 month')::date as month_end
),
session_reservation_counts as (
  select
    session.id,
    session.studio_id,
    session.class_template_id,
    case
      when session.status = 'cancelled' then 0
      else count(reservation.id) filter (
        where reservation.status in (
          'reserved',
          'completed',
          'cancel_requested',
          'studio_rejected'
        )
      )
    end::integer as reserved_count
  from public.class_sessions session
  join context
    on context.studio_id = session.studio_id
  left join public.reservations reservation
    on reservation.class_session_id = session.id
  where session.session_date >= context.month_start
    and session.session_date < context.month_end
  group by session.id
)
select
  class_template.id as class_template_id,
  class_template.studio_id,
  class_template.name as class_name,
  class_template.category,
  class_template.capacity,
  coalesce(count(session_count.id) filter (where session_count.id is not null), 0)::integer as opened_session_count,
  coalesce(round(avg(session_count.reserved_count::numeric), 1), 0)::numeric(8, 1) as avg_reserved_count
from public.class_templates class_template
join context
  on context.studio_id = class_template.studio_id
left join session_reservation_counts session_count
  on session_count.class_template_id = class_template.id
where class_template.status = 'active'
group by
  class_template.id,
  class_template.studio_id,
  class_template.name,
  class_template.category,
  class_template.capacity;


create or replace view public.v_admin_session_reservation_summary
with (security_invoker = true)
as
select
  session.id as class_session_id,
  session.studio_id,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status as session_status,
  class_template.name as class_name,
  class_template.category,
  coalesce(count(reservation.id) filter (
    where reservation.status in (
      'reserved',
      'completed',
      'cancel_requested',
      'studio_rejected'
    )
  ), 0)::integer as reservation_count
from public.class_sessions session
join public.class_templates class_template
  on class_template.id = session.class_template_id
left join public.reservations reservation
  on reservation.class_session_id = session.id
group by
  session.id,
  session.studio_id,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status,
  class_template.name,
  class_template.category;


create or replace view public.v_admin_monthly_financial_metrics
with (security_invoker = true)
as
with context as (
  select public.current_admin_studio_id() as studio_id,
         date_trunc('month', timezone('Asia/Seoul', now()))::date as current_month
),
bounds as (
  select
    context.studio_id,
    coalesce(
      least(
        coalesce((
          select min(date_trunc('month', user_pass.created_at at time zone 'Asia/Seoul')::date)
            from public.user_passes user_pass
           where user_pass.studio_id = context.studio_id
        ), context.current_month),
        coalesce((
          select min(date_trunc('month', refund_log.refunded_at at time zone 'Asia/Seoul')::date)
            from public.refund_logs refund_log
           where refund_log.studio_id = context.studio_id
        ), context.current_month)
      ),
      context.current_month
    ) as first_month,
    context.current_month
  from context
  where context.studio_id is not null
),
month_series as (
  select
    bounds.studio_id,
    generate_series(bounds.first_month, bounds.current_month, interval '1 month')::date as month_start
  from bounds
),
sales as (
  select
    user_pass.studio_id,
    date_trunc('month', user_pass.created_at at time zone 'Asia/Seoul')::date as month_start,
    sum(user_pass.paid_amount)::numeric(12, 2) as sales_amount
  from public.user_passes user_pass
  group by user_pass.studio_id, date_trunc('month', user_pass.created_at at time zone 'Asia/Seoul')::date
),
refunds as (
  select
    refund_log.studio_id,
    date_trunc('month', refund_log.refunded_at at time zone 'Asia/Seoul')::date as month_start,
    sum(refund_log.refund_amount)::numeric(12, 2) as refund_amount
  from public.refund_logs refund_log
  group by refund_log.studio_id, date_trunc('month', refund_log.refunded_at at time zone 'Asia/Seoul')::date
)
select
  month_series.studio_id,
  month_series.month_start,
  coalesce(sales.sales_amount, 0)::numeric(12, 2) as sales_amount,
  coalesce(refunds.refund_amount, 0)::numeric(12, 2) as refund_amount
from month_series
left join sales
  on sales.studio_id = month_series.studio_id
 and sales.month_start = month_series.month_start
left join refunds
  on refunds.studio_id = month_series.studio_id
 and refunds.month_start = month_series.month_start
order by month_series.month_start asc;


create or replace view public.v_admin_member_directory
with (security_invoker = true)
as
select
  membership.id as membership_id,
  membership.studio_id,
  membership.user_id,
  membership.membership_status,
  membership.joined_at,
  app_user.member_code,
  app_user.name,
  app_user.email,
  app_user.phone,
  coalesce(pass_summary.active_pass_count, 0)::integer as active_pass_count,
  pass_summary.latest_pass_valid_until,
  coalesce(pass_summary.has_expiring_soon_active_pass, false) as has_expiring_soon_active_pass,
  pass_summary.expiring_soon_active_pass_days
from public.studio_user_memberships membership
join public.users app_user
  on app_user.id = membership.user_id
left join lateral (
  select
    count(*) filter (where user_pass.status = 'active')::integer as active_pass_count,
    max(user_pass.valid_until) as latest_pass_valid_until,
    bool_or(
      user_pass.status = 'active'
      and user_pass.valid_until >= timezone('Asia/Seoul', now())::date
      and user_pass.valid_until <= (timezone('Asia/Seoul', now())::date + 14)
    ) as has_expiring_soon_active_pass,
    min((user_pass.valid_until - timezone('Asia/Seoul', now())::date)::integer) filter (
      where user_pass.status = 'active'
        and user_pass.valid_until >= timezone('Asia/Seoul', now())::date
        and user_pass.valid_until <= (timezone('Asia/Seoul', now())::date + 14)
    ) as expiring_soon_active_pass_days
  from public.user_passes user_pass
  where user_pass.studio_id = membership.studio_id
    and user_pass.user_id = membership.user_id
    and user_pass.status <> 'inactive'
) pass_summary on true;


create or replace view public.v_admin_member_pass_histories
with (security_invoker = true)
as
select
  user_pass.id,
  user_pass.studio_id,
  user_pass.user_id,
  app_user.member_code,
  app_user.name as member_name,
  user_pass.pass_product_id,
  user_pass.name_snapshot as pass_name,
  user_pass.total_count,
  user_pass.valid_from,
  user_pass.valid_until,
  user_pass.paid_amount,
  user_pass.refunded_amount,
  user_pass.status,
  user_pass.created_at as issued_at,
  coalesce(balance.planned_count, 0) as planned_count,
  coalesce(balance.completed_count, 0) as completed_count,
  (user_pass.total_count - coalesce(balance.planned_count, 0) - coalesce(balance.completed_count, 0))::integer as remaining_count,
  coalesce(hold_summary.total_hold_days, 0) as total_hold_days,
  active_hold.hold_from as active_hold_from,
  active_hold.hold_until as active_hold_until,
  latest_hold.hold_from as latest_hold_from,
  latest_hold.hold_until as latest_hold_until,
  latest_refund.refunded_at as latest_refunded_at,
  latest_refund.refund_reason as latest_refund_reason
from public.user_passes user_pass
join public.users app_user
  on app_user.id = user_pass.user_id
left join lateral (
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
    ), 0)::integer as completed_count
  from public.reservations reservation
  left join public.class_sessions session
    on session.id = reservation.class_session_id
  where reservation.user_pass_id = user_pass.id
) balance on true
left join lateral (
  select
    coalesce(sum((hold.hold_until - hold.hold_from + 1)), 0)::integer as total_hold_days
  from public.user_pass_holds hold
  where hold.user_pass_id = user_pass.id
) hold_summary on true
left join lateral (
  select
    hold.hold_from,
    hold.hold_until
  from public.user_pass_holds hold
  where hold.user_pass_id = user_pass.id
    and timezone('Asia/Seoul', now())::date between hold.hold_from and hold.hold_until
  order by hold.hold_from desc
  limit 1
) active_hold on true
left join lateral (
  select
    hold.hold_from,
    hold.hold_until
  from public.user_pass_holds hold
  where hold.user_pass_id = user_pass.id
  order by hold.hold_until desc, hold.hold_from desc
  limit 1
) latest_hold on true
left join lateral (
  select
    refund_log.refunded_at,
    refund_log.refund_reason
  from public.refund_logs refund_log
  where refund_log.user_pass_id = user_pass.id
  order by refund_log.refunded_at desc
  limit 1
) latest_refund on true;


create or replace view public.v_admin_member_consult_notes
with (security_invoker = true)
as
select
  consult_note.id,
  consult_note.studio_id,
  consult_note.user_id,
  app_user.member_code,
  app_user.name as member_name,
  consult_note.consulted_on,
  consult_note.note,
  consult_note.created_at,
  consult_note.updated_at,
  consult_note.created_by_admin_id,
  creator.name as created_by_admin_name
from public.member_consult_notes consult_note
join public.users app_user
  on app_user.id = consult_note.user_id
left join public.admin_users creator
  on creator.id = consult_note.created_by_admin_id;


create or replace view public.v_admin_expiring_pass_details
with (security_invoker = true)
as
with context as (
  select public.current_admin_studio_id() as studio_id,
         timezone('Asia/Seoul', now())::date as today_local,
         date_trunc('month', timezone('Asia/Seoul', now()))::date as month_start,
         (date_trunc('month', timezone('Asia/Seoul', now())) + interval '1 month')::date as month_end
)
select
  user_pass.id,
  user_pass.studio_id,
  user_pass.user_id,
  app_user.member_code,
  app_user.name as member_name,
  app_user.phone as member_phone,
  user_pass.name_snapshot as pass_name,
  user_pass.valid_from,
  user_pass.valid_until,
  coalesce(balance.planned_count, 0) as planned_count,
  coalesce(balance.completed_count, 0) as completed_count,
  (user_pass.total_count - coalesce(balance.planned_count, 0) - coalesce(balance.completed_count, 0))::integer as remaining_count,
  (user_pass.valid_until - context.today_local)::integer as days_until_expiry
from context
join public.user_passes user_pass
  on user_pass.studio_id = context.studio_id
join public.users app_user
  on app_user.id = user_pass.user_id
left join lateral (
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
    ), 0)::integer as completed_count
  from public.reservations reservation
  left join public.class_sessions session
    on session.id = reservation.class_session_id
  where reservation.user_pass_id = user_pass.id
) balance on true
where user_pass.status = 'active'
  and user_pass.valid_until >= context.month_start
  and user_pass.valid_until < context.month_end
  and (user_pass.total_count - coalesce(balance.planned_count, 0) - coalesce(balance.completed_count, 0)) > 0;


create or replace view public.v_admin_operating_pass_details
with (security_invoker = true)
as
with context as (
  select public.current_admin_studio_id() as studio_id,
         timezone('Asia/Seoul', now())::date as today_local
)
select
  user_pass.id,
  user_pass.studio_id,
  user_pass.user_id,
  app_user.member_code,
  app_user.name as member_name,
  app_user.phone as member_phone,
  user_pass.name_snapshot as pass_name,
  user_pass.valid_from,
  user_pass.valid_until,
  coalesce(balance.planned_count, 0) as planned_count,
  coalesce(balance.completed_count, 0) as completed_count,
  (user_pass.total_count - coalesce(balance.planned_count, 0) - coalesce(balance.completed_count, 0))::integer as remaining_count,
  (user_pass.valid_until - context.today_local)::integer as days_until_expiry
from context
join public.user_passes user_pass
  on user_pass.studio_id = context.studio_id
join public.users app_user
  on app_user.id = user_pass.user_id
left join lateral (
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
    ), 0)::integer as completed_count
  from public.reservations reservation
  left join public.class_sessions session
    on session.id = reservation.class_session_id
  where reservation.user_pass_id = user_pass.id
) balance on true
where user_pass.status = 'active'
  and context.today_local between user_pass.valid_from and user_pass.valid_until;


create or replace view public.v_admin_pass_product_details
with (security_invoker = true)
as
select
  product.id,
  product.studio_id,
  product.name,
  product.total_count,
  product.valid_days,
  product.price_amount,
  product.description,
  product.status,
  product.created_at,
  product.updated_at,
  coalesce(array_agg(distinct class_template.id) filter (where class_template.id is not null), '{}'::uuid[]) as allowed_template_ids,
  coalesce(array_agg(distinct class_template.name) filter (where class_template.id is not null), '{}'::text[]) as allowed_template_names
from public.pass_products product
left join public.pass_product_template_mappings mapping
  on mapping.pass_product_id = product.id
left join public.class_templates class_template
  on class_template.id = mapping.class_template_id
group by product.id;


create or replace view public.v_admin_cancel_request_details
with (security_invoker = true)
as
select
  reservation.id,
  reservation.studio_id,
  reservation.user_id,
  app_user.member_code,
  app_user.name as member_name,
  app_user.phone as member_phone,
  app_user.email as member_email,
  reservation.class_session_id,
  class_template.name as class_name,
  class_template.category,
  reservation.user_pass_id,
  user_pass.name_snapshot as pass_name,
  reservation.request_cancel_reason,
  reservation.requested_cancel_at,
  reservation.cancel_request_response_comment,
  reservation.cancel_request_processed_at,
  processed_admin.name as processed_admin_name,
  session.start_at,
  session.end_at,
  reservation.status
from public.reservations reservation
join public.users app_user
  on app_user.id = reservation.user_id
join public.class_sessions session
  on session.id = reservation.class_session_id
join public.class_templates class_template
  on class_template.id = session.class_template_id
join public.user_passes user_pass
  on user_pass.id = reservation.user_pass_id
left join public.admin_users processed_admin
  on processed_admin.id = reservation.cancel_request_processed_by_admin_id
where reservation.requested_cancel_at is not null;


drop view if exists public.v_class_session_feed;


create view public.v_class_session_feed
with (security_invoker = true)
as
select
  session.id,
  session.studio_id,
  session.class_template_id,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status,
  class_template.name as class_name,
  class_template.category,
  class_template.description,
  instructor.name as instructor_name,
  instructor.image_url as instructor_image_url,
  (session.capacity - public.get_session_reserved_count(session.id))::integer
    as spots_left,
  public.get_session_waitlist_count(session.id)::integer as waitlist_count,
  current_reservation.id as my_reservation_id,
  current_reservation.status as my_reservation_status,
  coalesce(current_reservation.can_cancel_directly, false) as can_cancel_directly,
  coalesce(current_reservation.can_request_cancel, false) as can_request_cancel,
  coalesce(current_reservation.is_cancel_locked, false) as is_cancel_locked
from public.class_sessions session
join public.class_templates class_template
  on class_template.id = session.class_template_id
join public.studios studio
  on studio.id = session.studio_id
left join public.instructors instructor
  on instructor.id = session.instructor_id
left join lateral (
  select
    reservation.id,
    reservation.status,
    case
      when reservation.status = 'reserved'
        and session.start_at > now()
        and now() < public.calculate_session_cancel_cutoff(
          session.session_date,
          session.start_at,
          studio.cancel_policy_mode,
          studio.cancel_policy_hours_before,
          studio.cancel_policy_days_before,
          studio.cancel_policy_cutoff_time
        )
      then true
      when reservation.status = 'waitlisted'
      then true
      else false
    end as can_cancel_directly,
    case
      when reservation.status = 'reserved'
        and session.start_at > now()
        and studio.cancel_inquiry_enabled
        and now() >= public.calculate_session_cancel_cutoff(
          session.session_date,
          session.start_at,
          studio.cancel_policy_mode,
          studio.cancel_policy_hours_before,
          studio.cancel_policy_days_before,
          studio.cancel_policy_cutoff_time
        )
      then true
      else false
    end as can_request_cancel,
    case
      when reservation.status = 'reserved'
        and session.start_at > now()
        and not studio.cancel_inquiry_enabled
        and now() >= public.calculate_session_cancel_cutoff(
          session.session_date,
          session.start_at,
          studio.cancel_policy_mode,
          studio.cancel_policy_hours_before,
          studio.cancel_policy_days_before,
          studio.cancel_policy_cutoff_time
        )
      then true
      else false
    end as is_cancel_locked
  from public.reservations reservation
  where reservation.class_session_id = session.id
    and reservation.user_id = auth.uid()
    and (
      reservation.status in (
        'reserved',
        'waitlisted',
        'cancel_requested',
        'cancelled',
        'completed',
        'studio_cancelled',
        'studio_rejected'
      )
    )
  order by reservation.created_at desc
  limit 1
) current_reservation
  on true;


drop view if exists public.v_user_reservation_details;


create view public.v_user_reservation_details
with (security_invoker = true)
as
select
  reservation.id,
  reservation.studio_id,
  reservation.user_id,
  reservation.class_session_id,
  reservation.user_pass_id,
  reservation.status,
  reservation.request_cancel_reason,
  reservation.requested_cancel_at,
  reservation.approved_cancel_at,
  reservation.approved_cancel_comment,
  approving_admin.name as approved_cancel_admin_name,
  reservation.cancel_request_response_comment,
  reservation.cancel_request_processed_at,
  processed_admin.name as cancel_request_processed_admin_name,
  reservation.is_waitlisted,
  reservation.waitlist_order,
  reservation.created_at,
  reservation.updated_at,
  session.session_date,
  session.start_at,
  session.end_at,
  session.capacity,
  session.status as session_status,
  session.instructor_id,
  class_template.id as class_template_id,
  class_template.name as class_name,
  class_template.category,
  class_template.description,
  instructor.name as instructor_name,
  instructor.image_url as instructor_image_url,
  (session.capacity - public.get_session_reserved_count(session.id))::integer
    as spots_left,
  public.get_session_waitlist_count(session.id)::integer as waitlist_count,
  user_pass.name_snapshot as pass_name,
  case
    when reservation.status = 'reserved'
      and session.start_at > now()
      and now() < public.calculate_session_cancel_cutoff(
        session.session_date,
        session.start_at,
        studio.cancel_policy_mode,
        studio.cancel_policy_hours_before,
        studio.cancel_policy_days_before,
        studio.cancel_policy_cutoff_time
      )
    then true
    else false
  end as can_cancel_directly,
  case
    when reservation.status = 'reserved'
      and session.start_at > now()
      and studio.cancel_inquiry_enabled
      and now() >= public.calculate_session_cancel_cutoff(
        session.session_date,
        session.start_at,
        studio.cancel_policy_mode,
        studio.cancel_policy_hours_before,
        studio.cancel_policy_days_before,
        studio.cancel_policy_cutoff_time
      )
    then true
    else false
  end as can_request_cancel,
  case
    when reservation.status = 'reserved'
      and session.start_at > now()
      and not studio.cancel_inquiry_enabled
      and now() >= public.calculate_session_cancel_cutoff(
        session.session_date,
        session.start_at,
        studio.cancel_policy_mode,
        studio.cancel_policy_hours_before,
        studio.cancel_policy_days_before,
        studio.cancel_policy_cutoff_time
      )
    then true
    else false
  end as is_cancel_locked
from public.reservations reservation
join public.class_sessions session
  on session.id = reservation.class_session_id
join public.studios studio
  on studio.id = reservation.studio_id
join public.class_templates class_template
  on class_template.id = session.class_template_id
left join public.instructors instructor
  on instructor.id = session.instructor_id
join public.user_passes user_pass
  on user_pass.id = reservation.user_pass_id
left join public.admin_users approving_admin
  on approving_admin.id = reservation.approved_cancel_by_admin_id
left join public.admin_users processed_admin
  on processed_admin.id = reservation.cancel_request_processed_by_admin_id;



-- Triggers.


drop trigger if exists set_studios_updated_at on public.studios;


create trigger set_studios_updated_at
before update on public.studios
for each row
execute function public.set_updated_at();


drop trigger if exists set_admin_users_updated_at on public.admin_users;


create trigger set_admin_users_updated_at
before update on public.admin_users
for each row
execute function public.set_updated_at();


drop trigger if exists set_platform_admin_users_updated_at on public.platform_admin_users;


create trigger set_platform_admin_users_updated_at
before update on public.platform_admin_users
for each row
execute function public.set_updated_at();


drop trigger if exists set_studio_signup_requests_updated_at on public.studio_signup_requests;


create trigger set_studio_signup_requests_updated_at
before update on public.studio_signup_requests
for each row
execute function public.set_updated_at();


drop trigger if exists set_users_updated_at on public.users;


create trigger set_users_updated_at
before update on public.users
for each row
execute function public.set_updated_at();


drop trigger if exists set_memberships_updated_at on public.studio_user_memberships;


create trigger set_memberships_updated_at
before update on public.studio_user_memberships
for each row
execute function public.set_updated_at();


drop trigger if exists set_instructors_updated_at on public.instructors;


create trigger set_instructors_updated_at
before update on public.instructors
for each row
execute function public.set_updated_at();


drop trigger if exists set_class_templates_updated_at on public.class_templates;


create trigger set_class_templates_updated_at
before update on public.class_templates
for each row
execute function public.set_updated_at();


drop trigger if exists set_pass_products_updated_at on public.pass_products;


create trigger set_pass_products_updated_at
before update on public.pass_products
for each row
execute function public.set_updated_at();


drop trigger if exists set_class_sessions_updated_at on public.class_sessions;


create trigger set_class_sessions_updated_at
before update on public.class_sessions
for each row
execute function public.set_updated_at();


drop trigger if exists set_user_passes_updated_at on public.user_passes;


create trigger set_user_passes_updated_at
before update on public.user_passes
for each row
execute function public.set_updated_at();


drop trigger if exists set_user_pass_holds_updated_at on public.user_pass_holds;


create trigger set_user_pass_holds_updated_at
before update on public.user_pass_holds
for each row
execute function public.set_updated_at();


drop trigger if exists set_reservations_updated_at on public.reservations;


create trigger set_reservations_updated_at
before update on public.reservations
for each row
execute function public.set_updated_at();


drop trigger if exists set_notices_updated_at on public.notices;


create trigger set_notices_updated_at
before update on public.notices
for each row
execute function public.set_updated_at();


drop trigger if exists set_events_updated_at on public.events;


create trigger set_events_updated_at
before update on public.events
for each row
execute function public.set_updated_at();


drop trigger if exists set_member_consult_notes_updated_at on public.member_consult_notes;


create trigger set_member_consult_notes_updated_at
before update on public.member_consult_notes
for each row
execute function public.set_updated_at();


drop trigger if exists validate_template_default_instructor on public.class_templates;


create trigger validate_template_default_instructor
before insert or update on public.class_templates
for each row
execute function public.validate_template_default_instructor();


drop trigger if exists validate_session_instructor on public.class_sessions;


create trigger validate_session_instructor
before insert or update on public.class_sessions
for each row
execute function public.validate_session_instructor();


drop trigger if exists apply_member_defaults_on_users on public.users;


create trigger apply_member_defaults_on_users
before insert on public.users
for each row
execute function public.apply_member_defaults();


drop trigger if exists prevent_member_code_mutation_on_users on public.users;


create trigger prevent_member_code_mutation_on_users
before update on public.users
for each row
execute function public.prevent_member_code_mutation();


drop trigger if exists on_auth_user_created on auth.users;


create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_auth_user();


drop trigger if exists on_auth_user_updated on auth.users;


create trigger on_auth_user_updated
after update of email, phone, raw_user_meta_data on auth.users
for each row
execute function public.handle_updated_auth_user();


drop trigger if exists on_admin_auth_user_created on auth.users;


create trigger on_admin_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_admin_auth_user();


drop trigger if exists on_admin_auth_user_confirmed on auth.users;


create trigger on_admin_auth_user_confirmed
after update of email_confirmed_at on auth.users
for each row
execute function public.handle_confirmed_admin_signup();


drop trigger if exists trg_notice_notifications on public.notices;


create trigger trg_notice_notifications
after insert or update on public.notices
for each row
execute function public.handle_notice_notifications();


drop trigger if exists trg_event_notifications on public.events;


create trigger trg_event_notifications
after insert or update on public.events
for each row
execute function public.handle_event_notifications();


drop trigger if exists trg_enqueue_notification_push_job on public.notifications;


create trigger trg_enqueue_notification_push_job
after insert on public.notifications
for each row
execute function public.enqueue_notification_push_job();



-- Runtime/bootstrap blocks.


do $$
begin
  if not exists (
    select 1
      from pg_constraint
     where conname = 'users_login_id_format'
       and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
      add constraint users_login_id_format
      check (login_id is null or login_id ~ '^[a-z0-9][a-z0-9._-]{2,31}$');
  end if;
end $$;


do $$
declare
  v_platform_admin_id uuid;
  v_platform_identity_id uuid;
  v_platform_email text := '8up_admin@8up.local';
begin
  if not exists (
    select 1
      from public.platform_admin_users platform_admin
     where lower(platform_admin.login_id) = '8up_admin'
  ) and not exists (
    select 1
      from auth.users auth_user
     where lower(coalesce(auth_user.email, '')) = v_platform_email
  ) then
    v_platform_admin_id := gen_random_uuid();
    v_platform_identity_id := gen_random_uuid();

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
      v_platform_admin_id,
      'authenticated',
      'authenticated',
      v_platform_email,
      extensions.crypt('Admin123!', extensions.gen_salt('bf')),
      timezone('utc', now()),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"name":"8UP Admin","account_type":"platform_admin"}'::jsonb,
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
      v_platform_identity_id,
      v_platform_admin_id,
      v_platform_email,
      jsonb_build_object(
        'sub', v_platform_admin_id::text,
        'email', v_platform_email,
        'email_verified', true
      ),
      'email',
      timezone('utc', now()),
      timezone('utc', now()),
      timezone('utc', now())
    );

    insert into public.platform_admin_users (
      id,
      login_id,
      name,
      email,
      status
    ) values (
      v_platform_admin_id,
      '8up_admin',
      '8UP Admin',
      v_platform_email,
      'active'
    );
  end if;
end $$;


do $$
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then
      raise notice 'pg_cron extension is not available: %', sqlerrm;
  end;

  perform public.setup_scheduled_user_notification_jobs();
  perform public.setup_push_notification_dispatch_job();
  perform public.setup_notification_push_cleanup_job();
end;
$$;



-- RLS and policies.


alter table public.studios enable row level security;


alter table public.admin_users enable row level security;


alter table public.platform_admin_users enable row level security;


alter table public.studio_signup_requests enable row level security;


alter table public.users enable row level security;


alter table public.studio_user_memberships enable row level security;


alter table public.instructors enable row level security;


alter table public.class_templates enable row level security;


alter table public.pass_products enable row level security;


alter table public.pass_product_template_mappings enable row level security;


alter table public.class_sessions enable row level security;


alter table public.user_passes enable row level security;


alter table public.reservations enable row level security;


alter table public.pass_usage_ledger enable row level security;


alter table public.notices enable row level security;


alter table public.events enable row level security;


alter table public.refund_logs enable row level security;


alter table public.user_pass_holds enable row level security;


alter table public.member_consult_notes enable row level security;


drop policy if exists "Users can read own profile" on public.users;


create policy "Users can read own profile"
on public.users
for select
to authenticated
using (id = auth.uid());


drop policy if exists "Users can update own profile" on public.users;


create policy "Users can update own profile"
on public.users
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());


drop policy if exists "Members can read own memberships" on public.studio_user_memberships;


create policy "Members can read own memberships"
on public.studio_user_memberships
for select
to authenticated
using (user_id = auth.uid());


drop policy if exists "Members can read studio" on public.studios;


create policy "Members can read studio"
on public.studios
for select
to authenticated
using (public.is_member_of_studio(id));


drop policy if exists "Members can read templates in studio" on public.class_templates;


create policy "Members can read templates in studio"
on public.class_templates
for select
to authenticated
using (public.is_active_member_of_studio(studio_id));


drop policy if exists "Members can read pass products in studio" on public.pass_products;


create policy "Members can read pass products in studio"
on public.pass_products
for select
to authenticated
using (public.is_active_member_of_studio(studio_id));


drop policy if exists "Members can read pass-template mappings in studio" on public.pass_product_template_mappings;


create policy "Members can read pass-template mappings in studio"
on public.pass_product_template_mappings
for select
to authenticated
using (public.is_active_member_of_studio(studio_id));


drop policy if exists "Members can read sessions in studio" on public.class_sessions;


create policy "Members can read sessions in studio"
on public.class_sessions
for select
to authenticated
using (public.is_active_member_of_studio(studio_id));


drop policy if exists "Members can read instructors in studio" on public.instructors;


create policy "Members can read instructors in studio"
on public.instructors
for select
to authenticated
using (public.is_active_member_of_studio(studio_id));


drop policy if exists "Users can read own passes" on public.user_passes;


create policy "Users can read own passes"
on public.user_passes
for select
to authenticated
using (user_id = auth.uid());


drop policy if exists "Users can read own reservations" on public.reservations;


create policy "Users can read own reservations"
on public.reservations
for select
to authenticated
using (user_id = auth.uid());


drop policy if exists "Users can read own pass holds" on public.user_pass_holds;


create policy "Users can read own pass holds"
on public.user_pass_holds
for select
to authenticated
using (user_id = auth.uid());


drop policy if exists "Users can read own ledger" on public.pass_usage_ledger;


create policy "Users can read own ledger"
on public.pass_usage_ledger
for select
to authenticated
using (
  exists (
    select 1
      from public.user_passes user_pass
     where user_pass.id = pass_usage_ledger.user_pass_id
       and user_pass.user_id = auth.uid()
  )
);


drop policy if exists "Members can read notices in studio" on public.notices;


create policy "Members can read notices in studio"
on public.notices
for select
to authenticated
using (public.is_active_member_of_studio(studio_id));


drop policy if exists "Members can read events in studio" on public.events;


create policy "Members can read events in studio"
on public.events
for select
to authenticated
using (public.is_active_member_of_studio(studio_id));


drop policy if exists "Members can read notices in studio" on public.notices;


create policy "Members can read notices in studio"
on public.notices
for select
to authenticated
using (
  public.is_active_member_of_studio(studio_id)
  and is_published
  and (visible_from is null or visible_from <= timezone('utc', now()))
  and (visible_until is null or visible_until >= timezone('utc', now()))
);


drop policy if exists "Members can read events in studio" on public.events;


create policy "Members can read events in studio"
on public.events
for select
to authenticated
using (
  public.is_active_member_of_studio(studio_id)
  and is_published
  and (visible_from is null or visible_from <= timezone('utc', now()))
  and (visible_until is null or visible_until >= timezone('utc', now()))
);


drop policy if exists "Admins can read own admin profile" on public.admin_users;


create policy "Admins can read own admin profile"
on public.admin_users
for select
to authenticated
using (id = auth.uid());


drop policy if exists "Platform admins can read own profile" on public.platform_admin_users;


create policy "Platform admins can read own profile"
on public.platform_admin_users
for select
to authenticated
using (id = auth.uid());


drop policy if exists "Platform admins can update own profile" on public.platform_admin_users;


create policy "Platform admins can update own profile"
on public.platform_admin_users
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());


drop policy if exists "Admins can read own studio" on public.studios;


create policy "Admins can read own studio"
on public.studios
for select
to authenticated
using (public.is_admin_of_studio(id));


drop policy if exists "Admins can update own studio" on public.studios;


create policy "Admins can update own studio"
on public.studios
for update
to authenticated
using (public.is_admin_of_studio(id))
with check (public.is_admin_of_studio(id));


drop policy if exists "Admins can update own admin profile" on public.admin_users;


create policy "Admins can update own admin profile"
on public.admin_users
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid() and public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read templates in studio" on public.class_templates;


create policy "Admins can read templates in studio"
on public.class_templates
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read instructors in studio" on public.instructors;


create policy "Admins can read instructors in studio"
on public.instructors
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can insert instructors in studio" on public.instructors;


create policy "Admins can insert instructors in studio"
on public.instructors
for insert
to authenticated
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can update instructors in studio" on public.instructors;


create policy "Admins can update instructors in studio"
on public.instructors
for update
to authenticated
using (public.is_admin_of_studio(studio_id))
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can delete instructors in studio" on public.instructors;


create policy "Admins can delete instructors in studio"
on public.instructors
for delete
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can insert templates in studio" on public.class_templates;


create policy "Admins can insert templates in studio"
on public.class_templates
for insert
to authenticated
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can update templates in studio" on public.class_templates;


create policy "Admins can update templates in studio"
on public.class_templates
for update
to authenticated
using (public.is_admin_of_studio(studio_id))
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can delete templates in studio" on public.class_templates;


create policy "Admins can delete templates in studio"
on public.class_templates
for delete
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read pass products in studio" on public.pass_products;


create policy "Admins can read pass products in studio"
on public.pass_products
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can insert pass products in studio" on public.pass_products;


create policy "Admins can insert pass products in studio"
on public.pass_products
for insert
to authenticated
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can update pass products in studio" on public.pass_products;


create policy "Admins can update pass products in studio"
on public.pass_products
for update
to authenticated
using (public.is_admin_of_studio(studio_id))
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read pass mappings in studio" on public.pass_product_template_mappings;


create policy "Admins can read pass mappings in studio"
on public.pass_product_template_mappings
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can insert pass mappings in studio" on public.pass_product_template_mappings;


create policy "Admins can insert pass mappings in studio"
on public.pass_product_template_mappings
for insert
to authenticated
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can update pass mappings in studio" on public.pass_product_template_mappings;


create policy "Admins can update pass mappings in studio"
on public.pass_product_template_mappings
for update
to authenticated
using (public.is_admin_of_studio(studio_id))
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can delete pass mappings in studio" on public.pass_product_template_mappings;


create policy "Admins can delete pass mappings in studio"
on public.pass_product_template_mappings
for delete
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read sessions in studio" on public.class_sessions;


create policy "Admins can read sessions in studio"
on public.class_sessions
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can insert sessions in studio" on public.class_sessions;


create policy "Admins can insert sessions in studio"
on public.class_sessions
for insert
to authenticated
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can update sessions in studio" on public.class_sessions;


create policy "Admins can update sessions in studio"
on public.class_sessions
for update
to authenticated
using (public.is_admin_of_studio(studio_id))
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read memberships in studio" on public.studio_user_memberships;


create policy "Admins can read memberships in studio"
on public.studio_user_memberships
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can insert memberships in studio" on public.studio_user_memberships;


create policy "Admins can insert memberships in studio"
on public.studio_user_memberships
for insert
to authenticated
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can update memberships in studio" on public.studio_user_memberships;


create policy "Admins can update memberships in studio"
on public.studio_user_memberships
for update
to authenticated
using (public.is_admin_of_studio(studio_id))
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read studio members" on public.users;


create policy "Admins can read studio members"
on public.users
for select
to authenticated
using (
  exists (
    select 1
      from public.studio_user_memberships membership
     where membership.user_id = users.id
       and membership.studio_id = public.current_admin_studio_id()
  )
);


drop policy if exists "Admins can read passes in studio" on public.user_passes;


create policy "Admins can read passes in studio"
on public.user_passes
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read reservations in studio" on public.reservations;


create policy "Admins can read reservations in studio"
on public.reservations
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read refund logs in studio" on public.refund_logs;


create policy "Admins can read refund logs in studio"
on public.refund_logs
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read pass holds in studio" on public.user_pass_holds;


create policy "Admins can read pass holds in studio"
on public.user_pass_holds
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read consult notes in studio" on public.member_consult_notes;


create policy "Admins can read consult notes in studio"
on public.member_consult_notes
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read notices in studio" on public.notices;


create policy "Admins can read notices in studio"
on public.notices
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can insert notices in studio" on public.notices;


create policy "Admins can insert notices in studio"
on public.notices
for insert
to authenticated
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can update notices in studio" on public.notices;


create policy "Admins can update notices in studio"
on public.notices
for update
to authenticated
using (public.is_admin_of_studio(studio_id))
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can delete notices in studio" on public.notices;


create policy "Admins can delete notices in studio"
on public.notices
for delete
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can read events in studio" on public.events;


create policy "Admins can read events in studio"
on public.events
for select
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can insert events in studio" on public.events;


create policy "Admins can insert events in studio"
on public.events
for insert
to authenticated
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can update events in studio" on public.events;


create policy "Admins can update events in studio"
on public.events
for update
to authenticated
using (public.is_admin_of_studio(studio_id))
with check (public.is_admin_of_studio(studio_id));


drop policy if exists "Admins can delete events in studio" on public.events;


create policy "Admins can delete events in studio"
on public.events
for delete
to authenticated
using (public.is_admin_of_studio(studio_id));


drop policy if exists "Public can read app images" on storage.objects;


create policy "Public can read app images"
on storage.objects
for select
to public
using (bucket_id = 'app-images');


drop policy if exists "Users can upload own profile image" on storage.objects;


create policy "Users can upload own profile image"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'users'
  and split_part(name, '/', 2) = coalesce(public.current_member_code(), '') || '.jpg'
);


drop policy if exists "Users can update own profile image" on storage.objects;


create policy "Users can update own profile image"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'users'
  and split_part(name, '/', 2) = coalesce(public.current_member_code(), '') || '.jpg'
)
with check (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'users'
  and split_part(name, '/', 2) = coalesce(public.current_member_code(), '') || '.jpg'
);


drop policy if exists "Users can delete own profile image" on storage.objects;


create policy "Users can delete own profile image"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'users'
  and split_part(name, '/', 2) = coalesce(public.current_member_code(), '') || '.jpg'
);


drop policy if exists "Admins can upload studio images" on storage.objects;


create policy "Admins can upload studio images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'studios'
  and split_part(name, '/', 2) = coalesce(public.current_admin_studio_id()::text, '') || '.jpg'
);


drop policy if exists "Admins can update studio images" on storage.objects;


create policy "Admins can update studio images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'studios'
  and split_part(name, '/', 2) = coalesce(public.current_admin_studio_id()::text, '') || '.jpg'
)
with check (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'studios'
  and split_part(name, '/', 2) = coalesce(public.current_admin_studio_id()::text, '') || '.jpg'
);


drop policy if exists "Admins can delete studio images" on storage.objects;


create policy "Admins can delete studio images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'studios'
  and split_part(name, '/', 2) = coalesce(public.current_admin_studio_id()::text, '') || '.jpg'
);


drop policy if exists "Admins can upload instructor images" on storage.objects;


create policy "Admins can upload instructor images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'instructors'
  and split_part(name, '/', 2) like coalesce(public.current_admin_studio_id()::text, '') || '_%'
);


drop policy if exists "Admins can update instructor images" on storage.objects;


create policy "Admins can update instructor images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'instructors'
  and split_part(name, '/', 2) like coalesce(public.current_admin_studio_id()::text, '') || '_%'
)
with check (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'instructors'
  and split_part(name, '/', 2) like coalesce(public.current_admin_studio_id()::text, '') || '_%'
);


drop policy if exists "Admins can delete instructor images" on storage.objects;


create policy "Admins can delete instructor images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'app-images'
  and split_part(name, '/', 1) = 'instructors'
  and split_part(name, '/', 2) like coalesce(public.current_admin_studio_id()::text, '') || '_%'
);


alter table public.notifications enable row level security;


drop policy if exists "Users can read own notifications" on public.notifications;


create policy "Users can read own notifications"
on public.notifications
for select
to authenticated
using (user_id = auth.uid());


drop policy if exists "Users can update own notifications" on public.notifications;


create policy "Users can update own notifications"
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());


alter table public.push_notification_devices enable row level security;


alter table public.notification_push_jobs enable row level security;


alter table public.notification_push_deliveries enable row level security;



-- Grants.


grant usage on schema public to anon, authenticated;


grant select on public.studios to authenticated;


grant select, update on public.users to authenticated;


grant select on public.studio_user_memberships to authenticated;


grant select on public.class_templates to authenticated;


grant select on public.pass_products to authenticated;


grant select on public.pass_product_template_mappings to authenticated;


grant select on public.class_sessions to authenticated;


grant select on public.user_passes to authenticated;


grant select on public.reservations to authenticated;


grant select on public.refund_logs to authenticated;


grant select on public.user_pass_holds to authenticated;


grant select on public.member_consult_notes to authenticated;


grant select on public.pass_usage_ledger to authenticated;


grant select on public.notices to authenticated;


grant select on public.events to authenticated;


grant select on public.v_user_pass_summaries to authenticated;


grant select on public.v_user_pass_usage_entries to authenticated;


grant select on public.v_user_reservation_details to authenticated;


grant select on public.v_class_session_feed to authenticated;


grant execute on function public.get_user_pass_balance(uuid) to authenticated;


grant execute on function public.get_session_reserved_count(uuid) to authenticated;


grant execute on function public.get_session_waitlist_count(uuid) to authenticated;


grant execute on function public.reserve_class_session(uuid, uuid) to authenticated;


grant execute on function public.cancel_class_reservation(uuid) to authenticated;


grant execute on function public.request_class_reservation_cancel(uuid, text) to authenticated;


grant execute on function public.complete_finished_sessions() to authenticated;


grant execute on function public.resolve_sign_in_email(text) to anon, authenticated;


grant execute on function public.register_member_account(text, text, text, text) to anon, authenticated;


grant execute on function public.validate_admin_signup_request(text, text, text) to anon, authenticated;


grant execute on function public.validate_admin_signup_request(text, text, text, uuid) to anon, authenticated;


grant execute on function public.submit_studio_signup_request(text, text, text, text, text, text, text) to anon, authenticated;


grant execute on function public.approve_studio_signup_request(uuid) to authenticated;


grant execute on function public.reject_studio_signup_request(uuid, text) to authenticated;


grant execute on function public.fetch_pending_studio_signup_requests() to authenticated;


grant execute on function public.fetch_platform_studio_overview() to authenticated;


grant execute on function public.register_studio_admin_account(text, text, text, text, text, text, text) to anon, authenticated;


grant select on public.v_user_reservation_details to authenticated;


grant execute on function public.current_admin_studio_id() to authenticated;


grant execute on function public.current_member_code() to authenticated;


grant execute on function public.current_platform_admin_id() to authenticated;


grant execute on function public.is_current_admin() to authenticated;


grant execute on function public.is_platform_admin() to authenticated;


grant execute on function public.is_admin_of_studio(uuid) to authenticated;


grant execute on function public.resolve_admin_sign_in_context(text) to anon, authenticated;


grant execute on function public.resolve_admin_sign_in_email(text) to anon, authenticated;


grant execute on function public.find_user_by_member_code(text) to authenticated;


grant execute on function public.add_member_to_studio_admin(uuid) to authenticated;


grant execute on function public.create_member_consult_note_admin(uuid, date, text) to authenticated;


grant execute on function public.delete_member_consult_note_admin(uuid) to authenticated;


grant execute on function public.issue_user_pass_admin(uuid, uuid, date, numeric) to authenticated;


grant execute on function public.update_user_pass_admin(uuid, integer, numeric, date, date) to authenticated;


grant execute on function public.refund_user_pass_admin(uuid, numeric, text) to authenticated;


grant execute on function public.create_user_pass_hold_admin(uuid, date, date) to authenticated;


grant execute on function public.cancel_user_pass_hold_admin(uuid) to authenticated;


grant execute on function public.cancel_user_passs_hold_admin(uuid) to authenticated;


grant execute on function public.add_member_to_session_admin(uuid, text) to authenticated;


grant execute on function public.remove_member_from_session_admin(uuid, text) to authenticated;


grant execute on function public.approve_waitlisted_reservation_admin(uuid) to authenticated;


grant execute on function public.create_class_session_from_template_admin(uuid, date, integer) to authenticated;


grant execute on function public.create_class_sessions_from_template_admin(uuid, date, date, integer) to authenticated;


grant execute on function public.create_one_off_class_session_admin(text, text, date, time, time, integer, uuid[], uuid) to authenticated;


grant execute on function public.delete_class_session_admin(uuid) to authenticated;


grant execute on function public.cancel_class_session_admin(uuid) to authenticated;


grant execute on function public.approve_reservation_cancel_request_admin(uuid, text) to authenticated;


grant execute on function public.reject_reservation_cancel_request_admin(uuid, text) to authenticated;


grant select on public.admin_users to authenticated;


grant select on public.platform_admin_users to authenticated;


grant select, update on public.studios to authenticated;


grant select on public.instructors to authenticated;


grant select, insert, update on public.notices to authenticated;


grant delete on public.notices to authenticated;


grant select, insert, update on public.events to authenticated;


grant delete on public.events to authenticated;


grant select on public.v_admin_dashboard_metrics to authenticated;


grant select on public.v_admin_monthly_class_metrics to authenticated;


grant select on public.v_admin_session_reservation_summary to authenticated;


grant select on public.v_admin_monthly_financial_metrics to authenticated;


grant select on public.v_admin_member_directory to authenticated;


grant select on public.v_admin_member_pass_histories to authenticated;


grant select on public.v_admin_member_consult_notes to authenticated;


grant select on public.v_admin_operating_pass_details to authenticated;


grant select on public.v_admin_expiring_pass_details to authenticated;


grant select on public.v_admin_pass_product_details to authenticated;


grant select on public.v_admin_cancel_request_details to authenticated;


grant select on public.v_admin_class_session_feed to authenticated;


grant update on public.admin_users to authenticated;


grant insert, update, delete on public.instructors to authenticated;


grant insert, update, delete on public.class_templates to authenticated;


grant insert, update on public.pass_products to authenticated;


grant insert, update, delete on public.pass_product_template_mappings to authenticated;


grant insert, update on public.class_sessions to authenticated;


grant insert, update on public.studio_user_memberships to authenticated;


grant execute on function public.set_own_membership_status(uuid, public.membership_status) to authenticated;


grant select on public.v_class_session_feed to authenticated;


grant select on public.v_user_reservation_details to authenticated;


grant select, update on public.notifications to authenticated;


grant usage on schema public to service_role;


grant select on public.notifications to service_role;


grant select, insert, update on public.push_notification_devices to service_role;


grant select, insert, update on public.notification_push_jobs to service_role;


grant select, insert, update on public.notification_push_deliveries to service_role;


grant execute on function public.assign_session_instructor_admin(uuid, uuid) to authenticated;


grant execute on function public.upsert_push_notification_device(text, text, text) to authenticated;


grant execute on function public.disable_push_notification_device(text) to anon, authenticated;
