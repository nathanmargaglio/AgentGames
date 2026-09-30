#!/usr/bin/env python3
"""Version, rebuild, test, commit, tag, and optionally push a release."""
import argparse,datetime,json,subprocess
from common import ROOT,read,write,run,games,game_dir,fingerprint,catalog
from build import build
from validate import validate

def bump(version,kind):
 parts=list(map(int,version.split('.')));index=['major','minor','patch'].index(kind);parts[index]+=1
 for j in range(index+1,3):parts[j]=0
 return '.'.join(map(str,parts))

def change(directory,kind,message):
 version=bump((directory/'VERSION').read_text().strip(),kind)
 (directory/'VERSION').write_text(version+'\n')
 entries=read(directory/'CHANGES.json');entries.insert(0,{'version':version,'datetime':datetime.datetime.now(datetime.timezone.utc).isoformat(),'description':message});write(directory/'CHANGES.json',entries)
 return version

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--bump',choices=['major','minor','patch'],default='patch');p.add_argument('--game',action='append',default=[],metavar='SLUG:initial|patch|minor|major');p.add_argument('--message',required=True);p.add_argument('--initial',action='store_true');p.add_argument('--push',action='store_true');a=p.parse_args()
 assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()=='main','Publish releases from main. Use feature branches for experiments.'
 current=(ROOT/'VERSION').read_text().strip()
 assert not (a.initial and subprocess.run(['git','rev-parse','--verify','refs/tags/v'+current],cwd=ROOT,capture_output=True).returncode==0),'Initial release already exists'
 updated={}
 for entry in a.game:
  slug,kind=entry.split(':');assert kind in ['initial','major','minor','patch'],'Invalid game bump';game_dir(slug);updated[slug]=kind
 if not a.initial:
  for path in games():
   game=path.parent;stamp=game/'build.json'
   if (not stamp.exists() or read(stamp)['source_sha256']!=fingerprint(game)) and game.name not in updated:
    raise SystemExit(f'{game.name} changed; include --game {game.name}:patch (or minor/major).')
  version=change(ROOT,a.bump,a.message)
  package=read(ROOT/'package.json');package['version']=version;write(ROOT/'package.json',package)
  lock=read(ROOT/'package-lock.json');lock['version']=version;lock['packages']['']['version']=version;write(ROOT/'package-lock.json',lock)
  project=ROOT/'pyproject.toml';project.write_text(project.read_text().replace(f'version = "{current}"',f'version = "{version}"'))
  run(['uv','lock'])
  for slug,kind in updated.items():
   game=game_dir(slug)
   if kind=='initial':
    assert not subprocess.check_output(['git','tag','--list',slug+'/v*'],cwd=ROOT,text=True).strip(),'Game is already released'
   else:
    version_=change(game,kind,a.message);meta=read(game/'game.json');meta['version']=version_;write(game/'game.json',meta)
 else:
  updated={p.parent.name:'initial' for p in games()}
  now=datetime.datetime.now(datetime.timezone.utc).isoformat()
  for directory in [ROOT,*[p.parent for p in games()]]:
   entries=read(directory/'CHANGES.json');entries[0]['datetime']=now;write(directory/'CHANGES.json',entries)
 for path in games():build(path.parent)
 catalog();validate();run(['python3','tools/test.py']);run(['node','tests/browser.mjs'])
 # Stage only the repository project files; .env and ignored artifacts stay local.
 run(['git','add','--all'])
 run(['git','diff','--cached','--check'])
 run(['git','commit','-m',f'Release AgentGames {(ROOT/"VERSION").read_text().strip()}: {a.message}'])
 version=(ROOT/'VERSION').read_text().strip();tags=['v'+version]
 for slug in updated:tags.append(slug+'/v'+read(game_dir(slug)/'game.json')['version'])
 for tag in tags:run(['git','tag','-a',tag,'-m',tag])
 if a.push:run(['git','push','--atomic','origin','main',*['refs/tags/'+tag for tag in tags]])
 print('Release ready:',', '.join(tags))
if __name__=='__main__':main()
