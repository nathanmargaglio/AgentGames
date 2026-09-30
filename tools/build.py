#!/usr/bin/env python3
"""Build changed games locally, keeping browser exports in the repository."""
import argparse,datetime,pathlib,shutil,tempfile
from common import ROOT,read,write,games,game_dir,fingerprint,run,godot,blender,catalog,file_hash

def build(game,force=False,assets=False):
 manifest=read(game/'game.json');stamp=game/'build.json'
 generator=game/'art/generate.py'
 asset_hash=file_hash(generator) if generator.exists() else None
 previous=read(stamp) if stamp.exists() else {}
 if generator.exists() and (assets or previous.get('asset_generation_sha256')!=asset_hash or not (game/'assets/models').exists()):
  run([blender(),'--background','--python',generator])
 if not force and stamp.exists() and read(stamp).get('source_sha256')==fingerprint(game):
  print(manifest['id']+': build is current');return
 run([godot(),'--headless','--path',game,'--editor','--import'])
 (ROOT/'artifacts').mkdir(exist_ok=True)
 with tempfile.TemporaryDirectory(dir=ROOT/'artifacts') as tmp:
  output=pathlib.Path(tmp)
  run([godot(),'--headless','--path',game,'--export-release','Web',output/'index.html'])
  html=output/'index.html'
  html.write_text(html.read_text().rstrip()+'\n')
  target=game/'play';target.mkdir(exist_ok=True)
  # Remove obsolete export files, then install the successfully built output.
  for p in target.iterdir():
   if p.is_file():p.unlink()
  for p in output.iterdir():shutil.copy2(p,target/p.name)
  (target/'.gdignore').touch()
 write(stamp,{'version':manifest['version'],'godot':'4.6.1','asset_generation_sha256':asset_hash,'source_sha256':fingerprint(game),'built_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':{p.name:file_hash(p) for p in sorted((game/'play').iterdir()) if p.is_file() and not p.name.startswith('.')}})
 print(manifest['id']+': web release built')

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);group=p.add_mutually_exclusive_group(required=True);group.add_argument('--all',action='store_true');group.add_argument('--game');p.add_argument('--force',action='store_true');p.add_argument('--assets',action='store_true',help='Regenerate Blender sources, meshes and cover before exporting');a=p.parse_args()
 for g in [x.parent for x in games()] if a.all else [game_dir(a.game)]:build(g,a.force,a.assets)
 catalog()
