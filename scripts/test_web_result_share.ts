import assert from 'node:assert/strict';
import { shareResultLink } from '../src/app/r/[id]/share-result-link';
async function main() {
 const data={title:'결과',text:'원본 결과',url:'http://localhost:3111/r/test'};
 let copied=0;
 const copy=async (text:string)=>{assert.equal(text,data.url);copied++;};
 assert.equal(await shareResultLink({share:async payload=>{assert.deepEqual(payload,data);},copy},data),'shared');
 assert.equal(copied,0);
 assert.equal(await shareResultLink({share:async()=>{throw {name:'AbortError'};},copy},data),'cancelled');
 assert.equal(copied,0);
 assert.equal(await shareResultLink({share:async()=>{throw {name:'NotAllowedError'};},copy},data),'copied');
 assert.equal(copied,1);
 assert.equal(await shareResultLink({copy},data),'copied');
 assert.equal(copied,2);
 assert.equal(await shareResultLink({copy:async()=>{throw new Error('denied');}},data),'manual');
 assert.equal(await shareResultLink({},data),'manual');
 console.log('PASS: 공유성공·취소무복사·공유실패복사·미지원복사·복사거절직접안내·둘다미지원 6분기');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
