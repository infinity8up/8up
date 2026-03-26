# 8UP

8UP은 `사용자 앱`, `스튜디오 관리자 웹`, `Supabase 백엔드`를 하나의 저장소에서 함께 관리하는 프로젝트입니다.

현재 구조는 다음을 전제로 합니다.

- 모바일 앱: 회원이 수업, 공지, 이벤트, 수강권, 예약 내역을 확인하고 예약/취소를 진행
- 웹 앱: 스튜디오 관리자가 강사, 수업, 수강권, 회원, 콘텐츠, 취소 정책을 운영
- Supabase: 인증, 스토리지, 알림, 예약 로직, RLS, 뷰, cron 작업을 담당

## 1. 저장소 구성

- `app/`
  - Flutter 애플리케이션
  - 모바일에서는 사용자 앱으로 실행
  - 웹에서는 관리자 웹으로 실행
- `supabase/`
  - 스키마, 함수, 뷰, RLS, grants, 수동 패치 SQL
- `setup_supabase.md`
  - 새로운 Supabase 프로젝트를 실제 운영용으로 셋업할 때 필요한 상세 문서

## 2. 런타임 동작 방식

- 엔트리 포인트: `app/lib/main.dart`
- 부트스트랩: `app/lib/src/app/bootstrap.dart`
- 앱 루트: `app/lib/src/app/eightup_app.dart`

실행 기준:

- `kIsWeb == true`
  - 관리자 웹 `EightUpAdminWebApp` 실행
- `kIsWeb == false`
  - 사용자 앱 `RootShell` 실행

즉, 현재 저장소는 앱을 두 개로 분리한 것이 아니라 `Flutter 단일 코드베이스 + 플랫폼별 분기` 구조입니다.

## 3. 기술 스택

- Flutter / Dart
- Provider
- Supabase
- Firebase Core / Firebase Messaging
- flutter_local_notifications
- shared_preferences
- table_calendar

## 4. 빠른 실행

### 4-1. 환경 변수

`app/.env`에 최소 아래 값을 넣어야 합니다.

```env
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
```

`AppConfig`는 아래 순서로 값을 읽습니다.

1. `--dart-define=SUPABASE_URL=...`
2. `--dart-define=SUPABASE_ANON_KEY=...`
3. `app/.env`

### 4-2. 의존성 설치

```bash
cd /Users/hyunsuk.choi/coding/8up/app
flutter pub get
```

### 4-3. 사용자 앱 실행

```bash
cd /Users/hyunsuk.choi/coding/8up/app
flutter run
```

주의:

- iOS 푸시 알림 검증은 실기기에서 진행하는 것을 권장합니다.
- 현재 iOS 최소 타겟은 `13.0` 기준입니다.

### 4-4. 관리자 웹 실행

```bash
cd /Users/hyunsuk.choi/coding/8up/app
flutter run -d chrome
```

### 4-5. 점검 명령

```bash
cd /Users/hyunsuk.choi/coding/8up/app
flutter analyze
dart format lib
```

## 5. 사용자 앱 현재 기능

사용자 앱의 하단 탭은 다음 4개입니다.

- `스튜디오`
- `예약`
- `내 예약`
- `마이`

### 5-1. 스튜디오 탭

- 현재 선택된 스튜디오 요약 표시
- 공지와 이벤트를 최신 노출 시작일 기준으로 정렬
- 공지/이벤트 상세는 팝업이 아니라 별도 페이지로 이동
- 중요 공지/이벤트 여부를 라벨로 표시

### 5-2. 예약 탭

- `2주 / 월` 전환 가능한 수업 캘린더
- 날짜별 수업 상태를 dot로 표시
- 선택한 날짜의 수업 리스트 표시
- 버튼 문구는 취소 정책 상태에 따라 달라짐
  - `예약`
  - `취소`
  - `취소 요청`
  - `직접 문의`
- 수업 강사 정보는 `class_sessions.instructor_id`를 기준으로 표시

### 5-3. 내 예약 탭

- 상태 탭: `예정 / 대기 / 완료 / 취소`
- 각 탭에 항목 수 표시
- 취소 가능 여부에 따라 안내 문구 분기
- 취소 불가 기간인 경우 앱 내부 취소 대신 스튜디오 문의 안내 표시

### 5-4. 마이 탭

- `내 정보`
- `스튜디오 선택`
- `내 수강권`
- 설정 페이지 마지막에 로그아웃

현재 스튜디오 선택 규칙:

- 스튜디오 선택은 `마이` 탭에서만 변경
- 선택값은 로컬 저장되어 앱 재실행 후에도 유지
- 다른 탭은 이 선택된 스튜디오를 기준으로 데이터 표시

수강권 표시 규칙:

- 사용 중인 수강권은 카드형으로 표시
- 수강권명, 예약 가능 수업 라벨, 유효기간, 잔여/예정/완료 표시
- 사용 이력 상세의 영문 memo는 한글로 변환 표시

## 6. 관리자 웹 현재 기능

관리자 웹의 중심 파일은 `app/lib/src/admin/admin_web_app.dart`입니다.

현재 주요 탭은 다음과 같습니다.

- `대시보드`
- `콘텐츠 관리`
- `강사 관리`
- `수업 템플릿`
- `수업 관리`
- `취소 관리`
- `수강권 상품`
- `회원 관리`
- `사용법 설명`

### 6-1. 로그인 / 플랫폼 관리자

- 스튜디오 관리자 로그인
- 임시 비밀번호 발급
- 새 스튜디오 등록 요청
- 플랫폼 관리자(`8up_admin`)용 승인 화면

새 스튜디오 등록 요청 팝업은 현재:

- 모든 필수 입력이 유효해야 `등록 요청` 버튼 활성화
- 변경 불가 항목은 빨간색 안내 문구로 표시

### 6-2. 대시보드

- 오늘 수업
- 이번달 매출 / 환불
- 전월 비교 지표
- 운영 요약 카드

### 6-3. 콘텐츠 관리

- 공지 / 이벤트 등록, 수정, 삭제
- `중요 공지` 또는 중요 이벤트는 사용자 앱 푸시 대상
- 일반 공지/이벤트는 인앱 알림 및 노출 중심

### 6-4. 강사 관리

- 강사 등록 / 수정 / 삭제
- 강사 이미지 업로드
- 강사별 월간 스케줄 확인
- 실제 수업 카운트는 `수업 관리`에서 해당 회차에 강사가 지정된 경우만 반영

### 6-5. 수업 템플릿 / 수업 관리

수업 템플릿:

- 반복 수업의 기본 정의
- 기본 강사 지정 가능
- 활성 / 보관 구분

수업 관리:

- 월간 / 주간 달력
- 여러 템플릿을 한 번에 선택하여 기간 기준 일괄 개설
- 일회성 수업 생성
- 개별 회차 강사 지정
- 예약 회원 관리
- 강사 지정
- 회차 취소 / 삭제

### 6-6. 취소 관리

- 취소 정책 시간 / 마감 시각 설정
- `취소 문의 앱 내 허용 / 비허용` 토글
- 취소 요청 승인 / 거절
- 처리 완료 이력 확인

중요:

- `취소 문의 앱 내 허용`은 취소 정책 팝업 내부가 아니라 메인 카드에서 직접 토글합니다.

### 6-7. 수강권 상품

- 수강권 상품 생성 / 수정 / 보관
- 예약 가능한 수업 템플릿을 1개 이상 선택해야 저장 가능
- 선택 가능한 수업이 없으면 `수업 템플릿을 먼저 생성`하라는 안내 표시

### 6-8. 회원 관리

- 회원 검색 후 스튜디오 연결
- 수강권 발급 / 이력 / 환불 / 홀딩 / 상담 노트
- 회원 그룹 분류:
  - 수강권 있는 회원
  - 수강권 만료 후 1달 이내 회원
  - 수강권 만료 1달 이후 회원

분류 규칙:

- 수강권 발급 이력이 있으면 가장 최근 만료일 기준
- 수강권 이력이 없으면 `studio_user_memberships.joined_at` 기준

### 6-9. 사용법 설명

관리자 웹 마지막 탭에 사용법 설명 페이지가 있습니다.

포함된 내용:

- 수업 템플릿과 수강권의 관계
- 일회성 수업과 노출 수강권
- 강사 등록과 월별 정산
- 취소 정책과 취소 요청 흐름
- 회원 관리에서 수강권 발급 / 수정 / 환불 / 홀딩
- 운영 꿀팁

## 7. 현재 핵심 운영 규칙

### 7-1. 수업 템플릿과 수강권의 관계

- 수업 템플릿은 실제 수업 개설의 기준
- 수강권 상품은 어떤 템플릿을 예약 가능하게 할지 선택해서 생성
- 특정 수강권을 가진 회원은 그 수강권으로 예약 가능한 수업만 앱에서 볼 수 있음

### 7-2. 일회성 수업

- `수업 관리 > 수업 개설 > 일회성 수업 생성`에서 생성
- 이때도 `노출 수강권`을 선택해야 실제 회원 앱에 노출됨

### 7-3. 취소 정책

- 취소 정책 이전 시간: 앱에서 직접 취소 가능
- 취소 정책 이후 시간:
  - 앱 내 문의 허용이면 `취소 요청`
  - 앱 내 문의 비허용이면 `직접 문의`

### 7-4. 강사 표시

- 사용자 앱 강사 정보는 `class_sessions.instructor_id` 기준
- 강사를 템플릿에만 넣고 실제 회차에 배정하지 않으면 앱에서는 `강사 정보 없음`으로 보일 수 있음

## 8. 이미지 업로드 / 스토리지

이미지 업로드는 URL 직접 입력이 아니라 `파일 선택 -> Supabase Storage 업로드` 방식입니다.

공통 저장소:

- `app/lib/src/repositories/image_storage_repository.dart`

대표 경로 규칙:

- 사용자: `users/<member_code>.jpg`
- 스튜디오: `studios/<studio_id>.jpg`
- 강사: `instructors/<studio_id>_<sanitized-name>.jpg`

적용 대상:

- 사용자 프로필 이미지
- 스튜디오 이미지
- 강사 이미지

## 9. 알림 / 푸시

현재 알림 구조는 다음과 같습니다.

- 인앱 알림: `public.notifications`
- 푸시 큐: `public.notification_push_jobs`
- 디바이스 토큰: `public.push_notification_devices`
- 트리거: `trg_enqueue_notification_push_job`
- cron:
  - `eightup-user-notifications`
  - `eightup-push-dispatch`

중요 공지 / 이벤트는 푸시 대상이 될 수 있습니다.

실제 운영 셋업은 [`setup_supabase.md`](./setup_supabase.md)를 참고하세요.

## 10. Supabase 마이그레이션 구조

현재 핵심 파일은 아래 4개입니다.

- `supabase/migrations/0_reset_db.sql`
- `supabase/migrations/1_1_schema.sql`
- `supabase/migrations/1_2_logic.sql`
- `supabase/migrations/1_2_views_access.sql`

역할:

- `0_reset_db.sql`
  - 로컬/재구축용 reset 스크립트
- `1_1_schema.sql`
  - 테이블, enum, index, 기본 스키마
- `1_2_logic.sql`
  - 함수, RPC, 비즈니스 로직
- `1_2_views_access.sql`
  - 뷰, 트리거, RLS, 정책, grants, runtime bootstrap

`1_2_logic.sql`이 너무 커져서 현재는 다음처럼 분리되어 있습니다.

- 로직: `1_2_logic.sql`
- 뷰 / 접근제어: `1_2_views_access.sql`

## 11. DB 전체 재세팅 순서

깨끗하게 다시 세팅할 때는 반드시 아래 순서로 실행합니다.

1. `0_reset_db.sql`
2. `1_1_schema.sql`
3. `1_2_logic.sql`
4. `1_2_views_access.sql`

중요:

- `0_reset_db.sql`은 이미 데이터가 있는 DB를 강제로 비우는 용도입니다. 운영 DB에서 무분별하게 실행하면 안 됩니다.
- 새 Supabase 프로젝트처럼 처음부터 비어 있는 DB라면 `1_1_schema.sql -> 1_2_logic.sql -> 1_2_views_access.sql`만 실행해도 됩니다.
- `1_1 + 1_2_logic`까지만 실행하면 안 됩니다.
- 사용자 앱이 읽는 `v_class_session_feed`, `v_user_reservation_details`, 각종 RLS 정책은 `1_2_views_access.sql`에 있습니다.
- 강사 표시 문제 수정도 `1_2_views_access.sql`에 포함되어 있습니다.

즉, 새로 세팅할 때는 `manual_patches`를 사용할 필요가 없습니다.

## 12. manual_patches 사용 기준

`supabase/manual_patches/`는 이미 운영 중인 DB에 일부 변경만 빠르게 반영할 때 사용합니다.

예:

- 예약 중복 방지 수정
- 사용자 강사 표시 수정

하지만 DB를 새로 reset하고 다시 세팅하는 경우에는 `manual_patches`가 아니라 아래만 쓰면 됩니다.

- `1_1_schema.sql`
- `1_2_logic.sql`
- `1_2_views_access.sql`

## 13. 현재 중요 뷰

사용자 앱에서 특히 중요한 뷰는 다음 두 개입니다.

- `public.v_class_session_feed`
- `public.v_user_reservation_details`

현재 이 두 뷰는 모두:

- 강사 정보를 `class_sessions.instructor_id` 기준으로 읽음
- `instructors` 테이블의 이름 / 이미지 URL을 함께 노출
- 취소 정책 상태를 함께 내려서 앱 버튼 문구를 분기

## 14. 주요 파일 맵

### 사용자 앱

- 앱 루트: `app/lib/src/app/eightup_app.dart`
- 탭 쉘: `app/lib/src/presentation/screens/root_shell.dart`
- 예약: `app/lib/src/presentation/screens/calendar_screen.dart`
- 내 예약: `app/lib/src/presentation/screens/reservations_screen.dart`
- 스튜디오: `app/lib/src/presentation/screens/studio_screen.dart`
- 마이: `app/lib/src/presentation/screens/profile_screen.dart`
- 예약 상세 / 취소 팝업: `app/lib/src/presentation/widgets/session_detail_sheet.dart`

### 관리자 웹

- 관리자 웹 루트: `app/lib/src/admin/admin_web_app.dart`
- 관리자 저장소: `app/lib/src/admin/repositories/admin_repository.dart`
- 관리자 인증 저장소: `app/lib/src/admin/repositories/admin_auth_repository.dart`

### 공통 / 데이터 계층

- 앱 설정 저장: `app/lib/src/repositories/app_settings_repository.dart`
- 사용자 컨텍스트: `app/lib/src/providers/user_context_controller.dart`
- 세션 저장소: `app/lib/src/repositories/session_repository.dart`
- 예약 저장소: `app/lib/src/repositories/reservation_repository.dart`
- 수강권 저장소: `app/lib/src/repositories/pass_repository.dart`
- 이미지 저장소: `app/lib/src/repositories/image_storage_repository.dart`

## 15. 주의사항

- 현재 웹은 관리자 웹 전용입니다. 사용자 앱 웹 버전은 기본 진입 경로에 포함되어 있지 않습니다.
- iOS 푸시 알림은 시뮬레이터보다 실기기 검증이 우선입니다.
- DB 재세팅 후 앱에서 이전 상태가 보이면 로그아웃 후 재로그인 또는 hot restart로 다시 확인하세요.
- 관리자 웹은 현재 `admin_web_app.dart` 단일 파일 비중이 큽니다. 추가 리팩터링이 필요할 수 있습니다.

## 16. 참고 문서

- Supabase 실환경 셋업: [`setup_supabase.md`](./setup_supabase.md)
