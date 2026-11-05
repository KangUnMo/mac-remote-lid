# 원격지킴이 1.1.7 배포 준비 결과

작업일: 2026-11-05. 승인된 소스·문서·빌드 준비를 완료했습니다. 실기기 GUI 검수와 Git·릴리스 승인 및 게시 담당은 PM입니다.

## 변경 내용

- `Source/Info.plist`: 앱 버전을 1.1.7, 빌드 번호를 9로 변경했습니다.
- `Source/main.swift`: 두 버전 fallback을 1.1.7로 변경했습니다. 설치 가능한 정식 후보 1.1.7이 1.1.6보다 새 버전으로 선택됨을 기존 자체검사에서 확인합니다.
- `install.sh`: 설치 버전을 1.1.7로 변경했습니다. 기존 검증·백업·복구·격리 속성 처리 정책은 유지합니다.
- `Source/test-install.py`: 정상 fixture를 1.1.7로 바꾸고 잘못된 버전 사례는 1.1.6으로 유지했습니다. 기존 21개 시나리오를 그대로 실행합니다.
- `README.md`, `사용안내.md`: 현재 버전과 다운로드 안내를 1.1.7로 변경했습니다. 1.1.2·1.1.3 역사와 관련 테스트 예제는 유지했습니다.
- `website/index.html`: 버전과 ZIP·체크섬 링크 문자열만 변경했습니다. Git의 기존 파일과 문자열 치환 결과가 같음을 검사했습니다. 브라우저는 실행하지 않았습니다.
- 이 폴더에 `RELEASE_NOTES.md`, 이 보고서와 검사 로그를 작성했습니다.

이전 `docs/qa/2026-11-05-review-fixes/` 보고서는 수정하지 않았습니다. `.agents/`, `docs/brand/`와 기존 저장 코드는 수정하지 않았습니다. `Source/build.sh`도 수정하지 않았습니다.

## 검증

빌드 스크립트와 기존 자체검사·설치 모의검사의 안전 범위를 확인한 뒤 실행했습니다. 자체검사는 실제 전원 설정을 바꾸거나 관리자 인증을 요청하지 않습니다. 설치 검사는 임시 경로·모의 외부 명령과 새 프로세스 세션을 사용하며 실제 설치나 사용자 앱 종료를 수행하지 않습니다.

| 명령 또는 검사 | 결과 | 근거 |
|---|---|---|
| `/bin/bash -n install.sh` | 통과, 종료 코드 0 | `checks.log` |
| `/bin/sh -n install.sh` | 통과, 종료 코드 0 | `checks.log` |
| `/bin/sh -n Source/build.sh` | 통과, 종료 코드 0 | `checks.log` |
| `plutil -lint Source/Info.plist` | 통과, 종료 코드 0 | `checks.log` |
| `python3 Source/test-install.py` | 기존 모의 설치 21개 통과, 종료 코드 0 | `install-tests.log` |
| `sh Source/build.sh` | 컴파일·자체검사·서명·ZIP·체크섬 생성 통과, 종료 코드 0 | `build.log` |
| `shasum -a 256 -c remote-lid-1.1.7-arm64.zip.sha256` | `website/downloads`에서 실행, 통과, 종료 코드 0 | `checks.log` |
| ZIP 내부 plist·실행 파일 확인 | 식별자 `personal.remotelid`, 버전 1.1.7, 빌드 9, 실행 파일 확인 | `checks.log` |
| 웹 문자열·문서 버전 확인 | 버전·링크 문자열 변경 및 과거 이력 보존 확인 | `checks.log` |
| `git diff --check` | 통과, 종료 코드 0 | `checks.log` |

설치 검사는 실행 중 앱 거부, 다운로드·체크섬·번들·서명 실패, 신규 설치와 교체 성공, 관리자 실행 분기, 준비·백업·교체 실패, 복구 성공·실패와 백업 보존, 실행 요청 실패, 격리 속성 제거 실패 허용을 포함합니다. 기존 Swift 자체검사는 화면 요청과 시각, 업데이트 후보 필터, 복원 흐름, 모의 전원 명령, 렌더링 등을 검사하며 이번에 정식 1.1.7 선택과 1.1.6 대비 버전 비교를 추가했습니다.

## 검사 도구 조정

첫 ZIP 내부 조회에서 Python zipfile의 기본 파일명 디코딩으로 한글 앱 경로를 찾지 못했습니다. ZIP 항목을 읽어 UTF-8 플래그가 없는 파일명임을 확인했고 `metadata_encoding='utf-8'`로 조회하여 내부 plist와 실행 파일을 검증했습니다. 빌드·배포 자산은 수정하지 않았으며 최종 검사 실패는 없습니다.

## 생성 자산

- `build/원격지킴이.app`
- `website/downloads/remote-lid-1.1.7-arm64.zip`
- `website/downloads/remote-lid-1.1.7-arm64.zip.sha256`

ZIP 크기: 521543바이트.

SHA-256:

```text
a30df925e8e2c366917d3f6dd9ca2a05ea3af767a51a6779b9b6644521f0a45e
```

배포 결과물은 기존 `.gitignore` 대상입니다. 이전 1.1.6 자산은 삭제하지 않았습니다.

## 이번 작업 수정 파일

- `Source/Info.plist`
- `Source/main.swift`
- `install.sh`
- `Source/test-install.py`
- `README.md`
- `사용안내.md`
- `website/index.html`
- `docs/qa/2026-11-05-release-1.1.7/RELEASE_NOTES.md`
- `docs/qa/2026-11-05-release-1.1.7/REPORT.md`
- `docs/qa/2026-11-05-release-1.1.7/build.log`
- `docs/qa/2026-11-05-release-1.1.7/install-tests.log`
- `docs/qa/2026-11-05-release-1.1.7/checks.log`

## 미검증과 인계

실제 앱 설치·종료·관리자 인증·전원 및 로그인 설정 변경, 실제 화면 꺼짐·덮개·원격 연결, 브라우저·장시간 실기기 검증은 수행하지 않았습니다. PM의 GUI 실기기 검증과 Git 변경 명령 승인·실행, 릴리스 게시가 남았습니다. AWS CLI와 외부 게시는 수행하지 않았습니다.

현재 웹 링크는 게시 예정인 1.1.7 릴리스를 가리킵니다. 공개 자산 업로드 전에는 다운로드 링크가 열리지 않을 수 있습니다. 로컬 서명과 SHA-256 검증은 Apple 공증이나 배포자 신원 검증을 의미하지 않습니다.
