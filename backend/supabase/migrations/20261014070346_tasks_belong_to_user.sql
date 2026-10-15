alter table public.tasks
  add column user_id uuid references auth.users (id) on delete cascade;

alter table public.tasks
  add constraint tasks_owner_required
  check (user_id is not null) not valid;

drop index if exists public.tasks_open_schedule_idx;

create index tasks_owner_open_idx
  on public.tasks (user_id, due_on, created_at)
  where status = 'open';

grant select, insert, update, delete on table public.tasks to authenticated;

create policy tasks_select_own
  on public.tasks
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy tasks_insert_own
  on public.tasks
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy tasks_update_own
  on public.tasks
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy tasks_delete_own
  on public.tasks
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

notify pgrst, 'reload schema';
