# 변경 이력

원격 Git 태그가 가리키는 커밋, 버전 사이의 Git 기록과 기존 GitHub 릴리스 설명을 대조해 정리했습니다. 아래 게시 날짜는 GitHub의 UTC 날짜입니다. 과거 항목은 당시 변경 기록이며 현재 동작 설명은 최신 사용 안내를 따릅니다.

## 1.1.7 — 게시 준비 중

기준: `v1.1.6`의 `1308e0b` 대비 현재 작업 트리입니다. 아직 새 커밋·태그·공개 릴리스는 생성하지 않았습니다.

- 화면 자동 꺼짐 진단의 단정적 문구를 수정하고 마지막 조회 시각을 추가했습니다.
- 터미널 설치의 강제 종료를 제거하고 체크섬·번들 검증과 백업·교체·실패 복구를 보강했습니다.
- 시험판·잘못된 업데이트 후보를 제외하고 설치 가능한 정식 버전을 선택합니다.
- 네트워크 종류 오표시와 설치·보안 문서 불일치를 수정했습니다.
- macOS Bash 3.2 호환성을 확인하고 모의 설치 21개 상황과 기존 자체검사를 보강했습니다.
- 로컬 Mac에서 새 앱 설치와 전원 설정 켜기·끄기·복원을 확인했습니다. 실제 화면 자동 꺼짐과 장시간 덮개 동작은 미검증입니다.

[1.1.7 게시용 릴리스 노트](docs/qa/2026-11-05-release-1.1.7/RELEASE_NOTES.md)

## 1.1.6 — 2026-11-03

- 브랜드 A안 앱 아이콘과 사용 안내 알림창 가독성을 개선했습니다.
- 다운로드 페이지의 브랜드 디자인과 참조 아이콘을 반영했습니다.

[릴리스](https://github.com/KangUnMo/mac-remote-lid/releases/tag/v1.1.6) · [기준 커밋 1308e0b](https://github.com/KangUnMo/mac-remote-lid/commit/1308e0bf571d16a99bd64d6b1ebad2a1560703a9) · [이전 버전과 비교](https://github.com/KangUnMo/mac-remote-lid/compare/v1.1.5...v1.1.6)

## 1.1.5 — 2026-11-03

- 화면 꺼짐 방해 요청 표시를 정리하고 중복 요청을 병합했습니다.
- 시스템의 일시적인 화면 끄기 지연 요청을 일반 앱 요청과 구분해 처리했습니다.
- 상태 갱신 시 한 시간 간격으로 업데이트를 확인하도록 연결했습니다.

[릴리스](https://github.com/KangUnMo/mac-remote-lid/releases/tag/v1.1.5) · [기준 커밋 e3880f4](https://github.com/KangUnMo/mac-remote-lid/commit/e3880f480b0683f99749e282be51de2ec050125d) · [이전 버전과 비교](https://github.com/KangUnMo/mac-remote-lid/compare/v1.1.4...v1.1.5)

## 1.1.4 — 2026-11-03

- 화면 꺼짐 방해·현재 설정·이전 설정 탭을 추가했습니다.
- 상세 정보 스크롤 영역의 테두리와 배경을 개선했습니다.
- SSH 접속 명령어 복사 버튼과 메뉴를 추가했습니다.

[릴리스](https://github.com/KangUnMo/mac-remote-lid/releases/tag/v1.1.4) · [기준 커밋 8551f9a](https://github.com/KangUnMo/mac-remote-lid/commit/8551f9a8a16f3a3dd7182bb28468af952bb39a3b) · [이전 버전과 비교](https://github.com/KangUnMo/mac-remote-lid/compare/v1.1.3...v1.1.4)

## 1.1.3 — 2026-11-02

- 화면 꺼짐 방해 앱 이름·PID·요청 사유를 창과 메뉴에 표시하고 주기 및 수동 갱신을 제공했습니다.
- 원격 모드가 켜진 상태에서 업데이트 전 복원이 막히는 문제를 수정했습니다.
- 인앱 업데이트에 ZIP 체크섬·번들 검증, 기존 앱 백업과 교체 실패 복구를 추가했습니다.

[릴리스](https://github.com/KangUnMo/mac-remote-lid/releases/tag/v1.1.3) · [기준 커밋 36ced03](https://github.com/KangUnMo/mac-remote-lid/commit/36ced039607e013b78c9a070534094f02d19400f) · [이전 버전과 비교](https://github.com/KangUnMo/mac-remote-lid/compare/v1.1.2...v1.1.3)

## 1.1.2 — 2026-10-26

- 로그인 시 자동 실행과 활성 IP 주소 복사를 추가했습니다.
- IOKit 전원 알림 이벤트 감지와 GitHub 릴리스 기반 인앱 업데이트를 추가했습니다.
- 터미널 한 줄 설치 스크립트와 웹 설치 안내를 추가했습니다.

[릴리스](https://github.com/KangUnMo/mac-remote-lid/releases/tag/v1.1.2) · [기준 커밋 60d0651](https://github.com/KangUnMo/mac-remote-lid/commit/60d065138e415b85bdf86889507e659e36347925) · [이전 버전과 비교](https://github.com/KangUnMo/mac-remote-lid/compare/v1.1.1...v1.1.2)

## 1.1.1 — 2026-10-26

- 메뉴 막대 도트로 잠자기 방지 켜짐·꺼짐·확인 불가 상태를 구분했습니다.
- SSH 접속 허용 설정으로 이동하는 메뉴와 최초 실행 차단 시 허용 안내를 추가했습니다.
- 다운로드 페이지 게시 및 화면 구성을 개선했습니다.

[릴리스](https://github.com/KangUnMo/mac-remote-lid/releases/tag/v1.1.1) · [기준 커밋 39d1f76](https://github.com/KangUnMo/mac-remote-lid/commit/39d1f76e84e1b8918a5d42209b79016cec1d2c59) · [이전 버전과 비교](https://github.com/KangUnMo/mac-remote-lid/compare/v1.1.0...v1.1.1)

## 1.1.0 — 2026-10-26

- 메뉴 막대 원격 모드 토글과 이전 전원 설정 복원을 제공했습니다.
- MacBook 배터리 경고와 배터리가 없는 데스크톱 Mac 분기를 구현했습니다.
- 인증 취소·부분 실패·손상된 복원 기록 처리와 다운로드 페이지를 제공했습니다.

[릴리스](https://github.com/KangUnMo/mac-remote-lid/releases/tag/v1.1.0) · [기준 커밋 6ca7c43](https://github.com/KangUnMo/mac-remote-lid/commit/6ca7c437c3ac0f3349f7864980796998351ef576)
