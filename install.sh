#!/usr/bin/env bash
set -euo pipefail

# 원격지킴이 원클릭 설치 스크립트
# 사용법: curl -fsSL https://raw.githubusercontent.com/KangUnMo/mac-remote-lid/main/install.sh | bash

VERSION="1.1.2"
REPO="KangUnMo/mac-remote-lid"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}/remote-lid-${VERSION}-arm64.zip"
APP_NAME="원격지킴이.app"
TARGET_DIR="/Applications"
TARGET_APP="${TARGET_DIR}/${APP_NAME}"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}==> 원격지킴이 v${VERSION} 설치를 시작합니다...${NC}"

# 1. OS 확인
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${RED}[오류] 원격지킴이는 macOS 전용 애플리케이션입니다.${NC}" >&2
    exit 1
fi

# 2. 아키텍처 확인 (Apple Silicon)
ARCH="$(uname -m)"
if [[ "${ARCH}" != "arm64" ]]; then
    echo -e "${RED}[오류] 현재 버전은 Apple Silicon(M1/M2/M3/M4 등) 전용입니다. (현재 시스템: ${ARCH})${NC}" >&2
    exit 1
fi

# 3. 임시 디렉토리 생성
TMP_DIR="$(mktemp -d -t remote-lid-install-XXXXXX)"
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

ZIP_PATH="${TMP_DIR}/remote-lid.zip"

# 4. 다운로드
echo -e "${BLUE}==> 설치 파일 다운로드 중...${NC}"
if ! curl -fL --progress-bar "${DOWNLOAD_URL}" -o "${ZIP_PATH}"; then
    echo -e "${RED}[오류] 다운로드에 실패했습니다. 네트워크 상태나 릴리즈 URL을 확인해 주세요.${NC}" >&2
    exit 1
fi

# 5. 압축 해제
echo -e "${BLUE}==> 압축 해제 중...${NC}"
ditto -xk "${ZIP_PATH}" "${TMP_DIR}"

SOURCE_APP="${TMP_DIR}/${APP_NAME}"
if [[ ! -d "${SOURCE_APP}" ]]; then
    # 혹시 폴더 안에 있는 경우 검색
    SOURCE_APP="$(find "${TMP_DIR}" -name "${APP_NAME}" -type d -maxdepth 2 | head -n 1)"
fi

if [[ -z "${SOURCE_APP}" || ! -d "${SOURCE_APP}" ]]; then
    echo -e "${RED}[오류] 압축 해제된 앱을 찾을 수 없습니다.${NC}" >&2
    exit 1
fi

# 6. 기존 실행 중인 앱 종료
if pgrep -x "RemoteLid" > /dev/null 2>&1 || pgrep -x "원격지킴이" > /dev/null 2>&1; then
    echo -e "${BLUE}==> 실행 중인 기존 원격지킴이를 종료합니다...${NC}"
    killall "RemoteLid" 2>/dev/null || true
    killall "원격지킴이" 2>/dev/null || true
    sleep 1
fi

# 7. 응용 프로그램 폴더로 복사
echo -e "${BLUE}==> ${TARGET_DIR} 폴더로 앱 설치 중...${NC}"
if [[ -w "${TARGET_DIR}" ]]; then
    rm -rf "${TARGET_APP}"
    cp -R "${SOURCE_APP}" "${TARGET_APP}"
else
    echo -e "${BOLD}${BLUE}==> ${TARGET_DIR} 쓰기 권한이 필요하여 관리자 비밀번호를 요청합니다.${NC}"
    sudo rm -rf "${TARGET_APP}"
    sudo cp -R "${SOURCE_APP}" "${TARGET_APP}"
fi

# 8. 게이트키퍼 격리 속성 제거 (Gatekeeper quarantine 해제)
echo -e "${BLUE}==> 보안 격리(Gatekeeper) 속성 해제 중...${NC}"
if [[ -w "${TARGET_APP}" ]]; then
    xattr -cr "${TARGET_APP}" 2>/dev/null || true
else
    sudo xattr -cr "${TARGET_APP}" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}${BOLD}✓ 원격지킴이 v${VERSION} 설치가 완료되었습니다!${NC}"
echo -e "${BLUE}응용 프로그램 폴더(${TARGET_APP})에서 실행하거나 아래 명령어로 바로 열 수 있습니다:${NC}"
echo -e "${BOLD}open \"${TARGET_APP}\"${NC}"
echo ""

# 자동 실행 옵션 안내
if [[ -c /dev/tty ]]; then
    read -r -p "지금 바로 원격지킴이를 실행할까요? (Y/n): " RUN_NOW < /dev/tty || RUN_NOW="Y"
    RUN_NOW=${RUN_NOW:-Y}
    if [[ "${RUN_NOW}" =~ ^[Yy]$ ]]; then
        open "${TARGET_APP}"
    fi
else
    open "${TARGET_APP}"
fi
