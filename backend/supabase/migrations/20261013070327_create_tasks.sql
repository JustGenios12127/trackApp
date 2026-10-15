create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  due_on date not null,
  remind_at timestamptz,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  constraint tasks_title_length check (char_length(title) between 1 and 200),
  constraint tasks_status_check check (status in ('open', 'done'))
);

create index tasks_open_schedule_idx
  on public.tasks (due_on, created_at)
  where status = 'open';

alter table public.tasks enable row level security;

revoke all on table public.tasks from anon, authenticated;

grant select, insert on table public.tasks to service_role;

notify pgrst, 'reload schema';
