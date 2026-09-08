// 귀인지도 "웹에서 내 지도 관리" 페이지 — 사용자 명시 요구 "웹에서도 소유자가
// 삭제 가능"을 구현하기 위해 신설.
//
// [배경] 이 프로젝트는 두 가지 인증 체계가 완전히 분리되어 있었다:
//   1) 관리자(admin) 로그인(src/app/login/page.tsx) — HttpOnly Cookie, CMS용.
//   2) 일반회원(지도 소유자) 인증(src/lib/user-auth.ts) — Bearer JWT,
//      지금까지 Flutter 앱만 SharedPreferences에 토큰을 저장해 사용했고
//      웹 브라우저에서 이 토큰을 획득/저장하는 UI는 전혀 없었다.
// 이 페이지가 그 공백을 메운다 — 기존 `/api/public/auth/login`(이메일+
// 비밀번호, Flutter가 쓰는 것과 동일한 API)을 그대로 재사용해 로그인하고,
// 받은 JWT를 `localStorage`에 저장해 이후 `Authorization: Bearer` 헤더로
// `/api/public/guinji/maps/me`(내 지도 조회) · `DELETE .../members/{id}`
// (멤버 삭제)를 호출한다. 새로운 인증 체계를 만들지 않고 기존 것을
// 웹에 연결하는 최소 구현이다.
//
// [삭제 방식] 완전 삭제가 아니라 소프트 삭제(status="removed")다. 삭제된
// 멤버는 이 목록에서 즉시 사라지고, 초대 랜딩페이지(/g/[token])의 관계
// 집계·그래프에서도 제외된다(join/route.ts, page.tsx가 이미 member.status
// ="active" 필터를 적용하도록 수정됨).
"use client";

import { useCallback, useEffect, useState } from "react";

const TOKEN_KEY = "sintong_user_token";

type MapMember = {
  memberId: string;
  name: string;
  solarLunar: string;
  birthDate: string;
  birthTime: string | null;
  birthTimeMissing: boolean;
  joined: boolean;
};

type MapRelationship = {
  memberId: string;
  relationType: string;
  chemistryScore: number;
};

type MyMapData = {
  map: { mapId: string; name: string; token: string; createdAt: string };
  members: MapMember[];
  relationships: MapRelationship[];
};

function getStoredToken(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(TOKEN_KEY);
}

export default function MyGuinjiManagePage() {
  // [SSR/hydration 안전] localStorage는 브라우저에만 있어 SSR 시점엔 항상
  // null이어야 hydration mismatch가 나지 않는다 — 그래서 초기값은 null로
  // 시작하고, mount 이후 useEffect에서 실제 값을 읽어 세팅한다.
  const [token, setToken] = useState<string | null>(null);
  const [checkingToken, setCheckingToken] = useState(true);
  const [data, setData] = useState<MyMapData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  // 로그인 폼 상태
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loginError, setLoginError] = useState<string | null>(null);
  const [loginLoading, setLoginLoading] = useState(false);

  useEffect(() => {
    // [react-hooks/set-state-in-effect 예외] 이 effect는 "외부 시스템
    // (localStorage)과 동기화"하는 정확한 용례라 규칙이 우려하는 패턴
    // (파생 state를 effect로 복제)에 해당하지 않는다 — mount 시 1회만
    // 실행되고, localStorage 값 자체가 바뀌는 걸 구독하지도 않는다.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setToken(getStoredToken());
    setCheckingToken(false);
  }, []);

  const loadMap = useCallback(async (authToken: string) => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/public/guinji/maps/me", {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      const json = await res.json();
      if (res.status === 401) {
        // 토큰 만료/무효 — 로그아웃 처리.
        window.localStorage.removeItem(TOKEN_KEY);
        setToken(null);
        setError("로그인이 만료되었어요. 다시 로그인해 주세요.");
        return;
      }
      if (!json.success) {
        setError(json.error ?? "지도 조회에 실패했어요.");
        return;
      }
      setData(json.data);
    } catch {
      setError("네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // [react-hooks/set-state-in-effect 예외] loadMap 내부에서 fetch 완료
    // 후 setState하는 것은 "비동기 외부 시스템(API) 응답 반영"이지
    // "effect body에서 즉시 파생 state 계산"이 아니다 — 규칙의 의도(동기
    // 렌더 중 캐스케이드)에 해당하지 않는 정상적인 데이터 로딩 패턴이다.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (token) loadMap(token);
  }, [token, loadMap]);

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoginError(null);
    setLoginLoading(true);
    try {
      const res = await fetch("/api/public/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const json = await res.json();
      if (!json.success) {
        setLoginError(json.error ?? "로그인에 실패했어요.");
        return;
      }
      const newToken: string = json.data.token;
      window.localStorage.setItem(TOKEN_KEY, newToken);
      setToken(newToken);
    } catch {
      setLoginError("네트워크 오류가 발생했어요. 잠시 후 다시 시도해 주세요.");
    } finally {
      setLoginLoading(false);
    }
  }

  function handleLogout() {
    window.localStorage.removeItem(TOKEN_KEY);
    setToken(null);
    setData(null);
  }

  async function handleDelete(memberId: string, name: string) {
    if (!token || !data) return;
    const ok = window.confirm(`"${name}" 님을 지도에서 삭제할까요?\n삭제하면 관계·랭킹 집계에서도 제외돼요.`);
    if (!ok) return;

    setDeletingId(memberId);
    try {
      const res = await fetch(
        `/api/public/guinji/maps/${data.map.mapId}/members/${memberId}`,
        { method: "DELETE", headers: { Authorization: `Bearer ${token}` } }
      );
      const json = await res.json();
      if (!json.success) {
        window.alert(json.error ?? "삭제에 실패했어요.");
        return;
      }
      // 목록에서 즉시 제거(재조회 없이 낙관적 갱신).
      setData((prev) =>
        prev
          ? {
              ...prev,
              members: prev.members.filter((m) => m.memberId !== memberId),
              relationships: prev.relationships.filter((r) => r.memberId !== memberId),
            }
          : prev
      );
    } catch {
      window.alert("네트워크 오류로 삭제에 실패했어요. 잠시 후 다시 시도해 주세요.");
    } finally {
      setDeletingId(null);
    }
  }

  const relationByMemberId = new Map((data?.relationships ?? []).map((r) => [r.memberId, r]));

  if (checkingToken) {
    return <div className="mx-auto max-w-[440px] px-5 py-10 text-center text-sm text-[#6E5A54]">불러오는 중...</div>;
  }

  return (
    <div className="min-h-screen bg-[#FBF7EF] pb-10">
      <div className="mx-auto w-full max-w-[440px] px-5 pt-8">
        <h1 className="mb-1 text-xl font-bold text-[#2A2438]">내 귀인지도 관리</h1>
        <p className="mb-6 text-[13px] text-[#6E5A54]">
          이름이나 생년월일을 잘못 넣은 멤버는 여기서 삭제할 수 있어요.
        </p>

        {!token && (
          <form
            onSubmit={handleLogin}
            className="space-y-3 rounded-2xl border border-[#E8DDD0] bg-white/85 p-5"
          >
            <div>
              <label className="mb-1 block text-[12px] text-[#6E5A54]">이메일</label>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full rounded-xl border border-[#E8DDD0] px-3 py-2 text-sm outline-none focus:border-[#C99B7F]"
                placeholder="회원가입한 이메일"
              />
            </div>
            <div>
              <label className="mb-1 block text-[12px] text-[#6E5A54]">비밀번호</label>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full rounded-xl border border-[#E8DDD0] px-3 py-2 text-sm outline-none focus:border-[#C99B7F]"
                placeholder="비밀번호"
              />
            </div>
            {loginError && <p className="text-[12px] text-red-500">{loginError}</p>}
            <button
              type="submit"
              disabled={loginLoading}
              className="w-full rounded-xl bg-[#A6795E] py-2.5 text-sm font-semibold text-white disabled:opacity-60"
            >
              {loginLoading ? "로그인 중..." : "로그인"}
            </button>
            <p className="pt-1 text-center text-[11px] text-[#A08C82]">
              신통방통 앱에서 사용하는 계정으로 로그인해 주세요.
            </p>
          </form>
        )}

        {token && (
          <div>
            <div className="mb-4 flex items-center justify-between">
              <span className="text-[12px] text-[#A08C82]">
                {data ? `${data.map.name}` : ""}
              </span>
              <button
                onClick={handleLogout}
                className="text-[12px] text-[#A6795E] underline"
              >
                로그아웃
              </button>
            </div>

            {loading && <p className="text-center text-sm text-[#6E5A54]">불러오는 중...</p>}
            {error && <p className="mb-3 text-center text-sm text-red-500">{error}</p>}

            {data && data.members.length === 0 && !loading && (
              <p className="text-center text-sm text-[#6E5A54]">아직 지도에 참여한 멤버가 없어요.</p>
            )}

            {data && data.members.length > 0 && (
              <ul className="space-y-2">
                {data.members.map((m) => {
                  const rel = relationByMemberId.get(m.memberId);
                  return (
                    <li
                      key={m.memberId}
                      className="flex items-center justify-between rounded-2xl border border-[#E8DDD0] bg-white/85 px-4 py-3"
                    >
                      <div>
                        <p className="text-sm font-semibold text-[#2A2438]">{m.name}</p>
                        <p className="text-[11px] text-[#A08C82]">
                          {m.birthDate}
                          {m.birthTimeMissing ? " (시간모름)" : m.birthTime ? ` ${m.birthTime}` : ""}
                          {rel ? ` · 케미 ${rel.chemistryScore}` : ""}
                        </p>
                      </div>
                      <button
                        onClick={() => handleDelete(m.memberId, m.name)}
                        disabled={deletingId === m.memberId}
                        className="rounded-full border border-red-200 px-3 py-1.5 text-[12px] text-red-500 disabled:opacity-50"
                      >
                        {deletingId === m.memberId ? "삭제 중..." : "삭제"}
                      </button>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
