<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# 신통방통 공통 운영 지침 (필수 준수)

이 프로젝트(admin_web)의 모든 개발·배포 작업은 **`OPERATIONS_POLICY.md`**
(이 프로젝트 루트, 신통방통 개발·Preview·운영 배포 통합 지침서)를 반드시 따른다.
원본은 `/home/user/OPERATIONS_POLICY.md`에도 있으며, 두 파일은 동일 내용을 유지해야
한다(원본 수정 시 이 프로젝트의 사본도 함께 갱신할 것).

핵심 요약 (전문은 반드시 이 프로젝트의 `OPERATIONS_POLICY.md`를 직접 읽을 것):
- 코드 수정 → 테스트 → Preview 확인 → 대표 승인 → 운영 배포 → 실제 운영 검증, 이 순서를 생략하지 않는다.
- Preview 환경에 반영되지 않은 변경을 이미 확인한 것처럼 보고하지 않는다(외부 접근 가능한 URL로 재검증 필수).
- 대표 승인 전에는 어떤 경우에도(긴급 장애 포함) 운영 배포를 실행하지 않는다.
- 웹/관리자/서버·API/DB/Flutter앱/도메인·배포설정을 구분해서 배포 대상과 보고 범위를 명확히 한다.
- 배포 완료 보고는 반드시 7항목(수정내용/배포대상/Preview결과/승인여부/배포결과/운영검증결과/미완료항목) 형식을 따른다.
- 운영 배포 스크립트는 `/home/user/deploy_admin_web_to_prod.sh`이며, 대표 승인 없이 임의 실행하지 않는다.
