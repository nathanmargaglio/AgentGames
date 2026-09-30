#!/usr/bin/env python3
"""Install the pinned Playwright Chromium via its published archive on Linux."""
import json,pathlib,subprocess,zipfile
from common import ROOT
HOME=pathlib.Path.home()
def install():
 cfg=json.loads((ROOT/'node_modules/playwright-core/browsers.json').read_text())
 revision=next(b['revision'] for b in cfg['browsers'] if b['name']=='chromium')
 dest=HOME/'.cache/ms-playwright'/('chromium-'+revision)
 executable=dest/'chrome-linux/chrome'
 if (dest/'INSTALLATION_COMPLETE').exists() and executable.exists():return
 archive=HOME/'.local/share/agentgames/downloads'/('chromium-'+revision+'.zip');archive.parent.mkdir(parents=True,exist_ok=True)
 if not archive.exists():
  subprocess.run(['curl','-fL','-sS','--retry','3',f'https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/{revision}/chromium-linux.zip','-o',str(archive)],check=True)
 with zipfile.ZipFile(archive) as z:
  z.extractall(dest)
  for member in z.infolist():
   path=dest/member.filename
   mode=(member.external_attr>>16)&0o777
   if path.is_file() and mode:path.chmod(mode)
 (dest/'INSTALLATION_COMPLETE').touch()
 print('Installed Chromium',revision)
if __name__=='__main__':install()
