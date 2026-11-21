-- CONFAM Beat Participation Studio
alter table public.confam_posts
  add column if not exists is_beat boolean not null default false,
  add column if not exists allow_participation boolean not null default false,
  add column if not exists parent_beat_id uuid references public.confam_posts(id) on delete set null;

alter table public.confam_posts
  drop constraint if exists confam_posts_post_type_check;

alter table public.confam_posts
  add constraint confam_posts_post_type_check
  check (post_type in ('post','audio','voice_note','beat_collab'));

alter table public.confam_posts
  drop constraint if exists confam_posts_participation_requires_beat;

alter table public.confam_posts
  add constraint confam_posts_participation_requires_beat
  check (allow_participation = false or (is_beat = true and audio_url is not null));
