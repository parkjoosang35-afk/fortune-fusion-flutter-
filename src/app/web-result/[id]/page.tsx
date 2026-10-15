// [2026-10, 앱·웹 분리 개발 전면 폐기] `/r/[id]`와 동일 처리 — RedirectToApp이
// 방문자를 바로 `https://sintong.kr/app/#/r/{id}`로 보낸다. 자세한 배경은
// `../../r/[id]/redirect-to-app.tsx` 상단 주석 참고.
import { generateMetadata as legacyMetadata } from '../../r/[id]/page';
import { RedirectToApp } from '../../r/[id]/redirect-to-app';
import type { Metadata } from 'next';

export const dynamic = 'force-dynamic';
type Props = { params: Promise<{ id: string }> };

// /r App Links와 겹치지 않는 웹 전용 주소(OG 메타는 /web-result/{id} URL을
// 가리킨다). 실제 사람 방문자는 RedirectToApp이 Flutter 앱으로 보낸다.
export async function generateMetadata(props: Props): Promise<Metadata> {
  const metadata = await legacyMetadata(props);
  const { id } = await props.params;
  const baseUrl = process.env.PUBLIC_BASE_URL ?? 'http://localhost:3000';
  return { ...metadata, openGraph: { ...metadata.openGraph, url: `${baseUrl}/web-result/${id}` } };
}
export default async function WebResultPage({ params }: Props) {
  const { id } = await params;
  return <RedirectToApp shareId={id} />;
}
