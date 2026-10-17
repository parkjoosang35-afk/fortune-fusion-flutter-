"use client";

// ═══════════════════════════════════════════════════════════════════════════
// [쿠폰 디자인 스튜디오 4단계 — 작업순서3] React 에디터 본체
//
// 참고: 02f_4단계-에디터-골격.md의 골격(BokjuCouponDesignStudio.skeleton.tsx)을
// 기반으로 하되, 실제 저장소 타입/엔드포인트와 맞지 않던 지점을 바로잡았다
// (아래 "골격 대비 정정" 참고 — 투명성을 위해 남겨둔다).
//
// ── §0-H 위반금지 3원칙 ──────────────────────────────────────────────────
//   1) renderer.ts 를 import 하지 않는다(sharp가 클라이언트 번들에 끌려들어감)
//   2) 저장 좌표는 언제나 캔버스 공간(0~W/0~H). 화면 축소는 CSS
//      transform:scale()로만 한다 — moveElement()가 받는 x,y도 항상
//      캔버스 공간 값이다(드래그 핸들에서 스케일을 나눠 역산한다).
//   3) 미리보기 샘플값(PREVIEW_SAMPLE)은 저장 payload에 전혀 섞이지 않는다
//      — PUT 요청 body는 `{ layout, note }`뿐이다.
//
// ── 골격(02f) 대비 정정 3건(실제 타입과 교차 확인한 결과) ──────────────────
//   ① LayoutIssue 필드명은 `severity`가 아니라 `level`('error'|'warn').
//   ② buildSvg()는 (layout, ctx: SvgRenderContext, opts: BuildSvgOptions)
//      2-인자 분리 시그니처다 — 골격처럼 campaign 필드를 ctx 하나에
//      펀펀하게 섞어 넣으면 타입 에러가 난다. ctx.campaign.validFrom/validTo는
//      Date 객체여야 한다(ISO 문자열이면 QR 자리 텍스트가 깨진다).
//   ③ 실제 PUT 경로는 `/api/admin/bokju-coupons/campaigns/:id/design`이다
//      (골격의 `/api/admin/bokju-coupon-campaigns/...` 는 오타 — 복수형
//      `bokju-coupons`가 맞다. route.ts 실파일 경로로 직접 확인).
//   ④ GET design 응답은 `{layout, currentRevisionId, currentRevisionNo}`
//      이지 골격이 가정한 `{layout, currentDesignRevisionId, revisions}`가
//      아니다 — 리비전 목록은 별도 엔드포인트(.../design/revisions)에서 온다.
//   ⑤ design-catalog 응답에는 `canvases` 필드가 없다(studio-api.ts의
//      DesignCatalog 인터페이스 실측) — 캔버스 프리셋은 layout.ts의
//      CANVAS_PRESETS를 그대로 쓴다(카탈로그 API를 거치지 않음, §0-G 필수3과
//      무관 — CANVAS_PRESETS는 애초에 "카탈로그"가 아니라 상수 좌표값이라
//      서버/클라이언트 양쪽이 같은 모듈에서 직접 import하는 것이 더 안전하다).
//
// ── §0-K QR 관련 정정 반영 ───────────────────────────────────────────────
//   클라이언트의 실시간 캔버스는 브라우저 `qrcode`(lib/browser.js, canvas
//   인코더)로 QR을 그리고, 실제 발행 이미지는 서버 renderer.ts가
//   `qrcode`(lib/index.js, pngjs 인코더)로 그린다 — 인코더가 다르므로 두
//   PNG가 바이트 단위로 같다고 주장하지 않는다(완료기준1은 "같은 qrDataUri
//   문자열을 buildSvg에 주입하면 SVG 문자열이 같다"는 구조적 보장이지, 두
//   환경이 독립적으로 생성한 QR 이미지가 바이트 동일하다는 뜻이 아니다).
//   그래서 "서버 정확 미리보기" 버튼을 별도로 두어, 이미 구현된 서버
//   /design/preview 엔드포인트(sharp 렌더, 실제 발행과 동일 경로)로 진짜
//   결과물을 확인할 수 있게 한다 — 클라이언트 캔버스는 어디까지나 "빠른
//   편집용 근사치"이고, 발행 전 최종 확인은 서버 렌더가 맡는다.
// ═══════════════════════════════════════════════════════════════════════════

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  validateLayout,
  moveElement,
  removeElement,
  reorder,
  duplicateElement,
  addElement,
  normalizeLayout,
  resolveLayoutTheme,
  CANVAS_PRESETS,
  BIND_SOURCES,
  type DesignLayout,
  type LayoutElement,
  type LayoutIssue,
  type ElementKind,
} from "@/lib/bokju-coupon-design/layout";
import { buildSvg, type SvgRenderContext } from "@/lib/bokju-coupon-design/svg";
// ⛔ 절대 추가 금지: import { renderCouponImage } from '@/lib/bokju-coupon-design/renderer';
//    (renderer.ts는 모듈 최상단에서 sharp를 import한다 — 클라이언트 번들이 깨진다)
import QRCode from "qrcode"; // 번들러가 package.json의 "browser" 필드로 lib/browser.js로 자동 치환
import { PART_GROUPS, PARTS, TEMPLATES, buildTemplate, insertPart } from "@/lib/bokju-coupon-design/templates";

// ── 서버 응답 타입(studio-api.ts의 실제 interface와 맞춤) ───────────────────
interface CatalogPalette {
  id: string;
  name: string;
  note: string;
  dark: boolean;
  swatch: string[];
}
interface Catalog {
  palettes: CatalogPalette[];
  templates: Array<{ id: string; name: string; note: string; bestFor: string }>;
  parts: Array<{ id: string; name: string; group: string; note: string }>;
  partGroups: readonly string[];
}
interface RevisionItem {
  id: number;
  revNo: number;
  note: string | null;
  createdBy: string | null;
  createdAt: string;
  contentHash: string;
  isCurrent: boolean;
}

async function fetchJson(url: string, init?: RequestInit) {
  const res = await fetch(url, init);
  const json = await res.json();
  if (!json.success) {
    const err: Error & { issues?: LayoutIssue[] } = new Error(json.error || "요청 실패");
    err.issues = json.issues;
    throw err;
  }
  return json.data;
}

// ── 미리보기 전용 샘플값 ────────────────────────────────────────────────────
// [§0-H] 이 값들은 절대 레이아웃 JSON이나 저장 payload에 들어가지 않는다.
// 서버가 최종 판정하므로(saveCampaignDesign이 validateLayout을 다시 돌림),
// 여기서 섞여 들어갈 경로 자체를 만들지 않는다 — save()의 body는 {layout, note}뿐.
const PREVIEW_SAMPLE_COUPON_NO = "SAMPLE-0000-0000";
const PREVIEW_SAMPLE_REDEEM_TOKEN = "0".repeat(32);

interface Props {
  campaignId: number;
  canWrite: boolean;
  campaign: {
    title: string;
    grantAmount: number;
    guideText: string | null;
    validFrom: string; // ISO
    validTo: string; // ISO
  };
}

export default function BokjuCouponDesignStudio({ campaignId, canWrite, campaign }: Props) {
  // ── ① 상태 ─────────────────────────────────────────────────────────────
  const [layout, setLayout] = useState<DesignLayout | null>(null);
  const [catalog, setCatalog] = useState<Catalog | null>(null);
  const [revisions, setRevisions] = useState<RevisionItem[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [qrDataUri, setQrDataUri] = useState<string | null>(null); // 캐시. 드래그 중 재생성 금지.
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [saveIssues, setSaveIssues] = useState<LayoutIssue[] | null>(null);
  const [saveOk, setSaveOk] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [note, setNote] = useState("");
  const [serverPreviewUrl, setServerPreviewUrl] = useState<string | null>(null);
  const [serverPreviewLoading, setServerPreviewLoading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);

  const rafRef = useRef<number | null>(null);
  const stageRef = useRef<HTMLDivElement | null>(null);
  const dragState = useRef<{ id: string; offsetX: number; offsetY: number } | null>(null);

  // ── 초기 로드: 레이아웃 + 카탈로그 + 리비전 목록 ─────────────────────────
  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      setLoadError(null);
      try {
        const [designData, catalogData, revisionData] = await Promise.all([
          fetchJson(`/api/admin/bokju-coupons/campaigns/${campaignId}/design`),
          fetchJson("/api/admin/bokju-coupons/design-catalog"),
          fetchJson(`/api/admin/bokju-coupons/campaigns/${campaignId}/design/revisions`),
        ]);
        if (cancelled) return;
        setLayout(designData.layout);
        setCatalog(catalogData);
        setRevisions(revisionData.revisions);
      } catch (e) {
        if (!cancelled) setLoadError(e instanceof Error ? e.message : "불러오기 실패");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [campaignId]);

  const selected: LayoutElement | null = useMemo(
    () => (layout ? layout.elements.find((e) => e.id === selectedId) ?? null : null),
    [layout, selectedId],
  );

  // ── ② 발행 전 검사: validateLayout 반환 전체(12종)를 그대로 순회 ─────────
  // [02f §0-K 정정] 하드코딩 금지. 실제 코드(10 push + SCHEMA + ... 확인한
  // 개수와 무관하게) — 이 화면은 코드를 세지 않고 issues 배열을 그대로 그린다.
  // 그래서 validateLayout 내부 검사 종류가 늘거나 줄어도 이 화면은 깨지지 않는다.
  const report = useMemo(() => (layout ? validateLayout(layout) : { ok: true, issues: [] as LayoutIssue[] }), [layout]);
  const blockers = report.issues.filter((i) => i.level === "error");
  const warnings = report.issues.filter((i) => i.level === "warn");

  // ── ③ QR: 마운트 시(또는 캠페인 변경 시) 1회만 생성 → state 캐시 ────────
  // [§0-H] 드래그 중 재생성 금지 — 의존성 배열에 layout을 넣지 않는다.
  useEffect(() => {
    let alive = true;
    const origin = typeof window !== "undefined" ? window.location.origin : "";
    const target = `${origin}/coupon/${PREVIEW_SAMPLE_REDEEM_TOKEN}`;
    QRCode.toDataURL(target, { type: "image/png", margin: 1, width: 480, errorCorrectionLevel: "M" })
      .then((uri) => {
        if (alive) setQrDataUri(uri);
      })
      .catch(() => {
        if (alive) setQrDataUri(null);
      });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // 의도적으로 빈 배열 — layout을 넣으면 드래그마다 QR을 재생성해 성능이 무너진다.

  // ── ④ SVG 렌더: buildSvg는 동기 함수. 이미지 자산은 그대로 URL 통과 ──────
  // [§0-H 필수2] 여기서 쓰는 couponNo/redeemToken은 샘플 고정값이다. 실제
  // 쿠폰 데이터가 아니며, 아래 svg는 payload로 저장되지도 서버에 전송되지도
  // 않는다(화면 표시 전용).
  const svg = useMemo(() => {
    if (!layout || !qrDataUri) return null;
    const ctx: SvgRenderContext = {
      campaign: {
        title: campaign.title,
        grantAmount: campaign.grantAmount,
        guideText: campaign.guideText,
        validFrom: new Date(campaign.validFrom),
        validTo: new Date(campaign.validTo),
      },
      coupon: { couponNo: PREVIEW_SAMPLE_COUPON_NO, redeemToken: PREVIEW_SAMPLE_REDEEM_TOKEN },
    };
    return buildSvg(layout, ctx, {
      qrDataUri,
      // 업로드된 자산은 /uploads/... 상대경로라 브라우저가 same-origin으로
      // 바로 로드할 수 있다 — 별도 fetch/blob 변환이 필요 없다.
      resolveAsset: (src) => src || null,
    });
  }, [layout, qrDataUri, campaign]);

  const resolvedTheme = useMemo(() => (layout ? resolveLayoutTheme(layout) : null), [layout]);

  // ── ⑤ 좌표 변경: moveElement의 clamp를 그대로 재사용(직접 clamp 금지) ────
  const applyMove = useCallback((id: string, canvasX: number, canvasY: number) => {
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
    rafRef.current = requestAnimationFrame(() => {
      setLayout((prev) => (prev ? moveElement(prev, id, canvasX, canvasY) : prev));
    });
  }, []);

  // ── ⑥ 저장: 서버가 최종 판정한다. 400이면 issues를 그대로 표면화 ────────
  // [§0-H] body는 { layout, note }뿐 — PREVIEW_SAMPLE류 값을 섞지 않는다.
  const save = useCallback(async () => {
    if (!layout) return;
    setSaving(true);
    setSaveIssues(null);
    setSaveOk(null);
    try {
      const result = await fetchJson(`/api/admin/bokju-coupons/campaigns/${campaignId}/design`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ layout, note: note.trim() || undefined }),
      });
      setSaveOk(`저장되었습니다 (rev${result.revisionNo}${result.reused ? ", 기존 리비전 재사용" : ""}).`);
      if (result.issues?.length) setSaveIssues(result.issues); // warn만 남아 있을 수 있음
      const revisionData = await fetchJson(`/api/admin/bokju-coupons/campaigns/${campaignId}/design/revisions`);
      setRevisions(revisionData.revisions);
    } catch (e) {
      // [§0-G 필수1] 서버 거부(LAYOUT_INVALID)의 issues를 그대로 보여준다.
      // 클라이언트 검사를 통과했다고 주장해도 서버가 다시 거부할 수 있고,
      // 이 경우 화면을 성공으로 바꾸지 않는다.
      const err = e as Error & { issues?: LayoutIssue[] };
      setSaveIssues(err.issues?.length ? err.issues : [{ level: "error", code: "SAVE_FAILED", message: err.message }]);
    } finally {
      setSaving(false);
    }
  }, [campaignId, layout, note]);

  // ── ⑦ 되돌리기 ───────────────────────────────────────────────────────────
  const rollback = useCallback(
    async (revisionId: number) => {
      if (!confirm("이 리비전으로 되돌릴까요?")) return;
      try {
        const result = await fetchJson(
          `/api/admin/bokju-coupons/campaigns/${campaignId}/design/revisions/${revisionId}/rollback`,
          { method: "POST" },
        );
        // [§0-G 필수4] 서버가 내려준 두 안내 문구를 그대로 보여준다.
        alert(`되돌렸습니다 (rev${result.revisionNo}).\n\n- ${result.notice.existingCouponsUnaffected}\n- ${result.notice.futureCouponsUseThisRevision}`);
        const designData = await fetchJson(`/api/admin/bokju-coupons/campaigns/${campaignId}/design`);
        setLayout(designData.layout);
        const revisionData = await fetchJson(`/api/admin/bokju-coupons/campaigns/${campaignId}/design/revisions`);
        setRevisions(revisionData.revisions);
      } catch (e) {
        alert(e instanceof Error ? e.message : "되돌리기 실패");
      }
    },
    [campaignId],
  );

  // ── ⑧ 서버 정확 미리보기(§0-K 반영: 클라이언트 QR ≠ 서버 QR 바이트) ──────
  const openServerPreview = useCallback(async () => {
    if (!layout) return;
    setServerPreviewLoading(true);
    try {
      const res = await fetch(`/api/admin/bokju-coupons/campaigns/${campaignId}/design/preview`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ layout }),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        alert(body.error || "서버 미리보기 생성 실패");
        return;
      }
      const blob = await res.blob();
      if (serverPreviewUrl) URL.revokeObjectURL(serverPreviewUrl);
      setServerPreviewUrl(URL.createObjectURL(blob));
    } finally {
      setServerPreviewLoading(false);
    }
  }, [campaignId, layout, serverPreviewUrl]);

  // ── ⑨ 자산 업로드(이미지 요소) ────────────────────────────────────────────
  const uploadAsset = useCallback(
    async (file: File, targetElementId: string) => {
      setUploadError(null);
      const formData = new FormData();
      formData.append("file", file);
      try {
        const res = await fetch(`/api/admin/bokju-coupons/campaigns/${campaignId}/design/assets`, {
          method: "POST",
          body: formData,
        });
        const json = await res.json();
        if (!json.success) {
          // [02e §0-I] 서버가 MIME 화이트리스트 + 매직바이트 + 5MB 제한을
          // 재검증한다 — 클라이언트는 이 거부를 그대로 화면에 표면화한다.
          setUploadError(json.error || "업로드 실패");
          return;
        }
        setLayout((prev) =>
          prev
            ? {
                ...prev,
                elements: prev.elements.map((e) =>
                  e.id === targetElementId ? { ...e, assetUrl: json.data.assetUrl, assetId: null } : e,
                ),
              }
            : prev,
        );
      } catch {
        setUploadError("업로드 중 네트워크 오류가 발생했습니다.");
      }
    },
    [campaignId],
  );

  // ── 드래그 이벤트 핸들러 ───────────────────────────────────────────────────
  const canvas = layout?.canvas;
  const viewWidth = 420; // 좌측 패널(≈260px)·우측 패널(≈320px) 고려한 중앙 캔버스 표시폭
  const viewScale = canvas ? viewWidth / canvas.width : 1;

  const onPointerDownElement = useCallback(
    (e: React.PointerEvent, el: LayoutElement) => {
      if (!canWrite || el.locked) return;
      e.stopPropagation();
      setSelectedId(el.id);
      const rect = stageRef.current?.getBoundingClientRect();
      if (!rect) return;
      // [§0-H] 핸들러 안에서도 좌표는 즉시 캔버스 공간으로 역산한다 — 화면
      // 표시 스케일(viewScale)은 좌표 계산에서만 나누고, 저장값에는 남지 않는다.
      const canvasX = (e.clientX - rect.left) / viewScale;
      const canvasY = (e.clientY - rect.top) / viewScale;
      dragState.current = { id: el.id, offsetX: canvasX - el.x, offsetY: canvasY - el.y };
      (e.target as HTMLElement).setPointerCapture(e.pointerId);
    },
    [canWrite, viewScale],
  );

  const onPointerMoveStage = useCallback(
    (e: React.PointerEvent) => {
      if (!dragState.current) return;
      const rect = stageRef.current?.getBoundingClientRect();
      if (!rect) return;
      const canvasX = (e.clientX - rect.left) / viewScale - dragState.current.offsetX;
      const canvasY = (e.clientY - rect.top) / viewScale - dragState.current.offsetY;
      applyMove(dragState.current.id, canvasX, canvasY);
    },
    [applyMove, viewScale],
  );

  const onPointerUpStage = useCallback(() => {
    dragState.current = null;
  }, []);

  if (loading) return <p className="p-6 text-sm text-slate-500">불러오는 중...</p>;
  if (loadError || !layout || !canvas || !resolvedTheme) {
    return <p className="p-6 text-sm text-rose-700">불러오기 실패: {loadError ?? "알 수 없는 오류"}</p>;
  }

  function updateSelected(patch: Partial<LayoutElement>) {
    setLayout((prev) =>
      prev ? { ...prev, elements: prev.elements.map((e) => (e.id === selectedId ? { ...e, ...patch } : e)) } : prev,
    );
  }

  return (
    <div className="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-[260px_1fr_340px]">
      {/* ── 좌측: 구성 고르기 ── */}
      <aside className="space-y-5 overflow-y-auto rounded-xl border border-slate-200 bg-white p-4 lg:max-h-[calc(100vh-180px)]">
        <section>
          <h2 className="mb-2 text-xs font-semibold text-slate-700">구성 템플릿 ({catalog?.templates.length ?? 0})</h2>
          <div className="space-y-1">
            {catalog?.templates.map((t) => (
              <button
                key={t.id}
                type="button"
                disabled={!canWrite}
                onClick={() => setLayout(buildTemplate(t.id, resolvedTheme, canvas))}
                title={t.note}
                className="block w-full rounded border border-slate-200 px-2 py-1.5 text-left text-xs text-slate-700 hover:bg-slate-50 disabled:opacity-50"
              >
                {t.name}
              </button>
            ))}
          </div>
        </section>

        <section>
          <h2 className="mb-2 text-xs font-semibold text-slate-700">캔버스 크기</h2>
          <div className="flex flex-wrap gap-1">
            {(Object.keys(CANVAS_PRESETS) as Array<keyof typeof CANVAS_PRESETS>).map((key) => {
              const preset = CANVAS_PRESETS[key];
              const isCurrent = canvas.width === preset.width && canvas.height === preset.height;
              return (
                <button
                  key={key}
                  type="button"
                  disabled={!canWrite}
                  onClick={() => {
                    if (isCurrent) return;
                    // 캔버스 치수를 바꾸면 절대 좌표가 그대로면 요소가 어긋난다.
                    // 비율만 유지해 좌표/크기를 재계산한다(normalizeLayout으로
                    // z·id 정리까지 — layout.ts 함수만 재사용, 직접 clamp 없음).
                    const sx = preset.width / canvas.width;
                    const sy = preset.height / canvas.height;
                    setLayout((prev) =>
                      prev
                        ? normalizeLayout({
                            ...prev,
                            canvas: { ...prev.canvas, width: preset.width, height: preset.height },
                            elements: prev.elements.map((e) => ({
                              ...e,
                              x: e.x * sx,
                              y: e.y * sy,
                              width: e.width !== undefined ? e.width * sx : e.width,
                              height: e.height !== undefined ? e.height * sy : e.height,
                              fontSize: e.fontSize !== undefined ? e.fontSize * sx : e.fontSize,
                            })),
                          })
                        : prev,
                    );
                  }}
                  className={`rounded border px-2 py-1 text-[11px] ${
                    isCurrent ? "border-indigo-500 bg-indigo-50 text-indigo-700" : "border-slate-200 text-slate-600 hover:bg-slate-50"
                  } disabled:opacity-50`}
                >
                  {preset.width}×{preset.height}
                </button>
              );
            })}
          </div>
        </section>

        <section>
          <h2 className="mb-2 text-xs font-semibold text-slate-700">색 고르기 ({catalog?.palettes.length ?? 0})</h2>
          <div className="grid grid-cols-4 gap-1.5">
            {catalog?.palettes.map((p) => (
              <button
                key={p.id}
                type="button"
                disabled={!canWrite}
                title={p.name}
                onClick={() =>
                  setLayout((prev) =>
                    prev ? { ...prev, theme: { ...(prev.theme ?? {}), paletteId: p.id } as DesignLayout["theme"] } : prev,
                  )
                }
                className={`h-9 rounded border ${
                  resolvedTheme.paletteId === p.id ? "ring-2 ring-indigo-500" : "border-slate-200"
                }`}
                style={{ background: `linear-gradient(135deg, ${p.swatch[1]}, ${p.swatch[2]})` }}
              />
            ))}
          </div>
        </section>

        <section>
          <h2 className="mb-2 text-xs font-semibold text-slate-700">글자 크기 · 글꼴</h2>
          <div className="flex gap-1">
            {(["compact", "normal", "large"] as const).map((scale) => (
              <button
                key={scale}
                type="button"
                disabled={!canWrite}
                onClick={() =>
                  setLayout((prev) =>
                    prev ? { ...prev, theme: { ...(prev.theme ?? {}), textScale: scale } as DesignLayout["theme"] } : prev,
                  )
                }
                className={`flex-1 rounded border px-1 py-1 text-[11px] ${
                  resolvedTheme.textScaleId === scale ? "border-indigo-500 bg-indigo-50 text-indigo-700" : "border-slate-200 text-slate-600"
                } disabled:opacity-50`}
              >
                {scale === "compact" ? "작게" : scale === "normal" ? "보통" : "크게"}
              </button>
            ))}
          </div>
          <div className="mt-1 flex gap-1">
            {(["sans", "serif", "display"] as const).map((font) => (
              <button
                key={font}
                type="button"
                disabled={!canWrite}
                onClick={() =>
                  setLayout((prev) =>
                    prev ? { ...prev, theme: { ...(prev.theme ?? {}), fontStack: font } as DesignLayout["theme"] } : prev,
                  )
                }
                className={`flex-1 rounded border px-1 py-1 text-[11px] ${
                  resolvedTheme.fontStackId === font ? "border-indigo-500 bg-indigo-50 text-indigo-700" : "border-slate-200 text-slate-600"
                } disabled:opacity-50`}
              >
                {font === "sans" ? "고딕" : font === "serif" ? "명조" : "디스플레이"}
              </button>
            ))}
          </div>
        </section>

        <section>
          <h2 className="mb-2 text-xs font-semibold text-slate-700">부품 얹기</h2>
          {(PART_GROUPS as readonly string[]).map((g) => (
            <div key={g} className="mb-2">
              <h3 className="mb-1 text-[11px] font-medium text-slate-500">{g}</h3>
              <div className="flex flex-wrap gap-1">
                {PARTS.filter((p) => p.group === g).map((p) => (
                  <button
                    key={p.id}
                    type="button"
                    disabled={!canWrite}
                    title={p.note}
                    onClick={() => setLayout((prev) => (prev ? insertPart(prev, p.id, resolvedTheme) : prev))}
                    className="rounded border border-slate-200 px-1.5 py-0.5 text-[11px] text-slate-600 hover:bg-slate-50 disabled:opacity-50"
                  >
                    {p.name}
                  </button>
                ))}
              </div>
            </div>
          ))}
          {/* 기본정보5 · 등록4 · 텍스트3 · 이미지2 · 장식3 = 17종(PARTS 정본) */}
        </section>

        {selected?.kind === "image" && canWrite && (
          <section>
            <h2 className="mb-2 text-xs font-semibold text-slate-700">사진 / 로고 올리기</h2>
            <input
              type="file"
              accept="image/jpeg,image/png,image/webp"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file && selected) void uploadAsset(file, selected.id);
                e.target.value = "";
              }}
              className="w-full text-[11px]"
            />
            <p className="mt-1 text-[10px] text-slate-400">jpg/png/webp, 5MB 이하. 서버가 실제 바이트를 재검증합니다.</p>
            {uploadError && <p className="mt-1 text-[11px] text-rose-600">{uploadError}</p>}
          </section>
        )}
      </aside>

      {/* ── 중앙: 캔버스 ── */}
      <main className="flex flex-col items-center gap-3">
        <div className="flex w-full max-w-[460px] items-center justify-between text-[11px] text-slate-500">
          <span>미리보기용 QR·쿠폰번호는 샘플입니다(실제 발행 이미지에는 각 쿠폰의 진짜 값이 들어갑니다).</span>
        </div>
        <div
          ref={stageRef}
          className="relative overflow-hidden rounded-lg border border-slate-300 bg-white shadow-sm"
          style={{ width: canvas.width * viewScale, height: canvas.height * viewScale }}
          onPointerMove={onPointerMoveStage}
          onPointerUp={onPointerUpStage}
          onPointerLeave={onPointerUpStage}
          onClick={() => setSelectedId(null)}
        >
          {svg ? (
            <div
              style={{ width: canvas.width, height: canvas.height, transform: `scale(${viewScale})`, transformOrigin: "top left" }}
              // buildSvg()는 신뢰된 자체 생성물(외부 입력 SVG 아님) — 구조화된
              // layout/theme 데이터로부터 이 모듈이 직접 문자열을 조립한다.
              dangerouslySetInnerHTML={{ __html: svg }}
            />
          ) : (
            <div className="flex h-full items-center justify-center text-xs text-slate-400">QR 생성 중...</div>
          )}

          {/* 조작 오버레이 — 요소별 선택·드래그 핸들(SVG 자체는 건드리지 않는다) */}
          {layout.elements.map((el) => {
            const w = (el.width ?? (el.kind === "text" ? 160 : 80)) * viewScale;
            const h = (el.height ?? (el.kind === "text" ? 40 : 80)) * viewScale;
            const left = el.x * viewScale - w / 2;
            const top = el.y * viewScale - h / 2;
            const isSelected = el.id === selectedId;
            return (
              <div
                key={el.id}
                onPointerDown={(e) => onPointerDownElement(e, el)}
                onClick={(e) => {
                  e.stopPropagation();
                  setSelectedId(el.id);
                }}
                style={{ left, top, width: w, height: h, position: "absolute", touchAction: "none" }}
                className={`cursor-move rounded border-2 ${
                  isSelected ? "border-indigo-500" : "border-transparent hover:border-indigo-300"
                } ${el.locked ? "cursor-not-allowed" : ""}`}
              />
            );
          })}
        </div>

        <div className="flex gap-2">
          <button
            type="button"
            onClick={openServerPreview}
            disabled={serverPreviewLoading}
            className="rounded border border-slate-300 px-3 py-1.5 text-xs text-slate-700 hover:bg-slate-50 disabled:opacity-50"
          >
            {serverPreviewLoading ? "생성 중..." : "서버 정확 미리보기(발행과 동일 경로)"}
          </button>
        </div>
        {serverPreviewUrl && (
          <div className="rounded-lg border border-slate-200 bg-slate-50 p-2">
            <p className="mb-1 text-[11px] text-slate-500">서버 렌더 결과(실제 발행 시 사용하는 sharp 경로) — QR·쿠폰번호는 여기서도 샘플입니다.</p>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={serverPreviewUrl} alt="서버 렌더 미리보기" className="max-h-[420px] rounded border border-slate-200" />
          </div>
        )}
      </main>

      {/* ── 우측: 요소 목록 · 발행 전 검사 · 속성 · 되돌리기 ── */}
      <aside className="space-y-5 overflow-y-auto rounded-xl border border-slate-200 bg-white p-4 lg:max-h-[calc(100vh-180px)]">
        <section>
          <h2 className="mb-2 text-xs font-semibold text-slate-700">요소 목록 ({layout.elements.length})</h2>
          <ul className="space-y-1">
            {[...layout.elements]
              .sort((a, b) => b.z - a.z)
              .map((el) => (
                <li
                  key={el.id}
                  onClick={() => setSelectedId(el.id)}
                  className={`flex items-center justify-between rounded border px-2 py-1 text-[11px] ${
                    el.id === selectedId ? "border-indigo-500 bg-indigo-50" : "border-slate-200"
                  }`}
                >
                  <span className="truncate">
                    {el.kind} · {el.name}
                    {el.locked ? " 🔒" : ""}
                  </span>
                  {canWrite && (
                    <span className="flex shrink-0 gap-1">
                      <button type="button" onClick={() => setLayout((p) => (p ? reorder(p, el.id, "up") : p))} className="px-1 text-slate-500 hover:text-slate-800">
                        ▲
                      </button>
                      <button type="button" onClick={() => setLayout((p) => (p ? reorder(p, el.id, "down") : p))} className="px-1 text-slate-500 hover:text-slate-800">
                        ▼
                      </button>
                      <button type="button" onClick={() => setLayout((p) => (p ? duplicateElement(p, el.id) : p))} className="px-1 text-slate-500 hover:text-slate-800">
                        복제
                      </button>
                      <button
                        type="button"
                        onClick={() => {
                          setLayout((p) => (p ? removeElement(p, el.id) : p));
                          if (selectedId === el.id) setSelectedId(null);
                        }}
                        className="px-1 text-rose-500 hover:text-rose-700"
                      >
                        삭제
                      </button>
                    </span>
                  )}
                </li>
              ))}
          </ul>
          {canWrite && (
            <div className="mt-2 flex flex-wrap gap-1">
              {(["text", "image", "qr", "box", "line"] as ElementKind[]).map((kind) => (
                <button
                  key={kind}
                  type="button"
                  onClick={() => setLayout((p) => (p ? addElement(p, kind) : p))}
                  className="rounded border border-slate-200 px-1.5 py-0.5 text-[10px] text-slate-600 hover:bg-slate-50"
                >
                  + {kind}
                </button>
              ))}
            </div>
          )}
        </section>

        <section>
          <h2 className="mb-2 text-xs font-semibold text-slate-700">
            발행 전 검사 {blockers.length > 0 ? `(차단 ${blockers.length}건)` : report.issues.length > 0 ? `(경고 ${warnings.length}건)` : "(통과)"}
          </h2>
          {/* [02f §0-K] 하드코딩된 6종/10종 나열이 아니라 report.issues를
              배열 그대로 순회한다 — validateLayout이 반환하는 모든 검사
              코드가 늘어나거나 줄어도 이 화면은 깨지지 않는다. */}
          <ul className="space-y-1">
            {report.issues.map((i, n) => (
              <li
                key={`${i.code}_${n}`}
                className={`rounded border px-2 py-1 text-[11px] ${
                  i.level === "error" ? "border-rose-300 bg-rose-50 text-rose-800" : "border-amber-300 bg-amber-50 text-amber-800"
                }`}
              >
                [{i.level === "error" ? "차단" : "경고"} · {i.code}] {i.message}
              </li>
            ))}
            {report.issues.length === 0 && <li className="text-[11px] text-emerald-700">모든 검사를 통과했습니다.</li>}
          </ul>
        </section>

        {canWrite && (
          <section>
            <h2 className="mb-1 text-xs font-semibold text-slate-700">저장</h2>
            <input
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="변경 메모(선택)"
              className="mb-2 w-full rounded border border-slate-300 px-2 py-1 text-xs"
            />
            <button
              type="button"
              onClick={save}
              disabled={saving || blockers.length > 0}
              title={blockers.length > 0 ? "차단 항목을 먼저 해결해야 저장할 수 있습니다." : undefined}
              className="w-full rounded bg-indigo-600 px-3 py-2 text-xs font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              {saving ? "저장 중..." : "저장(발행에 반영)"}
            </button>
            {saveOk && <p className="mt-1 text-[11px] text-emerald-700">{saveOk}</p>}
            {saveIssues && saveIssues.length > 0 && (
              <div className="mt-1 space-y-1">
                {saveIssues.map((i, n) => (
                  <p key={n} className={`text-[11px] ${i.level === "error" ? "text-rose-700" : "text-amber-700"}`}>
                    [{i.code}] {i.message}
                  </p>
                ))}
              </div>
            )}
          </section>
        )}

        <section>
          <h2 className="mb-2 text-xs font-semibold text-slate-700">요소 속성</h2>
          {!selected ? (
            <p className="text-[11px] text-slate-400">요소를 선택하세요.</p>
          ) : (
            <div className="space-y-2 text-[11px]">
              <label className="block">
                <span className="text-slate-500">이름</span>
                <input
                  value={selected.name}
                  disabled={!canWrite}
                  onChange={(e) => updateSelected({ name: e.target.value })}
                  className="mt-0.5 w-full rounded border border-slate-300 px-2 py-1"
                />
              </label>
              <label className="block">
                <span className="text-slate-500">값 출처(bind)</span>
                <select
                  value={selected.bind}
                  disabled={!canWrite}
                  onChange={(e) => updateSelected({ bind: e.target.value as LayoutElement["bind"] })}
                  className="mt-0.5 w-full rounded border border-slate-300 px-2 py-1"
                >
                  {BIND_SOURCES.map((b) => (
                    <option key={b} value={b}>
                      {b}
                    </option>
                  ))}
                </select>
              </label>
              <div className="flex gap-2">
                <label className="flex-1">
                  <span className="text-slate-500">x</span>
                  <input
                    type="number"
                    value={Math.round(selected.x)}
                    disabled={!canWrite}
                    onChange={(e) => setLayout((p) => (p ? moveElement(p, selected.id, Number(e.target.value), selected.y) : p))}
                    className="mt-0.5 w-full rounded border border-slate-300 px-2 py-1"
                  />
                </label>
                <label className="flex-1">
                  <span className="text-slate-500">y</span>
                  <input
                    type="number"
                    value={Math.round(selected.y)}
                    disabled={!canWrite}
                    onChange={(e) => setLayout((p) => (p ? moveElement(p, selected.id, selected.x, Number(e.target.value)) : p))}
                    className="mt-0.5 w-full rounded border border-slate-300 px-2 py-1"
                  />
                </label>
              </div>

              {selected.kind === "text" && (
                <>
                  {selected.bind === "static" && (
                    <label className="block">
                      <span className="text-slate-500">텍스트</span>
                      <textarea
                        value={selected.text ?? ""}
                        disabled={!canWrite}
                        onChange={(e) => updateSelected({ text: e.target.value })}
                        rows={2}
                        className="mt-0.5 w-full rounded border border-slate-300 px-2 py-1"
                      />
                    </label>
                  )}
                  <label className="block">
                    <span className="text-slate-500">글자 크기</span>
                    <input
                      type="number"
                      value={Math.round(selected.fontSize ?? 24)}
                      disabled={!canWrite}
                      onChange={(e) => updateSelected({ fontSize: Number(e.target.value) })}
                      className="mt-0.5 w-full rounded border border-slate-300 px-2 py-1"
                    />
                  </label>
                  <label className="block">
                    <span className="text-slate-500">정렬</span>
                    <select
                      value={selected.align ?? "center"}
                      disabled={!canWrite}
                      onChange={(e) => updateSelected({ align: e.target.value as LayoutElement["align"] })}
                      className="mt-0.5 w-full rounded border border-slate-300 px-2 py-1"
                    >
                      <option value="left">왼쪽</option>
                      <option value="center">가운데</option>
                      <option value="right">오른쪽</option>
                    </select>
                  </label>
                  <label className="block">
                    <span className="text-slate-500">개별 색(토큰 미사용 시)</span>
                    <input
                      type="color"
                      value={selected.color ?? "#1c1a18"}
                      disabled={!canWrite}
                      onChange={(e) => updateSelected({ color: e.target.value, colorToken: undefined })}
                      className="mt-0.5 h-8 w-full rounded border border-slate-300"
                    />
                  </label>
                </>
              )}

              {(selected.kind === "qr" || selected.kind === "image" || selected.kind === "box") && (
                <div className="flex gap-2">
                  <label className="flex-1">
                    <span className="text-slate-500">너비</span>
                    <input
                      type="number"
                      value={Math.round(selected.width ?? 0)}
                      disabled={!canWrite}
                      onChange={(e) => updateSelected({ width: Number(e.target.value) })}
                      className="mt-0.5 w-full rounded border border-slate-300 px-2 py-1"
                    />
                  </label>
                  <label className="flex-1">
                    <span className="text-slate-500">높이</span>
                    <input
                      type="number"
                      value={Math.round(selected.height ?? 0)}
                      disabled={!canWrite}
                      onChange={(e) => updateSelected({ height: Number(e.target.value) })}
                      className="mt-0.5 w-full rounded border border-slate-300 px-2 py-1"
                    />
                  </label>
                </div>
              )}
              {selected.kind === "qr" && (
                <p className="text-[10px] text-amber-700">
                  QR은 가로·세로 중 작은 쪽이 160px 미만이면 발행이 차단됩니다(인쇄 후 스캔 불가 방지).
                </p>
              )}

              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={selected.visible !== false}
                  disabled={!canWrite}
                  onChange={(e) => updateSelected({ visible: e.target.checked })}
                />
                <span className="text-slate-500">표시</span>
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={!!selected.locked}
                  disabled={!canWrite}
                  onChange={(e) => updateSelected({ locked: e.target.checked })}
                />
                <span className="text-slate-500">잠금(드래그 방지)</span>
              </label>
            </div>
          )}
        </section>

        <section>
          <h2 className="mb-2 text-xs font-semibold text-slate-700">되돌리기(리비전 이력)</h2>
          <ul className="space-y-1">
            {revisions.map((r) => (
              <li key={r.id} className={`flex items-center justify-between rounded border px-2 py-1 text-[11px] ${r.isCurrent ? "border-indigo-400 bg-indigo-50" : "border-slate-200"}`}>
                <span className="truncate">
                  rev{r.revNo} {r.isCurrent && "(현재)"} — {r.note || "(메모 없음)"}
                </span>
                {canWrite && !r.isCurrent && (
                  <button type="button" onClick={() => rollback(r.id)} className="shrink-0 rounded border border-slate-300 px-1.5 py-0.5 text-[10px] hover:bg-slate-100">
                    되돌리기
                  </button>
                )}
              </li>
            ))}
            {revisions.length === 0 && <li className="text-[11px] text-slate-400">아직 저장된 리비전이 없습니다.</li>}
          </ul>
          {/* [§0-G 필수4] 되돌리기 실행 시 confirm/alert에 두 안내 문구를
              그대로 표시한다(rollback() 함수 참고) — 여기서는 버튼만 제공. */}
          <p className="mt-2 text-[10px] text-slate-400">
            되돌리면 이미 발행된 쿠폰은 발행 당시 디자인을 그대로 유지하며, 앞으로 새로 발행되는 쿠폰부터 되돌린 리비전이 적용됩니다.
          </p>
        </section>
      </aside>
    </div>
  );
}
