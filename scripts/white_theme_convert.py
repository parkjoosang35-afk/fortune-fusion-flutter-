#!/usr/bin/env python3
"""
[9단계 화이트톤 전환] admin_web 전체 다크(slate) 테마 -> 화이트 테마 일괄 치환.

원칙:
- 순수 neutral(slate) 배경/텍스트/보더만 라이트로 치환한다.
- 컬러 버튼/배지(bg-indigo-600, bg-emerald-600 등 색상+명도 배경)가 포함된
  문자열 리터럴 내부의 text-white 등은 "버튼 위 흰 글씨"이므로 그대로 둔다
  (라이트 배경에서도 컬러 버튼 위 흰 텍스트는 정상적인 디자인).
- bg-black/NN (모달 오버레이 딤 처리)은 그대로 둔다.
- 타로 관련 파일은 이번 작업 대상이 아니지만 admin_web에는 타로 다크 컨셉이
  없으므로 전체 대상.

사용법: python3 white_theme_convert.py [--dry-run] <file1> <file2> ...
"""
import re
import sys

COLOR_NAMES = [
    "red", "orange", "amber", "yellow", "lime", "green", "emerald", "teal",
    "cyan", "sky", "blue", "indigo", "violet", "purple", "fuchsia", "pink",
    "rose",
]
# 솔리드 색상 버튼 배경만 매칭(예: bg-indigo-600). 뒤에 "/NN" 투명도가 붙는
# 다크 전용 배지 배경(bg-emerald-950/60 등)은 별도 REPLACEMENTS 규칙으로
# 처리하므로 여기서 제외해야 한다(아니면 배지 치환이 통째로 스킵됨).
COLOR_BG_RE = re.compile(
    r"(?<!hover:)\bbg-(?:" + "|".join(COLOR_NAMES) + r")-(?!900\b|950\b)\d{2,3}\b(?!/)"
)

# 색상 배지/버튼용 컬러 팔레트(다크 배경 전제 → 라이트 배경용으로 톤 재조정).
# 예: "bg-emerald-950/60 text-emerald-400" (다크 카드 위의 초록 배지)
#     → "bg-emerald-100 text-emerald-700" (화이트 카드 위에서도 대비가 유지되는 배지)
_BADGE_COLORS = [
    "red", "orange", "amber", "yellow", "lime", "green", "emerald", "teal",
    "cyan", "sky", "blue", "indigo", "violet", "purple", "fuchsia", "pink",
    "rose",
]

# 순서 중요: 더 구체적인(긴) 패턴을 먼저 적용해야 짧은 패턴에 잘못 다시 매칭되지 않음
REPLACEMENTS = [
    # --- neutral(slate) 배경/텍스트/보더 ---
    (re.compile(r"\bhover:bg-slate-800\b"), "hover:bg-slate-100"),
    (re.compile(r"\bhover:bg-slate-700\b"), "hover:bg-slate-200"),
    (re.compile(r"\bhover:text-white\b"), "hover:text-slate-900"),
    (re.compile(r"\bbg-slate-950\b"), "bg-white"),
    (re.compile(r"\bbg-slate-900\b"), "bg-white"),
    (re.compile(r"\bbg-slate-800\b"), "bg-white"),
    (re.compile(r"\bbg-slate-700\b"), "bg-slate-100"),
    (re.compile(r"\bbg-slate-600\b"), "bg-slate-200"),
    (re.compile(r"\bborder-slate-800\b"), "border-slate-200"),
    (re.compile(r"\bborder-slate-700\b"), "border-slate-300"),
    (re.compile(r"\bdivide-slate-800\b"), "divide-slate-200"),
    (re.compile(r"\btext-white\b"), "text-slate-900"),
    (re.compile(r"\btext-slate-200\b"), "text-slate-700"),
    (re.compile(r"\btext-slate-300\b"), "text-slate-600"),
    (re.compile(r"\btext-slate-400\b"), "text-slate-500"),
]

# --- 색상 배지 계열(다크 전용 명도 -> 라이트 전용 명도) ---
for _c in _BADGE_COLORS:
    REPLACEMENTS.extend(
        [
            (re.compile(rf"\bhover:bg-{_c}-950/\d+\b"), f"hover:bg-{_c}-100"),
            (re.compile(rf"\bhover:bg-{_c}-900/\d+\b"), f"hover:bg-{_c}-100"),
            # 투명도가 없는 순수 hover 형태(예: hover:bg-amber-900)도 누락되어 있었음
            # (AdminUserRow.tsx에서 발견) - /NN 붙은 패턴보다 뒤에 둬서 먼저 매칭 안 되게 함
            (re.compile(rf"\bhover:bg-{_c}-950\b"), f"hover:bg-{_c}-100"),
            (re.compile(rf"\bhover:bg-{_c}-900\b"), f"hover:bg-{_c}-100"),
            (re.compile(rf"\bbg-{_c}-950/\d+\b"), f"bg-{_c}-100"),
            (re.compile(rf"\bbg-{_c}-900/\d+\b"), f"bg-{_c}-100"),
            (re.compile(rf"\bborder-{_c}-900\b"), f"border-{_c}-300"),
            (re.compile(rf"\bborder-{_c}-800\b"), f"border-{_c}-300"),
            (re.compile(rf"\bborder-{_c}-700\b"), f"border-{_c}-300"),
            (re.compile(rf"\bhover:text-{_c}-300\b"), f"hover:text-{_c}-800"),
            (re.compile(rf"\btext-{_c}-400\b"), f"text-{_c}-700"),
            (re.compile(rf"\btext-{_c}-300\b"), f"text-{_c}-800"),
        ]
    )

# 문자열 리터럴(쌍따옴표/홑따옴표) 매칭.
# 주의: 이전 버전은 r'"([^"\\]*)"' 처럼 백슬래시를 전혀 허용하지 않아서
# `"\n"` 같은 이스케이프 시퀀스가 포함된 리터럴(예: plan.benefits.join("\n"))을
# 만나면 그 지점에서 매칭이 깨지고, 이후 quote 페어링이 전부 어긋나 버려서
# 실제로는 변환되어야 할 뒤쪽의 className 리터럴들이 통째로 스킵되는 버그가 있었다.
# (SubscriptionPlanRow.tsx에서 "0/1 changed"로 나온 원인)
# `(?:\\.|[^"\\])*` 형태로 "이스케이프된 임의의 한 글자 또는 quote/backslash가
# 아닌 글자"를 반복 허용해서 이스케이프 시퀀스를 건너뛰도록 수정.
STR_LITERAL_RE = re.compile(r'"((?:\\.|[^"\\])*)"|\'((?:\\.|[^\'\\])*)\'')


def convert_literal(literal: str) -> str:
    if COLOR_BG_RE.search(literal):
        # 색상 버튼/배지 문자열 - neutral 치환 대상 없으면 그대로,
        # 있으면(예: "bg-indigo-600 text-white") 그 문자열은 스킵
        return literal
    new = literal
    for pattern, repl in REPLACEMENTS:
        new = pattern.sub(repl, new)
    return new


def convert_content(content: str) -> str:
    def _sub(m: re.Match) -> str:
        full = m.group(0)
        inner_dq = m.group(1)
        inner_sq = m.group(2)
        if inner_dq is not None:
            converted = convert_literal(inner_dq)
            if converted == inner_dq:
                return full
            return f'"{converted}"'
        else:
            converted = convert_literal(inner_sq)
            if converted == inner_sq:
                return full
            return f"'{converted}'"

    return STR_LITERAL_RE.sub(_sub, content)


def main() -> None:
    args = sys.argv[1:]
    dry_run = False
    if "--dry-run" in args:
        dry_run = True
        args.remove("--dry-run")

    changed_files = []
    for path in args:
        with open(path, "r", encoding="utf-8") as f:
            original = f.read()
        converted = convert_content(original)
        if converted != original:
            changed_files.append(path)
            if dry_run:
                print(f"[WOULD CHANGE] {path}")
            else:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(converted)
                print(f"[CHANGED] {path}")
    print(f"\nTotal files changed: {len(changed_files)} / {len(args)}")


if __name__ == "__main__":
    main()
