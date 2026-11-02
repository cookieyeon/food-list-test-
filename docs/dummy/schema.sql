-- =====================================================================
-- 가상 상품 DB 스키마 (실습 전용) — Supabase SQL Editor에서 실행
-- 데이터는 seed.sql. 실행 순서: schema.sql → seed.sql
--
-- 규칙
--   * NULL = 원문에 정보가 없음
--   * 모든 상품은 product_cautions에 '알레르기' 행이 최소 1개(없으면 '없음')
--   * 빠진 정보는 products_missing_info 뷰로 확인
--
-- 전체가 하나의 트랜잭션이라 중간에 실패하면 아무것도 만들어지지 않는다
-- 이미 테이블이 있으면 실패하므로, 다시 만들려면 맨 아래 '초기화' 부분을 먼저 실행
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. 테이블
-- ---------------------------------------------------------------------

-- 상품: 1행 = 1상품, 모든 상품에 있는 정보만
create table public.products (
    product_id   text primary key check (product_id ~ '^P-[0-9]{4}$'),
    name         text not null,
    category     text not null check (category in ('신선과일', '채소', '가공식품', '냉동식품')),
    net_amount   text not null,
    quantity     text,
    price        integer not null check (price >= 0),
    sale_period  text,
    description  text,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

-- 원재료: 원재료 1개당 1행
create table public.product_ingredients (
    id          bigint generated always as identity primary key,
    product_id  text not null references public.products (product_id) on update cascade on delete cascade,
    ingredient  text not null,
    origin      text,
    unique (product_id, ingredient)
);

-- 보관조건: 조건 1개당 1행
create table public.product_storage (
    id            bigint generated always as identity primary key,
    product_id    text not null references public.products (product_id) on update cascade on delete cascade,
    condition     text not null check (condition in ('수령 후', '개봉 전', '개봉 후')),
    storage_type  text not null check (storage_type in ('상온', '냉장', '냉동')),
    days          integer check (days > 0),
    note          text,
    unique (product_id, condition, storage_type)
);

-- 주의사항: 주의사항 1개당 1행
create table public.product_cautions (
    id            bigint generated always as identity primary key,
    product_id    text not null references public.products (product_id) on update cascade on delete cascade,
    caution_type  text not null check (caution_type in ('알레르기', '교차오염', '보관금지', '조리금지', '섭취주의')),
    content       text not null,
    unique (product_id, caution_type, content)
);

-- 배송정책: 모든 상품 공통
create table public.shipping_policies (
    id       bigint generated always as identity primary key,
    policy   text not null unique,
    content  text not null
);

-- 컬럼 설명(Supabase Table Editor에 표시됨)
comment on table public.products is '가상 상품(실습 전용). 1행 = 1상품';
comment on column public.products.quantity is '개수. 없으면 NULL';
comment on column public.products.price is '판매가(원)';
comment on column public.products.sale_period is '한정 판매일 때만 입력';
comment on table public.product_ingredients is '원재료 1개당 1행. origin NULL = 원문에 없음';
comment on table public.product_storage is '보관조건 1개당 1행. days NULL = 원문에 없음';
comment on column public.product_storage.condition is '수령 후(신선식품) / 개봉 전 · 개봉 후(포장 식품)';
comment on column public.product_storage.days is '일 단위. 6개월=180, 12개월=365, 18개월=540, 3주=21로 환산';
comment on table public.product_cautions is '주의사항 1개당 1행. 알레르기는 없어도 ''없음'' 행을 넣는다';
comment on table public.shipping_policies is '모든 상품 공통 배송 규칙';

-- products.updated_at 자동 갱신
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 2. 접근 권한(RLS)
-- public 스키마는 Supabase API로 노출되므로 RLS를 켠다
-- 정책이 없으면 API(anon · authenticated)로는 읽을 수 없고, 대시보드와 service_role만 접근 가능
-- ---------------------------------------------------------------------

alter table public.products            enable row level security;
alter table public.product_ingredients enable row level security;
alter table public.product_storage     enable row level security;
alter table public.product_cautions    enable row level security;
alter table public.shipping_policies   enable row level security;

-- 앱에서 누구나 읽게 하려면 아래 주석을 풀어 테이블마다 실행
-- create policy "누구나 읽기" on public.products for select to anon, authenticated using (true);

-- ---------------------------------------------------------------------
-- 3. 확인용 뷰: 원문에 없어 채워야 하는 정보 목록
-- security_invoker = 조회하는 사람의 권한(RLS)을 그대로 따름
-- ---------------------------------------------------------------------

create view public.products_missing_info
with (security_invoker = true) as
select p.product_id, p.name, '알레르기 정보 없음' as issue
from public.products p
where not exists (
    select 1 from public.product_cautions c
    where c.product_id = p.product_id and c.caution_type = '알레르기'
)
union all
select p.product_id, p.name, '원산지 미기재: ' || i.ingredient
from public.product_ingredients i
join public.products p on p.product_id = i.product_id
where i.origin is null
union all
select p.product_id, p.name, '보관기간 미기재: ' || s.condition || ' ' || s.storage_type
from public.product_storage s
join public.products p on p.product_id = s.product_id
where s.days is null;

commit;

-- ---------------------------------------------------------------------
-- 초기화: 처음부터 다시 만들 때만 실행 (모든 데이터가 지워짐)
-- ---------------------------------------------------------------------
-- drop view if exists public.products_missing_info;
-- drop table if exists public.product_cautions, public.product_storage, public.product_ingredients, public.shipping_policies, public.products;
-- drop function if exists public.set_updated_at();
