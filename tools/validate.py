#!/usr/bin/env python3
"""Validate metadata, histories and exported browser build integrity."""
import argparse,datetime,json,re,subprocess
from common import ROOT,read,games,fingerprint,file_hash,SEMVER

def versioned(directory,version):
 assert SEMVER.fullmatch(version),f'Invalid semver in {directory}'
 assert (directory/'VERSION').read_text().strip()==version,f'VERSION differs in {directory}'
 changes=read(directory/'CHANGES.json')
 assert changes and changes[0]['version']==version,f'Latest history differs in {directory}'
 seen=set()
 previous=None
 for c in changes:
  assert SEMVER.fullmatch(c['version']) and c['version'] not in seen,'Invalid or duplicate history version'
  current=tuple(map(int,c['version'].split('.')))
  assert previous is None or current<previous,'History must be newest first'
  previous=current;seen.add(c['version'])
  dt=datetime.datetime.fromisoformat(c['datetime'].replace('Z','+00:00'))
  assert dt.tzinfo is not None,'History dates need timezones'
  assert isinstance(c['description'],str) and c['description'].strip(),'History description is required'
 return changes

def validate():
 version=(ROOT/'VERSION').read_text().strip();versioned(ROOT,version)
 assert read(ROOT/'package.json')['version']==version,'package version differs'
 import tomllib
 assert tomllib.loads((ROOT/'pyproject.toml').read_text())['project']['version']==version,'tool package version differs'
 expected=[]
 for manifest in games():
  game=manifest.parent;m=read(manifest);versioned(game,m['version'])
  assert m['id']==game.name,'Game slug differs'
  assert m['entry']==f'games/{game.name}/play/','Game entry must point to the browser build'
  assert m['changes']==f'games/{game.name}/CHANGES.json','History path differs'
  assert (ROOT/m['cover']).is_file(),'Missing cover'
  assert m['controls']==['Mouse + keyboard','Xbox controller'],'Default input support is required'
  stamp=read(game/'build.json')
  assert stamp['version']==m['version'],'Build version differs'
  assert stamp['source_sha256']==fingerprint(game),f'Stale {game.name} build: run tools/build.py'
  assert {'index.html','index.js','index.wasm','index.pck'}<=stamp['files'].keys(),'Incomplete browser export'
  actual={p.name for p in (game/'play').iterdir() if p.is_file() and not p.name.startswith('.')}
  assert actual==stamp['files'].keys(),'Unrecorded or missing build files'
  for name,sha in stamp['files'].items():
   assert file_hash(game/'play'/name)==sha,f'Build file changed: {name}'
  preset=(game/'export_presets.cfg').read_text()
  assert 'variant/thread_support=false' in preset,'Pages requires single-threaded web exports'
  expected.append(m)
 assert read(ROOT/'web/catalog.json')=={'version':version,'games':expected},'Portal catalog is stale'
 assert (ROOT/'.nojekyll').exists(),'Pages should serve builds without Jekyll'
 assert not subprocess.check_output(['git','ls-files','.env'],cwd=ROOT,text=True).strip(),'Secret .env is tracked'
 print(f'Validated AgentGames {version}, {len(expected)} game(s), and all browser build hashes.')

if __name__=='__main__':
 try:validate()
 except (AssertionError,KeyError,FileNotFoundError,ValueError) as e:raise SystemExit('Validation failed: '+str(e))
