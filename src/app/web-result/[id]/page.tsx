// [웹 공유 "가짜 페이지" 근본 재설계 — 대표 긴급 지시, 2027-02]
// 과거에는 `/r/[id]`를 `webOnly: true`로 재호출해 "설치 유도 배너만 숨긴
// 동일한 가짜 렌더링"을 보여줬다. 이제 `/r/[id]`가 더 이상 자체 렌더링을
// 하지 않고(OG 전용 SSR + 즉시 Flutter 앱 리다이렉트로 전환됨 —
// `../../r/[id]/page.tsx`, `../../r/[id]/redirect-to-app.tsx` 참고) 이
// 페이지도 완전히 동일한 패턴을 그대로 쓴다. `/r/[id]`와 로직을 중복
// 작성하지 않기 위해 그 모듈을 그대로 재사용한다.
//
// [레거시 URL 호환] 이미 과거에 생성되어 유통된 `/web-result/{shareId}`
// 링크(`EnvConfig.webResultUrl()`이 만드는 주소)가 깨지지 않도록 이
// 경로 자체는 유지한다. 신규 공유 생성 로직(ShareService) 쪽 URL 생성
// 방식을 바꿀지는 별도 검토 대상이며, 이 파일은 "이미 발급된 링크가
// 열렸을 때의 동작"만 책임진다.
import SharedResultPage, { generateMetadata as legacyMetadata } from '../../r/[id]/page';
import type { Metadata } from 'next';

export const dynamic = 'force-dynamic';
type Props = { params: Promise<{ id: string }> };

export async function generateMetadata(props: Props): Promise<Metadata> {
  const metadata = await legacyMetadata(props);
  const { id } = await props.params;
  const baseUrl = process.env.PUBLIC_BASE_URL ?? 'http://localhost:3000';
  return { ...metadata, openGraph: { ...metadata.openGraph, url: `${baseUrl}/web-result/${id}` } };
}

export default function WebResultPage(props: Props) {
  return SharedResultPage(props);
}
