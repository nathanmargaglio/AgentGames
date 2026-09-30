"""Shared paths, hashing, and checked subprocesses for agent tools."""
import hashlib,json,pathlib,subprocess,os,re
ROOT=pathlib.Path(__file__).resolve().parents[1]
SEMVER=re.compile(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$')
def read(path):return json.loads(path.read_text())
def write(path,data):path.write_text(json.dumps(data,indent=2)+'\n')
def run(args,cwd=ROOT):
 print('+',' '.join(map(str,args)),flush=True)
 result=subprocess.run(list(map(str,args)),cwd=cwd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 # Godot can report script/import errors while exiting successfully.
 if result.returncode or 'SCRIPT ERROR:' in result.stdout or re.search(r'^ERROR:',result.stdout,re.M):
  print(result.stdout);raise RuntimeError('Command failed: '+str(args[0]))
 if result.stdout:print('\n'.join(result.stdout.splitlines()[-4:]))
 return result.stdout

def games():return sorted((ROOT/'games').glob('*/game.json'))
def game_dir(slug):
 if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*',slug):raise ValueError('Invalid game slug')
 p=ROOT/'games'/slug
 if not (p/'game.json').exists():raise ValueError('Unknown game: '+slug)
 return p

def source_files(game):
 for p in sorted(game.rglob('*')):
  rel=p.relative_to(game)
  if p.is_file() and not any(x in ['.godot','play','__pycache__'] for x in rel.parts) and not p.name.endswith('.blend1') and p.name not in ['build.json','.DS_Store']:
   yield p

def fingerprint(game):
 h=hashlib.sha256()
 for p in source_files(game):
  h.update(str(p.relative_to(game)).encode()+b'\0'+p.read_bytes()+b'\0')
 h.update((ROOT/'tools/toolchain.json').read_bytes())
 h.update((ROOT/'tools/build.py').read_bytes())
 h.update((ROOT/'tools/common.py').read_bytes())
 return h.hexdigest()

def file_hash(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def godot():return os.getenv('GODOT_BIN',str(pathlib.Path.home()/'.local/bin/godot'))
def blender():return os.getenv('BLENDER_BIN',str(pathlib.Path.home()/'.local/bin/blender'))

def catalog():
 write(ROOT/'web/catalog.json',{'version':(ROOT/'VERSION').read_text().strip(),'games':[read(p) for p in games()]})
