-- =====================================================================
--  HALPATI BASELINE SURVEY  -  Supabase setup
--  Run this ONCE: Supabase dashboard -> SQL Editor -> New query -> paste -> Run
-- =====================================================================

-- 1) Surveyors (one row per login). is_admin = true for people who may see everything.
create table if not exists public.surveyors (
  user_id  uuid primary key references auth.users(id) on delete cascade,
  code     text unique not null,          -- e.g. S001  (goes into the survey ID)
  name     text not null,
  is_admin boolean not null default false,
  created_at timestamptz default now()
);

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select coalesce((select is_admin from public.surveyors where user_id = auth.uid()), false)
$$;

-- 2) Village master list (optional, admin fills it; phones download it)
create table if not exists public.villages (
  district text not null, taluka text not null, village text not null,
  primary key (district, taluka, village)
);

-- 3) Survey entries  (one row = one beneficiary)
create table if not exists public.surveys (
  uid          uuid primary key,                      -- made on the phone, makes re-upload safe
  user_id      uuid not null default auth.uid() references auth.users(id),
  survey_id    text,                                  -- readable ID  HB-S001-261117-001
  survey_date  date,
  surveyor_code text,
  surveyor_name text,
  surveyor_mobile text,
  name         text,
  mobile       text,
  male int, female int, total int,
  caste        text,
  consent      text,
  consent_rel  text,
  district     text, taluka text, village text,
  house        text,
  kacha        text[],
  dil          text, dil_year text, dil_scheme text,
  own          text,
  land_type    text, land_area text,
  elig         text, elig_why text,
  income       numeric,
  src          text[], src_other text,
  gps_lat double precision, gps_lng double precision, gps_acc double precision, gps_manual boolean,
  other        text, other_why text,
  prop_front   text, prop_back text, prop_left text, prop_right text,
  castecert    text, inccert text,
  photos       jsonb not null default '{}'::jsonb,    -- {"ration":"<path in storage>", ...}
  photo_count  int  not null default 0,
  raw          jsonb,                                 -- complete copy of what the phone sent
  saved_at     timestamptz,
  synced_at    timestamptz not null default now()
);
create index if not exists surveys_place_idx   on public.surveys (district, taluka, village);
create index if not exists surveys_mobile_idx  on public.surveys (mobile);
create index if not exists surveys_sid_idx     on public.surveys (survey_id);
create index if not exists surveys_user_idx    on public.surveys (user_id);
create index if not exists surveys_date_idx    on public.surveys (survey_date);
create index if not exists surveys_order_idx   on public.surveys (survey_date, uid);

-- 4) Security (Row Level Security)
alter table public.surveyors enable row level security;
alter table public.villages  enable row level security;
alter table public.surveys   enable row level security;

drop policy if exists sv_sel on public.surveyors;
create policy sv_sel on public.surveyors for select to authenticated using (user_id = auth.uid() or public.is_admin());

drop policy if exists vil_sel on public.villages;
create policy vil_sel on public.villages for select to authenticated using (true);
drop policy if exists vil_all on public.villages;
create policy vil_all on public.villages for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists s_ins on public.surveys;
create policy s_ins on public.surveys for insert to authenticated with check (user_id = auth.uid());
drop policy if exists s_upd on public.surveys;
create policy s_upd on public.surveys for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists s_sel on public.surveys;
create policy s_sel on public.surveys for select to authenticated using (user_id = auth.uid() or public.is_admin());

-- 5) Private photo bucket.  File path = <surveyor user id>/<entry uid>/<photo name>.jpg
insert into storage.buckets (id, name, public) values ('survey-photos','survey-photos', false)
on conflict (id) do nothing;

drop policy if exists ph_ins on storage.objects;
create policy ph_ins on storage.objects for insert to authenticated
  with check (bucket_id = 'survey-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists ph_upd on storage.objects;
create policy ph_upd on storage.objects for update to authenticated
  using (bucket_id = 'survey-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists ph_sel on storage.objects;
create policy ph_sel on storage.objects for select to authenticated
  using (bucket_id = 'survey-photos' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- 6) Duplicate check: same mobile number used in more than one entry (admin only, via RLS)
create or replace view public.v_dup_mobile with (security_invoker = true) as
  select * from public.surveys
  where coalesce(mobile,'') <> ''
    and mobile in (select mobile from public.surveys where coalesce(mobile,'') <> '' group by mobile having count(*) > 1)
  order by mobile, survey_date;

-- 7) One call that feeds the whole admin dashboard
create or replace function public.admin_stats() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'not admin'; end if;
  return jsonb_build_object(
   'total',        (select count(*) from surveys),
   'today',        (select count(*) from surveys where survey_date = (now() at time zone 'Asia/Kolkata')::date),
   'villages',     (select count(*) from (select distinct district,taluka,village from surveys where coalesce(village,'')<>'') v),
   'eligible_yes', (select count(*) from surveys where elig = 'હા'),
   'photos',       (select coalesce(sum(photo_count),0) from surveys),
   'dup_mobile',   (select count(*) from (select 1 from surveys where coalesce(mobile,'')<>'' group by mobile having count(*)>1) d),
   'by_surveyor',  (select coalesce(jsonb_agg(t),'[]') from (select surveyor_code code, max(surveyor_name) name, count(*) n, max(survey_date) last from surveys group by 1 order by n desc) t),
   'by_taluka',    (select coalesce(jsonb_agg(t),'[]') from (select district, taluka, count(*) n from surveys group by 1,2 order by n desc) t),
   'by_caste',     (select coalesce(jsonb_agg(t),'[]') from (select coalesce(nullif(caste,''),'—') k, count(*) n from surveys group by 1 order by n desc) t),
   'by_house',     (select coalesce(jsonb_agg(t),'[]') from (select coalesce(nullif(house,''),'—') k, count(*) n from surveys group by 1 order by n desc) t),
   'by_src',       (select coalesce(jsonb_agg(t),'[]') from (select s k, count(*) n from surveys, unnest(src) s group by 1 order by n desc) t),
   'daily',        (select coalesce(jsonb_agg(t order by d),'[]') from (select survey_date d, count(*) n from surveys where survey_date >= current_date - 29 group by 1) t),
   'income_avg',   (select round(avg(income)) from surveys where income > 0)
  );
end $$;
grant execute on function public.admin_stats() to authenticated;

-- =====================================================================
--  AFTER running this: create users (Authentication -> Users -> Add user -> tick "Auto Confirm User"),
--  email = <ID>@halpati.survey  (e.g. s001@halpati.survey), then register each one here:
--
--  insert into public.surveyors (user_id, code, name, is_admin)
--  select id, 'S001', 'Ramesh Patel', false from auth.users where email = 's001@halpati.survey';
--
--  Your own admin account (same way, is_admin = true):
--  insert into public.surveyors (user_id, code, name, is_admin)
--  select id, 'ADMIN', 'Dhairya', true from auth.users where email = 'admin@halpati.survey';
-- =====================================================================

-- If you ran an earlier version of this file, run this line once more (safe to repeat):
alter table public.surveys add column if not exists surveyor_mobile text;

-- added later: relation to family head (for consent = હા)
alter table public.surveys add column if not exists consent_rel text;
alter table public.surveys add column if not exists dil text;
