#!/usr/bin/env python3
"""saju_qa_check.py — 정통사주 결과 검증 (의존성 없음)

saju-output-spec.pdf §8 "자동 검증 스크립트" 원문 그대로 이식.
admin_web 런타임(Next.js)에서는 동일 로직의 TypeScript 버전
(src/lib/saju-qa-check.ts)이 실제로 route.ts 저장 훅에 연결되어 사용된다.
이 파이썬 버전은 관리자가 로컬에서 결과 JSON 파일을 오프라인으로
검증하고 싶을 때 그대로 실행할 수 있도록 PDF 원문을 보존한 것이다.

사용법:
    python3 scripts/saju_qa_check.py result.json
"""
import re
import json
import sys


BANNED = [
    "죽음", "사망", "사고", "부상", "수술", "입원", "질병", "병원", "암",
    "이혼", "파혼", "이별", "파산", "파멸", "망한다", "큰 손실", "재앙",
    "배신", "단절", "액운", "흉", "살(煞)",
    "반드시", "절대", "틀림없이", "100%", "할 운명", "위험합니다",
]
HEDGE = ["반드시", "절대", "틀림없이", "확실히"]
CLICHE = ["이 사주는", "타고난", "구조입니다", "조만간 좋은 소식"]


def sentences(t):
    return [s.strip() for s in re.split(r"[.!?。]\s*", t) if s.strip()]


def trigrams(t):
    w = re.findall(r"[가-힣A-Za-z0-9]+", t)
    return set(zip(w, w[1:], w[2:])) if len(w) >= 3 else set()


def check(result: dict, max_overlap=0.15, max_len=60):
    fail = []
    blocks = {s["key"]: " ".join(s["body"]) for s in result.get("sections", [])}
    blocks["headline"] = result.get("headline", "")
    blocks["closing"] = result.get("closing", "")
    blocks["actions"] = " ".join(result.get("actions", []))
    full = " ".join(blocks.values())

    # 1) 금지어
    hits = [w for w in BANNED if w in full]
    if hits:
        fail.append(f"[금지어] {hits}")

    # 2) 확정 단정 표현
    for s in sentences(full):
        for h in HEDGE:
            if h in s and not any(k in s for k in ["쉬워요", "편이에요", "수월"]):
                fail.append(f"[단정] {s[:40]}")

    # 3) 블록 간 3-gram 겹침률
    keys = list(blocks)
    for i in range(len(keys)):
        for j in range(i + 1, len(keys)):
            a, b = trigrams(blocks[keys[i]]), trigrams(blocks[keys[j]])
            if not a or not b:
                continue
            ov = len(a & b) / min(len(a), len(b))
            if ov > max_overlap:
                fail.append(f"[중복] {keys[i]} ↔ {keys[j]} 겹침 {ov:.0%}")

    # 4) 문장 길이
    for s in sentences(full):
        if len(s) > max_len:
            fail.append(f"[장문 {len(s)}자] {s[:40]}")

    # 5) 블록 분량 / 실천 개수
    for s in result.get("sections", []):
        if not 2 <= len(s.get("body", [])) <= 3:
            fail.append(f"[분량] {s['key']} {len(s.get('body', []))}문장 (2~3 필요)")
    if len(result.get("actions", [])) != 3:
        fail.append(f"[실천] {len(result.get('actions', []))}개 (3개 필요)")

    # 6) 상투구 반복
    for c in CLICHE:
        if full.count(c) > 1:
            fail.append(f"[상투구] '{c}' {full.count(c)}회")

    # 7) 부정:긍정 비율 (주의 문장 1개당 해법 3개 권장 → 최소 1.5배 이상)
    neg = sum(1 for s in sentences(full) if any(w in s for w in ["주의", "조심", "어긋", "새는", "떨어지", "무리"]))
    pos = sum(1 for s in sentences(full) if any(w in s for w in ["좋아요", "유리", "강해", "수월", "챙기", "확인", "정해"]))
    if neg and pos / neg < 1.5:
        fail.append(f"[비율] 주의 {neg} : 해법·긍정 {pos} — 해법을 늘리세요")

    # 8) 근거 인용 자기신고
    if not result.get("evidence_used"):
        fail.append("[근거] evidence_used 비어 있음 — 계산값을 실제로 인용하지 않았을 가능성")

    return fail


if __name__ == "__main__":
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    problems = check(data)
    print("PASS ✅ 검증 통과" if not problems else "FAIL ❌\n" + "\n".join(problems))
    sys.exit(1 if problems else 0)
