#!/bin/bash
# =============================================================================
# 배포 전 갭 자동 감지 스크립트 ("빌드는 됐는데 운영에 반영 안 됨" 재발 방지)
#
# [배경 - 2026-11-06] 신당(THE SHRINE) v3 백엔드가 로컬에서는 완성됐지만
# 운영 서버(sintong.kr)에 전혀 배포되지 않은 채 "완료"로 간주되어, Flutter
# 앱 프리뷰에서 전체 기능이 비어있는 상태(API 404)로 방치된 사건이 있었다.
# 원인은 두 가지였다:
#   1) git 커밋은 했지만 실제 rsync+migrate deploy를 실행하지 않음
#   2) schema.prisma는 변경했지만 `prisma db push`로만 로컬 반영하고
#      정식 마이그레이션 파일(prisma/migrations/)을 생성하지 않음
#      → 운영에 `prisma migrate deploy`를 돌려도 새 테이블이 생성되지 않음
#
# 이 스크립트는 "기능 완료"를 선언하기 전, 또는 배포 직전에 실행해 두 가지
# 갭을 자동으로 감지한다. 실패(❌)가 하나라도 있으면 배포 전 반드시 해소할 것.
#
# 사용법: bash scripts/check_deploy_readiness.sh
# =============================================================================
set -uo pipefail

SSH_KEY="/home/user/.ssh_keys/sintong_server.pem"
SSH_HOST="ubuntu@sintong.kr"
cd "$(dirname "$0")/.."

FAIL=0

echo "════════════════════════════════════════════════════════════════"
echo " 1) Git 배포 갭 체크: 로컬 HEAD vs 운영 서버 실제 배포 커밋"
echo "════════════════════════════════════════════════════════════════"
LOCAL_HEAD=$(git rev-parse --short HEAD)
PROD_VERSION=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_HOST" \
  "cat /var/www/version_info/server_version.txt 2>/dev/null" | grep -oP 'commit=\K[a-f0-9]+' || echo "UNKNOWN")

echo "로컬 HEAD:        $LOCAL_HEAD"
echo "운영 배포 커밋:   $PROD_VERSION"

if [ "$PROD_VERSION" == "UNKNOWN" ]; then
  echo "⚠️  경고: 운영 서버 버전 메타데이터를 읽을 수 없습니다(SSH 실패 또는 파일 없음)."
elif [ "$LOCAL_HEAD" == "$PROD_VERSION" ]; then
  echo "✅ 로컬과 운영이 동일 커밋입니다."
else
  BEHIND_COUNT=$(git rev-list --count "$PROD_VERSION..$LOCAL_HEAD" 2>/dev/null || echo "?")
  echo "❌ 운영 서버가 로컬보다 $BEHIND_COUNT 커밋 뒤처져 있습니다!"
  echo "   운영에 아직 반영되지 않은 커밋 목록:"
  git log --oneline "$PROD_VERSION..$LOCAL_HEAD" 2>/dev/null | sed 's/^/     /'
  echo "   → 기능을 '완료'로 간주하기 전에 deploy_admin_web_to_prod.sh 실행 필요."
  FAIL=1
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " 2) Prisma 마이그레이션 드리프트 체크: schema.prisma vs 마이그레이션 파일"
echo "════════════════════════════════════════════════════════════════"
echo "(schema.prisma에 모델/필드를 추가했지만 정식 마이그레이션 파일 생성을"
echo " 깜빡한 경우 — 'prisma migrate deploy'가 운영에서 조용히 아무 것도"
echo " 만들지 않아 런타임에 'no such table' 에러로만 드러나는 패턴을 감지)"
echo ""

DIFF_OUTPUT=$(npx prisma migrate diff --from-migrations prisma/migrations --to-schema prisma/schema.prisma --script 2>&1 | grep -v "^Loaded Prisma config\|^$\|Update available\|major-version-upgrade\|npm i --save-dev\|npm i @prisma\|pris.ly\|^┌\|^│\|^└")

if [ -z "$DIFF_OUTPUT" ]; then
  echo "✅ drift 없음 — schema.prisma와 마이그레이션 이력이 완전히 일치합니다."
else
  echo "⚠️  schema.prisma와 마이그레이션 파일 사이에 차이(drift)가 발견되었습니다:"
  echo "---"
  echo "$DIFF_OUTPUT" | head -30
  echo "---"
  echo ""
  echo "   주의: 이 출력에는 과거부터 알려진 미해결 drift(예: users.google_id/"
  echo "   kakao_id, wishes 일부 컬럼 — 이미 운영 DB에 db push로 존재하지만"
  echo "   마이그레이션 파일만 없는 케이스)가 포함되어 있을 수 있습니다."
  echo "   → 이번에 새로 추가한 모델/필드가 이 출력에 포함되어 있다면,"
  echo "     반드시 수동으로 안전한 마이그레이션 파일을 작성하고(diff를"
  echo "     그대로 적용하지 말 것 — DROP/컬럼누락 위험), 운영 DB 사본에"
  echo "     migrate deploy로 먼저 검증한 뒤 배포할 것."
  echo "   → 이미 알려진 기존 drift만 보인다면 무시 가능(각 마이그레이션"
  echo "     파일 주석에 기록된 선례 참조: 20261025000000, 20261103150500)."
  FAIL=1
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
if [ "$FAIL" -eq 1 ]; then
  echo " ❌ 점검 결과: 배포 갭이 발견되었습니다. 위 내용을 확인 후 진행하세요."
  echo "════════════════════════════════════════════════════════════════"
  exit 1
else
  echo " ✅ 점검 결과: 배포 갭 없음. 로컬 작업이 운영과 일치합니다."
  echo "════════════════════════════════════════════════════════════════"
  exit 0
fi
