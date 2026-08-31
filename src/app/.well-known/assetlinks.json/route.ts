import { NextResponse } from "next/server";

// Android App Links 검증용 엔드포인트.
// Next.js가 public/ 폴더 안의 dotfile(.well-known 등)을 정적으로 서빙하지 않는
// 알려진 제약이 있어, API Route로 직접 응답한다.
// 참고: https://sintong.kr/.well-known/assetlinks.json 로 접근 가능해야
// Android가 앱-도메인 소유권을 자동 검증(autoVerify)할 수 있다.
const ASSET_LINKS = [
  {
    relation: ["delegate_permission/common.handle_all_urls"],
    target: {
      namespace: "android_app",
      package_name: "com.fortunefusion.fortune",
      sha256_cert_fingerprints: [
        "98:85:8E:63:95:58:51:4C:13:C1:07:71:10:65:2F:86:52:2E:ED:34:8A:B8:43:72:5D:0D:45:1F:8C:F3:E1:3D",
      ],
    },
  },
];

export function GET() {
  return NextResponse.json(ASSET_LINKS, {
    headers: {
      "Content-Type": "application/json",
    },
  });
}
