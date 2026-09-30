#!/usr/bin/env python3
"""Install pinned Ubuntu x86-64 headless tools without root privileges."""
import hashlib,os,pathlib,platform,shutil,tarfile,urllib.request,zipfile
from common import ROOT,read,run
HOME=pathlib.Path.home();BASE=HOME/'.local/share/agentgames';BIN=HOME/'.local/bin'
def download(name,item):
 p=BASE/'downloads'/name;p.parent.mkdir(parents=True,exist_ok=True)
 if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest()!=item['sha256']:
  print('Downloading',item['url'],flush=True)
  req=urllib.request.Request(item['url'],headers={'User-Agent':'AgentGames/0.1'})
  with urllib.request.urlopen(req) as src, p.open('wb') as dest:shutil.copyfileobj(src,dest)
 if hashlib.sha256(p.read_bytes()).hexdigest()!=item['sha256']:raise RuntimeError('Download checksum mismatch: '+name)
 return p
if __name__=='__main__':
 if platform.system()!='Linux' or platform.machine()!='x86_64':raise SystemExit('This installer supports Linux x86_64. See docs/SETUP.md for other systems.')
 cfg=read(ROOT/'tools/toolchain.json');BIN.mkdir(parents=True,exist_ok=True)
 archive=download('godot.zip',cfg['godot']);dest=BASE/'godot-4.6.1'
 with zipfile.ZipFile(archive) as z:
  dest.mkdir(parents=True,exist_ok=True)
  for name in z.namelist():
   target=dest/name;data=z.read(name)
   if not target.exists() or hashlib.sha256(target.read_bytes()).digest()!=hashlib.sha256(data).digest():target.write_bytes(data)
 executable=dest/'Godot_v4.6.1-stable_linux.x86_64';executable.chmod(0o755)
 link=BIN/'godot';link.unlink(missing_ok=True);link.symlink_to(executable)
 archive=download('templates.tpz',cfg['templates']);dest=HOME/'.local/share/godot/export_templates/4.6.1.stable';dest.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(archive) as z:
  for name in z.namelist():
   if pathlib.Path(name).name.startswith('web') or pathlib.Path(name).name=='version.txt':(dest/pathlib.Path(name).name).write_bytes(z.read(name))
 archive=download('blender.tar.xz',cfg['blender'])
 if not (BASE/'blender-4.5.3-linux-x64/blender').exists():
  with tarfile.open(archive) as t:t.extractall(BASE,filter='data')
 link=BIN/'blender';link.unlink(missing_ok=True);link.symlink_to(BASE/'blender-4.5.3-linux-x64/blender')
 run([BIN/'godot','--version']);run([BIN/'blender','--version'])
 run(['npm','ci','--no-audit','--no-fund']);run(['python3','tools/install_browser.py'])
 run(['uv','sync','--frozen'])
 run(['git','config','core.hooksPath','tools/hooks'])
 print('Ready. Use python3 tools/build.py --all and python3 tools/serve.py. Local MCP: uv run python tools/mcp_server.py')
