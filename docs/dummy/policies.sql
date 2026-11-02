-- =====================================================================
-- 누구나 읽기 · 쓰기 허용하는 RLS 정책 (학습 · 테스트 전용)
-- schema.sql 실행 후 Supabase SQL Editor에서 실행. 여러 번 실행해도 된다
-- 이걸 실행하면 app/product-admin 페이지를 로그인 없이 anon 키만으로 쓸 수 있다
--
-- 주의: anon 키를 가진 사람은 누구나 데이터를 조회 · 추가 · 수정 · 삭제할 수 있다
--       실제 서비스 데이터에는 쓰지 않는다
-- =====================================================================

begin;

-- 이전에 관리자 전용 정책을 실행했다면 지운다
drop policy if exists "관리자 전체 권한" on public.products;
drop policy if exists "관리자 전체 권한" on public.product_ingredients;
drop policy if exists "관리자 전체 권한" on public.product_storage;
drop policy if exists "관리자 전체 권한" on public.product_cautions;
drop policy if exists "관리자 전체 권한" on public.shipping_policies;
drop function if exists public.is_admin();

-- 다시 실행할 때 겹치지 않도록 먼저 지우고 만든다
drop policy if exists "누구나 전체 권한" on public.products;
drop policy if exists "누구나 전체 권한" on public.product_ingredients;
drop policy if exists "누구나 전체 권한" on public.product_storage;
drop policy if exists "누구나 전체 권한" on public.product_cautions;
drop policy if exists "누구나 전체 권한" on public.shipping_policies;

-- 로그인 여부와 관계없이 조회 · 추가 · 수정 · 삭제 전부 허용
create policy "누구나 전체 권한" on public.products
    for all to anon, authenticated using (true) with check (true);

create policy "누구나 전체 권한" on public.product_ingredients
    for all to anon, authenticated using (true) with check (true);

create policy "누구나 전체 권한" on public.product_storage
    for all to anon, authenticated using (true) with check (true);

create policy "누구나 전체 권한" on public.product_cautions
    for all to anon, authenticated using (true) with check (true);

create policy "누구나 전체 권한" on public.shipping_policies
    for all to anon, authenticated using (true) with check (true);

commit;

-- ---------------------------------------------------------------------
-- 확인 (따로 실행): 테이블 5개에 "누구나 전체 권한" 정책이 1개씩 있어야 함
-- ---------------------------------------------------------------------
-- select tablename, policyname, cmd, roles from pg_policies where schemaname = 'public' order by tablename;

-- ---------------------------------------------------------------------
-- 되돌리기: 정책을 지우면 다시 service_role 키로만 접근 가능
-- ---------------------------------------------------------------------
-- drop policy if exists "누구나 전체 권한" on public.products;
-- drop policy if exists "누구나 전체 권한" on public.product_ingredients;
-- drop policy if exists "누구나 전체 권한" on public.product_storage;
-- drop policy if exists "누구나 전체 권한" on public.product_cautions;
-- drop policy if exists "누구나 전체 권한" on public.shipping_policies;
