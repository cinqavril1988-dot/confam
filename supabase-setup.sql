-- Likes de commentaires et réponses imbriquées dans confam_comments.
alter table public.confam_comments add column if not exists parent_comment_id uuid references public.confam_comments(id) on delete cascade;
create table if not exists public.confam_comment_likes (comment_id uuid not null references public.confam_comments(id) on delete cascade,user_id uuid not null references public.confam_profiles(id) on delete cascade,created_at timestamptz not null default now(),primary key(comment_id,user_id));
-- CONFAM — Base de données Supabase
-- Script autonome : crée uniquement des objets préfixés confam_ et ne supprime aucune donnée existante.
-- À exécuter une seule fois dans Supabase > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.confam_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Membre CONFAM',
  username text not null unique,
  bio text not null default '',
  role text not null default 'music_lover' check (role in ('artist','music_lover')),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.confam_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.confam_profiles(id) on delete cascade,
  content text not null default '',
  audio_url text,
  audio_path text,
  audio_name text,
  image_url text,
  image_path text,
  post_type text not null default 'post' check (post_type in ('post','audio','voice_note')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint confam_posts_has_content check (length(trim(content)) > 0 or audio_url is not null or image_url is not null)
);

create table if not exists public.confam_likes (
  post_id uuid not null references public.confam_posts(id) on delete cascade,
  user_id uuid not null references public.confam_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(post_id,user_id)
);

create table if not exists public.confam_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.confam_posts(id) on delete cascade,
  user_id uuid not null references public.confam_profiles(id) on delete cascade,
  content text not null check(length(trim(content)) between 1 and 500),
  created_at timestamptz not null default now()
);

create table if not exists public.confam_follows (
  follower_id uuid not null references public.confam_profiles(id) on delete cascade,
  following_id uuid not null references public.confam_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(follower_id,following_id),
  constraint confam_no_self_follow check(follower_id <> following_id)
);

-- Tables préparées pour les modules communautaires (Face-Off, Inbox et Activity).
create table if not exists public.confam_faceoffs (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.confam_profiles(id) on delete cascade,
  title text not null,
  description text not null default '',
  audio_a_url text,
  audio_a_name text,
  audio_b_url text,
  audio_b_name text,
  status text not null default 'open' check(status in ('open','closed')),
  ends_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.confam_faceoff_votes (
  faceoff_id uuid not null references public.confam_faceoffs(id) on delete cascade,
  user_id uuid not null references public.confam_profiles(id) on delete cascade,
  choice text not null check(choice in ('a','b')),
  created_at timestamptz not null default now(),
  primary key(faceoff_id,user_id)
);
create table if not exists public.confam_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.confam_profiles(id) on delete cascade,
  recipient_id uuid not null references public.confam_profiles(id) on delete cascade,
  content text not null check(length(trim(content)) between 1 and 4000),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint confam_no_self_message check(sender_id <> recipient_id)
);
create table if not exists public.confam_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.confam_profiles(id) on delete cascade,
  actor_id uuid references public.confam_profiles(id) on delete set null,
  kind text not null check(kind in ('like','comment','follow','message','faceoff_vote')),
  post_id uuid references public.confam_posts(id) on delete cascade,
  message text not null default '',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists confam_posts_created_idx on public.confam_posts(created_at desc);
create index if not exists confam_posts_user_idx on public.confam_posts(user_id,created_at desc);
create index if not exists confam_comments_post_idx on public.confam_comments(post_id,created_at);
create index if not exists confam_messages_pair_idx on public.confam_messages(sender_id,recipient_id,created_at desc);
create index if not exists confam_notifications_recipient_idx on public.confam_notifications(recipient_id,created_at desc);

-- Création automatique du profil à l'inscription.
create or replace function public.confam_handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
declare base_name text; clean_name text; candidate text;
begin
  base_name := coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'),''), split_part(new.email,'@',1), 'membre');
  clean_name := lower(regexp_replace(base_name,'[^a-zA-Z0-9_]+','_','g'));
  clean_name := trim(both '_' from clean_name);
  if clean_name='' then clean_name:='membre'; end if;
  candidate := left(clean_name,18)||'_'||substr(replace(new.id::text,'-',''),1,5);
  insert into public.confam_profiles(id,display_name,username,role)
  values(new.id,base_name,candidate,case when new.raw_user_meta_data->>'role'='artist' then 'artist' else 'music_lover' end)
  on conflict(id) do nothing;
  return new;
end; $$;
drop trigger if exists confam_on_auth_user_created on auth.users;
create trigger confam_on_auth_user_created after insert on auth.users for each row execute procedure public.confam_handle_new_user();

create or replace function public.confam_set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists confam_profiles_updated_at on public.confam_profiles;
create trigger confam_profiles_updated_at before update on public.confam_profiles for each row execute procedure public.confam_set_updated_at();

alter table public.confam_profiles enable row level security;
alter table public.confam_posts enable row level security;
alter table public.confam_likes enable row level security;
alter table public.confam_comments enable row level security;
alter table public.confam_follows enable row level security;
alter table public.confam_faceoffs enable row level security;
alter table public.confam_faceoff_votes enable row level security;
alter table public.confam_messages enable row level security;
alter table public.confam_notifications enable row level security;

-- Profils publics en lecture ; chaque membre modifie uniquement son profil.
drop policy if exists "CONFAM profiles are readable" on public.confam_profiles;
create policy "CONFAM profiles are readable" on public.confam_profiles for select to anon,authenticated using(true);
drop policy if exists "CONFAM users insert own profile" on public.confam_profiles;
create policy "CONFAM users insert own profile" on public.confam_profiles for insert to authenticated with check(auth.uid()=id);
drop policy if exists "CONFAM users update own profile" on public.confam_profiles;
create policy "CONFAM users update own profile" on public.confam_profiles for update to authenticated using(auth.uid()=id) with check(auth.uid()=id);

-- Feed public en lecture ; création, modification et suppression réservées à l'auteur.
drop policy if exists "CONFAM posts are readable" on public.confam_posts;
create policy "CONFAM posts are readable" on public.confam_posts for select to anon,authenticated using(true);
drop policy if exists "CONFAM users create own posts" on public.confam_posts;
create policy "CONFAM users create own posts" on public.confam_posts for insert to authenticated with check(auth.uid()=user_id);
drop policy if exists "CONFAM users update own posts" on public.confam_posts;
create policy "CONFAM users update own posts" on public.confam_posts for update to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
drop policy if exists "CONFAM users delete own posts" on public.confam_posts;
create policy "CONFAM users delete own posts" on public.confam_posts for delete to authenticated using(auth.uid()=user_id);

-- Réactions et commentaires.
drop policy if exists "CONFAM likes are readable" on public.confam_likes;
create policy "CONFAM likes are readable" on public.confam_likes for select to anon,authenticated using(true);
drop policy if exists "CONFAM users like as themselves" on public.confam_likes;
create policy "CONFAM users like as themselves" on public.confam_likes for insert to authenticated with check(auth.uid()=user_id);
drop policy if exists "CONFAM users remove own likes" on public.confam_likes;
create policy "CONFAM users remove own likes" on public.confam_likes for delete to authenticated using(auth.uid()=user_id);
drop policy if exists "CONFAM comments are readable" on public.confam_comments;
create policy "CONFAM comments are readable" on public.confam_comments for select to anon,authenticated using(true);
drop policy if exists "CONFAM users create own comments" on public.confam_comments;
drop policy if exists "CONFAM users create own comments" on public.confam_comments;
create policy "CONFAM users create own comments" on public.confam_comments for insert to authenticated with check(auth.uid()=user_id and (parent_comment_id is null or exists(select 1 from public.confam_comments parent where parent.id=parent_comment_id and parent.post_id=post_id)));
drop policy if exists "CONFAM users delete own comments" on public.confam_comments;
create policy "CONFAM users delete own comments" on public.confam_comments for delete to authenticated using(auth.uid()=user_id);

-- Likes de commentaires
alter table public.confam_comment_likes enable row level security;
drop policy if exists "CONFAM comment likes readable" on public.confam_comment_likes;
create policy "CONFAM comment likes readable" on public.confam_comment_likes for select to anon,authenticated using(true);
drop policy if exists "CONFAM users like comments as themselves" on public.confam_comment_likes;
create policy "CONFAM users like comments as themselves" on public.confam_comment_likes for insert to authenticated with check(auth.uid()=user_id);
drop policy if exists "CONFAM users unlike own comment likes" on public.confam_comment_likes;
create policy "CONFAM users unlike own comment likes" on public.confam_comment_likes for delete to authenticated using(auth.uid()=user_id);
-- Abonnements.
drop policy if exists "CONFAM follows are readable" on public.confam_follows;
create policy "CONFAM follows are readable" on public.confam_follows for select to anon,authenticated using(true);
drop policy if exists "CONFAM users follow as themselves" on public.confam_follows;
create policy "CONFAM users follow as themselves" on public.confam_follows for insert to authenticated with check(auth.uid()=follower_id);
drop policy if exists "CONFAM users unfollow as themselves" on public.confam_follows;
create policy "CONFAM users unfollow as themselves" on public.confam_follows for delete to authenticated using(auth.uid()=follower_id);

-- Face-Off : consultation publique, création par membre, vote unique par membre.
drop policy if exists "CONFAM faceoffs are readable" on public.confam_faceoffs;
create policy "CONFAM faceoffs are readable" on public.confam_faceoffs for select to anon,authenticated using(true);
drop policy if exists "CONFAM users create faceoffs" on public.confam_faceoffs;
create policy "CONFAM users create faceoffs" on public.confam_faceoffs for insert to authenticated with check(auth.uid()=creator_id);
drop policy if exists "CONFAM creators update faceoffs" on public.confam_faceoffs;
create policy "CONFAM creators update faceoffs" on public.confam_faceoffs for update to authenticated using(auth.uid()=creator_id) with check(auth.uid()=creator_id);
drop policy if exists "CONFAM votes are readable" on public.confam_faceoff_votes;
create policy "CONFAM votes are readable" on public.confam_faceoff_votes for select to anon,authenticated using(true);
drop policy if exists "CONFAM users vote as themselves" on public.confam_faceoff_votes;
create policy "CONFAM users vote as themselves" on public.confam_faceoff_votes for insert to authenticated with check(auth.uid()=user_id);
drop policy if exists "CONFAM users change own vote" on public.confam_faceoff_votes;
create policy "CONFAM users change own vote" on public.confam_faceoff_votes for update to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);

-- Inbox : seuls l'expéditeur et le destinataire voient une conversation.
drop policy if exists "CONFAM participants read messages" on public.confam_messages;
create policy "CONFAM participants read messages" on public.confam_messages for select to authenticated using(auth.uid()=sender_id or auth.uid()=recipient_id);
drop policy if exists "CONFAM users send as themselves" on public.confam_messages;
create policy "CONFAM users send as themselves" on public.confam_messages for insert to authenticated with check(auth.uid()=sender_id);
drop policy if exists "CONFAM recipients mark messages read" on public.confam_messages;
create policy "CONFAM recipients mark messages read" on public.confam_messages for update to authenticated using(auth.uid()=recipient_id) with check(auth.uid()=recipient_id);

-- Activity : le destinataire lit et marque ses notifications.
drop policy if exists "CONFAM users read own notifications" on public.confam_notifications;
create policy "CONFAM users read own notifications" on public.confam_notifications for select to authenticated using(auth.uid()=recipient_id);
drop policy if exists "CONFAM users mark own notifications read" on public.confam_notifications;
create policy "CONFAM users mark own notifications read" on public.confam_notifications for update to authenticated using(auth.uid()=recipient_id) with check(auth.uid()=recipient_id);

-- Buckets publics en lecture pour les médias publiés. Les uploads/suppressions restent privés à chaque compte.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values
 ('confam-audio','confam-audio',true,52428800,array['audio/mpeg','audio/mp3','audio/wav','audio/x-wav','audio/mp4','audio/aac','audio/ogg','audio/flac','audio/webm']),
 ('confam-images','confam-images',true,10485760,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict(id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "CONFAM public audio read" on storage.objects;
create policy "CONFAM public audio read" on storage.objects for select to anon,authenticated using(bucket_id='confam-audio');
drop policy if exists "CONFAM users upload own audio" on storage.objects;
create policy "CONFAM users upload own audio" on storage.objects for insert to authenticated with check(bucket_id='confam-audio' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "CONFAM users update own audio" on storage.objects;
create policy "CONFAM users update own audio" on storage.objects for update to authenticated using(bucket_id='confam-audio' and (storage.foldername(name))[1]=auth.uid()::text) with check(bucket_id='confam-audio' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "CONFAM users delete own audio" on storage.objects;
create policy "CONFAM users delete own audio" on storage.objects for delete to authenticated using(bucket_id='confam-audio' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "CONFAM public images read" on storage.objects;
create policy "CONFAM public images read" on storage.objects for select to anon,authenticated using(bucket_id='confam-images');
drop policy if exists "CONFAM users upload own images" on storage.objects;
create policy "CONFAM users upload own images" on storage.objects for insert to authenticated with check(bucket_id='confam-images' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "CONFAM users update own images" on storage.objects;
create policy "CONFAM users update own images" on storage.objects for update to authenticated using(bucket_id='confam-images' and (storage.foldername(name))[1]=auth.uid()::text) with check(bucket_id='confam-images' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "CONFAM users delete own images" on storage.objects;
create policy "CONFAM users delete own images" on storage.objects for delete to authenticated using(bucket_id='confam-images' and (storage.foldername(name))[1]=auth.uid()::text);

-- Fin du script. Aucune clé secrète n'est nécessaire côté navigateur.
