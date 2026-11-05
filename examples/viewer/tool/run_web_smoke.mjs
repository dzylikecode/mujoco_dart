// Run against the smoke app served from build/web, with a separate headless
// Chromium exposing CDP on 9228. Does not touch the user's browser profile.
import {writeFile} from 'node:fs/promises';
const base=process.argv[2] ?? 'http://127.0.0.1:8237';
const tabs=await (await fetch('http://127.0.0.1:9228/json')).json();
const page=tabs.find(p=>p.type==='page');
if(!page) throw new Error('No headless browser page');
const ws=new WebSocket(page.webSocketDebuggerUrl);
await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject});
let seq=0; const pending=new Map(),errors=[],resources=[];
ws.onmessage=event=>{
 const m=JSON.parse(event.data);
 if(m.id){const p=pending.get(m.id);pending.delete(m.id);if(m.error)p?.reject(m.error);else p?.resolve(m.result);}
 if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);
 if(m.method==='Network.responseReceived' && /mujoco\.(js|wasm)|bootstrap\.js/.test(m.params.response.url))resources.push({url:m.params.response.url,status:m.params.response.status});
};
function call(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));})}
try {
 await call('Runtime.enable');await call('Network.enable');await call('Page.enable');
 await call('Emulation.setDeviceMetricsOverride',{width:1280,height:800,deviceScaleFactor:1,mobile:false});
 await call('Page.navigate',{url:base});
 let result;
 for(let i=0;i<120;i++){
  const r=await call('Runtime.evaluate',{expression:'globalThis.mujocoSmokeResult ?? null',returnByValue:true});
  result=r.result?.value;
  if(result?.status==='passed'||result?.status==='failed')break;
  await new Promise(r=>setTimeout(r,500));
 }
 if(result?.status!=='passed'){console.error(JSON.stringify({result,errors,resources},null,2));process.exitCode=1;}
 else {
  await new Promise(r=>setTimeout(r,2000));
  const shot=await call('Page.captureScreenshot',{format:'png'});
  await writeFile(new URL('../docs/web_preview.png',import.meta.url),Buffer.from(shot.data,'base64'));
  const output={...result,errors,resources};
  await writeFile(new URL('../docs/web_smoke_result.json',import.meta.url),JSON.stringify(output,null,2)+'\n');
  console.log(JSON.stringify(output,null,2));
 }
} finally {ws.close();}
