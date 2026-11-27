#!/usr/bin/env bash
# build_local.sh — 로컬/테스트용 Flutter 웹 빌드 전용 스크립트.
#
# [배경 — 운영 서버 오접속 재발 방지]
# EnvConfig.adminApiBaseUrl의 기본값은 운영 서버(https://sintong.kr)다.
# 로컬 admin_web(dev.db)을 대상으로 테스트하려면 빌드 시 반드시
# --dart-define=ADMIN_API_BASE_URL=http://localhost:3100 을 넘겨야 하는데,
# 이 플래그를 빠뜨린 채로 빌드해 버리는 실수가 이미 두 번 발생했다
# (캡처/검수 결과가 실제로는 운영 서버 응답이었던 사고).
#
# 이 스크립트는 그 실수를 구조적으로 막기 위한 "단일 진입점"이다 —
# 로컬 테스트 빌드는 항상 이 스크립트 하나로만 실행하고, 수동으로
# `flutter build web ...`을 직접 치지 않는다. ADMIN_API_BASE_URL은 아래에서
# 항상 http://localhost:3100으로 고정되며, 혹시 외부 환경변수로 다른 값을
# 넘겨도 무시하고 로컬 주소를 강제한다(실수로 운영 주소가 섞여 들어오는
# 것을 막기 위함 — 다른 포트/주소가 필요하면 이 스크립트 자체를 수정할 것).
#
# 사용법:
#   ./build_local.sh            # 기본 release 빌드
#   ./build_local.sh --debug    # 디버그 빌드(화면 구석 서버주소 표시 라벨 포함)
#
# 빌드가 끝나면 build/web 디렉터리가 생성된다. 프리뷰 서버 기동은 별도
# (예: 샌드박스의 ${FLUTTER_SERVE} 참고).

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# 로컬 admin_web(dev.db) 대상 주소 — 항상 고정. 운영 서버로 바뀌는 것을
# 원천 차단하기 위해 외부에서 ADMIN_API_BASE_URL을 주입해도 무시한다.
LOCAL_ADMIN_API_BASE_URL="http://localhost:3100"

BUILD_MODE="release"
if [[ "${1:-}" == "--debug" ]]; then
  BUILD_MODE="debug"
fi

echo "============================================================"
echo " build_local.sh — 로컬 테스트 빌드 (${BUILD_MODE})"
echo "   ADMIN_API_BASE_URL = ${LOCAL_ADMIN_API_BASE_URL}  (항상 고정)"
echo "============================================================"

flutter build web --${BUILD_MODE} \
  --dart-define=ADMIN_API_BASE_URL="${LOCAL_ADMIN_API_BASE_URL}" \
  --dart-define=flutter.inspector.structuredErrors=false \
  --dart-define=debugShowCheckedModeBanner=false

echo "============================================================"
echo " 빌드 완료: build/web"
echo " 접속 대상 서버: ${LOCAL_ADMIN_API_BASE_URL}"
if [[ "${BUILD_MODE}" == "debug" ]]; then
  echo " 디버그 빌드이므로 앱 화면 구석에 서버 주소 라벨이 표시됩니다."
fi
echo "============================================================"
