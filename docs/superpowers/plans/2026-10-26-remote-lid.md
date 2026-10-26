# 원격지킴이 1.1 구현 계획

목표: 기존 상태 복원과 전원 승인 흐름을 보완하고 다운로드 가능한 로컬 페이지를 완성합니다.

구조: Source/main.swift의 기존 AppDelegate와 순수 명령 생성 함수를 유지합니다. 외부 의존성 없이 상태 조회 큐와 기존 자체 검사를 확장합니다.

## 제약

- macOS 13 이상, Apple Silicon을 유지합니다.
- TDD와 신규 테스트 파일을 사용하지 않고 기존 자체 검사를 구현 후 실행합니다.
- 기존 restore.json 형식과 최초 안내 UserDefaults를 유지합니다.
- Git 변경, 외부 등록·배포는 정확한 명령과 대상을 설명한 뒤 별도 승인받습니다.
- 사용자 서버와 실행 중 앱은 종료하지 않습니다.

## 작업

- [x] Source/main.swift: 전원 파싱과 20% 경계값, 실제 상태 토글, 관리자 인증 전 승인, 실행 중 경고를 구현합니다.
- [x] Source/main.swift: 변경 항목 복원, 외부 값 확인, 실패 복구, 인증 취소 기록 정리, 긴급 해제를 구현합니다.
- [x] Source/main.swift: 별도 큐에서 상태를 읽고 명령 시간 제한 및 종료 시 복원을 처리합니다.
- [x] Source/main.swift의 selfTest(): 실제 pmset 변경 없이 모의 셸 명령으로 성공·부분 실패·외부 변경을 검사합니다.
- [x] Source/build.sh와 Info.plist: 1.1.0 빌드, 로컬 서명 검사, ZIP 및 SHA-256을 생성합니다.
- [x] website/: 반응형 소개·설치·다운로드 페이지를 만들고 실제 로컬 배포 ZIP으로 연결합니다.
- [x] README.md, 사용 안내, .gitignore: 사용·복구·빌드·발행 방법과 제외 파일을 정리합니다.
- [x] 빌드 자체 검사, sh -n, plutil, 코드 서명, ZIP·해시, JS 문법, 페이지 콘솔·요청 실패를 확인합니다.
- [x] 사용자에게 검증 결과와 미검증 범위, Git 등록 대상·제외 파일 및 정확한 다음 명령을 제시합니다.

## Mac 공통 지원 보완

- [x] Source/main.swift: IOPowerSources API로 내장 배터리 유무와 조회 오류를 구분하고, 데스크톱의 배터리·덮개 표시를 생략합니다.
- [x] Source/main.swift의 selfTest(): 정상 데스크톱, UPS, MacBook 경계값, 잘못된 배터리 정보와 공통 복원 경로를 검사합니다.
- [x] website/index.html, README.md, 사용 안내: 공통 기능과 MacBook 전용 기능, 저장소명 mac-remote-lid를 반영합니다.
- [x] 빌드·서명·자체 검사·ZIP·체크섬·페이지 콘솔 검증 후 검증 문서를 갱신합니다.
