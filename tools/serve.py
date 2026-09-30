#!/usr/bin/env python3
"""Serve the project locally with the same subpath as GitHub Pages."""
import argparse,functools,http.server
from common import ROOT
class Handler(http.server.SimpleHTTPRequestHandler):
 def translate_path(self,path):
  if path.startswith('/AgentGames/'):
   path=path[len('/AgentGames'):]
  return super().translate_path(path)
 def end_headers(self):
  self.send_header('Cache-Control','no-cache');super().end_headers()
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8000);a=p.parse_args()
 print(f'http://localhost:{a.port}/AgentGames/',flush=True)
 http.server.ThreadingHTTPServer(('127.0.0.1',a.port),functools.partial(Handler,directory=str(ROOT))).serve_forever()
