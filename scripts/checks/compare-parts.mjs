// PARTS 배열 자동 비교 — ui-목업 data.js(원본) vs admin_web 이식본 templates.ts
// 사용법: node scripts/checks/compare-parts.mjs [ui-목업 data.js 경로]
import fs from 'node:fs';
const uiPath = process.argv[2] || '/home/user/uploaded_files/sintong_coupon_v3_extracted/신통방통-쿠폰-개발전달/sintong-coupon/ui-목업/data.js';
const extractIds = (src, re) => { const m = src.match(re); return m ? [...m[1].matchAll(/id:\s*'(\w+)'/g)].map(x => x[1]) : []; };
const uiIds = extractIds(fs.readFileSync(uiPath, 'utf8'), /const PARTS\s*=\s*\[([\s\S]*?)\n\];/);
const tsIds = extractIds(fs.readFileSync(new URL('../../src/lib/bokju-coupon-design/templates.ts', import.meta.url), 'utf8'), /export const PARTS[^=]*=\s*\[([\s\S]*?)\n\];/);
const same = uiIds.length === tsIds.length && uiIds.every((id, i) => id === tsIds[i]);
console.log(`ui-목업 ${uiIds.length}종 vs admin_web ${tsIds.length}종 — 순서까지 완전 동일: ${same}`);
if (!same) { console.log('ui:', uiIds); console.log('ts:', tsIds); process.exit(1); }
