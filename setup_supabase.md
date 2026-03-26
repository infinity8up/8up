# 새로운 Supabase 실환경 셋업 가이드

이 문서는 **이 저장소 기준**으로 새로운 Supabase hosted project(real DB)를 만들 때 해야 하는 작업을 순서대로 정리한 운영 문서입니다.

대상 범위:

- 새 Supabase project 생성
- DB 스키마/RLS/스토리지/기본 관리자 반영
- Auth URL/OAuth/SMTP 설정
- 푸쉬 알림용 Edge Function/FCM 연결
- 관리자 계정 생성
- 앱과 새 Supabase 연결

주의:

- `supabase/config.toml`은 **로컬 개발 설정**입니다.
- `db push`로 **DB 스키마/함수/RLS/스토리지 버킷/트리거**는 올라가지만,
  `Auth URL`, `OAuth provider`, `SMTP`, `Edge Function secrets`, `Vault secrets` 같은 항목은 **별도 설정**해야 합니다.
- `supabase/migrations/0_reset_db.sql`은 **실DB에서 실행하면 안 됩니다**.

## 1. 사전 준비

준비물:

- Supabase 계정
- 새 Supabase 프로젝트를 만들 권한
- 로컬에 `supabase` CLI 설치
- 이 저장소 최신 코드
- 푸쉬 알림을 쓸 경우 Firebase 프로젝트
- 소셜 로그인을 쓸 경우 Google / Kakao / Apple 개발자 콘솔 접근 권한

미리 기록해둘 값:

- Supabase `project ref`
- Supabase `Project URL`
- Supabase `anon key`
- Supabase `service_role key`
- DB 비밀번호

## 2. 새 Supabase 프로젝트 생성

Supabase Dashboard에서 새 프로젝트를 생성합니다.

추천 체크:

- Region은 실제 사용자와 가까운 곳
- DB 비밀번호는 별도 비밀 저장소에 보관
- 프로젝트 이름은 `8up-prod`, `8up-real`처럼 dev와 구분 가능하게

생성 후 아래 값을 기록합니다.

- `Project URL`
  - 예: `https://<project-ref>.supabase.co`
- `project ref`
  - 예: `<project-ref>`
- `anon key`
- `service_role key`

확인 위치:

- `Project Settings > API`

## 3. 로컬 CLI를 새 프로젝트에 연결

```bash
cd /Users/hyunsuk.choi/coding/8up

supabase login
supabase link --project-ref <YOUR_SUPABASE_PROJECT_REF>
```

연결 확인:

```bash
supabase status
```

## 4. 실DB에 스키마 반영

현재 이 저장소의 핵심 DB 파일은 아래 세 개입니다.

- 스키마/기본 정의: `supabase/migrations/1_1_schema.sql`
- 함수/프로시저: `supabase/migrations/1_2_logic.sql`
- 뷰/트리거/RLS/권한: `supabase/migrations/1_2_views_access.sql`

실행:

```bash
cd /Users/hyunsuk.choi/coding/8up
supabase db push
```

반영되는 주요 항목:

- `public` 스키마 테이블
- 함수 / RPC / 뷰
- RLS / policy / grant
- `app-images` storage bucket
- `notifications`, `notification_push_jobs` 등 알림 관련 구조
- 사용자/관리자 계정 동기화 트리거
- 기본 플랫폼 관리자 bootstrap

주의:

- `supabase/migrations/0_reset_db.sql`은 로컬 초기화용입니다. 실DB에서 실행 금지입니다.
- `supabase/migrations/3_1_small_seeds.sql`, `supabase/migrations/3_2_seeds.sql`는 실환경에 기본 적용하지 않는 것을 권장합니다.
  - 데모/샘플 데이터가 섞일 수 있으니, 꼭 필요할 때 내용을 검토한 뒤 수동 실행하세요.

## 5. 마이그레이션 후 바로 확인할 것

Supabase SQL Editor에서 아래를 확인합니다.

### 5-1. extension

```sql
select extname
from pg_extension
where extname in ('pgcrypto', 'pg_net', 'vault', 'pg_cron')
order by extname;
```

의미:

- `pgcrypto`: 비밀번호 암호화 등
- `pg_net`: DB에서 Edge Function HTTP 호출
- `vault`: DB 내부 secret 저장
- `pg_cron`: 예약 알림 / 푸쉬 dispatch 스케줄

`pg_cron`이 없다면:

- 수업 리마인드 생성
- 푸쉬 dispatch cron

이 자동으로 돌지 않습니다.

### 5-2. storage bucket

```sql
select id, name, public, file_size_limit
from storage.buckets
where id = 'app-images';
```

현재 버킷 기본값:

- bucket: `app-images`
- public: `true`
- size limit: `5MB`
- mime: `image/jpeg`

### 5-3. 기본 플랫폼 관리자

```sql
select login_id, email, status
from public.platform_admin_users;
```

현재 마이그레이션은 기본 플랫폼 관리자 1개를 자동 생성합니다.

- `login_id`: `8up_admin`
- `email`: `8up_admin@8up.local`
- 초기 비밀번호: `Admin123!`

실환경에서는 **반드시 즉시 비밀번호를 바꾸거나, 운영용 계정으로 교체**하세요.

### 5-4. cron job

```sql
select jobname, schedule, command
from cron.job
where jobname in ('eightup-user-notifications', 'eightup-push-dispatch')
order by jobname;
```

현재 등록 대상:

- `eightup-user-notifications`
  - 15분마다 수업 리마인드용 인앱 알림 생성
- `eightup-push-dispatch`
  - 1분마다 푸쉬 큐 처리

## 6. Auth 기본 설정

이 단계는 `db push`로 되지 않습니다. Dashboard에서 직접 맞춰야 합니다.

위치:

- `Authentication > URL Configuration`

설정할 것:

- `Site URL`
  - 실제 서비스 URL이 있으면 그 주소
  - 아직 없으면 운영 관리용 기준 URL을 넣고 나중에 교체
- `Redirect URLs`
  - `eightup://login-callback/`
  - 관리자 웹 실제 도메인이 있으면 그 URL
  - 필요 시 로컬 개발 URL도 추가

현재 앱 모바일 콜백 URL:

- `eightup://login-callback/`

주의:

- `supabase/config.toml`의 `site_url`, `additional_redirect_urls`는 local dev용입니다.
- hosted real project에는 자동 반영되지 않습니다.

## 7. 이메일 / SMTP 설정

위치:

- `Authentication > SMTP Settings`

이 프로젝트는 다음 기능에서 메일이 필요할 수 있습니다.

- 이메일 로그인/가입
- 이메일 변경
- 비밀번호 재설정 또는 인증 메일

실환경에서는 기본 테스트 메일러 대신 실제 SMTP를 설정하는 것이 안전합니다.

체크 항목:

- 발신자 주소
- 발신자 이름
- SMTP host / port / username / password
- 인증 메일 템플릿 문구

## 8. 소셜 로그인 설정

위치:

- `Authentication > Providers`

현재 앱에서 고려해야 하는 provider:

- Google
- Kakao
- Apple

### 8-1. Google

현재 코드 기준:

- Android: native Google Sign-In 후 Supabase `signInWithIdToken`
- iOS: Supabase OAuth redirect

실무 체크:

- Google Cloud에서 `Web client` 생성
- Supabase Google provider에 `Web client ID / secret` 입력
- Android/iOS client ID가 있으면 필요에 따라 추가
- Redirect URL에 `https://<project-ref>.supabase.co/auth/v1/callback` 등록
- 앱 redirect URL에는 `eightup://login-callback/` 허용

자세한 메모:

- `login.md` 참고

### 8-2. Kakao

현재 코드 기준:

- Supabase Kakao provider 사용
- 모바일은 외부 브라우저 OAuth 후 `eightup://login-callback/` 복귀

실무 체크:

- Kakao Developers에서 앱 생성
- Kakao 로그인 활성화
- Supabase Kakao provider 활성화
- Kakao REST API 키 / Client Secret 입력
- Kakao Redirect URI:
  - `https://<project-ref>.supabase.co/auth/v1/callback`
- Supabase Redirect URLs:
  - `eightup://login-callback/`

### 8-3. Apple

Apple 로그인을 실제로 사용할 경우:

- Apple Developer에서 Service ID / Key 준비
- Supabase Apple provider 활성화
- Redirect URL / Return URL 설정
- iOS bundle / capability와 함께 검증

## 9. Storage / 이미지 업로드 확인

이미지 업로드는 Supabase Storage `app-images` 버킷을 사용합니다.

대표 경로:

- 사용자: `users/<member_code>.jpg`
- 스튜디오: `studios/<studio_id>.jpg`
- 강사: `instructors/<studio_id>_<name>.jpg`

실환경 확인:

- 사용자 앱에서 프로필 이미지 업로드
- 관리자 웹에서 스튜디오 대표 이미지 업로드
- 관리자 웹에서 강사 이미지 업로드

업로드가 실패하면 아래를 확인합니다.

- `app-images` 버킷 존재 여부
- storage policy 정상 반영 여부
- 로그인 세션으로 업로드했는지

## 10. 푸쉬 알림을 쓸 경우 해야 하는 일

푸쉬는 DB만으로 끝나지 않습니다. 아래 3개가 모두 있어야 합니다.

1. Firebase 프로젝트
2. Supabase Edge Function 배포
3. DB Vault secret 등록

현재 Edge Function:

- `supabase/functions/dispatch-push-notifications`

배포:

```bash
cd /Users/hyunsuk.choi/coding/8up
supabase functions deploy dispatch-push-notifications --project-ref <YOUR_SUPABASE_PROJECT_REF>
```

Edge Function secret:

```bash
supabase secrets set --project-ref <YOUR_SUPABASE_PROJECT_REF> \
  FCM_PROJECT_ID="your-firebase-project-id" \
  FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"..."}'
```

중요:

- `--project-ref`는 **Supabase project ref**
- `FCM_PROJECT_ID`는 **Firebase project id**
- 둘은 서로 다른 값입니다

DB Vault secret:

```sql
select vault.create_secret('https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co', 'supabase_project_url');
select vault.create_secret('<YOUR_SUPABASE_ANON_KEY>', 'supabase_anon_key');
```

자세한 절차:

- `push_notifications.md` 참고

현재 푸쉬는 모든 인앱 알림이 아니라 아래 항목만 허용됩니다.

- `session_cancelled`
- `session_instructor_changed`
- `session_reservation_removed`
- `waitlist_promoted`
- `cancel_request_approved`
- `cancel_request_rejected`
- `session_reminder_day_before`
- `session_reminder_hour_before`
- 중요 공지
- 중요 이벤트

## 11. 최초 스튜디오 / 관리자 계정 생성

실환경에서 첫 스튜디오와 관리자 계정을 만들려면 아래 스크립트를 사용합니다.

- `supabase/migrations/99_1_create_admin.sql`

사용 방법:

1. SQL Editor 열기
2. `99_1_create_admin.sql` 내용 붙여넣기
3. declare 블록의 값 수정
4. 실행

입력할 값:

- 스튜디오명
- 스튜디오 전화번호
- 스튜디오 주소
- 관리자 이름
- 관리자 이메일
- 관리자 전화번호
- 관리자 로그인 ID
- 임시 비밀번호

추가 참고:

- `role`: `admin` 또는 `staff`
- `must_change_password`: 보통 `true`

## 12. 관리자 비밀번호 초기화가 필요할 때

아래 템플릿을 사용합니다.

- `supabase/migrations/99_2_reset_admin_password_template.sql`

용도:

- 관리자 로그인 ID 또는 이메일 기준으로 비밀번호 초기화
- `must_change_password = true`로 표시

## 13. 앱을 새 Supabase로 연결

모바일 앱은 아래 두 값을 읽습니다.

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

읽는 방법:

- `app/.env`
- 또는 `--dart-define`

현재 코드 기준:

- `app/lib/src/core/app_config.dart`
- `app/lib/src/app/bootstrap.dart`

예시 `.env`:

```env
SUPABASE_URL=https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co
SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY>
```

예시 실행:

```bash
flutter run --dart-define=SUPABASE_URL=https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co --dart-define=SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY>
```

## 14. 실환경 오픈 전 최종 점검

아래는 최소 점검 목록입니다.

- 이메일/비밀번호 로그인 정상 동작
- 사용자 회원가입 시 `auth.users` / `public.users` 동시 생성
- 기본 플랫폼 관리자 로그인 가능, 비밀번호 즉시 변경 완료
- 스튜디오 관리자 계정 생성 완료
- 관리자 웹에서 수업/회원/수강권 생성 가능
- 사용자 앱에서 예약/취소/취소문의 가능
- 공지/이벤트 노출 확인
- 이미지 업로드 확인
- 인앱 알림 생성 확인
- 푸쉬 사용 시 `notification_push_jobs`가 정상 처리되는지 확인
- `cron.job`에 두 작업이 존재하는지 확인
- OAuth provider별 실제 로그인 테스트
- iOS/Android deep link 복귀 확인

## 15. dev / prod 분리 시 같이 분리할 것

새 real DB를 만들 때 dev와 prod를 확실히 나누려면 아래도 같이 분리해야 합니다.

- Supabase project
- Supabase URL / anon key / service key
- Firebase project
- `FCM_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- Android / iOS 앱 설정 파일
  - `google-services.json`
  - `GoogleService-Info.plist`
- Google OAuth client
- Kakao app / redirect URI
- Apple 로그인 설정

즉:

- dev 앱은 dev Supabase / dev Firebase
- prod 앱은 prod Supabase / prod Firebase

구조로 두는 것이 맞습니다.

## 16. 하지 말아야 할 것

- `supabase/migrations/0_reset_db.sql`을 실DB에 실행
- seed 파일을 검토 없이 실환경에 그대로 주입
- `service_role key`, Firebase service account JSON을 Git에 커밋
- 기본 플랫폼 관리자 비밀번호 `Admin123!`를 그대로 운영
- `project ref`와 `FCM_PROJECT_ID`를 같은 값이라고 생각하고 혼용

## 17. 추천 순서 요약

가장 안전한 순서는 아래입니다.

1. 새 Supabase project 생성
2. `supabase link`
3. `supabase db push`
4. extension / bucket / platform admin 확인
5. Auth URL / SMTP / OAuth provider 설정
6. 필요 시 Firebase + Edge Function + Vault secret 설정
7. `99_1_create_admin.sql`로 첫 스튜디오 관리자 생성
8. 앱 `.env` 또는 `dart-define` 교체
9. 실제 로그인/예약/알림 시나리오 검증

---

관련 문서:

- `README.md`
- `login.md`
- `push_notifications.md`
