# Push Notifications Setup

이 프로젝트는 `notifications` 테이블에 인앱 알림이 생성되면,

1. DB가 `notification_push_jobs` 큐에 적재하고
2. Supabase Edge Function `dispatch-push-notifications`가 큐를 읽어
3. Firebase Cloud Messaging(FCM)으로 Android/iPhone 푸쉬를 전송하는 구조입니다.

앱 안에서는 `계정 관리 > 앱 푸시 알림` 토글로 기기별 푸쉬 수신 여부를 제어합니다.

단, 모든 인앱 알림이 푸쉬로 가는 것은 아닙니다. 현재 푸쉬 대상은 아래 항목만 허용됩니다.

- `session_cancelled`
- `session_instructor_changed`
- `session_reservation_removed`
- `waitlist_promoted`
- `cancel_request_approved`
- `cancel_request_rejected`
- `session_reminder_day_before`
- `session_reminder_hour_before`
- `notice` 중 `is_important = true`
- `event` 중 `is_important = true`

## 1. Firebase 프로젝트 준비

### Android

Firebase Console에서 Android 앱을 추가합니다.

- 패키지명: `com.eightup.app`
- 완료 후 `google-services.json` 다운로드
- 파일 위치:
  - `app/android/app/google-services.json`

### iOS

Firebase Console에서 iOS 앱을 추가합니다.

- 번들 ID: Xcode `Runner` 타깃의 Bundle Identifier와 동일해야 함
- 완료 후 `GoogleService-Info.plist` 다운로드
- 파일 위치:
  - `app/ios/Runner/GoogleService-Info.plist`

### iOS APNs 연결

FCM이 iPhone 푸쉬를 보내려면 Apple Push Notification service(APNs)가 연결되어야 합니다.

Apple Developer에서:

- `Keys` 또는 `Certificates, Identifiers & Profiles`에서 APNs 인증 키 생성
- Key ID, Team ID 확인

Firebase Console `Project settings > Cloud Messaging`에서:

- APNs Authentication Key 업로드
- Key ID / Team ID 입력

## 2. iOS Xcode 설정

Xcode에서 `ios/Runner.xcworkspace`를 열고 `Runner` 타깃에 아래 Capability를 켭니다.

- `Push Notifications`
- `Background Modes`
  - `Remote notifications` 체크

주의:

- Push capability를 Apple Developer App ID에도 켜야 합니다.
- 개발/배포 프로비저닝 프로파일이 새 capability를 포함하도록 다시 받아야 할 수 있습니다.

## 3. Supabase Edge Function 배포

이 레포에는 아래 함수가 들어 있습니다.

- `supabase/functions/dispatch-push-notifications/index.ts`

배포 예시:

```bash
supabase functions deploy dispatch-push-notifications
```

## 4. Supabase Edge Function secrets

Edge Function은 Firebase 서비스 계정으로 FCM HTTP v1 API를 호출합니다.

필요한 secret:

- `FCM_PROJECT_ID`
  - Firebase 프로젝트 ID
- `FIREBASE_SERVICE_ACCOUNT_JSON`
  - Firebase Admin SDK용 서비스 계정 JSON 전체 문자열

예시:

```bash
supabase secrets set FCM_PROJECT_ID="your-firebase-project-id"
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"..."}'
```

서비스 계정 JSON은 Google Cloud Console에서 생성합니다.

- `IAM & Admin > Service Accounts`
- 서비스 계정 생성
- `Firebase Cloud Messaging API Admin` 또는 이에 준하는 FCM 전송 권한 부여
- JSON key 다운로드

## 5. Supabase DB Vault secrets

DB cron job이 Edge Function을 호출할 때 사용할 값입니다.

- `supabase_project_url`
  - 예: `https://<project-ref>.supabase.co`
- `supabase_anon_key`
  - 해당 프로젝트의 anon/publishable key

SQL 예시:

```sql
select vault.create_secret('https://<project-ref>.supabase.co', 'supabase_project_url');
select vault.create_secret('<anon-key>', 'supabase_anon_key');
```

이미 같은 이름의 secret이 있다면 Dashboard에서 업데이트하거나 기존 secret을 정리한 뒤 다시 생성합니다.

## 6. DB 마이그레이션 적용

이번 변경으로 아래 항목이 추가되었습니다.

- `push_notification_devices`
- `notification_push_jobs`
- `notification_push_deliveries`
- `upsert_push_notification_device(...)`
- `disable_push_notification_device(...)`
- `trg_enqueue_notification_push_job`
- `setup_push_notification_dispatch_job()`
- `cleanup_notification_push_history()`
- `setup_notification_push_cleanup_job()`

마이그레이션 적용 후, cron 설정을 다시 보장하려면 아래를 한 번 실행해도 됩니다.

```sql
select public.setup_push_notification_dispatch_job();
select public.setup_notification_push_cleanup_job();
```

기본 스케줄은 1분마다 큐를 확인합니다.

- `eightup-push-dispatch`
  - 매분 `pending` 큐만 확인
- `eightup-push-cleanup`
  - 매일 한 번 처리 완료된(`sent`, `skipped`, `failed`) 푸쉬 job과 delivery 기록을 30일 기준으로 정리

## 7. 동작 확인 순서

1. 앱에서 로그인
2. `계정 관리 > 앱 푸시 알림` 활성화
3. 권한 허용
4. `push_notification_devices`에 현재 기기 토큰이 저장됐는지 확인
5. 관리자 웹에서 공지/이벤트/수업 변경 등 알림이 발생하는 작업 수행
6. `notifications` 생성 확인
7. `notification_push_jobs`가 `sent` 또는 `skipped`로 바뀌는지 확인
8. 휴대폰에 푸쉬 수신 확인

## 8. dev / prod 분리 권장

나중에 dev/prod를 분리할 경우 다음도 같이 분리하는 것이 안전합니다.

- Firebase 프로젝트
- Android 앱 등록
- iOS 앱 등록
- `google-services.json`
- `GoogleService-Info.plist`
- Supabase project
- Edge Function secrets
- DB Vault secrets

즉, dev Supabase는 dev Firebase를 보고, prod Supabase는 prod Firebase를 보게 두는 것이 맞습니다.
