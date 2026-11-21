-- CONFAM migration: schema compatible avec l'interface Duel actuelle
-- À exécuter dans Supabase > SQL Editor avant d'utiliser "Demander un Duel".

alter table public.confam_faceoffs
  add column if not exists artist_a_id uuid references public.confam_profiles(id) on delete cascade,
  add column if not exists artist_b_id uuid references public.confam_profiles(id) on delete cascade,
  add column if not exists post_a_id uuid references public.confam_posts(id) on delete set null,
  add column if not exists post_b_id uuid references public.confam_posts(id) on delete set null,
  add column if not exists artist_a_status text not null default 'pending',
  add column if not exists artist_b_status text not null default 'pending',
  add column if not exists duel_status text not null default 'pending';

create or replace function public.confam_create_faceoff(
  p_title text,
  p_description text default '',
  p_artist_a_id uuid default null,
  p_artist_b_id uuid default null,
  p_post_a_id uuid default null,
  p_post_b_id uuid default null,
  p_ends_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user uuid := auth.uid();
  v_id uuid;
begin
  if v_user is null then
    raise exception 'Connecte-toi pour proposer un Duel.';
  end if;
  if nullif(trim(p_title),'') is null then
    raise exception 'Indique le thème du Duel.';
  end if;
  if p_artist_a_id is null or p_artist_b_id is null then
    raise exception 'Choisis les deux artistes.';
  end if;
  if p_artist_a_id=p_artist_b_id then
    raise exception 'Le Duel doit opposer deux artistes différents.';
  end if;
  if not exists(select 1 from public.confam_profiles where id=p_artist_a_id and role='artist') then
    raise exception 'Artiste A introuvable.';
  end if;
  if not exists(select 1 from public.confam_profiles where id=p_artist_b_id and role='artist') then
    raise exception 'Artiste B introuvable.';
  end if;
  if p_post_a_id is not null and not exists(select 1 from public.confam_posts where id=p_post_a_id and user_id=p_artist_a_id) then
    raise exception 'Le son sélectionné pour Artiste A ne lui appartient pas.';
  end if;
  if p_post_b_id is not null and not exists(select 1 from public.confam_posts where id=p_post_b_id and user_id=p_artist_b_id) then
    raise exception 'Le son sélectionné pour Artiste B ne lui appartient pas.';
  end if;

  insert into public.confam_faceoffs(
    creator_id,title,description,artist_a_id,artist_b_id,post_a_id,post_b_id,
    artist_a_status,artist_b_status,duel_status,ends_at
  ) values (
    v_user,trim(p_title),coalesce(p_description,''),p_artist_a_id,p_artist_b_id,p_post_a_id,p_post_b_id,
    'pending','pending','pending',p_ends_at
  ) returning id into v_id;
  return v_id;
end;
$$;

grant execute on function public.confam_create_faceoff(text,text,uuid,uuid,uuid,uuid,timestamptz) to authenticated;
