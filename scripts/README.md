# Scripts

이 디렉토리는 `8UP` 사용자 앱과 관리자 웹을 실행하거나 배포 빌드할 때 사용하는 보조 스크립트를 모아둔 곳입니다.

## 공통 규칙

- 권장 기준 파일은 저장소 루트의 `.env`입니다.
- 스크립트는 기본적으로 저장소 루트의 `.env`를 먼저 찾습니다.
- 루트 `.env`가 없으면 호환성을 위해 `app/.env`를 찾습니다.
- 다른 위치의 환경 파일을 쓰고 싶으면 `EIGHTUP_ENV_FILE` 환경변수로 경로를 지정할 수 있습니다.
- `SUPABASE_URL_DEV`, `SUPABASE_ANON_KEY_DEV`, `SUPABASE_URL_REAL`, `SUPABASE_ANON_KEY_REAL` 값을 읽습니다.
- Google 로그인이 환경별로 다르면 `GOOGLE_WEB_CLIENT_ID_DEV`, `GOOGLE_WEB_CLIENT_ID_REAL`도 함께 읽습니다.
- 개발용 값이 없으면 `run_dev.sh`는 `SUPABASE_URL`, `SUPABASE_ANON_KEY`도 fallback으로 읽습니다.

## 사용자 앱 실행

### 개발 환경 실행

```bash
./scripts/run_dev.sh
```

예:

```bash
./scripts/run_dev.sh -d chrome
./scripts/run_dev.sh -d "iPhone 16"
```

### 운영 환경 실행

```bash
./scripts/run_real.sh
```

예:

```bash
./scripts/run_real.sh -d "iPhone 16"
```

## 사용자 앱 빌드

### 안드로이드 운영 빌드

```bash
./scripts/build_android_real.sh
```

결과물:

- `app/build/app/outputs/bundle/release/*.aab`

### iOS 운영 빌드

```bash
./scripts/build_ios_real.sh
```

주의:

- 내부적으로 `flutter build ipa --release`를 실행합니다.
- Xcode signing 설정과 Apple Developer 인증서/프로비저닝 프로파일이 먼저 준비되어 있어야 합니다.

## 관리자 웹 실행

관리자 웹은 같은 Flutter 프로젝트를 `web`으로 실행하면 자동으로 관리자 화면이 열립니다.

### 개발 환경 실행

```bash
./scripts/run_web.sh
```

### 운영 환경 실행

```bash
./scripts/run_web.sh real
```

예:

```bash
./scripts/run_web.sh dev --web-port 3000
./scripts/run_web.sh real --web-port 3001
```

## 관리자 웹 빌드

### 운영 환경 웹 빌드

```bash
./scripts/build_web_real.sh
```

결과물:

- `app/build/web`

## 환경 파일 예시

```dotenv
SUPABASE_URL=https://your-dev-project.supabase.co
SUPABASE_ANON_KEY=your-dev-anon-key
GOOGLE_WEB_CLIENT_ID_DEV=your-dev-web-client-id.apps.googleusercontent.com

SUPABASE_URL_REAL=https://your-real-project.supabase.co
SUPABASE_ANON_KEY_REAL=your-real-anon-key
GOOGLE_WEB_CLIENT_ID_REAL=your-real-web-client-id.apps.googleusercontent.com
```
