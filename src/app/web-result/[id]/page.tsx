// [웹 공유 완결 — REQ-21/23] `/r/[id]`와 동일한 데이터·렌더 로직(service-result-view
// 기반 ServiceResultView)을 그대로 재사용하되, `webOnly: true`로 호출해 설치
// 유도 배너와 "앱에서 전체 결과 보기" 버튼만 숨긴다. 이 라우트는 웹 공유
// 버튼(`WebShareButton`)이 생성하는 링크(`{origin}/web-result/{shareId}`)의
// 도착지이며, 앱의 App Links 대상인 `/r/{shareId}`와는 분리된 별도 URL이다
// (AC-21-1~3). 리다이렉트하지 않는다 — 이 페이지 자체가 웹에서 완결된
// 콘텐츠를 보여준다.
import SharedResultPage, { generateMetadata as legacyMetadata } from '../../r/[id]/page';
import type { Metadata } from 'next';

export const dynamic = 'force-dynamic';
type Props = { params: Promise<{ id: string }> };

// /r App Links와 겹치지 않는 웹 전용 주소. 리다이렉트하지 않는다.
export async function generateMetadata(props: Props): Promise<Metadata> {
  const metadata = await legacyMetadata(props);
  const { id } = await props.params;
  const baseUrl = process.env.PUBLIC_BASE_URL ?? 'http://localhost:3000';
  return { ...metadata, openGraph: { ...metadata.openGraph, url: `${baseUrl}/web-result/${id}` } };
}
export default function WebResultPage(props: Props) {
  return SharedResultPage({ ...props, webOnly: true });
}
