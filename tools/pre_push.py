#!/usr/bin/env python3
"""Reject stale, unversioned main pushes before GitHub Pages can serve them."""
import subprocess,sys
from common import ROOT,read,games
from validate import validate

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()

def check():
 lines=[line.split() for line in sys.stdin if line.strip()]
 targets={line[2] for line in lines}
 for local_ref,local_sha,remote_ref,remote_sha in lines:
  if remote_ref!='refs/heads/main' or local_sha=='0'*40:continue
  assert local_sha==git('rev-parse','HEAD'),'Push main from its checked-out release commit'
  assert not git('status','--porcelain'),'Commit all project changes before publishing'
  validate();version=(ROOT/'VERSION').read_text().strip()
  assert git('rev-parse','v'+version+'^{}')==local_sha,'Current AgentGames tag must point to this commit'
  assert 'refs/tags/v'+version in targets,'Push the current AgentGames tag together with main'
  if remote_sha!='0'*40:
   result=subprocess.run(['git','show',remote_sha+':VERSION'],cwd=ROOT,capture_output=True,text=True)
   if result.returncode==0:assert result.stdout.strip()!=version,'Every main push must bump AgentGames'
  for path in games():
   slug=path.parent.name;changed=True
   if remote_sha!='0'*40:
    previous=subprocess.run(['git','show',remote_sha+':games/'+slug+'/build.json'],cwd=ROOT,capture_output=True,text=True)
    if previous.returncode==0:
     import json
     old=json.loads(previous.stdout);new=read(path.parent/'build.json');changed=old['source_sha256']!=new['source_sha256']
     if changed:assert old['version']!=new['version'],f'Changed {slug} requires a game version bump'
   if changed:
    tag=slug+'/v'+read(path)['version']
    assert git('rev-parse',tag+'^{}')==local_sha,f'Tag changed game: {tag}'
    assert 'refs/tags/'+tag in targets,f'Push changed game tag with main: {tag}'
  print('Release gate passed. Push with tools/release.py to include version tags.')
if __name__=='__main__':
 try:check()
 except (AssertionError,subprocess.CalledProcessError,FileNotFoundError) as e:raise SystemExit('Push rejected: '+str(e))
