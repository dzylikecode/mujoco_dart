// Dependency-free static server for local Web smoke tests.
import {createServer} from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import {resolve,relative,extname,join} from 'node:path';
const root=resolve(process.argv[2]??'build/web');
const types={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.json':'application/json','.png':'image/png','.svg':'image/svg+xml','.ttf':'font/ttf','.otf':'font/otf'};
createServer(async(req,res)=>{
 try{
  let file=resolve(root,'.'+decodeURIComponent(new URL(req.url,'http://localhost').pathname));
  const rel=relative(root,file);
  if(rel==='..'||rel.startsWith('../')){res.writeHead(403);res.end();return;}
  if((await stat(file)).isDirectory())file=join(file,'index.html');
  res.setHeader('Content-Type',types[extname(file)]??'application/octet-stream');
  res.setHeader('Cache-Control','no-store');
  res.end(await readFile(file));
 }catch{res.writeHead(404);res.end('Not found');}
}).listen(8237,'127.0.0.1',()=>console.log(`Serving ${root} on http://127.0.0.1:8237`));
