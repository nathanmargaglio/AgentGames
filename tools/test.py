#!/usr/bin/env python3
"""Run metadata/build integrity checks and headless gameplay tests."""
from common import ROOT,run,godot,games
from validate import validate
if __name__=='__main__':
 validate()
 for manifest in games():
  game=manifest.parent;test=game/'tests/smoke.gd'
  if test.exists():run([godot(),'--headless','--path',game,'--script',test])
 run(['python3','-m','unittest','discover','-s','tests','-p','test_*.py'])
