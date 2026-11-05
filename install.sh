#!/usr/bin/env bash
set -euo pipefail

# 원격지킴이 원클릭 설치 스크립트
# 사용법: curl -fsSL https://raw.githubusercontent.com/KangUnMo/mac-remote-lid/main/install.sh | bash

VERSION="1.1.7"
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

# 실행 중인 앱은 전원 설정 복원을 위해 사용자가 정상 종료해야 합니다.
check_not_running() {
    if pgrep -x "RemoteLid" > /dev/null 2>&1 || pgrep -x "원격지킴이" > /dev/null 2>&1; then
        echo "[오류] 원격 모드를 끄고 원격지킴이 메뉴의 종료를 선택한 뒤 다시 설치해 주세요." >&2
        exit 1
    fi
}
check_not_running

TMP_DIR="$(mktemp -d -t remote-lid-install-XXXXXX)"
WORK=""
MOVED=0
INSTALLED=0
USE_SUDO=0
install_command() {
    if [[ "$USE_SUDO" == 1 ]]; then sudo "$@"; else "$@"; fi
}
cleanup() {
    status=$?
    trap - EXIT
    if [[ "$status" -ne 0 && "$MOVED" == 1 ]]; then
        if { [[ "$INSTALLED" == 0 ]] || install_command rm -rf "$TARGET_APP"; } &&
            install_command mv "$BACKUP" "$TARGET_APP"; then
            echo "[안내] 기존 앱을 복구했습니다." >&2
        else
            echo "[오류] 기존 앱 복구에 실패했습니다. 백업을 보존했습니다: $BACKUP" >&2
            rm -rf "$TMP_DIR"
            exit "$status"
        fi
    elif [[ "$status" -ne 0 && "$INSTALLED" == 1 ]]; then
        install_command rm -rf "$TARGET_APP" || true
    fi
    if [[ -n "$WORK" ]]; then install_command rm -rf "$WORK"; fi
    rm -rf "$TMP_DIR"
    exit "$status"
}
trap cleanup EXIT

ZIP_PATH="${TMP_DIR}/remote-lid.zip"
CHECKSUM_PATH="${ZIP_PATH}.sha256"
echo -e "${BLUE}==> 설치 파일과 SHA-256 다운로드 중...${NC}"
curl --proto '=https' --proto-redir '=https' -fL --progress-bar "$DOWNLOAD_URL" -o "$ZIP_PATH"
curl --proto '=https' --proto-redir '=https' -fL --progress-bar "$DOWNLOAD_URL.sha256" -o "$CHECKSUM_PATH"
EXPECTED="$(awk 'NR == 1 {print $1}' "$CHECKSUM_PATH" | tr '[:upper:]' '[:lower:]')"
ACTUAL="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
if [[ ! "$EXPECTED" =~ ^[0-9a-f]{64}$ || "$EXPECTED" != "$ACTUAL" ]]; then
    echo "[오류] 설치 파일의 SHA-256이 일치하지 않습니다. 기존 앱을 유지했습니다." >&2
    exit 1
fi

ditto -xk "$ZIP_PATH" "$TMP_DIR"
SOURCE_APP="${TMP_DIR}/${APP_NAME}"
validate_app() {
    local app="$1"
    local plist="$app/Contents/Info.plist"
    if ! install_command test -d "$app" || ! install_command test -f "$plist" ||
        [[ "$(install_command /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" != personal.remotelid ]] ||
        [[ "$(install_command /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" != "$VERSION" ]] ||
        [[ "$(install_command /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")" != RemoteLid ]] ||
        ! install_command test -x "$app/Contents/MacOS/RemoteLid"; then
        echo "[오류] 앱 식별자, 버전 또는 실행 파일이 올바르지 않습니다." >&2
        return 1
    fi
    install_command codesign --verify --deep --strict "$app"
}
validate_app "$SOURCE_APP"

if [[ ! -w "$TARGET_DIR" ]]; then
    echo -e "${BOLD}${BLUE}==> ${TARGET_DIR} 쓰기 권한이 필요하여 관리자 비밀번호를 요청합니다.${NC}"
    USE_SUDO=1
fi
WORK="$(install_command mktemp -d "$TARGET_DIR/.RemoteLidInstall-XXXXXX")"
STAGED="$WORK/$APP_NAME"
BACKUP="$WORK/previous.app"
install_command ditto "$SOURCE_APP" "$STAGED"
validate_app "$STAGED"
# 기존 격리 해제 동작을 유지하되 다른 확장 속성은 보존합니다.
install_command xattr -dr com.apple.quarantine "$STAGED" 2>/dev/null || true
check_not_running
if [[ -e "$TARGET_APP" || -L "$TARGET_APP" ]]; then
    install_command mv "$TARGET_APP" "$BACKUP"
    MOVED=1
fi
install_command mv "$STAGED" "$TARGET_APP"
INSTALLED=1

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

echo -e "${GREEN}${BOLD}✓ 원격지킴이 v${VERSION} 설치가 완료되었습니다!${NC}"
echo "응용 프로그램 폴더(${TARGET_APP})에서 실행할 수 있습니다."
