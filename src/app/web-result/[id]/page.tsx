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
