// [프리패스/배너 광고소스 클릭 이동 URL 자동 추출]
// 관리자가 CMS 배너를 adType='script'(쿠팡파트너스 등 제휴사 임베드 코드)로
// 등록할 때는 linkUrl을 별도로 입력하지 않는 경우가 많다(제휴사가 발급하는
// 코드에는 이미 자체 클릭 링크가 내장되어 있기 때문). 이 경우 "쿠팡 방문하기"
// 버튼이 이동할 URL이 없어 클릭해도 아무 반응이 없는 문제가 발생한다.
//
// 이 유틸은 관리자에게 별도 입력을 요구하지 않고, adScript 문자열 안에서
// 실제 이동 가능한 URL을 자동으로 찾아낸다:
//   1) <iframe src="...">  — 쿠팡파트너스 위젯형 배너의 표준 발급 형태
//   2) <a href="...">      — 앵커 태그로 발급되는 경우
//   3) 순수 URL 문자열만 저장된 경우 (예: "https://link.coupang.com/a/xxx")
//   4) 위 패턴에 걸리지 않으면 문자열 내 첫 http(s) URL을 그대로 사용
export function extractLinkFromAdScript(adScript: string | null | undefined): string | null {
  if (!adScript) return null;
  const trimmed = adScript.trim();
  if (!trimmed) return null;

  const srcMatch = trimmed.match(/\bsrc\s*=\s*["']([^"']+)["']/i);
  if (srcMatch && /^https?:\/\//i.test(srcMatch[1])) {
    return srcMatch[1];
  }

  const hrefMatch = trimmed.match(/\bhref\s*=\s*["']([^"']+)["']/i);
  if (hrefMatch && /^https?:\/\//i.test(hrefMatch[1])) {
    return hrefMatch[1];
  }

  if (/^https?:\/\/\S+$/i.test(trimmed)) {
    return trimmed;
  }

  const urlMatch = trimmed.match(/https?:\/\/[^\s"'<>]+/i);
  return urlMatch ? urlMatch[0] : null;
}
