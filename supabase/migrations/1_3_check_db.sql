drop table if exists _supabase_check_results;

create temp table _supabase_check_results (
  section text,
  item text,
  value text
);

do $$
begin
  insert into _supabase_check_results (section, item, value)
  select
    'extensions',
    t.name,
    case when e.extname is null then 'MISSING' else 'installed' end
  from (
    values
      ('pg_cron'),
      ('pg_net'),
      ('supabase_vault')
  ) as t(name)
  left join pg_extension e
    on e.extname = t.name;

  insert into _supabase_check_results (section, item, value)
  select
    'functions',
    t.name,
    case when p.oid is null then 'MISSING' else 'installed' end
  from (
    values
      ('dispatch_scheduled_user_notifications'),
      ('setup_scheduled_user_notification_jobs'),
      ('invoke_push_notification_dispatcher'),
      ('setup_push_notification_dispatch_job'),
      ('should_send_notification_push'),
      ('enqueue_notification_push_job')
  ) as t(name)
  left join pg_proc p
    on p.proname = t.name
   and p.pronamespace = 'public'::regnamespace;

  insert into _supabase_check_results (section, item, value)
  select
    'triggers',
    'trg_enqueue_notification_push_job',
    case
      when exists (
        select 1
        from pg_trigger tg
        where tg.tgname = 'trg_enqueue_notification_push_job'
          and tg.tgrelid = 'public.notifications'::regclass
          and not tg.tgisinternal
      )
      then 'installed on public.notifications'
      else 'MISSING'
    end;

  if to_regnamespace('cron') is null then
    insert into _supabase_check_results (section, item, value)
    values ('cron_jobs', '__note__', 'cron schema is missing');
  else
    execute $sql$
      insert into _supabase_check_results (section, item, value)
      select
        'cron_jobs',
        j.jobname,
        format('schedule=%s | active=%s | command=%s', j.schedule, j.active, j.command)
      from cron.job j
      where j.jobname in ('eightup-user-notifications', 'eightup-push-dispatch')
    $sql$;

    if not exists (
      select 1
      from _supabase_check_results
      where section = 'cron_jobs'
        and item <> '__note__'
    ) then
      insert into _supabase_check_results (section, item, value)
      values ('cron_jobs', '__note__', 'target cron jobs not found');
    end if;

    execute $sql$
      insert into _supabase_check_results (section, item, value)
      select
        'cron_runs',
        j.jobname || ' @ ' || to_char(d.start_time, 'YYYY-MM-DD HH24:MI:SS'),
        format('status=%s | return=%s', d.status, coalesce(d.return_message, ''))
      from cron.job_run_details d
      join cron.job j
        on j.jobid = d.jobid
      where j.jobname in ('eightup-user-notifications', 'eightup-push-dispatch')
      order by d.start_time desc
      limit 20
    $sql$;

    if not exists (
      select 1
      from _supabase_check_results
      where section = 'cron_runs'
    ) then
      insert into _supabase_check_results (section, item, value)
      values ('cron_runs', '__note__', 'no run history yet');
    end if;
  end if;

  if to_regnamespace('vault') is null then
    insert into _supabase_check_results (section, item, value)
    values ('vault_secrets', '__note__', 'vault schema is missing');
  else
    execute $sql$
      insert into _supabase_check_results (section, item, value)
      select
        'vault_secrets',
        s.name,
        'present'
      from vault.decrypted_secrets s
      where s.name in ('supabase_project_url', 'supabase_anon_key')
    $sql$;

    if not exists (
      select 1
      from _supabase_check_results
      where section = 'vault_secrets'
        and item <> '__note__'
    ) then
      insert into _supabase_check_results (section, item, value)
      values ('vault_secrets', '__note__', 'target vault secrets not found');
    end if;
  end if;

  if to_regclass('public.notification_push_jobs') is null then
    insert into _supabase_check_results (section, item, value)
    values ('push_jobs', '__note__', 'public.notification_push_jobs table is missing');
  else
    insert into _supabase_check_results (section, item, value)
    select
      'push_jobs',
      status,
      count(*)::text
    from public.notification_push_jobs
    group by status;

    if not exists (
      select 1
      from _supabase_check_results
      where section = 'push_jobs'
        and item <> '__note__'
    ) then
      insert into _supabase_check_results (section, item, value)
      values ('push_jobs', '__note__', 'no push jobs yet');
    end if;
  end if;
end
$$;

select
  section,
  item,
  value
from _supabase_check_results
order by
  case section
    when 'extensions' then 1
    when 'functions' then 2
    when 'triggers' then 3
    when 'cron_jobs' then 4
    when 'cron_runs' then 5
    when 'vault_secrets' then 6
    when 'push_jobs' then 7
    else 99
  end,
  item;
