import json,pathlib,sys,tempfile,unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'tools'))
from common import fingerprint,write
from release import bump
from validate import versioned
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
