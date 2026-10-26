# 원격지킴이 1.1.0 검증 결과

## 구현 범위

실제 시스템 상태 기반 토글, 변경 전 설정 복원, MacBook의 저전력·충전기 미연결 시 승인, 실행 중 전원 위험 안내, 외부 변경 확인, 손상 기록의 긴급 해제와 정적 다운로드 페이지를 구현했습니다.

기존 restore.json 형식을 유지했습니다. 새 브라우저 스토리지, 서버 저장소, 외부 패키지와 추적 코드는 도입하지 않았습니다. 앱은 비밀번호를 저장하지 않습니다.

## 실행한 검사

| 검사 | 결과 |
| --- | --- |
| `sh Source/build.sh` | 컴파일, 임시 코드 서명, 자체 검사, ZIP·체크섬 생성 통과 |
| 생성 앱의 `--self-test` | 통과 |
| `codesign --verify --deep --strict --verbose=2` | 빌드된 앱 서명 무결성 통과 |
| 생성 앱의 `--status` | 실제 SleepDisabled 0, AC 연결, 배터리 100%, 덮개 열림 확인 |
| `sh -n Source/build.sh` | 통과 |
| 소스·빌드 앱의 `Info.plist` | plutil 검사 통과 |
| `node --check website/app.js` | 통과 |
| HTML 내부 앵커·상대 경로·중복 ID | 통과 |
| ZIP CRC·포함 파일·실행 파일 일치 | 통과 |
| ZIP SHA-256 | 일치 |
| 로컬 HTTP 문서·CSS·JS·아이콘·ZIP·체크섬 | 6개 응답 모두 200 |
| ego-browser에서 페이지 한 번 열기 | 콘솔 오류·예외·실패 요청 없음 |

자체 검사에는 IOPowerSources 전원·배터리 해석, 내장 배터리가 없는 데스크톱과 UPS의 구분, 0~100% 정수 잔량과 20% 기준, 잘못된 입력, 기존 JSON 왕복, 복원 대상 판정, 비관리 항목 보존, 관리자 명령 전 외부 값 확인, 모의 켜기·복원 실패 시 복구와 프로세스 시간 제한이 포함됩니다. 관리자 명령은 실행하지 않고 모의 명령과 AppleScript 컴파일로 확인했습니다.

ZIP은 macOS ditto로 생성했습니다. ditto가 UTF-8 이름 플래그를 설정하지 않는 형식이므로 Python 검증에서는 metadata_encoding='utf-8'을 지정했습니다. 압축 데이터 자체의 오류는 없었습니다.

## 발견·보완한 문제

- 이 Mac의 기본 `pmset -g` 출력에는 SleepDisabled 항목이 없었습니다. 없는 값을 0으로 추측하지 않고 IOPMrootDomain의 실제 SleepDisabled 값을 읽도록 변경했습니다. Apple의 [pmset 소스](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m)에서도 해당 설정 키가 있을 때만 출력하는 것을 확인했습니다.
- 최초 인증 취소 시 설정이 바뀌지 않은 것이 확인되면 새 복원 기록을 정리합니다. 원인을 확정할 수 없는 오류에는 기록을 보존합니다.
- 실패한 변경은 직전 설정으로 복구를 시도합니다. 복원 시 앱이 바꾸지 않은 AC 항목을 덮어쓰지 않는 것을 모의 실행으로 확인했습니다.
- 기존 루트 앱의 실행은 Gatekeeper에서 차단됐습니다. 새 로컬 빌드는 이 Mac에서 자체 검사를 실행할 수 있었습니다. 다른 Mac에서의 다운로드 후 실행 허용을 검증한 것은 아닙니다.

## 결과물

- 앱: `build/원격지킴이.app`
- 페이지: `website/index.html`
- ZIP: `website/downloads/remote-lid-1.1.0-arm64.zip`
- ZIP 크기: 976132바이트
- SHA-256: `92fff17a3e58490baedaff27a49f6e3e6fbc0b88b4158d36a8fbec5e272d7e9f`

루트에 있던 이전 앱·ZIP과 생성 아이콘 PNG는 유지하고 Git 등록 대상에서 제외했습니다. 직접 실행한 임시 서버와 브라우저 작업 공간은 검증 후 종료했습니다. 사용자 서버와 실행 중 앱은 종료하지 않았습니다.

## 미검증·배포 상태

- Mac mini·Mac Studio 등 데스크톱 실기기와 24시간 연속 동작, 실제 관리자 인증을 거친 켜기·끄기, 손상 파일 UI, 전원 분리·배터리 저하 알림과 장시간 덮개 닫기는 실사용 검증이 필요합니다. 실제 전원 설정은 변경하지 않았습니다.
- 브라우저 검증은 콘솔과 실패 요청만 확인했습니다. 클릭·스크린샷·화면 크기별 상세 조작 검증은 수행하지 않았습니다.
- 키체인에서 유효한 코드 서명 인증서를 찾지 못했습니다. Developer ID Application 서명·Hardened Runtime·공증은 미완료입니다. [Apple 배포 요구 사항](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)에 따른 준비가 필요합니다.
- 소스 저장소 등록과 main push는 커밋 6ca7c43으로 완료했습니다. 다운로드 사이트의 Release·Pages 배포 구성은 아래에 기록합니다.
- 페이지의 앱 ZIP·체크섬 링크는 v1.1.0 Release의 절대 URL로 연결합니다. 앱 ZIP은 Pages 아티팩트에 포함하지 않습니다.

## Mac 공통 지원 보완 검증

- 소스 저장소는 `KangUnMo/mac-remote-lid`이며 초기 커밋은 `6ca7c43`입니다.
- 배터리 유무는 macOS IOPowerSources API로 구분합니다. 내장 배터리가 없는 정상 상태에서는 배터리 경고와 덮개 표시를 생략합니다. API 조회 실패와 불완전한 내장 배터리 정보는 켜기를 중단합니다.
- 정상 데스크톱, UPS, MacBook 0~100% 잔량, 20%·21% 경계, 용량 환산, 잘못된 잔량·최대 용량·타입과 정수 넘침을 자체 검사했습니다.
- 데스크톱에서 선택적인 네트워크 항목이 없는 전원 설정으로도 명령 생성·실행을 모의 검사했습니다. 공통 복원 명령과 실패 복구 검사를 유지했습니다.
- 새 빌드의 자체 검사·서명·ZIP·체크섬 검사를 다시 통과했습니다. 현재 MacBook의 실제 전원 읽기는 AC 연결, 배터리 100%, SleepDisabled 0으로 확인했습니다.
- 갱신된 페이지는 ego-browser에서 한 번 열어 콘솔·예외·실패 요청이 없음을 확인했습니다. 문서·CSS·JS·아이콘·ZIP·체크섬의 로컬 HTTP 응답 6개도 모두 200이었습니다.
- 데스크톱 실기기·24시간 유지, 실제 관리자 인증과 전원 변경은 수행하지 않았습니다. 외장 UPS의 잔량 경고는 제공하지 않습니다.

## 다운로드 사이트 공개 구성

- 공개 페이지 주소: https://KangUnMo.github.io/mac-remote-lid/
- 릴리스: https://github.com/KangUnMo/mac-remote-lid/releases/tag/v1.1.0
- 기존 검증 ZIP과 SHA-256을 v1.1.0 미리보기 릴리스로 공개했습니다. 빌드 소스는 6ca7c437c3ac0f3349f7864980796998351ef576입니다.
- .github/workflows/pages.yml은 공식 checkout·configure-pages·upload-pages-artifact·deploy-pages 액션으로 website/만 게시합니다.
- 변경한 페이지의 다운로드·체크섬 링크는 Releases를 가리키며, 로컬 다운로드 파일에 의존하지 않습니다.
- 배포 후 공개 HTML·CSS·JavaScript·아이콘 응답, 콘솔 오류와 실패 요청, 실제 다운로드 ZIP의 크기·SHA-256을 확인합니다. 실행 결과는 [Pages 배포 내역](https://github.com/KangUnMo/mac-remote-lid/actions/workflows/pages.yml)에서 확인할 수 있습니다.
- 앱 서명·실기기 검증 범위는 기존과 같습니다. 공증되지 않은 미리보기임을 페이지와 릴리스 노트에 표시합니다.

### 공개 배포 전 확인 결과

- v1.1.0 미리보기 릴리스에 앱 ZIP 976132바이트와 체크섬 파일 93바이트가 업로드된 것을 확인했습니다.
- 인증 없는 공개 다운로드 URL에서 ZIP·체크섬 응답이 모두 HTTP 200이었고, ZIP 내용과 SHA-256이 로컬 검증 파일과 일치했습니다.
- GitHub Pages는 workflow 방식으로 활성화했으며 공개 주소는 https://kangunmo.github.io/mac-remote-lid/ 입니다.
- 변경 페이지의 다운로드 URL 3개, 내부 앵커와 정적 파일 경로, Pages YAML의 트리거·권한·업로드 경로를 검사했습니다. 앱 자체 검사와 서명 무결성도 다시 통과했습니다.
- Pages의 실제 게시와 공개 페이지 검증은 이 커밋의 push로 실행되는 배포 작업을 기준으로 확인합니다. 결과는 위 배포 실행 내역에서 확인할 수 있습니다.
