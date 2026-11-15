import json,re,yaml,os
from pathlib import Path
from collections import deque
p=Path(__file__).resolve().parent.parent
files=list(p.glob('lib/**/*.dart')); print('dart files',len(files))
errs=[]
# Import and export resolver with conditional branches for browser.
resolver=re.compile(r"(?:^|\n)\s*(import|export)\s+'([^']+)'((?:\s+if\s*\(dart\.library\.[^)]+\)\s+'[^']+')*)",re.M)
condition=re.compile(r"if\s*\(dart\.library\.([a-z_]+)\)\s*'([^']+)'",re.M)
imports={}
for f in files:
 s=f.read_text(encoding='utf-8')
 found=[]
 for kind,raw,conditions in resolver.findall(s):
  options=condition.findall(conditions)
  web=raw
  io=raw
  for cond,uri in options:
   if cond in ('js_interop','html'): web=uri
   if cond == 'io':io=uri
  def resolve(uri):
   if uri.startswith('dart:'):return uri
   if uri.startswith('package:sysyphus/'):return (p/'lib'/uri[len('package:sysyphus/'):]).resolve()
   if uri.startswith('package:'):return uri
   return (f.parent/uri).resolve()
  for uri in [raw,web,io]+[v for _,v in options]:
   r=resolve(uri)
   if isinstance(r,Path) and not r.is_file():errs.append(f'Falta {r} em {f}')
  found.append((resolve(web),resolve(io)))
 imports[f.resolve()]=found
reachable=set();q=deque([p/'lib/main.dart'])
while q:
 f=q.popleft().resolve()
 if f in reachable:continue
 reachable.add(f)
 for web,io in imports.get(f,[]):
  if isinstance(web,Path):q.append(web)
  if web=='dart:io':errs.append(f'Web importe IO: {f}')
print('Web-reachable files:',len(reachable));print('Web reaches io files:',[str(x.relative_to(p)) for x in reachable if 'io.dart' in str(x) or 'service_io.dart' in str(x)])
for f in reachable:
 src=f.read_text()
 if re.search(r"^\s*import\s+'dart:io'",src,re.M):errs.append(f'Web io: {f}')
for l in ['pt','en']:
 d=json.loads((p/f'lib/l10n/{l}.json').read_text())
 print('translations',l,len(d),'Web notice',d.get('sync.webNotice','missing')[:48])
for y in [p/'pubspec.yaml',p/'analysis_options.yaml']:
 data=yaml.safe_load(y.read_text());print(y.name,'YAML valid')
print('new web binaries exist',[(x,(p/'web'/x).exists()) for x in ['sqlite3.wasm','sqflite_sw.js']])
print('critical UI files',[(str(x),x.exists()) for x in [p/'lib/widgets/media_image.dart',p/'lib/data/services/sync_service_web.dart',p/'INICIAR_WEB.bat']])
if errs:
 for e in errs: print('ERROR',e)
 raise SystemExit(f'FAILED: {len(errs)}')
print('PASS: import graph, schemas, resource references')
