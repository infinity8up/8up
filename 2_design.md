# 수강권 기반 스튜디오 출결/예약 앱 상세 설계서
## DB 테이블 구조

---

## 1. studios
스튜디오 기본 정보

### 컬럼
- id (uuid, pk)
- name (text, not null)
- contact_phone (text)
- address (text)
- status (text) -- active / inactive
- created_at (timestamp)
- updated_at (timestamp)

---

## 2. admin_users
스튜디오 관리자 계정

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- login_id (text, unique, not null)
- password_hash (text, not null)
- name (text)
- email (text)
- phone (text)
- role (text) -- admin / staff
- must_change_password (boolean, default true)
- status (text) -- active / inactive
- created_at (timestamp)
- updated_at (timestamp)

---

## 3. users
앱 사용자 계정

### 컬럼
- id (uuid, pk)
- member_code (varchar(5), unique, not null)
- phone (text)
- email (text)
- password_hash (text)
- name (text)
- status (text) -- active / inactive
- created_at (timestamp)
- updated_at (timestamp)

### member_code 규칙
- 소문자 + 숫자 5자리
- unique
- 생성 후 수정 불가

---

## 4. studio_user_memberships
스튜디오-회원 연결 테이블

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- user_id (uuid, fk -> users.id)
- membership_status (text) -- active / inactive
- joined_at (timestamp)
- created_at (timestamp)
- updated_at (timestamp)

### 제약
- unique(studio_id, user_id)

---

## 5. class_templates
수업 템플릿

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- name (text, not null)
- category (text) -- yoga / pilates / ballet / etc
- description (text)
- day_of_week_mask (text or jsonb)
- start_time (time, not null)
- end_time (time, not null)
- capacity (int, not null)
- status (text) -- active / inactive
- created_at (timestamp)
- updated_at (timestamp)

### day_of_week_mask 예시
- ["tue","thu"]
- ["mon","wed","fri"]

---

## 6. pass_products
수강권 상품 정의

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- name (text, not null)
- total_count (int, not null)
- valid_days (int, not null)
- price_amount (numeric(12,2), not null)
- description (text)
- status (text) -- active / inactive
- created_at (timestamp)
- updated_at (timestamp)

---

## DB 테이블 구조 / 상태값 설계

---

## 7. pass_product_template_mappings
수강권 상품과 예약 가능한 수업 템플릿 매핑

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- pass_product_id (uuid, fk -> pass_products.id)
- class_template_id (uuid, fk -> class_templates.id)
- created_at (timestamp)

### 제약
- unique(pass_product_id, class_template_id)

---

## 8. class_sessions
실제 달력에 생성된 수업 회차

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- class_template_id (uuid, fk -> class_templates.id)
- session_date (date, not null)
- start_at (timestamp, not null)
- end_at (timestamp, not null)
- capacity (int, not null)
- status (text) -- scheduled / cancelled / completed
- created_by_admin_id (uuid, fk -> admin_users.id)
- created_at (timestamp)
- updated_at (timestamp)

### 인덱스 추천
- index(studio_id, session_date)
- index(class_template_id, session_date)

---

## 9. user_passes
회원이 실제로 보유한 수강권

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- user_id (uuid, fk -> users.id)
- pass_product_id (uuid, fk -> pass_products.id)
- name_snapshot (text)
- total_count (int, not null)
- valid_from (date, not null)
- valid_until (date, not null)
- paid_amount (numeric(12,2), default 0)
- refunded_amount (numeric(12,2), default 0)
- status (text) -- active / exhausted / expired / refunded / inactive
- created_by_admin_id (uuid, fk -> admin_users.id)
- created_at (timestamp)
- updated_at (timestamp)

### 설명
- 상품 정의가 바뀌어도 과거 보유 수강권은 snapshot 기준으로 유지 가능
- status는 직접 갱신하거나 배치성 업데이트 가능

---

## 10. reservations
회원의 수업 예약

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- user_id (uuid, fk -> users.id)
- class_session_id (uuid, fk -> class_sessions.id)
- user_pass_id (uuid, fk -> user_passes.id)
- status (text)
- request_cancel_reason (text)
- requested_cancel_at (timestamp)
- approved_cancel_at (timestamp)
- approved_cancel_by_admin_id (uuid, fk -> admin_users.id)
- is_waitlisted (boolean, default false)
- waitlist_order (int)
- created_at (timestamp)
- updated_at (timestamp)

### reservation.status 후보
- reserved
- waitlisted
- cancelled
- cancel_requested
- completed
- studio_cancelled

### 제약
- 같은 session에 같은 user의 중복 예약 방지
- 같은 시간대 중복 예약은 애플리케이션 로직 또는 DB constraint 보조 로직으로 제어

---

## 11. pass_usage_ledger
수강권 차감/복원 이력

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- user_pass_id (uuid, fk -> user_passes.id)
- reservation_id (uuid, fk -> reservations.id)
- entry_type (text)
- count_delta (int, not null)
- memo (text)
- created_at (timestamp)

### entry_type 후보
- planned
- restored
- completed
- refund_adjustment
- manual_adjustment

### count_delta 예시
- planned: -1
- restored: +1
- completed: 0 또는 상태 전환성 기록
- manual_adjustment: ±1 이상 가능

### 권장 방식
잔여 횟수는 user_passes에 직접 저장하지 않고 ledger 집계 또는 reservation 상태 집계 기반으로 계산

---

## 상태값 / 시퀀스 / 와이어프레임

---

## 12. notices
공지사항

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- title (text, not null)
- body (text, not null)
- is_important (boolean, default false)
- visible_from (timestamp)
- visible_until (timestamp)
- status (text) -- active / inactive
- created_by_admin_id (uuid, fk -> admin_users.id)
- created_at (timestamp)
- updated_at (timestamp)

---

## 13. events
이벤트

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- title (text, not null)
- body (text, not null)
- visible_from (timestamp)
- visible_until (timestamp)
- status (text) -- active / inactive
- created_by_admin_id (uuid, fk -> admin_users.id)
- created_at (timestamp)
- updated_at (timestamp)

---

## 14. refund_logs
환불 처리 이력

### 컬럼
- id (uuid, pk)
- studio_id (uuid, fk -> studios.id)
- user_pass_id (uuid, fk -> user_passes.id)
- refund_amount (numeric(12,2), not null)
- refund_reason (text)
- refunded_by_admin_id (uuid, fk -> admin_users.id)
- refunded_at (timestamp, not null)
- created_at (timestamp)

---

## 15. 상태값 설계

### 15-1. class_sessions.status
- scheduled: 정상 예약 가능 상태
- cancelled: 스튜디오 측 취소/휴강 처리됨
- completed: 종료 처리됨

### 15-2. user_passes.status
- active: 사용 가능
- exhausted: 횟수 소진
- expired: 기간 만료
- refunded: 환불 완료
- inactive: 관리자 비활성화

### 15-3. reservations.status
- reserved: 예약 확정
- waitlisted: 대기 등록
- cancel_requested: 24시간 이내 취소 요청 상태
- cancelled: 정상 취소 완료
- completed: 수업 종료 후 자동 차감 완료
- studio_cancelled: 스튜디오 휴강/취소로 종료

---

## 16. 계산 로직

### 16-1. 차감 예정 횟수
현재 시점 기준 미래의 예약 중 status = reserved 인 건수

### 16-2. 차감 완료 횟수
status = completed 인 예약 건수
또는 ledger 기준 completed 관련 이력 집계

### 16-3. 잔여 횟수
user_pass.total_count - 차감 예정 횟수 - 차감 완료 횟수

### 16-4. 만료 여부
today > valid_until 이면 expired 처리

---

## 17. 주요 시퀀스

### 17-1. 예약 시퀀스
1. 사용자가 수업 상세 진입
2. 가능한 수강권 목록 조회
3. 기본값은 valid_until이 가장 빠른 active 수강권
4. 사용자 선택 후 예약 요청
5. 서버 검증
   - session.status = scheduled
   - start_at > now
   - 같은 시간대 중복 예약 없음
   - 선택 수강권이 해당 템플릿 예약 가능
   - 잔여 가능 횟수 존재
6. 정원 남음
   - reservation.status = reserved
   - is_waitlisted = false
   - ledger planned 기록
7. 정원 초과
   - reservation.status = waitlisted
   - is_waitlisted = true
   - waitlist_order 부여

### 17-2. 24시간 이전 취소 시퀀스
1. 사용자가 취소 버튼 클릭
2. 서버가 now <= start_at - 24h 검증
3. reservation.status = cancelled
4. ledger restored 기록
5. 빈 자리 발생 시 waitlisted 중 가장 빠른 순번 자동 승급
6. 승급된 예약은 reserved로 변경
7. 승급 대상에게 푸시 발송

### 17-3. 24시간 이내 취소 요청 시퀀스
1. 사용자가 관리자 문의 클릭
2. 사유 입력 후 요청 전송
3. reservation.status = cancel_requested
4. requested_cancel_at 저장
5. 관리자가 승인 시
   - reservation.status = cancelled
   - approved_cancel_at 저장
   - ledger restored 기록
   - 대기자 자동 승급
6. 관리자가 거절 시
   - reservation.status = reserved 유지 또는 별도 reject 메모 저장

### 17-4. 자동 승급 시퀀스
1. reserved 상태 예약이 취소되거나 studio_cancelled 제외로 자리 발생
2. 동일 session의 waitlisted 예약 조회
3. created_at 또는 waitlist_order 기준 가장 빠른 건 선택
4. 해당 예약을 reserved로 변경
5. 차감 예정 반영
6. 사용자에게 승급 푸시 발송

### 17-5. 수업 종료 후 자동 차감 시퀀스
1. 배치 또는 스케줄러가 종료된 session 조회
2. session.end_at < now 이고 session.status = scheduled 인 건 처리
3. 해당 session의 reserved 예약을 completed로 변경
4. ledger completed 기록
5. session.status = completed 로 변경

### 17-6. 스튜디오 휴강 시퀀스
1. 관리자가 회차 취소 또는 날짜 단위 휴강 처리
2. class_session.status = cancelled
3. reserved 예약들 → studio_cancelled
4. ledger restored 기록
5. waitlisted 예약도 studio_cancelled
6. 관련 사용자들에게 푸시 발송

---

## 18. 와이어프레임 구조

### 18-1. 관리자 웹
#### A. 로그인
- login_id
- password
- 최초 로그인 시 비밀번호 변경

#### B. 대시보드
- 오늘 수업 수
- 오늘 예약 인원
- 이번 달 매출
- 이번 달 환불
- 만료 예정 수강권 수

#### C. 수업 템플릿 관리
- 템플릿 목록
- 새 템플릿 등록
- 수정 / 삭제

#### D. 수강권 상품 관리
- 상품 목록
- 새 상품 등록
- 예약 가능한 수업 템플릿 버튼 선택 UI

#### E. 일정 관리
- 달력 뷰
- 템플릿 일정 적용
- 회차 단건 수정 / X 삭제

#### F. 회원 관리
- member_code 검색
- 스튜디오 회원 등록
- 회원 상세
- 수강권 발급
- 환불 처리

#### G. 취소 요청 관리
- 요청 리스트
- 사유 보기
- 승인 / 거절

#### H. 공지 / 이벤트 관리
- 목록
- 작성
- 수정
- 종료 처리

### 18-2. 사용자 앱
#### A. 로그인 / 회원가입
- 전화번호 또는 이메일
- 가입 완료 후 member_code 표시

#### B. 스튜디오 / 스튜디오 선택
- 현재 스튜디오 드롭다운
- 중요 공지 배너

#### C. 달력 화면
- 이번 달 / 다음 달
- 날짜별 수업 리스트
- 시간 / 수업명 / 잔여 자리 / 예약 여부 표시

#### D. 수업 상세
- 수업명 / 설명 / 시간 / 남은 자리
- 수강권 선택
- 등록 / 취소 / 관리자 문의 버튼 상태 분기

#### E. 내 예약
- 예정
- 대기
- 완료
- 취소 요청/취소됨

#### F. 수강권 목록
- 종료일 임박 순
- 만료권 하단 회색 표시
- 잔여 / 예정 / 완료 표시 (잔여 횟수가 0인 완료 수강권도 만료권이며 이는 만료 후 30일 뒤 앱에서 보이지 않음(관리자 페이지에서는 보임))

#### G. 수강권 상세
- 수강권 기본 정보
- 사용 가능 수업 라벨
- 가까운 시간 순 사용 예정 이력 ('예정' 라벨)
- 시간 최신순 사용 이력 ('사용' 라벨)

#### H. 프로필
- 회원 ID 표시
- 복사 버튼
- 연결된 스튜디오 목록 표시

#### 사용자 앱 내 네비바 설명
- 스튜디오: 1. 현재 스튜디오 드롭다운, 2. 중요 공지 배너
- 달력 화면: 
  - 1. 최상단 현재 스튜디오 드롭다운
  - 2. 이번 달, 다음 달 선택된 스튜디오 내 신청 가능한 수업 리스트 
    - 내 수강권 중, 잔여 횟수 있는 수강권 기준 선택 가능한 수업들만 표시
    - 수업들의 기본 정보 표시 (시간, 수업명, 남은자리)
    - 수업을 클릭하면 수업 상세 정보가 팝업으로 보임. 그리고 등록 / 취소 / 관리자 문의 버튼이 우측 하단에 존재
    - 달력에서 내가 이미 수강 신청한 수업은 해당 Row 가 초록색으로 표시
    - 달력에서 내가 대기 중인 수업은 해당 row 가 주황색으로 표시
- 내 예약: 
- 프로필: 1. 개인 정보 2. 연결된 스튜디오 드롭다운 3. 선택된 스튜디오의 수강권 목록 (특정 수강권 클릭 시 수강권 상세 정보 및 수강 이력 팝업)
