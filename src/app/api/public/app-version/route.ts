// [DEV-2026-001 작업3-5-1] 앱 버전 체크 API — Flutter 앱이 부팅 시점에
// 호출하여 "지금 설치된 버전으로 서비스를 계속 이용해도 되는지"를 판단하는
// 근거를 제공한다.
//
// [설계] 05_Admin_System_Design.md §3.11 system_settings(key-value) 테이블을
// 그대로 재사용한다(새 테이블/마이그레이션 불필요, ADD ONLY 원칙에도 부합
// — 기존 스키마를 전혀 변경하지 않는다). 다음 4개 key로 Android 플랫폼
// 버전 정책을 관리한다:
//   - latest_version_code_android : 최신 버전의 versionCode(정수)
//   - min_version_code_android    : 이 미만이면 강제 업데이트 대상(정수)
//   - update_url_android          : "업데이트" 버튼이 열 URL(플레이스토어 등)
//   - update_notice               : 팝업에 표시할 안내 문구(선택)
//
// [기존 min_app_version_android(semver 문자열, "2.4.0")와의 관계] 기존 값은
// 05단계 설계서에 존재했으나 실제로 어떤 코드도 읽지 않는 죽은 설정이었다
// (grep 결과 actions/system-settings.ts CRUD 화면 외 참조 0건). 이번에
// versionCode(정수) 기반의 새 key를 추가하는 이유: Android 빌드시스템은
// build.gradle.kts에서 versionCode(정수, flutter.versionCode)를 실제 비교
// 기준으로 쓰고, semver 문자열 비교는 "1.10.0" vs "1.9.0"처럼 문자열 사전식
// 비교 시 오판(1.10.0 < 1.9.0으로 잘못 판정)이 나므로 정수 비교가 더
// 안전하다. 기존 semver key는 삭제하지 않고 그대로 둔다(ADD ONLY).
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

// system_settings.value는 JSON.stringify로 저장되어 있으므로(예: 정수 "12"
// -> value 컬럼에 "12" 문자열, 문자열 "url" -> value 컬럼에 "\"url\""),
// 안전하게 JSON.parse 후 폴백한다.
function parseSettingValue(raw: string | undefined, fallback: unknown): unknown {
  if (raw === undefined) return fallback;
  try {
    return JSON.parse(raw);
  } catch {
    return raw; // 순수 문자열이 그대로 저장된 레거시 데이터 대비
  }
}

export async function GET() {
  const keys = [
    "latest_version_code_android",
    "min_version_code_android",
    "update_url_android",
    "update_notice",
  ];

  const rows = await prisma.systemSetting.findMany({
    where: { key: { in: keys }, deletedAt: null },
  });
  const map = new Map(rows.map((r) => [r.key, r.value]));

  const latestVersionCode = Number(
    parseSettingValue(map.get("latest_version_code_android"), 1)
  );
  const minVersionCode = Number(
    parseSettingValue(map.get("min_version_code_android"), 1)
  );
  const updateUrl = String(
    parseSettingValue(
      map.get("update_url_android"),
      "https://play.google.com/store/apps"
    )
  );
  const noticeRaw = parseSettingValue(map.get("update_notice"), "");
  const notice = noticeRaw ? String(noticeRaw) : null;

  return NextResponse.json(
    {
      success: true,
      data: {
        platform: "android",
        latestVersionCode,
        minVersionCode,
        updateUrl,
        notice,
      },
    },
    {
      headers: {
        // 버전 정책은 앱 부팅마다 항상 최신값을 확인해야 하므로 캐시 금지
        // (DEV-2026-001 작업2-4-1 캐시차단 원칙과 동일하게 적용).
        "Cache-Control": "no-store, no-cache, must-revalidate",
        "Access-Control-Allow-Origin": "*",
      },
    }
  );
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
