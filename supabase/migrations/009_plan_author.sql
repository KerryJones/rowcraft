-- Add author_id to training_plans so users own their custom plans
alter table public.training_plans
  add column author_id uuid references public.profiles(id) on delete set null;

create index idx_training_plans_author on public.training_plans(author_id);

-- Allow authors to update/delete their own plans
create policy "Authors can update own plans"
  on public.training_plans for update
  to authenticated
  using (auth.uid() = author_id);

create policy "Authors can delete own plans"
  on public.training_plans for delete
  to authenticated
  using (auth.uid() = author_id);

-- Allow authenticated users to insert plans they own
create policy "Users can create plans"
  on public.training_plans for insert
  to authenticated
  with check (auth.uid() = author_id);
