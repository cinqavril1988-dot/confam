-- CONFAM : commentaires enrichis sous les Duels
-- À exécuter dans Supabase > SQL Editor après le déploiement du site.

-- La table des commentaires est utilisée par le site. Si elle existe déjà,
-- cette instruction ne supprime aucune donnée.
create table if not exists public.confam_faceoff_comments (
  id uuid primary key default gen_random_uuid(),
  faceoff_id uuid not null references public.confam_faceoffs(id) on delete cascade,
  user_id uuid not null references public.confam_profiles(id) on delete cascade,
  parent_comment_id uuid references public.confam_faceoff_comments(id) on delete cascade,
  content text not null check (length(trim(content)) between 1 and 500),
  created_at timestamptz not null default now()
);

alter table public.confam_faceoff_comments
  add column if not exists parent_comment_id uuid
  references public.confam_faceoff_comments(id) on delete cascade;

create table if not exists public.confam_faceoff_comment_likes (
  comment_id uuid not null references public.confam_faceoff_comments(id) on delete cascade,
  user_id uuid not null references public.confam_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

alter table public.confam_faceoff_comments enable row level security;
alter table public.confam_faceoff_comment_likes enable row level security;

drop policy if exists "CONFAM duel comments readable" on public.confam_faceoff_comments;
create policy "CONFAM duel comments readable"
  on public.confam_faceoff_comments for select to anon, authenticated using (true);

drop policy if exists "CONFAM users add own duel comments" on public.confam_faceoff_comments;
create policy "CONFAM users add own duel comments"
  on public.confam_faceoff_comments for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "CONFAM users delete own duel comments" on public.confam_faceoff_comments;
create policy "CONFAM users delete own duel comments"
  on public.confam_faceoff_comments for delete to authenticated
  using (auth.uid() = user_id);

drop policy if exists "CONFAM duel comment likes readable" on public.confam_faceoff_comment_likes;
create policy "CONFAM duel comment likes readable"
  on public.confam_faceoff_comment_likes for select to anon, authenticated using (true);

drop policy if exists "CONFAM users like duel comments as themselves" on public.confam_faceoff_comment_likes;
create policy "CONFAM users like duel comments as themselves"
  on public.confam_faceoff_comment_likes for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "CONFAM users unlike own duel comments" on public.confam_faceoff_comment_likes;
create policy "CONFAM users unlike own duel comments"
  on public.confam_faceoff_comment_likes for delete to authenticated
  using (auth.uid() = user_id);

grant select on public.confam_faceoff_comments to anon, authenticated;
grant insert, delete on public.confam_faceoff_comments to authenticated;
grant select on public.confam_faceoff_comment_likes to anon, authenticated;
grant insert, delete on public.confam_faceoff_comment_likes to authenticated;
