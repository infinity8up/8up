# 사용자 앱 Google / Apple 로그인 도입 가이드

이 문서는 **현재 8UP 코드베이스 기준**으로 사용자 앱에 Google 로그인과 Apple 로그인을 추가하는 방법을 정리한 구현 메모입니다.  
목표는 `첫 로그인 = 회원가입`까지 포함한 소셜 로그인 도입입니다.

## 1. 현재 상태

현재 사용자 인증 구조는 아래와 같습니다.

- 로그인 화면: `app/lib/src/presentation/screens/auth_screen.dart`
- 인증 상태: `app/lib/src/providers/auth_controller.dart`
- 인증 저장소: `app/lib/src/repositories/auth_repository.dart`
- Supabase 초기화: `app/lib/src/app/bootstrap.dart`
- 모바일 딥링크 콜백: `app/lib/src/core/auth_redirects.dart`
- 현재 회원가입:
  - 이메일/비밀번호 입력
  - `register_member_account` RPC 호출
  - `auth.users` + `public.users` 생성

중요한 점은, **소셜 로그인은 `register_member_account` RPC를 타지 않아도 된다**는 것입니다.  
현재 `supabase/migrations/1_2_logic.sql`의 `handle_new_auth_user()` trigger가 `auth.users`에 새 사용자가 들어오면 `public.users`도 자동으로 만들어 줍니다.

즉:

- 이메일 회원가입: 기존 RPC 유지
- Google/Apple 로그인: Supabase Auth로 바로 로그인
- 첫 로그인 시 DB trigger가 `public.users` 생성

이 구조로 같이 가는 것이 가장 안전합니다.

## 2. 현재 채택한 구현 방향

현재 코드베이스는 아래 방식으로 가고 있습니다.

- Google:
  - Android: **native Google SDK + Supabase `signInWithIdToken`**
  - iOS: **Supabase `signInWithOAuth(...)` 브라우저 OAuth**
- Apple:
  - iOS: **native Apple SDK + Supabase `signInWithIdToken`**
  - Android: **Supabase `signInWithOAuth(...)` 브라우저 OAuth**

이렇게 나눈 이유는 iOS native Google 로그인에서 `nonce` mismatch 이슈가 발생하기 쉬웠기 때문입니다.  
현재 앱은 이미 `eightup://login-callback/` 딥링크를 갖고 있으므로, iOS Google은 브라우저 OAuth가 더 단순하고 안정적입니다.

## 3. 추천 범위

현재 구현/설정은 아래를 기준으로 맞추면 됩니다.

- Google 로그인:
  - Android는 native
  - iOS는 브라우저 OAuth
- Apple 로그인:
  - iOS는 native
  - Android는 브라우저 OAuth

이유:

- Apple 로그인은 iOS에서는 native가 가장 안정적이다
- Android에서는 Apple native SDK가 없어서 브라우저 OAuth가 정석이다
- 현재 앱은 이미 `eightup://login-callback/` 딥링크를 갖고 있어 Android Apple OAuth를 붙이기 쉽다

이 문서에서는 **Google는 Android native + iOS 브라우저 OAuth**, **Apple은 iOS native + Android 브라우저 OAuth** 기준으로 설명합니다.

## 4. Google 로그인 구현

### 4-1. Supabase 설정

Supabase Dashboard에서 Google provider를 활성화합니다.

- `Authentication`
- `Providers`
- `Google`
- 활성화
- Google Client ID / Client Secret 입력

여기서 들어가는 값은 Google Cloud Console에서 만든 OAuth 클라이언트 정보입니다.

### 4-2. Google Cloud Console 준비

필수 준비:

- OAuth consent screen 설정
- Android OAuth client 생성
- Web OAuth client 생성

현재 구현에서는 **iOS OAuth client는 쓰지 않습니다.**

실무적으로는 아래 2개가 필요합니다.

- Android client
  - package name: `com.eightup.app`
  - SHA-1 / SHA-256
- Web client
  - Supabase Google provider 설정용
  - Supabase callback URL 등록용

메모:

- `google_sign_in` 문서 기준으로 Android에서는 Firebase 프로젝트 등록 절차를 참고하도록 되어 있습니다.
- `google-services.json`은 Firebase 기능이 필요하지 않으면 꼭 앱에 넣지 않아도 됩니다.
- 다만 OAuth client 발급과 consent screen 설정은 반드시 되어 있어야 합니다.

### 4-3. Flutter 의존성 추가

`app/pubspec.yaml`에 아래를 추가합니다.

```yaml
dependencies:
  google_sign_in: ^6.3.0
```

### 4-4. iOS 설정

현재 구현에서 iOS Google 로그인은 `google_sign_in_ios` native SDK를 쓰지 않고,  
Supabase 브라우저 OAuth로 처리합니다.

즉 iOS에서 필요한 것은:

- `eightup://login-callback/` 딥링크 유지
- Supabase의 Redirect URL 허용 목록에 `eightup://login-callback/` 추가
- 앱에서는 외부 Safari로 Google 인증 페이지를 엽니다

즉 현재는 아래가 **필요 없습니다**.

- `GIDClientID`
- `GIDServerClientID`
- `CFBundleURLTypes`의 Google `REVERSED_CLIENT_ID`

### 4-5. 앱 코드 변경 포인트

#### 1) `auth_repository.dart`

아래 메서드를 추가합니다.

```dart
Future<void> signInWithGoogle() async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: currentAuthRedirectUrl(),
    );
    return;
  }

  final googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: _googleWebClientId,
  );

  final googleUser = await googleSignIn.signIn();
  if (googleUser == null) return;

  final googleAuth = await googleUser.authentication;
  final idToken = googleAuth.idToken;
  if (idToken == null || idToken.isEmpty) {
    throw Exception('Google idToken을 받지 못했습니다.');
  }

  await _client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    accessToken: googleAuth.accessToken,
  );
}
```

핵심:

- Android는 native Google SDK + `signInWithIdToken`
- iOS는 Supabase 브라우저 OAuth
- 현재 Google 로그인의 기준 client는 `Web client`다

#### 2) `auth_controller.dart`

wrapper 메서드 추가:

```dart
Future<void> signInWithGoogle() async {
  await _run(_repository.signInWithGoogle);
}
```

#### 3) `auth_screen.dart`

로그인 탭과 회원가입 탭 하단에 Google 버튼 추가:

- `Google로 시작하기`
- 또는 로그인/회원가입 각각 같은 버튼을 둬도 됨

실제로는 **“로그인”과 “회원가입”을 나누지 않고 하나의 Google 버튼**으로 처리하는 것이 일반적입니다.  
첫 로그인인지 여부는 Supabase/Auth가 판단하고, 우리 앱에서는 같은 버튼만 두면 됩니다.

### 4-6. Supabase / Google 최종 체크리스트

현재 프로젝트 기준 최종 체크리스트는 아래와 같습니다.

#### Google Cloud Console

- OAuth consent screen 설정 완료
- Android OAuth client 생성
  - package name: `com.eightup.app`
  - SHA-1 등록
- Web OAuth client 생성
  - Authorized redirect URI:
    - `https://bpkfqqitkklumrqowkib.supabase.co/auth/v1/callback`

#### Supabase Dashboard

- `Authentication > Providers > Google`
- 활성화
- Client ID:
  - `1066464765244-to72o6iiv8k9u5fmu1naenhvsgo8k9to.apps.googleusercontent.com`
  - 현재 구현에서는 **이 값 하나만** 넣습니다
- Client Secret:
  - Google Cloud의 **Web client secret**

#### Supabase Redirect URLs

- `eightup://login-callback/`

#### Supabase Site URL

- 개발 중 `localhost`로 두어도 되지만, Google 로그인 후 Safari가 `localhost`로 가면
  거의 항상 **Redirect URLs 허용 목록에 `eightup://login-callback/`가 빠진 상태**입니다
- 즉 `localhost` 페이지가 열리면 먼저 Supabase Auth 설정의 Redirect URLs를 다시 확인합니다

#### iOS 앱

- bundle id: `com.eightup.app`
- `Info.plist`에는 Google iOS 전용 키를 넣지 않음
- `eightup` custom URL scheme만 유지

### 4-7. 자주 나오는 오류

#### 1) Safari가 `localhost`를 여는 경우

원인:

- Supabase Auth의 Redirect URLs에 `eightup://login-callback/`가 없음

확인할 것:

- `Authentication > URL Configuration > Redirect URLs`
- `eightup://login-callback/` 등록 여부

#### 2) `Error while launching https://.../auth/v1/authorize?...` 가 뜨는 경우

원인:

- iOS in-app Safari 뷰에서 OAuth authorize URL 로드가 실패한 경우

현재 코드 대응:

- iOS는 Supabase OAuth를 **외부 Safari**로 열도록 처리함

### 4-7. 첫 로그인 처리

첫 Google 로그인 시:

- `auth.users` 생성
- DB trigger `handle_new_auth_user()` 실행
- `public.users` 자동 생성
- `member_code` 자동 생성

즉 Google의 첫 로그인은 별도 회원가입 RPC 없이도 회원가입으로 동작합니다.

## 5. Apple 로그인 구현

### 5-1. Supabase 설정

Supabase Dashboard에서 Apple provider를 활성화합니다.

- `Authentication`
- `Providers`
- `Apple`

필요 값:

- `Client IDs`
  - iOS bundle ID: `com.eightup.app`
  - Android/Web OAuth용 Services ID: 현재 8UP 기준 `com.eightup.app.auth`
- OAuth용 Secret Key
  - Apple signing key(`.p8`)로 생성한 **JWT client secret**
- Team ID
- Key ID

현재 8UP 실사용 예시는 아래 조합입니다.

- bundle ID: `com.eightup.app`
- Services ID: `com.eightup.app.auth`
- Supabase `Client IDs`: `com.eightup.app.auth,com.eightup.app`

### 5-2. Apple Developer 준비

Apple은 Google보다 준비 단계가 더 많습니다.

#### iOS만 붙일 경우

- App ID 생성 또는 기존 App ID 수정
- `Sign in with Apple` capability 활성화
- Xcode에서 동일 capability 활성화

#### Android / Web까지 붙일 경우

- 추가로 Service ID 생성
- Return URL 설정
- Sign in with Apple key 생성

실무 순서는 아래가 가장 안전합니다.

1. Apple Developer `Identifiers > App IDs`에서 `com.eightup.app` 확인
2. `Sign in with Apple` capability 활성화
3. `Identifiers > Services IDs`에서 `com.eightup.app.auth` 생성
4. Services ID의 Sign in with Apple 설정에서 아래 2개 등록
   - Primary App ID: `com.eightup.app`
   - Return URL: `https://<project-ref>.supabase.co/auth/v1/callback`
5. `Keys`에서 Sign in with Apple key 생성 후 `.p8` 다운로드
6. `.p8`로 client secret JWT 생성
   - Account ID / Team ID: Apple Developer 우측 상단의 Team ID
   - Service ID: `com.eightup.app.auth`
   - Key ID: `AuthKey_XXXXXXXXXX.p8` 파일명의 `XXXXXXXXXX`
7. Supabase Apple provider에 아래 값 입력
   - Client IDs: `com.eightup.app.auth,com.eightup.app`
   - Secret Key (for OAuth): 생성한 JWT

주의:

- Apple Developer 유료 계정이 필요합니다
- Apple private email relay를 쓰는 사용자가 있을 수 있으므로 메일 발송이 있다면 private relay 대응이 필요합니다
- `나의 이메일 가리기`는 이메일이 없는 것이 아니라 Apple relay 이메일을 쓰는 것입니다
- `fullName`, `email`은 **최초 동의 시 한 번만** 내려오는 경우가 많으므로 첫 로그인 때 바로 저장해야 합니다

#### Apple OAuth secret 6개월 갱신

Supabase의 Apple `Secret Key (for OAuth)`는 영구 키가 아니라, Apple 규격의 **만료되는 JWT**입니다.

- Apple은 이 client secret JWT의 만료(`exp`)를 최대 6개월까지만 허용합니다
- 6개월이 지나면 Android/Web의 Apple OAuth 로그인이 실패할 수 있습니다
- 이때 `.p8`를 새로 만드는 것이 아니라 **같은 값으로 새 JWT만 다시 생성**하면 됩니다

다시 generate할 때 그대로 두는 값:

- Team ID
- Service ID: `com.eightup.app.auth`
- Key ID
- `.p8` private key 파일

다시 generate할 때 바뀌는 값:

- `iat`
- `exp`

즉 6개월 뒤에는 브라우저 생성기에서 같은 `Team ID / Service ID / Key ID / .p8`를 넣고 다시 생성한 뒤,
새 JWT 문자열만 Supabase `Secret Key (for OAuth)`에 덮어쓰면 됩니다.

### 5-3. Flutter 의존성 추가

`app/pubspec.yaml`에 아래를 추가합니다.

```yaml
dependencies:
  sign_in_with_apple: ^6.1.4
  crypto: ^3.0.7
```

`crypto`는 Apple nonce 해싱에 필요합니다.

### 5-4. iOS 설정

필수:

- Xcode `Signing & Capabilities`에서 `Sign in with Apple` 추가
- bundle id가 Apple Developer의 App ID와 일치해야 함

현재 `Info.plist`와 AndroidManifest에는 `eightup://login-callback/` 딥링크가 이미 있으므로, Android Apple OAuth에서 추가 앱 코드 설정은 크지 않고 Supabase/Apple Console 설정이 핵심입니다.

### 5-5. 앱 코드 변경 포인트

#### 1) nonce 생성

Apple은 raw nonce와 hashed nonce를 같이 다뤄야 합니다.

예시:

```dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

String generateNonce([int length = 32]) {
  const chars =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

String sha256Of(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}
```

#### 2) `auth_repository.dart`

```dart
Future<void> signInWithApple() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: currentAuthRedirectUrl(),
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    return;
  }

  final rawNonce = generateNonce();
  final hashedNonce = sha256Of(rawNonce);

  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: const [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: hashedNonce,
  );

  final idToken = credential.identityToken;
  if (idToken == null || idToken.isEmpty) {
    throw Exception('Apple identityToken을 받지 못했습니다.');
  }

  await _client.auth.signInWithIdToken(
    provider: OAuthProvider.apple,
    idToken: idToken,
    nonce: rawNonce,
  );

  final fullName = [
    credential.givenName,
    credential.familyName,
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');

  if (fullName.isNotEmpty) {
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'name': fullName,
          'account_type': 'member',
        },
      ),
    );
  }
}
```

핵심:

- Apple에서 넘기는 것은 hashed nonce
- Supabase에는 raw nonce를 다시 넘겨야 함
- 이름/이메일은 최초 응답에서만 들어올 수 있으므로 즉시 반영

#### 3) `auth_controller.dart`

```dart
Future<void> signInWithApple() async {
  await _run(_repository.signInWithApple);
}
```

#### 4) `auth_screen.dart`

Apple 버튼 추가:

- iOS에서만 노출하는 것이 1차 구현으로 가장 안전
- `Platform.isIOS` 조건 또는 `SignInWithApple.isAvailable()` 기준으로 노출

## 6. 현재 DB 구조에서 중요한 점

현재 `1_2_logic.sql`의 auth trigger는 아래 규칙으로 동작합니다.

- `account_type in ('admin', 'admin_pending', 'platform_admin')` 이면 `public.users` 생성 안 함
- 그 외는 member로 취급해서 `public.users` 생성

즉 social login에서 굳이 `account_type = member`를 먼저 심지 않아도 기본적으로는 member 취급됩니다.  
다만 아래 이유로 metadata 업데이트는 유지하는 편이 좋습니다.

- 이름 저장
- 향후 사용자 분기 로직 명확화
- 운영 데이터 정합성

## 7. 추가로 추천하는 보완

### 7-1. 최초 소셜 로그인 후 프로필 보정

Apple은 이름/이메일을 항상 주지 않습니다.  
그래서 첫 소셜 로그인 직후 아래 화면을 한 번 보여주는 것을 추천합니다.

- 이름 확인
- 휴대폰 번호 입력
- 이메일 확인

즉:

- session 생성 성공
- `public.users` row 생성 확인
- 필수 필드가 비어 있으면 `프로필 보완` 모달 강제

### 7-2. provider 구분 필드

나중에 운영 편의를 위해 `public.users` 또는 별도 profile metadata에 아래 정보 저장을 추천합니다.

- `last_sign_in_provider`
- `is_social_account`

지금은 없어도 동작하지만, 운영 화면에서 계정 유형을 볼 때 유용합니다.

### 7-3. 기존 이메일 로그인과 충돌 처리

같은 이메일로 이미 이메일/비밀번호 계정이 있는 경우 처리 방침을 먼저 정해야 합니다.

추천 정책:

- 같은 이메일이면 같은 Supabase 계정으로 연결되도록 유도
- 중복 계정 자동 병합은 하지 않음

이 부분은 실제 운영 전에 한 번 더 정책을 정하는 것이 좋습니다.

## 8. 구현 순서 추천

1. Google 로그인 먼저 붙이기
2. 첫 로그인에서 `public.users` row 생성 확인
3. 이름/이메일/휴대폰 보정 흐름 추가
4. Apple 로그인 iOS 붙이기
5. App Store 제출 전 Apple 버튼 노출 정책 정리
6. Android Apple OAuth 설정 확인

## 9. Android에서 Apple 로그인까지 붙이고 싶다면

현재 구현은 이 방식을 사용합니다.

추가 필요 사항:

- Apple Service ID
- callback URL
- Android에서 web-based Apple auth 흐름
- Supabase Apple provider의 OAuth secret JWT

현재 프로젝트는 이미 `eightup://login-callback/`을 갖고 있으므로,  
브라우저 OAuth 기반 Apple 로그인 fallback을 바로 사용할 수 있습니다.

## 10. 현재 코드 기준 실제 수정 파일

소셜 로그인 구현 시 직접 수정될 가능성이 높은 파일:

- `app/pubspec.yaml`
- `app/lib/src/repositories/auth_repository.dart`
- `app/lib/src/providers/auth_controller.dart`
- `app/lib/src/presentation/screens/auth_screen.dart`
- `app/lib/src/core/auth_redirects.dart`
- `app/android/app/src/main/AndroidManifest.xml`
- 필요 시 `supabase/migrations/1_2_logic.sql`

## 11. 참고 링크

공식/원문 기준으로 확인한 자료:

- Supabase Google Auth: <https://supabase.com/docs/guides/auth/social-login/auth-google>
- Supabase Apple Auth: <https://supabase.com/docs/guides/auth/social-login/auth-apple>
- Supabase Flutter `signInWithIdToken` 시그니처: 로컬 패키지 `gotrue 2.18.0`
- `google_sign_in` 패키지 문서: <https://pub.dev/packages/google_sign_in>
- `sign_in_with_apple` 패키지 문서: <https://pub.dev/packages/sign_in_with_apple>

## 12. 한 줄 결론

이 프로젝트는 이미 **소셜 로그인용 기본 토대가 준비된 상태**입니다.

- auth trigger가 `public.users`를 자동 생성하고
- 모바일 딥링크도 이미 있고
- 사용자 앱 인증 구조도 단순합니다

그래서 실제 구현은 `AuthRepository + AuthController + AuthScreen + Supabase/Google 콘솔 설정` 중심으로 진행하면 됩니다.
