# 원격지킴이 · mac-remote-lid

Mac의 잠자기를 방지하는 개인용 macOS 메뉴 막대 앱입니다. 토글로 켜고 끄며, 끌 때 앱이 변경한 전원 항목을 이전 값으로 복원합니다. 원격 접속 프로그램이나 인터넷 연결 자체는 구성하지 않습니다.

## 지원 환경

- Apple Silicon MacBook·Mac mini·Mac Studio 등, macOS 13 이상
- 시스템·유휴 잠자기 방지는 공통 기능이며, 배터리 경고와 덮개 상태 표시는 MacBook에 적용합니다.
- Intel용 빌드는 현재 제공하지 않습니다.
- 빌드: Xcode 명령줄 도구 및 Swift 컴파일러
- 외부 패키지 의존성 없음

## 사용

1. `원격지킴이.app`을 열고 원격 모드 토글을 켭니다.
2. MacBook에서 충전기가 없거나 배터리가 20% 이하이면 경고 내용을 확인하고 켜기를 승인합니다.
3. 필요한 경우 macOS 창에서 관리자 인증을 진행합니다.
4. 원격 작업을 마치면 토글을 끄거나 이전 설정 복원을 선택합니다.

메뉴 막대 아이콘 중앙 도트는 잠자기 방지가 켜져 있으면 초록색, 꺼져 있으면 빨간색, 상태를 읽지 못하면 회색으로 표시됩니다. ‘SSH 접속 허용 설정…’ 메뉴는 시스템 설정의 공유 화면을 엽니다. 원격 로그인과 허용할 사용자는 해당 화면에서 직접 선택해 주세요. SSH를 자동으로 켜거나 원격 모드와 연동해 변경하지 않습니다.

창을 닫아도 메뉴 막대에서 실행됩니다. 상태는 10초마다 확인합니다. MacBook에서 켜진 뒤 충전기 연결 여부나 저전력 위험 상태가 바뀌면 다시 알립니다. 데스크톱 Mac에는 배터리 확인 단계를 적용하지 않습니다. 경고는 원격 모드를 자동으로 해제하지 않습니다.

## 설치

### 방법 1: 터미널 한 줄 설치 (권장)
보안 경고 없이 `/Applications` 폴더에 즉시 설치 및 실행됩니다. 터미널을 열고 아래 명령어를 실행하세요.

```bash
curl -fsSL https://raw.githubusercontent.com/KangUnMo/mac-remote-lid/main/install.sh | bash
```

### 방법 2: 수동 ZIP 다운로드
현재 빌드는 Apple 개발자 인증서 서명과 공증이 없습니다. 출처와 파일 무결성을 확인하고 신뢰하는 경우에만 실행해 주세요.

1. [GitHub Releases](https://github.com/KangUnMo/mac-remote-lid/releases)에서 ZIP을 다운로드하고 압축을 풉니다.
2. `원격지킴이.app`을 응용 프로그램 폴더(`/Applications`)로 옮깁니다.
3. 앱을 열어 본 뒤 실행 차단 경고가 나오면 ‘완료’를 선택합니다.
4. 시스템 설정 → 개인정보 보호 및 보안에서 원격지킴이의 ‘그래도 열기’를 누릅니다.
5. 인증 후 다시 ‘열기’를 선택합니다. (또는 터미널에서 `xattr -cr /Applications/원격지킴이.app` 실행)

[Apple 공식 최초 실행 안내](https://support.apple.com/ko-kr/102445)를 따릅니다.

업데이트할 때는 기존 앱에서 원격 모드를 끄고 종료한 뒤 위 설치 명령어를 다시 실행하거나 새 앱으로 교체합니다. 복원 기록은 임의로 삭제하지 마세요.

## 변경하는 설정

- 시스템 잠자기 방지: `pmset -a disablesleep 1`
- AC 전원 사용 시 자동 잠자기 방지: `pmset -c sleep 0`
- 지원되는 AC 전원 항목: `womp 1`, `tcpkeepalive 1`
- 앱 실행 중 유휴 잠자기 방지 IOKit assertion

화면 밝기, 자동 잠금, 충전 최적화, FileVault, 방화벽, 원격 접속 권한은 변경하지 않습니다.

## 저장과 복원

켜기 직전 전원 설정과 저장 시각을 다음 경로에 보관합니다.

```text
~/Library/Application Support/RemoteLid/restore.json
```

기존 버전의 JSON 형식과 호환됩니다. 폴더 권한은 `0700`, 파일 권한은 `0600`입니다. 최초 사용 안내 확인 여부는 기존 UserDefaults에 저장합니다. 비밀번호, 배터리 경고 승인 이력은 저장하지 않습니다. 별도 계정·원격 서버·브라우저 스토리지를 사용하지 않습니다.

끄면 최초 값에서 실제로 변경한 AC 항목과 시스템 잠자기 방지를 복원합니다. 예를 들어 처음부터 `tcpkeepalive`가 1이었다면 앱이 바꾸지 않은 항목이므로, 실행 중 다른 곳에서 수정해도 복원 대상에 포함하지 않습니다. 관리 항목에 예상 밖 값이 있으면 복원 전에 확인합니다.

관리자 명령 직전에 실제 값이 조회 시점과 같은지 확인합니다. 명령 일부가 실패하면 변경 직전 값으로 복구를 시도합니다. 복구 명령도 실패할 수 있으므로 기록은 실제 상태를 확인한 뒤 정리합니다. 인증 취소가 명확하고 설정이 그대로인 경우에만 새 복원 기록을 삭제합니다. 원인을 확정할 수 없는 실행 오류에는 기록을 보존합니다.

복원이 확인되지 않으면 원래 기록을 유지합니다. 다른 앱과 전원 설정을 동시에 변경하지 마세요. macOS 전체 설정 변경을 다른 앱과 완전히 잠그는 기능은 없습니다.

## 주의와 긴급 복구

모든 Mac은 전원을 안정적으로 연결하고 통풍되는 곳에서 사용해 주세요. MacBook의 잠자기 방지는 배터리 사용 중에도 적용되므로, 가방에 넣기 전에는 꺼 주세요. 배터리 소진을 자동으로 방지하거나 덮개를 닫은 상태의 원격 연결을 보장하지는 않습니다.

강제 종료·전원 중단 후에도 전원 설정이 남을 수 있습니다. 앱을 다시 열고 이전 설정 복원을 선택하세요. 복원 기록을 임의로 삭제하지 마세요.

복원 파일이 손상되면 앱에서 안내와 승인을 거쳐 잠자기 방지만 긴급 해제할 수 있습니다. 이때 파일과 다른 전원 항목은 유지됩니다. 터미널에서 같은 긴급 해제를 수행하려면 직접 다음 명령을 실행합니다.

```sh
sudo pmset -a disablesleep 0
```

이 명령은 이전 전원 설정 전체를 복원하지 않습니다.

## 빌드와 검사

```sh
sh Source/build.sh
```

빌드는 임시 폴더에서 컴파일과 로컬 서명, 자체 검사를 수행하고 다음 결과물을 만듭니다. 루트 폴더에 있던 이전 앱과 ZIP은 덮어쓰지 않습니다.

```text
build/원격지킴이.app
website/downloads/remote-lid-1.1.1-arm64.zip
website/downloads/remote-lid-1.1.1-arm64.zip.sha256
```

```sh
build/원격지킴이.app/Contents/MacOS/RemoteLid --self-test
build/원격지킴이.app/Contents/MacOS/RemoteLid --status
```

macOS IOPowerSources API로 내장 배터리 유무를 구분합니다. 배터리가 없는 정상 상태는 데스크톱으로 처리하고 배터리·덮개 상태를 표시하지 않습니다. API 조회 실패나 잘못된 배터리 정보는 정상적인 배터리 없음으로 처리하지 않고 켜기를 중단합니다. 외장 UPS의 잔량 경고는 제공하지 않습니다.

자체 검사는 파싱, 데스크톱·MacBook 전원 분기, 배터리 경계값, 저장 데이터 검증, 변경 항목 복원, 외부 값 보존, 명령 실패 시 복구, 시간 제한, AppleScript 컴파일과 실제 전원 상태 읽기를 수행합니다. 실제 전원 설정 변경이나 관리자 인증은 수행하지 않습니다. `pmset -g`가 SleepDisabled를 생략하는 환경에서도 IOPMrootDomain의 실제 값을 읽습니다.

## 다운로드 페이지

- [공개 다운로드 페이지](https://KangUnMo.github.io/mac-remote-lid/)
- [v1.1.1 미리보기 릴리스](https://github.com/KangUnMo/mac-remote-lid/releases/tag/v1.1.1)

`website/index.html`은 외부 폰트, CDN, 분석 코드 없이 열 수 있는 정적 페이지입니다. 다운로드 버튼은 GitHub Releases의 앱 ZIP과 체크섬 파일을 가리킵니다. 로컬 빌드 결과는 기존 website/downloads 경로에 생성됩니다. 페이지의 토글은 화면 설명용이며 시스템 설정을 바꾸지 않습니다.

로컬 서버가 필요하다면 사용 중이지 않은 포트에서 실행합니다.

```sh
python3 -m http.server 8766 --bind 127.0.0.1 --directory website
```

## 공개 배포 준비

현재 빌드는 로컬 임시 서명만 사용합니다. Apple 개발자 인증서 서명과 공증이 없어 다른 Mac에서 Gatekeeper에 차단될 수 있습니다. 빌드·서명 무결성 검사 통과는 공증 통과를 의미하지 않습니다. 위 최초 실행 안내는 해당 앱에 대한 실행 예외를 사용자가 직접 허용하는 절차입니다. Gatekeeper 전체 비활성화나 격리 속성 제거 절차는 제공하지 않습니다.

사용자의 최초 실행 예외 없이 배포하려면 [Apple의 Developer ID 안내](https://developer.apple.com/developer-id/)와 [공증 요구 사항](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)을 따라 Developer ID Application 서명, Hardened Runtime, secure timestamp와 공증을 준비해 주세요. 공증 완료 후 앱에 티켓을 첨부하고 ZIP과 SHA-256을 다시 생성해야 합니다.

소스는 [KangUnMo/mac-remote-lid](https://github.com/KangUnMo/mac-remote-lid) 공개 저장소에서 관리합니다.

소스·문서·페이지 파일은 main 브랜치에 보관하고, 앱 ZIP과 SHA-256은 GitHub Releases에 별도로 공개합니다. `.gitignore`는 빌드 결과와 기존 루트 앱·ZIP을 제외합니다.

`.github/workflows/pages.yml`은 main 브랜치의 website/ 또는 배포 설정이 변경되면 해당 정적 페이지를 GitHub Pages에 게시합니다. GitHub의 Pages 설정은 GitHub Actions 방식으로 활성화합니다. [배포 실행 내역](https://github.com/KangUnMo/mac-remote-lid/actions/workflows/pages.yml)에서 결과를 확인할 수 있습니다.

현재 v1.1.1은 미리보기 릴리스입니다. 다음 버전을 배포할 때는 새 앱 ZIP·체크섬을 Releases에 공개한 다음 페이지의 다운로드 URL과 버전을 갱신합니다. 앱 ZIP은 소스 커밋이나 Pages 아티팩트에 포함하지 않습니다.

## 소스 구성

- `Source/main.swift`: 앱, 상태 조회, 전원 명령, 저장·복원, 자체 검사
- `Source/build.sh`: 빌드·서명 검사·ZIP·SHA-256 생성
- `Source/Info.plist`: 앱 버전과 메뉴 막대 앱 설정
- `Source/make-icon.swift`: 앱 아이콘 생성
- `website/`: 정적 다운로드 페이지
- `docs/`: 승인 범위, 구현 계획, 검증 결과

데스크톱 Mac 실기기·24시간 연속 동작, 실제 사용자 인증 후 켜기·끄기, 장시간 덮개 닫기, 전원 분리·배터리 저하의 실제 UI 동작은 별도 실사용 검증이 필요합니다.
