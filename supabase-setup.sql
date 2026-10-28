-- 금포식당 메뉴 조사: 투표를 저장할 표와 함수
-- 브라우저는 표에 직접 접근하지 못하고, 아래 세 함수로만 투표/취소/조회합니다.

create table if not exists public.lunch_votes (
  voter_id   uuid primary key,
  dept       text not null check (char_length(dept) between 1 and 30),
  name       text not null check (char_length(name) between 1 and 20),
  choice     text not null check (choice in ('doenjang', 'sundubu', 'donkatsu')),
  updated_at timestamptz not null default now()
);

alter table public.lunch_votes enable row level security;
revoke all on public.lunch_votes from anon, authenticated;

-- 투표하기 / 바꾸기
create or replace function public.cast_vote(p_voter uuid, p_dept text, p_name text, p_choice text)
returns void
language sql
security definer
set search_path = public
as $$
  insert into lunch_votes (voter_id, dept, name, choice, updated_at)
  values (p_voter, btrim(p_dept), btrim(p_name), p_choice, now())
  on conflict (voter_id) do update
    set dept = excluded.dept, name = excluded.name, choice = excluded.choice, updated_at = now();
$$;

-- 내 선택 취소
create or replace function public.cancel_vote(p_voter uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from lunch_votes where voter_id = p_voter;
$$;

-- 집계 조회 (다른 사람의 voter_id는 돌려주지 않음)
create or replace function public.list_votes(p_voter uuid)
returns table (dept text, name text, choice text, mine boolean, updated_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select dept, name, choice, voter_id = p_voter, updated_at
  from lunch_votes
  order by updated_at;
$$;

revoke all on function public.cast_vote(uuid, text, text, text) from public;
revoke all on function public.cancel_vote(uuid) from public;
revoke all on function public.list_votes(uuid) from public;
grant execute on function public.cast_vote(uuid, text, text, text) to anon, authenticated;
grant execute on function public.cancel_vote(uuid) to anon, authenticated;
grant execute on function public.list_votes(uuid) to anon, authenticated;
