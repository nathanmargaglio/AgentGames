#!/usr/bin/env python3
"""Serve locally, or over LAN HTTPS, with the same subpath as GitHub Pages."""
import argparse,functools,http.server,pathlib,shutil,socket,ssl,subprocess,tempfile,urllib.parse
from common import ROOT
class Handler(http.server.SimpleHTTPRequestHandler):
 def translate_path(self,path):
  if path.startswith('/AgentGames/'):
   path=path[len('/AgentGames'):]
  return super().translate_path(path)
 def send_head(self):
  parts=pathlib.PurePosixPath(urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)).parts
  if any(part.startswith('.') or part in {'artifacts','node_modules','__pycache__'} for part in parts):
   self.send_error(404);return None
  return super().send_head()
 def list_directory(self,path):
  self.send_error(404);return None
 def end_headers(self):
  self.send_header('Cache-Control','no-cache');super().end_headers()

def lan_addresses():
 addresses=set()
 try:
  addresses.update(info[4][0] for info in socket.getaddrinfo(socket.gethostname(),None,socket.AF_INET))
 except socket.gaierror:
  pass
 # A UDP connect selects the default interface without sending traffic.
 try:
  with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as probe:
   probe.connect(('192.0.2.1',9));addresses.add(probe.getsockname()[0])
 except OSError:
  pass
 return sorted(ip for ip in addresses if not ip.startswith('127.') and ip!='0.0.0.0')

def serve(port,lan):
 if lan and not shutil.which('openssl'):
  raise SystemExit('LAN HTTPS needs openssl. Install it, or test on localhost without --lan.')
 addresses=lan_addresses() if lan else []
 with tempfile.TemporaryDirectory(prefix='agentgames-tls-') as directory:
  server=http.server.ThreadingHTTPServer(('0.0.0.0' if lan else '127.0.0.1',port),functools.partial(Handler,directory=str(ROOT)))
  try:
   if lan:
    # Keep the private key outside the served repository, then remove it on exit.
    cert=pathlib.Path(directory)/'certificate.pem';key=pathlib.Path(directory)/'private-key.pem'
    names=','.join(['DNS:localhost','IP:127.0.0.1',*[f'IP:{ip}' for ip in addresses]])
    result=subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-noenc','-keyout',str(key),'-out',str(cert),'-days','7','-subj','/CN=AgentGames local test','-addext','subjectAltName='+names],capture_output=True,text=True)
    if result.returncode:raise SystemExit('Could not generate the local HTTPS certificate: '+result.stderr)
    context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key)
    server.socket=context.wrap_socket(server.socket,server_side=True)
   port=server.server_address[1]
   scheme='https' if lan else 'http'
   print(f'{scheme}://localhost:{port}/AgentGames/',flush=True)
   for ip in addresses:print(f'LAN: https://{ip}:{port}/AgentGames/',flush=True)
   if lan:
    print('Local HTTPS: accept the self-signed certificate warning in each test browser.',flush=True)
    print('Both players open the same LAN URL, then exchange the invitation and answer.',flush=True)
   server.serve_forever()
  except KeyboardInterrupt:
   pass
  finally:
   server.server_close()

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8000);p.add_argument('--lan',action='store_true',help='Serve LAN HTTPS and print local IP links for a second computer');a=p.parse_args()
 serve(a.port,a.lan)
