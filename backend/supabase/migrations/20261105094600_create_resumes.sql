create table public.resumes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  file_name text not null,
  full_name text not null,
  direction text not null,
  profile text not null,
  source_text text not null,
  created_at timestamptz not null default now(),
  constraint resumes_file_name_length check (char_length(file_name) between 1 and 180),
  constraint resumes_full_name_length check (char_length(full_name) between 1 and 120),
  constraint resumes_direction_length check (char_length(direction) between 1 and 160),
  constraint resumes_profile_length check (char_length(profile) between 1 and 4000),
  constraint resumes_source_length check (char_length(source_text) between 1 and 50000)
);

create index resumes_owner_created_idx
  on public.resumes (user_id, created_at);

alter table public.resumes enable row level security;

revoke all on table public.resumes from anon, authenticated;

grant select, insert, delete on table public.resumes to authenticated;

create policy resumes_select_own
  on public.resumes
  for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy resumes_insert_own
  on public.resumes
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy resumes_delete_own
  on public.resumes
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

notify pgrst, 'reload schema';
