import functools,http.server,json,pathlib,sys,tempfile,threading,unittest,urllib.error,urllib.request
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from common import fingerprint,write
from release import bump
from validate import versioned
from serve import Handler
class PipelineTest(unittest.TestCase):
 def test_semver(self):
  self.assertEqual(bump('1.2.3','patch'),'1.2.4');self.assertEqual(bump('1.2.3','minor'),'1.3.0');self.assertEqual(bump('1.2.3','major'),'2.0.0')
 def test_history_rejects_missing_timezone_and_duplicates(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);(p/'VERSION').write_text('0.1.0')
   entry={'version':'0.1.0','datetime':'2026-09-30T20:00:00Z','description':'Initial'}
   write(p/'CHANGES.json',[entry]);versioned(p,'0.1.0')
   write(p/'CHANGES.json',[entry,entry])
   with self.assertRaises(AssertionError):versioned(p,'0.1.0')
   entry['datetime']='2026-09-30T20:00:00';write(p/'CHANGES.json',[entry])
   with self.assertRaises(AssertionError):versioned(p,'0.1.0')
 def test_fingerprint_detects_source_change_ignores_export(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);(p/'src').mkdir();(p/'src/main.gd').write_text('extends Node');a=fingerprint(p)
   (p/'play').mkdir();(p/'play/index.html').write_text('build');self.assertEqual(a,fingerprint(p))
   (p/'src/main.gd').write_text('extends Node3D');self.assertNotEqual(a,fingerprint(p))

 def test_lan_handler_serves_game_files_and_blocks_private_paths(self):
  class QuietHandler(Handler):
   def log_message(self,*args):pass
  with tempfile.TemporaryDirectory() as directory:
   root=pathlib.Path(directory)
   (root/'index.html').write_text('public game portal')
   (root/'.env').write_text('private test fixture')
   (root/'artifacts').mkdir();(root/'artifacts/report.txt').write_text('private test fixture')
   (root/'games').mkdir()
   server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(QuietHandler,directory=directory))
   worker=threading.Thread(target=server.serve_forever,daemon=True);worker.start()
   try:
    base=f'http://127.0.0.1:{server.server_address[1]}/'
    with urllib.request.urlopen(base+'AgentGames/index.html') as response:
     self.assertEqual(response.read(),b'public game portal')
    for path in ['.env','AgentGames/%2eenv','AgentGames/.git/config','AgentGames/artifacts/report.txt','AgentGames/games/']:
     with self.subTest(path=path),self.assertRaises(urllib.error.HTTPError) as error:
      urllib.request.urlopen(base+path)
     self.assertEqual(error.exception.code,404)
   finally:
    server.shutdown();worker.join();server.server_close()
