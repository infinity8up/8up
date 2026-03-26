# Firebase Hosting으로 관리자 웹 배포하기

이 문서는 현재 `/Users/hyunsuk.choi/coding/8up` 저장소 기준으로 `관리자 웹`을 Firebase Hosting에 배포하는 방법을 정리한 문서입니다.

현재 프로젝트 구조에서 웹 빌드는 `사용자 웹`이 아니라 `관리자 웹`입니다.

- 엔트리: [`app/lib/main.dart`](/Users/hyunsuk.choi/coding/8up/app/lib/main.dart)
- 웹 분기: [`app/lib/src/app/eightup_app.dart`](/Users/hyunsuk.choi/coding/8up/app/lib/src/app/eightup_app.dart#L40)
- 웹에서 실행되는 앱: `EightUpAdminWebApp`

즉, `flutter build web` 결과물을 Firebase Hosting에 올리면 `관리자 웹`이 배포됩니다.

## 1. 배포 개념

관리자 웹 배포는 아래 순서입니다.

1. Flutter web 빌드
2. `app/build/web` 생성
3. Firebase Hosting에 업로드
4. 필요하면 커스텀 도메인 연결
5. Supabase Auth redirect URL을 운영 도메인으로 반영

공식 문서:

- Flutter web 배포: [Flutter web deployment](https://docs.flutter.dev/deployment/web)
- Firebase Hosting 기본 배포: [Get started with Firebase Hosting](https://firebase.google.com/docs/hosting)
- Flutter web + Firebase Hosting: [Integrate Flutter Web](https://firebase.google.com/docs/hosting/frameworks/flutter)
- 커스텀 도메인 연결: [Connect a custom domain](https://firebase.google.com/docs/hosting/custom-domain)

## 2. 배포 전 확인사항

### 2-1. 운영 환경으로 빌드할 것

현재 앱은 [`app/lib/src/core/app_config.dart`](/Users/hyunsuk.choi/coding/8up/app/lib/src/core/app_config.dart#L4) 에서 `APP_ENV=real`일 때 `SUPABASE_URL_REAL`, `SUPABASE_ANON_KEY_REAL`을 읽습니다.

따라서 관리자 웹 운영 배포는 반드시 `real` 기준으로 빌드해야 합니다.

사용 가능한 명령:

```bash
cd /Users/hyunsuk.choi/coding/8up/app
flutter build web --release --dart-define=APP_ENV=real
```

또는 이미 만들어둔 스크립트를 쓰려면:

```bash
zsh /Users/hyunsuk.choi/coding/8up/scripts/flutter-build-web-real.sh
```

주의: 현재 저장소에는 `flutter-build-web-real.sh`가 없으므로, 필요하면 직접 만들거나 위의 원본 명령을 사용하면 됩니다.

### 2-2. 관리자 웹 도메인을 먼저 정하는 것이 좋음

예:

- `https://8up.kr`
- `https://studio-admin.8up.kr`

도메인이 정해져야 나중에 Supabase Auth redirect URL 설정이 깔끔해집니다.

### 2-3. 웹 로그인 Redirect

웹에서는 [`app/lib/src/core/auth_redirects.dart`](/Users/hyunsuk.choi/coding/8up/app/lib/src/core/auth_redirects.dart#L6) 에 따라 현재 브라우저 주소를 redirect URL로 사용합니다.

즉, 운영 도메인이 `https://8up.kr`라면:

- Supabase `Site URL`
- Supabase `Redirect URLs`

에 운영 주소를 반영해야 합니다.

## 3. Firebase CLI 설치

Firebase CLI가 없다면 설치합니다.

```bash
npm install -g firebase-tools
```

설치 확인:

```bash
firebase --version
```

로그인:

```bash
firebase login
```

## 4. 관리자 웹 빌드

현재 저장소에서 아래 명령으로 운영용 웹 번들을 만듭니다.

```bash
cd /Users/hyunsuk.choi/coding/8up/app
flutter build web --release --dart-define=APP_ENV=real
```

빌드 결과물:

- [`app/build/web`](/Users/hyunsuk.choi/coding/8up/app/build/web)

배포할 실제 파일은 이 폴더 안 내용입니다.

## 5. Firebase Hosting 초기화

루트 저장소(`/Users/hyunsuk.choi/coding/8up`)에서 진행하는 것을 권장합니다.

```bash
cd /Users/hyunsuk.choi/coding/8up
firebase init hosting
```

질문이 나오면 이렇게 답하면 됩니다.

### 5-1. Which Firebase project do you want to use?

- 기존 Firebase 프로젝트 선택
- 관리자 웹을 올릴 Firebase 프로젝트 선택

보통은 앱의 운영 Firebase 프로젝트와 같은 프로젝트를 써도 됩니다.

### 5-2. What do you want to use as your public directory?

다음 값 입력:

```text
app/build/web
```

### 5-3. Configure as a single-page app (rewrite all urls to /index.html)?

`Yes`

Flutter web은 SPA처럼 동작하므로 `Yes`가 안전합니다.

### 5-4. Set up automatic builds and deploys with GitHub?

처음에는 `No` 권장

이유:

- 먼저 수동 배포로 정상 동작 확인
- 그 후 GitHub Actions 자동 배포를 붙이는 것이 안전

## 6. 생성될 파일

`firebase init hosting`을 마치면 보통 아래 파일이 생깁니다.

- `firebase.json`
- `.firebaserc`

권장 예시는 다음과 같습니다.

### 6-1. `firebase.json` 예시

```json
{
  "hosting": {
    "public": "app/build/web",
    "ignore": [
      "firebase.json",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public,max-age=31536000,immutable"
          }
        ]
      },
      {
        "source": "index.html",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "no-cache"
          }
        ]
      }
    ]
  }
}
```

중요:

현재 앱은 [`app/lib/src/core/app_config.dart`](/Users/hyunsuk.choi/coding/8up/app/lib/src/core/app_config.dart#L22) 에서 `.env` asset을 읽도록 되어 있고, [`app/pubspec.yaml`](/Users/hyunsuk.choi/coding/8up/app/pubspec.yaml#L37) 에도 `.env`가 asset으로 등록돼 있습니다.

따라서 `firebase.json`의 `ignore`에 아래처럼 점파일 전체 제외 패턴을 넣으면 안 됩니다.

```json
"**/.*"
```

이 패턴이 있으면 배포 시 [`app/build/web/assets/.env`](/Users/hyunsuk.choi/coding/8up/app/build/web/assets/.env) 도 같이 빠져서, 운영 URL에서는 `Supabase 설정이 필요합니다` 화면이 뜹니다.

즉, 이 프로젝트 기준으로는 `ignore`에서 `**/.*`를 제거해야 합니다.

### 6-2. `.firebaserc` 예시

```json
{
  "projects": {
    "default": "your-firebase-project-id"
  }
}
```

`your-firebase-project-id`는 실제 Firebase 프로젝트 ID로 바꿉니다.

## 7. 첫 배포

웹을 다시 빌드한 뒤 Firebase Hosting에 올립니다.

```bash
cd /Users/hyunsuk.choi/coding/8up/app
flutter build web --release --dart-define=APP_ENV=real

cd /Users/hyunsuk.choi/coding/8up
firebase deploy --only hosting
```

배포가 끝나면 Firebase가 기본 도메인을 줍니다.

예:

- `https://your-project-id.web.app`
- `https://your-project-id.firebaseapp.com`

이 주소로 관리자 웹 접속이 가능해야 합니다.

### 7-1. `.env` 대신 `dart-define`로 고정해서 빌드하는 방법

운영 배포에서는 `.env` asset에 의존하지 않고, build 시점에 값을 직접 주입하는 방식도 가능합니다.

```bash
cd /Users/hyunsuk.choi/coding/8up/app
flutter build web --release \
  --dart-define=APP_ENV=real \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_REAL_ANON_KEY
```

이 방식의 장점:

- Firebase Hosting이 `.env` 파일을 누락해도 영향이 없음
- 어떤 Supabase 프로젝트로 빌드했는지 명확함

이 프로젝트는 [`app/lib/src/core/app_config.dart`](/Users/hyunsuk.choi/coding/8up/app/lib/src/core/app_config.dart#L11) 에서 `SUPABASE_URL`, `SUPABASE_ANON_KEY` `dart-define` 값을 우선 사용하므로, 운영 배포에서는 이 방식이 가장 안전합니다.

## 8. 배포 전 미리보기

정식 반영 전에 preview channel을 쓰는 방법도 좋습니다.

```bash
cd /Users/hyunsuk.choi/coding/8up
firebase hosting:channel:deploy preview
```

그러면 미리보기 URL이 발급되므로 실제 관리자 로그인, 수업 관리, 회원 관리 등을 먼저 점검할 수 있습니다.

공식 문서:

- [Preview your site locally and share changes at a temporary URL](https://firebase.google.com/docs/hosting/test-preview-deploy)

## 9. 커스텀 도메인 연결

운영용 주소를 연결하려면 Firebase Console에서 Hosting 사이트에 도메인을 추가합니다.

예:

- `admin.8up.kr`

순서:

1. Firebase Console
2. Hosting
3. `Add custom domain`
4. 도메인 입력
5. Firebase가 안내하는 DNS 레코드 추가
6. SSL 인증서 발급 완료까지 대기

공식 문서:

- [Connect a custom domain](https://firebase.google.com/docs/hosting/custom-domain)

주의:

- 기존에 다른 서비스로 향하던 A/CNAME 레코드가 있으면 충돌할 수 있습니다
- SSL 발급까지 수 분에서 수 시간, 길면 하루 가까이 걸릴 수 있습니다

## 10. Supabase 설정

관리자 웹 로그인과 OAuth redirect가 정상 동작하려면 Supabase 설정도 같이 맞춰야 합니다.

### 10-1. Site URL

Supabase Dashboard:

- `Authentication > URL Configuration`

운영 도메인을 넣습니다.

예:

```text
https://admin.8up.kr
```

### 10-2. Redirect URLs

운영 주소를 추가합니다.

예:

```text
https://admin.8up.kr
https://eight-up.web.app
https://eight-up.firebaseapp.com
```

처음에는 Firebase 기본 도메인까지 같이 넣어두는 것이 안전합니다.

## 11. OAuth 로그인 설정 주의

관리자 웹에서 만약 Google/Kakao 같은 브라우저 OAuth를 쓴다면, 공급자 콘솔에도 운영 주소나 Supabase callback URL을 맞춰야 합니다.

### 11-1. Google

Google Cloud Console의 OAuth client에는 보통 Supabase callback URL을 넣습니다.

예:

```text
https://<your-project-ref>.supabase.co/auth/v1/callback
```

### 11-2. Kakao

Kakao Developers에도 Supabase callback URL을 넣습니다.

예:

```text
https://<your-project-ref>.supabase.co/auth/v1/callback
```

웹 redirect 허용 자체는 Supabase `Site URL`/`Redirect URLs`에 운영 관리자 웹 주소를 넣습니다.

## 12. 하위 경로에 배포하는 경우

가능하면 하위 경로보다 `서브도메인` 배포를 권장합니다.

권장:

- `https://admin.8up.kr`

비권장:

- `https://8up.kr/admin/`

하위 경로로 올리려면 Flutter build 시 `--base-href`를 맞춰야 합니다.

예:

```bash
cd /Users/hyunsuk.choi/coding/8up/app
flutter build web --release --dart-define=APP_ENV=real --base-href /admin/
```

그리고 Firebase Hosting도 해당 구조에 맞게 rewrite를 조정해야 합니다.

기본적으로는 서브도메인이 운영과 디버깅 모두 더 단순합니다.

## 13. 배포 후 점검 체크리스트

배포가 끝나면 아래를 확인합니다.

### 13-1. 기본 접속

- 관리자 웹 메인 진입 가능
- 새로고침해도 흰 화면 없이 정상 로드
- 직접 URL 접속도 정상

### 13-2. 인증

- 관리자 로그인 가능
- 로그아웃 가능
- OAuth 로그인 사용 시 redirect 정상

### 13-3. 실제 기능

- 대시보드 데이터 정상
- 콘텐츠 관리 CRUD 정상
- 수업 관리 달력/팝업 정상
- 회원 관리 검색/등록 정상

### 13-4. 네트워크 / 콘솔

- 브라우저 콘솔 에러 없음
- 404 정적 파일 없음
- Supabase 요청 실패 없음

## 14. 추천 운영 방식

처음에는 아래 방식이 가장 안전합니다.

1. Firebase Hosting preview channel로 테스트
2. Firebase 기본 도메인에서 내부 점검
3. 커스텀 도메인 연결
4. Supabase `Site URL`, `Redirect URLs`를 커스텀 도메인 기준으로 최종 정리

## 15. 실제 명령어 모음

### 15-1. 운영 웹 빌드

```bash
cd /Users/hyunsuk.choi/coding/8up/app
flutter build web --release --dart-define=APP_ENV=real
```

### 15-2. Firebase Hosting 초기화

```bash
cd /Users/hyunsuk.choi/coding/8up
firebase init hosting
```

### 15-3. 정식 배포

```bash
cd /Users/hyunsuk.choi/coding/8up
firebase deploy --only hosting
```

### 15-4. 미리보기 배포

```bash
cd /Users/hyunsuk.choi/coding/8up
firebase hosting:channel:deploy preview
```

## 16. 이 프로젝트에서 가장 중요한 요약

- 웹 빌드 = 관리자 웹 빌드
- `APP_ENV=real`로 빌드해야 운영 Supabase를 사용
- Firebase Hosting `public`은 `app/build/web`
- `single-page app rewrite = Yes`
- 운영 도메인을 정하면 Supabase Auth 설정도 같이 변경
- 가능하면 `admin.도메인` 같은 서브도메인 사용
