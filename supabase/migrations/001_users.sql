-- Profiles table extending Supabase auth
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  c2_user_id text,
  c2_access_token text,
  c2_refresh_token text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', new.email));
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
