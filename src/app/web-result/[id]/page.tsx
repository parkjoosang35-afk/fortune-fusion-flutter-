// [웹 공유 완결 — REQ-21/23, 2027-02 복원] `/r/[id]`와 동일한 데이터·렌더
// 로직(service-result-view 기반 ServiceResultView)을 그대로 재사용하되,
// `webOnly: true`로 호출해 설치 유도 배너와 "앱에서 전체 결과 보기" 버튼만
// 숨긴다. 이 라우트는 웹 공유 버튼(`WebShareButton`)이 생성하는 링크
// (`{origin}/web-result/{shareId}`)의 도착지이며, 앱의 App Links 대상인
// `/r/{shareId}`와는 분리된 별도 URL이다(AC-21-1~3).
//
// [절대 금지] 리다이렉트하지 않는다 — 이 페이지 자체가 웹에서 완결된
// 콘텐츠를 보여준다. fortunefusion:// 호출도, window.location.replace로
// Flutter 앱(또는 앱스토어)으로 이동시키는 어떤 코드도 여기 있으면 안 된다
// (2027-02 "앱·웹 공유 최종 근본 수정" 대표 지시서 — 웹 공유는 앱 딥링크로
// 변환하지 않는다).
//
// [과거 경위] 2026-10-19(7d5ed92)에 `/r/[id]`가 통째로 "OG 전용 SSR + 즉시
// Flutter 앱 리다이렉트"로 바뀌면서 이 파일도 같은 패턴(`RedirectToApp`
// 재사용)으로 전환되었다. 그 결과 "웹 전용"이어야 할 이 주소가 사람이 열면
// 무조건 `https://sintong.kr/app/#/r/{id}`로 튕기는 상태가 되어 있었다 —
// 이번 작업에서 48af7ff(r/g/w 웹 완결형 콘텐츠 복원) 시점의 원래 구현을
// 그대로 되돌린다.
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
