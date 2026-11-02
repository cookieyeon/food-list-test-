# 진행 기록

## 2026-11-02 — 가상 상품 엑셀 DB 생성

- 결과물: `docs/dummy/products_db.xlsx` (실습 전용, `docs/dummy/` 밖에 섞지 않음)
- 구조: 상품 1행 = 1상품, 빈 칸이 많던 정보는 하위 시트로 분리해 상품코드로 연결
  - `상품` 10행: 상품코드 · 상품명 · 분류 · 용량 · 수량 · 판매가 · 판매기간 · 특징
  - `원재료` 15행: 상품코드 · 원재료 · 원산지 (원재료 1개당 1행)
  - `보관조건` 16행: 상품코드 · 상태(수령 후/개봉 전/개봉 후) · 보관방법 · 기간(일) · 비고
  - `주의사항` 22행: 상품코드 · 유형(알레르기/교차오염/보관금지/조리금지/섭취주의) · 내용
  - `배송정책` 3행, `필드설명`(전 시트 열 정의 + 범례 · 규칙)
- 규칙: 모든 상품은 주의사항에 알레르기 행이 최소 1개(없으면 "없음")
- `신선식품여부` 열은 사용하지 않기로 해서 제거함
- 원문에 없어 "미기재"로 둔 칸(노란색) 8개: 사과칩 · 대추칩 알레르기, 납작만두 원재료 4종 원산지, 흑마늘 진액 정제수 원산지, 대추칩 개봉 전 보관기간
- 추정으로 채운 열: `분류` — 확인 필요
- 생성 방법: 이 PC에 Python이 없어 PowerShell + Excel COM으로 생성. 스크립트는 세션 scratchpad의 `make_products_db.ps1`
- 남은 일: 미기재 8칸 확인

## 2026-11-02 — Supabase용 SQL 작성

- 결과물: `docs/dummy/schema.sql`(구조) + `docs/dummy/seed.sql`(데이터). 실행 순서 schema → seed
  - SQL은 사용자가 Supabase SQL Editor에서 직접 실행
  - 처음엔 한 파일(`products_db.sql`)이었으나 스키마와 데이터로 나누고 원래 파일은 삭제(문장 단위 대조로 내용 동일 확인)
  - 테이블: `products` · `product_ingredients` · `product_storage` · `product_cautions` · `shipping_policies`
  - 하위 테이블은 `product_id` 외래 키로 연결(상품 삭제 · 코드 변경 시 함께 반영)
  - 허용 값은 check 제약으로 제한(분류 · 상태 · 보관방법 · 주의사항 유형)
  - 모든 테이블 RLS 켬, 정책은 없음 → API로는 읽을 수 없음. 공개 읽기 정책은 주석으로 준비
  - `products_missing_info` 뷰: 채워야 할 정보 8건(알레르기 2 · 원산지 5 · 보관기간 1)
- 엑셀과 다른 점: "미기재"는 NULL로, 미기재 알레르기 행은 넣지 않음(뷰로 확인)
- 영문 키 변경: `count` → `quantity`, `type` → `caution_type` (엑셀 필드설명도 맞춤)
- 검증: 엑셀과 행 단위 대조 완료. 이 PC에 Postgres가 없어 SQL 실행 검증은 못 함
- 남은 일: Supabase에서 실행 후 행 수 · 뷰 결과 확인, 앱에서 읽을 거면 RLS 읽기 정책 추가
- 사용자 실행 결과: `schema.sql`에서 `relation "products" already exists`. 이전 `products_db.sql`을 이미 실행했는지, 다른 `products` 테이블이 있는지 아직 확인 안 됨(확인 쿼리 안내함)

## 2026-11-02 — 알레르기 상품 조회 SQL

- 결과물: `docs/dummy/queries/allergen_products.sql`
  - 1번: 알레르기 · 교차오염 주의가 있는 상품 목록(상품별 한 줄). 예상 3행(사과칩 · 납작만두 · 대추칩)
  - 2번: 특정 성분('견과류' 등)으로 찾기
- 검증: seed.sql 데이터와 손으로 대조. Supabase 실행은 사용자 몫
- 수정: 알레르기가 확인된 상품만 나오도록 1번을 바꿈('없음' · '미확인' · '미기재' · 빈 값 제외). 예상 결과는 납작만두 1행
- 사용자 결과에 '미확인'이 보이고 납작만두가 빠졌다고 함 → seed.sql에는 '미확인' 값이 없으므로 Supabase의 실제 데이터가 seed와 다를 가능성. 파일 맨 아래 [점검] 쿼리로 확인 요청함

## 2026-11-02 — 로컬 상품 관리 웹페이지

- 결과물: `app/product-admin/index.html` (파일 하나, 서버 없이 브라우저로 열기)
  - 기능: 목록 조회, 검색(코드 · 이름 · 원재료 · 주의사항), 분류 · 알레르기(있음/없음/미확인) 필터, 상세 보기, 추가(원재료 · 보관조건 · 주의사항 포함), 삭제
  - 수정 기능은 없음(요청 범위 밖)
  - 연결: 페이지에서 Project URL + service_role 키 입력. 키는 파일에 저장하지 않고, "기억" 체크 시 브라우저 localStorage에만 저장
  - 앱 코드에 가상 상품 데이터 없음(CLAUDE.md 규칙), 허용 값 목록만 schema.sql과 맞춤
- 검증: 브라우저에서 가짜 DB 객체로 조회 · 검색 · 필터 · 상세 · 추가 · 입력 검사 · 삭제 확인. 실제 Supabase 연결은 사용자 몫
- 주의: 실제 DB가 schema.sql과 다르면(앞의 already exists · '미확인' 건) 조회가 실패할 수 있음

## 2026-11-02 — service_role 키 없이 쓰도록 변경

- 방식: anon 키 + Supabase 로그인(이메일 · 비밀번호) + 관리자 이메일만 허용하는 RLS 정책
- 새 파일: `docs/dummy/policies.sql` — `is_admin()` 함수(관리자 이메일 1개) + 5개 테이블에 "관리자 전체 권한" 정책
  - 이메일 자리는 '관리자 이메일을 여기에'로 비워 둠. 안 바꾸고 실행하면 아무도 접근 못 함
- 페이지 수정: `app/product-admin/index.html` — 연결 화면을 URL · anon 키 · 이메일 · 비밀번호 로그인으로, "연결 해제" → "로그아웃"
  - 비밀번호는 저장 안 함. "로그인 유지" 체크 시 URL · anon 키와 세션만 브라우저에 저장
- 검증: 가짜 인증 객체로 로그인 실패 · 성공 · 로그아웃 확인. 실제 Supabase 로그인은 사용자 몫
- 사용자가 할 일: 관리자 계정 만들기 → policies.sql 이메일 바꿔 실행 → (권장) 회원가입 끄기

## 2026-11-02 — 로그인 없이 누구나 접근으로 변경 (위 관리자 방식 대체)

- 이유: 사용자 요청. 실제 사용이 아니라 학습 · 테스트용
- `docs/dummy/policies.sql`: 5개 테이블에 "누구나 전체 권한"(anon · authenticated, 조회 · 추가 · 수정 · 삭제) 정책
  - 이전 관리자 정책과 `is_admin()`을 먼저 지우고 만듦. 여러 번 실행해도 됨
- `app/product-admin/index.html`: 로그인 제거, URL + anon 키로 연결
  - 스크립트 맨 위 `SUPABASE_URL` · `SUPABASE_ANON_KEY`에 적어 두면 열자마자 연결(비어 있으면 연결 화면)
- 검증: 가짜 객체로 연결 · 연결 해제 확인, 남은 로그인 코드 없음 확인. 실제 Supabase는 사용자 몫
- 주의: anon 키를 가진 누구나 데이터를 바꾸거나 지울 수 있음(테스트용이라 감수)

## 2026-11-02 — 처음 버전 페이지 + .env.local 설정 (위 두 방식 대체)

- 사용자 요청: 페이지는 처음 버전(service_role 키로 연결)으로, 연결 정보는 `.env.local`에서(Session pooler 아님)
- `app/product-admin/index.html`: 처음 버전으로 되돌림 + `config.js`의 값으로 자동 연결. 값이 없으면 처음처럼 연결 화면
- 새 파일 `app/product-admin/server.ps1`: `.env.local`을 읽어 `http://localhost:8787`로 페이지 제공(Node · Python 없어 PowerShell로)
  - 제공 경로는 `/`와 `/config.js`뿐. `.env.local` 등 다른 파일은 404
  - service_role 키가 있으면 그 키, 없으면 anon 키를 페이지에 넘김
- 새 파일 `app/product-admin/.env.local`: 빈 템플릿(`NEXT_PUBLIC_SUPABASE_URL` · `NEXT_PUBLIC_SUPABASE_ANON_KEY` · `SUPABASE_SERVICE_ROLE_KEY`). 값은 사용자가 입력
- 새 파일 `app/product-admin/.gitignore`: `.env.local` 제외
- 버그 수정: PowerShell `Split('=', 2)`가 2를 구분 문자로 처리해 '='가 든 값이 잘림 → 첫 '=' 위치로 자르도록 수정
- 검증: 가짜 값 env로 서버 응답 · 경로 차단 · 자동 연결 시도 확인, 빈 env 응답 확인. 실제 Supabase 연결은 사용자 몫
- `docs/dummy/policies.sql`("누구나 전체 권한")은 그대로 둠. service_role로 연결하면 필요 없음. 이미 실행했다면 anon 키로도 누구나 접근 가능한 상태이니 파일 아래 되돌리기 SQL 참고

## 2026-11-02 — 개발 서버

- `app/product-admin/server.ps1`: 자동 새로고침 추가. `index.html` · `.env.local` 수정 시각을 `/__version`으로 알려 주고, 페이지에 1초 간격 확인 스크립트를 끼워 넣음(index.html 파일 자체는 안 바뀜)
  - 제공 경로: `/` · `/config.js` · `/__version`. 나머지 404
- 새 파일 `.claude/launch.json`: 이름 `product-admin`, 포트 8787. Claude 앱 브라우저 미리보기에서 바로 실행
- 검증: 미리보기로 서버 실행, index.html 수정 시각 변경 → 페이지 자동 새로고침 확인, `.env.local` · `server.ps1` 404 확인

## 2026-11-02 — GitHub 저장소 연결

- git 2.56.0 설치(사용자). 이 폴더를 git 저장소로 만들고 `main` 브랜치, origin = `https://github.com/cookieyeon/food-list-test-.git`
- 작성자는 이 저장소에만 설정: `cookieyeon` / 계정 이메일
- `README.md`(`# food-list-test-`)만 커밋: `b758971 first commit`. 다른 파일은 아직 git에 안 올림
  - README는 PowerShell `echo`로 UTF-16으로 만들어져 있던 것을 UTF-8로 다시 저장
- push: Claude 실행 창은 GitHub 로그인 창을 띄울 수 없어 사용자가 자기 터미널에서 `git push -u origin main` 실행 → 성공(원격 `main` = `b758971` 확인)
- 폴더 맨 위 `.gitignore` 새로 만듦: `.DS_Store` · `.env` · `.env*.local` · `.claude/settings.local.json` 제외. 한글 파일명 표시용 `core.quotepath false`(이 저장소만)
- 나머지 파일 23개 커밋 · push: `05a69ae 상품 DB · 관리 페이지 추가`. 원격 `main` = `05a69ae` 확인, `.env.local`은 안 올라감 확인

## 2026-11-02 — Vercel 배포 404 해결

- 증상: 사용자가 저장소를 Vercel에 연결해 배포 → 사이트 주소에서 404(맨 위에 index.html이 없음)
- 사용자가 Vercel 설정 화면(Root Directory)을 못 찾아서 대시보드 대신 파일로 해결
  - 새 파일 `vercel.json`: `/` → `/app/product-admin/index.html`로 연결
  - 새 파일 `.vercelignore`: `app/product-admin/index.html`만 배포(SQL · 문서 · `server.ps1` 등 제외)
- 배포판에는 `config.js`가 없어 자동 연결 안 됨 → 연결 화면에서 URL · 키 입력. service_role 키는 배포판에 쓰지 말고 anon 키 + `policies.sql` 사용 권장
- 검증: 이 PC에서 Vercel을 돌려 볼 수 없어 배포 결과는 사이트 주소로 확인 필요
