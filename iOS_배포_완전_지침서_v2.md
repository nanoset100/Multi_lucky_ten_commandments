# iOS App Store 배포 완전 지침서 v2.0
## (왕초보 성경통독 앱 실전 배포 경험 기반 - 실수 없는 버전)
### 대상 앱: AI 가나안교회 / 말씀브릿지 WordBridge

---

## ⚠️ 이 지침서를 만든 이유
왕초보 성경통독 앱 배포 과정에서 다음 실수들이 있었습니다.
이 지침서는 같은 실수를 반복하지 않도록 정리한 것입니다.

### 실패 목록 (교훈)
| 실수 | 원인 | 해결 |
|------|------|------|
| `provisioning_profile` 필드 오류 | codemagic.yaml ios_signing에 없는 필드 | 제거 |
| `app_store_connect` 위치 오류 | environment 안에 넣음 | integrations로 이동 |
| `app_apple_id` 필드 오류 | publishing에 없는 필드 | 제거 |
| No valid code signing certificates | xcode-project use-profiles 누락 | 스크립트 추가 |
| No artifacts were found | --export-options-plist 누락 | ExportOptions.plist 생성 |
| Certificate Not uploaded (빨간X) | Fetch로 가져온 인증서 = 개인키 없음 | Apple Portal에서 직접 수정 |

---

## 📋 사전 확인 사항

### 앱 정보 확인 (시작 전 메모)
```
AI 가나안교회:
  - Bundle ID: com.nanoset.ai_canaan_church
  - App Store Apple ID: (App Store Connect에서 확인)
  - 팀 ID: NCB9774DGY

말씀브릿지:
  - Bundle ID: com.logosflow.wordbridge
  - App Store Apple ID: (App Store Connect에서 확인)
  - 팀 ID: NCB9774DGY
```

---

## STEP 1: 코드 준비

### 1-1. Bundle ID 확인
파일: `ios/Runner.xcodeproj/project.pbxproj`

아래 명령으로 현재 Bundle ID 확인:
```bash
grep "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj
```

`com.example.` 이 남아있으면 전체 교체 필요:
- VSCode Ctrl+H → 전체 교체
- `com.example.앱이름` → `com.nanoset.ai_canaan_church` (또는 `com.logosflow.wordbridge`)

### 1-2. iOS 최소 타겟 확인
파일: `ios/Podfile`

반드시 15.0 이상:
```ruby
platform :ios, '15.0'
```

post_install 블록도 확인:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

### 1-3. pubspec.yaml 버전 올리기
```yaml
version: 1.0.0+1   # 빌드번호는 매번 +1 증가
```

### 1-4. ExportOptions.plist 생성 (필수!)
파일: `ios/ExportOptions.plist` (없으면 새로 생성)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>NCB9774DGY</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.nanoset.ai_canaan_church</key>
        <string>canaan_appstore</string>
    </dict>
</dict>
</plist>
```
> ⚠️ Bundle ID와 프로파일 이름은 앱마다 다르게 설정

---

## STEP 2: codemagic.yaml 작성

### 올바른 전체 구조 (검증 완료)
```yaml
workflows:
  ios-release:
    name: iOS Release
    max_build_duration: 60
    integrations:
      app_store_connect: LuckyTenAPI    # ← integrations 위치 (environment 안에 넣으면 오류!)
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.nanoset.ai_canaan_church  # ← 앱 Bundle ID
      groups:
        - bible                          # ← Codemagic 환경변수 그룹명
      vars:
        BUNDLE_ID: "com.nanoset.ai_canaan_church"

    scripts:
      - name: .env 파일 생성             # ← API 키가 있는 경우만
        script: |
          echo "SUPABASE_URL=$SUPABASE_URL" > .env
          echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env

      - name: Flutter pub get
        script: flutter pub get

      - name: Xcode 서명 설정 적용       # ← 반드시 필요! 없으면 "No valid code signing" 오류
        script: xcode-project use-profiles

      - name: Flutter build IPA
        script: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
        # ← --export-options-plist 없으면 "No artifacts were found" 오류

    artifacts:
      - build/ios/ipa/*.ipa

    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true       # ← true로 설정해야 자동 업로드
        submit_to_app_store: false
        # ⚠️ app_apple_id 필드 없음 (넣으면 validation 오류)
```

### ❌ 절대 하면 안 되는 것
```yaml
# 잘못된 예시 1 - ios_signing에 없는 필드
ios_signing:
  provisioning_profile: 이름   # ← 오류!

# 잘못된 예시 2 - publishing에 없는 필드
publishing:
  app_store_connect:
    app_apple_id: "123"        # ← 오류!

# 잘못된 예시 3 - integrations 위치 잘못됨
environment:
  app_store_connect: LuckyTenAPI  # ← 오류! integrations 아래에 있어야 함
```

---

## STEP 3: Codemagic 서명 설정

### 3-1. iOS Certificates 탭
**"Fetch certificate" 사용 금지** (개인키 없음)

올바른 방법:
- 기존 `lucky10_p12_cert` (Jun 22, 2026, 개인키 있음) 재사용
- 이미 등록되어 있으므로 추가 작업 불필요

### 3-2. iOS Provisioning Profiles 탭

**새 앱 프로파일 추가 순서:**

1. **Apple Developer Portal**에서 프로파일 준비
   - developer.apple.com → Profiles → 새 프로파일 생성
   - Type: App Store
   - App ID: com.nanoset.ai_canaan_church
   - Certificate: **"Kyung soo Chang(Distribution) Jun 21, 2026"** ← 반드시 이것 선택
     (Mar 13, 2027 선택하면 개인키 없어서 빌드 실패!)
   - 프로파일명: `canaan_appstore`
   - Save → Download

2. **Codemagic에 업로드**
   - iOS provisioning profiles → "Choose a .mobileprovision file" 클릭
   - 다운로드한 파일 선택
   - Reference name: `canaan_appstore` (ExportOptions.plist의 이름과 동일하게!)
   - "Add profile" 클릭
   - Certificate 열에 **초록색 체크** 확인 (빨간X면 인증서 불일치)

### 3-3. 초록색 체크 확인 방법
```
Available provisioning profiles:
┌─────────────────────┬────────────┬─────────────┬──────────────────────────────┐
│ 이름                 │ Type       │ Certificate │ Bundle ID                    │
├─────────────────────┼────────────┼─────────────┼──────────────────────────────┤
│ canaan_appstore     │ app_store  │ ✅ (초록)   │ com.nanoset.ai_canaan_church │
└─────────────────────┴────────────┴─────────────┴──────────────────────────────┘
```

---

## STEP 4: App Store Connect 앱 준비

### 4-1. 앱 등록 (이미 되어 있으면 skip)
- appstoreconnect.apple.com → 앱 → "+" 클릭
- Bundle ID 등록 필요 (Apple Developer Portal에서 먼저 생성)

### 4-2. 필수 입력 항목
- [ ] 앱 이름
- [ ] 자막 (30자 이내)
- [ ] 설명
- [ ] 키워드
- [ ] 지원 URL
- [ ] 개인정보 처리방침 URL
- [ ] 연령 등급 (설문 응답)
- [ ] 버전 정보 (새 기능)
- [ ] 심사팀 연락처

### 4-3. 스크린샷 크기
| 기기 | 필수 크기 |
|------|----------|
| iPhone 6.9" | 1320×2868 또는 1290×2796 |
| iPhone 6.5" | 1284×2778 또는 1242×2688 |

스크린샷 변환 Python 코드:
```python
from PIL import Image
img = Image.open("원본.png")
img_resized = img.resize((1242, 2688), Image.LANCZOS)
img_resized.save("iphone65.png")
```

---

## STEP 5: 빌드 & 업로드

### 5-1. 빌드 전 체크리스트
- [ ] codemagic.yaml YAML 문법 오류 없음
- [ ] ExportOptions.plist Bundle ID와 프로파일명 정확한지 확인
- [ ] Codemagic 환경변수 그룹에 필요한 키 있는지 확인
- [ ] Provisioning profile 초록색 체크 확인
- [ ] git push 완료

### 5-2. 빌드 시작
1. codemagic.io → 앱 선택 → Start new build
2. Branch: main, Workflow: ios-release
3. Start build 클릭

### 5-3. 빌드 성공 확인
```
✅ Preparing build machine
✅ Fetching app sources
✅ Installing SDKs
✅ Set up code signing identities
✅ .env 파일 생성
✅ Flutter pub get
✅ Xcode 서명 설정 적용
✅ Flutter build IPA          ← 3분 이상 걸려야 정상
✅ Publishing                  ← 1분 이상 걸려야 정상 (< 1s면 업로드 안 된 것)
```

Artifacts에 `.ipa` 파일이 보여야 성공

### 5-4. TestFlight 확인
- App Store Connect → TestFlight → 빌드 목록
- Apple 처리 시간: 15~30분
- 이메일로 "앱이 TestFlight에서 사용 가능" 알림 옴

---

## STEP 6: 심사 제출

### 6-1. 심사 전 최종 확인
- [ ] 스크린샷 모든 크기 업로드
- [ ] 개인정보 수집 항목 설정 완료 → "게시" 버튼 클릭
- [ ] 연령 등급 설정 완료
- [ ] TestFlight 빌드가 버전 페이지에 연결됨

### 6-2. 심사 제출
1. 버전 페이지 → "심사에 추가" 클릭
2. "심사를 위해 제출" 클릭
3. 상태: "심사 대기 중" 확인
4. 24~48시간 내 결과 이메일 수신

---

## 🔧 앱별 설정 차이

### AI 가나안교회 (com.nanoset.ai_canaan_church)
```yaml
bundle_identifier: com.nanoset.ai_canaan_church
```
```xml
<!-- ExportOptions.plist -->
<key>com.nanoset.ai_canaan_church</key>
<string>canaan_appstore</string>
```
Codemagic 프로파일 Reference name: `canaan_appstore`

### 말씀브릿지 (com.logosflow.wordbridge)
```yaml
bundle_identifier: com.logosflow.wordbridge
```
```xml
<!-- ExportOptions.plist -->
<key>com.logosflow.wordbridge</key>
<string>wordbridge_appstore</string>
```
Codemagic 프로파일 Reference name: `wordbridge_appstore`

---

## ⚡ 빠른 체크리스트 (Claude Code에게 지시할 때)

```
Claude Code야, iOS 배포 준비해줘:

1. ios/Runner.xcodeproj/project.pbxproj에서 Bundle ID를
   [com.nanoset.ai_canaan_church]으로 전체 교체해줘

2. ios/Podfile이 platform :ios, '15.0' 인지 확인하고
   아니면 수정해줘

3. ios/ExportOptions.plist 파일을 생성해줘:
   - teamID: NCB9774DGY
   - Bundle ID: com.nanoset.ai_canaan_church
   - 프로파일명: canaan_appstore

4. codemagic.yaml을 아래 검증된 구조로 만들어줘:
   [iOS_배포_완전_지침서_v2.md의 STEP 2 구조 참고]

5. git add, commit, push 해줘
```

---

## 📞 주요 링크
- Codemagic: https://codemagic.io
- App Store Connect: https://appstoreconnect.apple.com
- Apple Developer: https://developer.apple.com

---

*작성일: 2026-03-14*
*기준: 왕초보 성경통독 앱 실전 배포 경험 (8번 빌드 시도 끝에 성공)*
*팀 ID: NCB9774DGY (Kyung soo Chang)*

---

## 🚨 App Store 심사 반려 대응 사례 (2026-03-21 추가)

---

### 📱 사례 1: 매일 행운 십계명 (com.nanoset.fortune10) - 빌드 406

#### 반려 이유 3가지 및 해결

---

**Guideline 2.3.3 - 스크린샷이 실제 앱 화면을 보여주지 않음**

원인:
- 일부 스크린샷(appstore_3, appstore_6)이 카드가 기울어진 3D 마케팅 이미지
- 전체 스크린샷에 iOS 상태바(시간/배터리/와이파이) 없음 → Apple이 실제 앱 화면으로 인정 안 함

해결 (Python/Pillow로 자동 처리):
```python
# 1. 상태바 추가 + 기울어진 이미지를 flat 버전으로 교체
# assets/images/final_screenshots/ 에 결과물 저장

from PIL import Image, ImageDraw, ImageFont

def add_status_bar(img):
    w, h = img.size
    bar_h = max(44, int(h * 0.052))
    # 상단 배경색 샘플링, 9:41 시간 + 배터리/와이파이 아이콘 그리기
    ...

# iPhone 6.5" 필수 크기: 1242×2688
# 기울어진 이미지(appstore_3,6) → [크기변환]3.png (flat) 으로 교체
```

결과 파일 위치: `assets/images/final_screenshots/screenshot_1~6.png` (iPhone), `ipad_1~6.png` (iPad 2048×2732)

> ⚠️ 스크린샷 핵심: 상태바 필수 + 기울어진/마케팅 이미지 금지 + 실제 앱 UI만

---

**Guideline 1.2 - 사용자 생성 콘텐츠(UGC) 안전장치 미비**

원인: `community_memo_page.dart`에 메모/댓글 기능이 있는데 아래가 없음
- 이용약관(EULA) 동의 없음
- 신고(Report) 기능 없음

해결 (`lib/community_memo_page.dart` 수정):
1. **EULA 다이얼로그**: 커뮤니티 첫 진입 시 SharedPreferences로 동의 여부 확인, 미동의 시 다이얼로그 표시 (5개 언어: ko/en/ja/zh/es)
2. **신고 버튼**: 각 메모 카드에 🚩 아이콘 추가 → 확인 다이얼로그 → Supabase `memo_reports` 테이블에 기록

Supabase memo_reports 테이블 생성 SQL:
```sql
CREATE TABLE memo_reports (
  id BIGSERIAL PRIMARY KEY,
  memo_id BIGINT NOT NULL REFERENCES community_memos(id),
  reporter_device_id TEXT,
  reported_at TIMESTAMPTZ DEFAULT NOW()
);
```

> ⚠️ UGC 기능이 있으면 반드시: EULA + 신고 + 차단 + 24시간 내 처리 정책

---

**Guideline 1.5 - 지원 URL 접속 불가**

원인: App Store Connect에 등록된 URL이 실제 작동하지 않음

해결: GitHub Pages로 지원 페이지 배포
1. 지원 HTML 파일을 `docs/fortune10/support/index.html`에 작성
2. 루트에 `docs/.nojekyll` 파일 생성
3. GitHub → 레포 Settings → Pages → Branch: main / Folder: /docs → Save
4. URL: `https://[username].github.io/[repo명]/fortune10/support/`
5. App Store Connect 지원 URL 변경 후 저장

> ⚠️ GitHub Pages 폴더는 `/docs`만 가능 (루트 또는 `/docs`)

---

### 📱 사례 2: 대표기도문 (com.nanoset.leaderprayer) - 빌드 136

#### 반려 이유 2가지 및 해결

---

**Guideline 2.1(a) - iPad에서 앱 실행 즉시 크래시 (SIGABRT)**

원인: `adx_sdk` (Android 전용 광고 SDK)가 iOS에서도 `GeneratedPluginRegistrant.m`에 등록됨
```objc
// 이 줄이 iOS에서도 실행되어 NSException 발생 → SIGABRT
[AdxSdkPlugin registerWithRegistrar:[registry registrarForPlugin:@"AdxSdkPlugin"]];
```

- Flutter는 pubspec.yaml에 있는 모든 플러그인을 iOS에도 자동 등록
- `if (Platform.isAndroid)` Dart 코드 조건과 무관하게 네이티브 레벨에서 먼저 실행됨

해결: `codemagic.yaml`에 빌드 스크립트 추가 (`flutter pub get` 이후, `flutter build ipa` 이전):
```yaml
- name: iOS 빌드에서 adx_sdk 제거 (Android 전용 SDK)
  script: |
    sed -i '' '/#import.*adx_sdk/d' ios/Runner/GeneratedPluginRegistrant.m
    sed -i '' '/@import adx_sdk/d' ios/Runner/GeneratedPluginRegistrant.m
    sed -i '' '/AdxSdkPlugin/d' ios/Runner/GeneratedPluginRegistrant.m
```

> ⚠️ Android 전용 SDK(adx_sdk 등)는 iOS 빌드 시 GeneratedPluginRegistrant.m에서 반드시 제거
> Android 빌드에는 영향 없음 (iOS workflow에서만 패치)

---

**Guideline 2.3.8 - 앱 아이콘이 플레이스홀더처럼 보임**

원인: 빌드 시점에 일부 아이콘 크기가 Flutter 기본 파란 로고(Dart 아이콘)로 남아 있었음

확인 방법: Apple이 첨부한 크래시 스크린샷에 파란 Flutter 기본 아이콘이 찍혀 있음

해결:
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` 안의 **모든 크기** 아이콘을 교체
- 1024×1024 하나만 교체하면 안 됨, 20x20, 29x29, 40x40, 60x60, 76x76, 83.5x83.5 전부 교체

> ⚠️ flutter_launcher_icons 패키지 사용하면 한 번에 전체 크기 교체 가능:
> ```yaml
> # pubspec.yaml
> flutter_launcher_icons:
>   icon: assets/app_icon.png  # 1024x1024 원본
>   ios: true
>   android: true
> ```
> ```bash
> flutter pub run flutter_launcher_icons
> ```

---

### 📋 심사 반려 공통 체크리스트

```
심사 제출 전 확인:
- [ ] 스크린샷: 상태바 있음 + 실제 앱 UI + 기울어진 이미지 없음
- [ ] 스크린샷 크기: iPhone 6.5" = 1242×2688, iPhone 6.7" = 1290×2796
- [ ] 지원 URL 실제 접속 가능한지 브라우저에서 직접 확인
- [ ] UGC 기능(댓글/게시판) 있으면 EULA + 신고 버튼 필수
- [ ] Android 전용 SDK가 iOS에 등록되지 않는지 확인
- [ ] 앱 아이콘 모든 크기 교체됐는지 확인 (flutter_launcher_icons 권장)
- [ ] 빌드 번호 이전 빌드보다 높은지 확인 (ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE 방지)
```

---

## 📌 2026-03-15 침신 말씀노트 배포 추가 경험

### 앱 정보
- Bundle ID: `com.logosflow.chimshinBibleNote`
- 팀 ID: `NCB9774DGY`
- Codemagic 프로파일: `chimshin_appstore`
- 빌드 성공: 1.0.0 (118) → App Store 심사 제출 완료

---

### 🔴 새로 만난 오류들

#### 오류 1: `-G flag` arm64 비호환 (gRPC-Core)
**원인:** firebase_messaging이 gRPC-Core를 의존하고, gRPC-Core가 arm64에서 지원하지 않는 `-G` 컴파일러 플래그를 사용
**해결 1 (근본 해결):** Firebase v3으로 업그레이드
```yaml
# pubspec.yaml
firebase_core: ^3.6.0
firebase_auth: ^5.3.1
cloud_firestore: ^5.4.5
firebase_storage: ^12.3.3
firebase_messaging: ^15.1.6
```
**해결 2 (Podfile post_install hook):**
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings.each_key do |key|
        val = config.build_settings[key]
        if val.is_a?(String) && val.include?('-G')
          tokens = val.split(' ')
          filtered = tokens.reject { |t| t.start_with?('-G') }
          config.build_settings[key] = filtered.join(' ') if filtered.length != tokens.length
        elsif val.is_a?(Array)
          config.build_settings[key] = val.reject { |t| t.to_s.start_with?('-G') }
        end
      end
    end
  end
  Dir.glob(File.join(installer.sandbox.root.to_s, '**', '*.xcconfig')).each do |xcconfig_path|
    content = File.read(xcconfig_path)
    next unless content.include?('-G')
    new_content = content.gsub(/\s+-G\S*/, '')
    File.write(xcconfig_path, new_content) if content != new_content
  end
end
```
**해결 3 (codemagic.yaml 스크립트):**
```yaml
- name: Fix -G flag (gRPC-Core arm64 incompatibility)
  script: |
    find ios -name "*.xcconfig" | while read f; do
      if grep -q '\-G' "$f"; then
        sed -i '' 's/[[:space:]]*-G[^[:space:]]* / /g; s/[[:space:]]*-G[^[:space:]]*$//g' "$f"
      fi
    done
```

---

#### 오류 2: ITMS-90683 Missing purpose string in Info.plist
**원인:** `file_picker` 패키지가 사진 보관함/마이크 접근 → Apple이 목적 문자열 요구
**해결:** `ios/Runner/Info.plist`에 추가
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>설교 오디오 파일을 업로드하기 위해 파일에 접근합니다.</string>
<key>NSMicrophoneUsageDescription</key>
<string>음성 녹음을 위해 마이크에 접근합니다.</string>
```
> ⚠️ Apple이 이메일(apple@email.apple.com)로 ITMS 오류 코드를 보내줌 → 반드시 확인

---

#### 오류 3: Post-processing "App Store distribution" 실패
**증상:** IPA 빌드 성공 + Publishing 성공 → Post-processing만 실패
**원인 A:** Apple 서버 처리 타임아웃 (16분 이상) → TestFlight에 빌드가 올라와 있을 수 있음
**원인 B:** ITMS 오류로 Apple이 IPA 거부 → TestFlight에 빌드 없음 + Apple 이메일 도착
**대응:**
1. TestFlight 탭에서 빌드 있는지 확인
2. Apple 이메일 확인 (ITMS 코드 확인)
3. 빌드 없으면 → 오류 수정 후 빌드 번호 +1 올려서 재빌드

---

#### 오류 4: 빌드 번호 중복
**증상:** App Store에 이미 제출된 빌드 번호로 재업로드 시 거부
**해결:** `pubspec.yaml` 버전 번호 반드시 +1 증가
```yaml
version: 1.0.0+118  # 매 빌드마다 증가
```

---

### ✅ App Store 심사 제출 전 체크리스트 (추가)

- [ ] `앱 정보` → 콘텐츠 관련 정보 (연령 등급) 설정
- [ ] `가격 및 사용 가능 여부` → 가격 등급 선택 (무료 = 0원)
- [ ] `빌드` → 빌드 추가 버튼으로 빌드 연결 (없으면 심사 제출 불가)
- [ ] 수출 규정 문서 → "위에 언급된 알고리즘에 모두 해당하지 않음" 선택

---

### 🔑 Firebase 사용 앱 필수 Info.plist 항목
```xml
<!-- Firebase Messaging -->
<key>FirebaseMessagingAutoInitEnabled</key>
<false/>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>

<!-- file_picker 사용 시 -->
<key>NSPhotoLibraryUsageDescription</key>
<string>파일 업로드를 위해 접근합니다.</string>
<key>NSMicrophoneUsageDescription</key>
<string>음성 녹음을 위해 마이크에 접근합니다.</string>
```

---

### 침신 말씀노트 codemagic.yaml (검증 완료)
```yaml
chimshin-ios-release:
  name: Chimshin iOS Release
  max_build_duration: 60
  working_directory: chimshin
  integrations:
    app_store_connect: LuckyTenAPI
  environment:
    flutter: stable
    xcode: latest
    cocoapods: default
    ios_signing:
      distribution_type: app_store
      bundle_identifier: com.logosflow.chimshinBibleNote
    groups:
      - chimshin
    vars:
      BUNDLE_ID: "com.logosflow.chimshinBibleNote"
      WHISPER_SERVER_URL: "https://logosflow-production.up.railway.app"
  scripts:
    - name: GoogleService-Info.plist 복원
      script: echo "$GOOGLESERVICE_INFO_PLIST" | base64 --decode > ios/Runner/GoogleService-Info.plist
    - name: .env 파일 생성
      script: |
        echo "FLAVOR=chimshin" > .env
        echo "WHISPER_SERVER_URL=$WHISPER_SERVER_URL" >> .env
        echo "NOTIFY_SERVER_KEY=$NOTIFY_SERVER_KEY" >> .env
    - name: Flutter pub get
      script: flutter pub get
    - name: Fix -G flag (gRPC-Core arm64 incompatibility)
      script: |
        find ios -name "*.xcconfig" | while read f; do
          if grep -q '\-G' "$f"; then
            sed -i '' 's/[[:space:]]*-G[^[:space:]]* / /g; s/[[:space:]]*-G[^[:space:]]*$//g' "$f"
          fi
        done
    - name: Xcode 서명 설정 적용
      script: xcode-project use-profiles
    - name: Flutter build IPA
      script: flutter build ipa --release --no-pub --export-options-plist=ios/ExportOptions.plist
  artifacts:
    - build/ios/ipa/*.ipa
  publishing:
    app_store_connect:
      auth: integration
      submit_to_testflight: true
      submit_to_app_store: false
```

*추가일: 2026-03-15 | 침신 말씀노트 (com.logosflow.chimshinBibleNote) 실전 경험*

---

## 📌 2026-03-19 매일 행운 십계명 배포 추가 경험
### (Prayday / 매일기도루틴 배포 시 참고)

### 앱 정보
- 앱 이름: 매일 행운 십계명
- Bundle ID: `com.nanoset.fortune10`
- 팀 ID: `NCB9774DGY`
- Codemagic 프로파일: `Lucky10App_Prod_Profile`
- Codemagic 환경변수 그룹: `lucky10`
- 빌드 성공: 1.1.1 (405) → TestFlight 업로드 → App Store 심사 제출 완료

---

### 🔴 새로 만난 오류들

#### 오류 1: App Store Connect Integration이 없는 경우
**증상:** Codemagic에 `LuckyTenAPI` 등록이 안 되어 있어 `integrations: app_store_connect: LuckyTenAPI` 방식 사용 불가
**해결:** `integrations` 방식 대신 **환경변수 방식**으로 publishing 설정

```yaml
# ❌ integrations 미등록 앱에서 이 방식은 오류
integrations:
  app_store_connect: LuckyTenAPI

publishing:
  app_store_connect:
    auth: integration   # ← integrations 없으면 오류
```

```yaml
# ✅ 환경변수 방식 (integration 없을 때)
publishing:
  app_store_connect:
    api_key: $APP_STORE_CONNECT_PRIVATE_KEY      # p8 파일 전체 내용
    key_id: $APP_STORE_CONNECT_KEY_IDENTIFIER    # 예: 33SGV65XW7
    issuer_id: $APP_STORE_CONNECT_ISSUER_ID      # UUID 형식
    submit_to_testflight: true
    submit_to_app_store: false
```

**Codemagic 환경변수 그룹에 추가할 항목:**
- `APP_STORE_CONNECT_PRIVATE_KEY` = AuthKey_XXXXXX.p8 파일의 전체 내용 (-----BEGIN EC PRIVATE KEY----- 포함)
- `APP_STORE_CONNECT_KEY_IDENTIFIER` = Key ID (예: 33SGV65XW7)
- `APP_STORE_CONNECT_ISSUER_ID` = Issuer ID (UUID 형식, App Store Connect → 사용자 → 키 탭에서 확인)

**p8 파일 위치:** App Store Connect → 사용자 및 액세스 → 키 탭 (1회만 다운로드 가능!)

---

#### 오류 2: Bundle ID 불일치
**증상:** ExportOptions.plist, codemagic.yaml에 설정한 Bundle ID와 실제 앱 Bundle ID가 다름
**원인:** 초기 설정 시 `com.nanoset.luckyten`으로 했으나 실제는 `com.nanoset.fortune10`
**해결:** 아래 3개 파일 모두 동일한 Bundle ID로 맞춰야 함

```bash
# 확인 방법
grep "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj
```

수정 대상 파일:
1. `ios/Runner.xcodeproj/project.pbxproj` - PRODUCT_BUNDLE_IDENTIFIER 전체 교체
2. `ios/ExportOptions.plist` - `<key>` 태그의 Bundle ID
3. `codemagic.yaml` - `bundle_identifier` 값

> ⚠️ **가장 흔한 실수**: 지침서에 있는 예시 Bundle ID를 그대로 쓰지 말고, 실제 App Store Connect에 등록된 Bundle ID 확인 후 입력!

---

#### 오류 3: 새로 만든 파일이 git에 안 올라감
**증상:** 로컬에서 파일 생성 후 commit + push 했는데 Codemagic 빌드에서 파일 없음 오류
**원인:** 새 파일은 `git add` 없이 commit하면 포함되지 않음 (untracked 상태)
**해결:**
```bash
git add 파일명        # 특정 파일
git add -A            # 전체 (주의: .env 등 민감 파일 포함될 수 있음)
git status            # 확인
git commit -m "메시지"
git push
```
> ⚠️ Claude Code에게 파일 생성 요청 후 바로 push 시키면 자동으로 git add도 해줌

---

#### 오류 4: flutter_local_notifications zonedSchedule 파라미터 누락
**증상:** `uiLocalNotificationDateInterpretation` 파라미터 없으면 컴파일 오류
**해결:** `zonedSchedule` 호출 시 반드시 포함

```dart
await _plugin.zonedSchedule(
  0,
  '알림 제목',
  '알림 내용',
  _nextNineAM(),
  const NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_9am', '채널명',
      channelDescription: '설명',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  ),
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  uiLocalNotificationDateInterpretation:            // ← 필수! 없으면 오류
      UILocalNotificationDateInterpretation.absoluteTime,
  matchDateTimeComponents: DateTimeComponents.time,  // ← 매일 반복
);
```

---

### 🌐 지원 URL & 개인정보 처리방침 URL 만들기

#### 지원 URL - GitHub Pages 활용 (무료, 간단)

1. GitHub 저장소 → Settings → Pages → `main` 브랜치 `/docs` 폴더 선택 → Save
2. `docs/support.html` 파일 생성 (한국어/영어 포함)
3. `docs/index.html` 파일 생성 (support.html로 리다이렉트)
4. URL 형식: `https://[GitHub계정].github.io/[저장소명]/support.html`

```html
<!-- docs/index.html -->
<!DOCTYPE html>
<html><head>
  <meta http-equiv="refresh" content="0; url=support.html" />
</head><body><a href="support.html">Support Page</a></body>
</html>
```

#### 개인정보 처리방침 URL - 구글 닥스 활용

1. [docs.google.com](https://docs.google.com) → 새 문서 → 내용 작성
2. 파일 → 공유 → **"링크가 있는 모든 사용자"** → 뷰어 설정
3. 링크 복사 → App Store Connect 앱 정보 → 개인정보 처리방침 URL에 입력

**개인정보 처리방침 최소 포함 항목:**
- 수집하는 데이터 목록
- 데이터 사용 목적
- 제3자 제공 여부
- 데이터 보존 기간
- 사용자 권리 (삭제 요청 등)
- 아동 보호 정책 (14세 미만)
- 문의 이메일

---

### ✅ 매일 행운 십계명 검증된 codemagic.yaml (환경변수 방식)

```yaml
workflows:
  ios-release:
    name: iOS Release
    max_build_duration: 60
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.nanoset.fortune10
      groups:
        - lucky10
      vars:
        BUNDLE_ID: "com.nanoset.fortune10"

    scripts:
      - name: .env 파일 생성
        script: |
          echo "SUPABASE_URL=$SUPABASE_URL" > .env
          echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env

      - name: Flutter pub get
        script: flutter pub get

      - name: Xcode 서명 설정 적용
        script: xcode-project use-profiles

      - name: Flutter build IPA
        script: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

    artifacts:
      - build/ios/ipa/*.ipa

    publishing:
      app_store_connect:
        api_key: $APP_STORE_CONNECT_PRIVATE_KEY
        key_id: $APP_STORE_CONNECT_KEY_IDENTIFIER
        issuer_id: $APP_STORE_CONNECT_ISSUER_ID
        submit_to_testflight: true
        submit_to_app_store: false
```

---

### 🔧 앱별 설정 (Prayday / 매일기도루틴)

앞으로 Prayday와 매일기도루틴 배포 시 아래 항목을 실제 값으로 채워서 사용:

#### Prayday
```
Bundle ID: (App Store Connect에서 확인 후 입력)
팀 ID: NCB9774DGY
Codemagic 환경변수 그룹: prayday
Provisioning Profile 이름: prayday_appstore
```

```yaml
# codemagic.yaml 내 변경할 부분
bundle_identifier: [Prayday Bundle ID]
groups:
  - prayday
vars:
  BUNDLE_ID: "[Prayday Bundle ID]"
```

```xml
<!-- ios/ExportOptions.plist -->
<key>[Prayday Bundle ID]</key>
<string>prayday_appstore</string>
```

#### 매일기도루틴
```
Bundle ID: (App Store Connect에서 확인 후 입력)
팀 ID: NCB9774DGY
Codemagic 환경변수 그룹: prayroutine
Provisioning Profile 이름: prayroutine_appstore
```

---

### ⚡ Prayday / 매일기도루틴용 Claude Code 지시 템플릿

```
Claude Code야, iOS 배포 준비해줘:

앱 정보:
- Bundle ID: [여기에 실제 Bundle ID 입력]
- Provisioning Profile 이름: [prayday_appstore 또는 prayroutine_appstore]
- Codemagic 환경변수 그룹: [prayday 또는 prayroutine]
- Supabase 사용 여부: [Yes/No]

1. ios/Runner.xcodeproj/project.pbxproj에서 Bundle ID를
   위 Bundle ID로 전체 교체해줘

2. ios/Podfile이 platform :ios, '15.0' 인지 확인해줘

3. ios/ExportOptions.plist 파일 생성해줘:
   - teamID: NCB9774DGY
   - Bundle ID: [위 Bundle ID]
   - 프로파일명: [위 프로파일 이름]

4. codemagic.yaml을 환경변수 방식으로 만들어줘:
   (integrations 방식 아닌 api_key/key_id/issuer_id 환경변수 방식)
   - 그룹: [위 그룹명]
   - Supabase 있으면 .env 생성 스크립트 포함

5. git add, commit, push 해줘

그리고 iOS_배포_완전_지침서_v2.md 참고해서 누락된 것 있으면 알려줘
```

---

*추가일: 2026-03-19 | 매일 행운 십계명 (com.nanoset.fortune10) 실전 경험*
*다음 대상: Prayday, 매일기도루틴*
