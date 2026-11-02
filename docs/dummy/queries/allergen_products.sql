-- =====================================================================
-- 알레르기 유발물질이 확인된 상품 조회 (실습 전용, 조회만 하고 데이터는 바꾸지 않음)
-- 대상 테이블: products, product_cautions (schema.sql · seed.sql 실행 후)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. 알레르기 유발물질이 확인된 상품 (상품별 한 줄)
--    제외: 알레르기가 '없음' · '미확인' · '미기재'이거나 비어 있는 상품
--    교차오염은 참고용으로 옆에 표시
-- ---------------------------------------------------------------------
select
    p.product_id as "상품코드",
    p.name       as "상품명",
    string_agg(c.content, ', ' order by c.id) filter (where c.caution_type = '알레르기') as "알레르기",
    string_agg(c.content, ', ' order by c.id) filter (where c.caution_type = '교차오염') as "교차오염"
from public.products p
join public.product_cautions c
  on c.product_id = p.product_id
 and c.caution_type in ('알레르기', '교차오염')
 and nullif(trim(c.content), '') is not null
 and trim(c.content) not in ('없음', '미확인', '미기재')
group by p.product_id, p.name
having count(*) filter (where c.caution_type = '알레르기') > 0
order by p.product_id;

-- 예상 결과 (seed.sql 기준 1행)
--  P-0402 | 서문시장 납작만두 | 밀, 대두 | 계란(제조 라인에서 사용)


-- ---------------------------------------------------------------------
-- 2. 특정 성분이 들어가거나 섞일 수 있는 상품 찾기
--    '대두' 자리를 찾을 성분으로 바꿔서 실행 (예: '견과류', '계란', '밀')
-- ---------------------------------------------------------------------
select
    p.product_id   as "상품코드",
    p.name         as "상품명",
    c.caution_type as "유형",
    c.content      as "내용"
from public.products p
join public.product_cautions c on c.product_id = p.product_id
where c.caution_type in ('알레르기', '교차오염')
  and c.content like '%' || '대두' || '%'
order by p.product_id;

-- 예상 결과 ('대두' 기준 1행)
--  P-0402 | 서문시장 납작만두 | 알레르기 | 대두


-- ---------------------------------------------------------------------
-- [점검] 1번 결과가 예상과 다를 때: 실제로 들어 있는 알레르기 · 교차오염 값 전체
-- seed.sql 기준이면 12행(알레르기 9 + 교차오염 3)이고 '미확인'이라는 값은 없어야 함
-- ---------------------------------------------------------------------
select c.product_id, p.name, c.caution_type, c.content
from public.product_cautions c
left join public.products p on p.product_id = c.product_id
where c.caution_type in ('알레르기', '교차오염')
order by c.product_id, c.caution_type, c.id;
