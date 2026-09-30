#!/usr/bin/env python3
"""Opt-in OpenRouter audio generation; never runs as part of builds."""
import argparse, base64, datetime, json, os, pathlib, subprocess, urllib.request
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'games/debug/assets/audio'
LEDGER = ROOT / 'tools/asset-spend.json'
MODEL = 'google/lyria-3-clip-preview'
PROMPTS = {
 'music': 'Generate a 30-second instrumental loop for a playful first person bug-swatting game inside a computer server. Minimal electronic synth groove, 112 BPM, soft analog bass, tight quiet drums, curious plucked arpeggios in E minor, retro computer atmosphere. Light, focused and mischievous. No vocals, no speech, no dramatic introduction. Constant energy, clean loop-friendly ending.',
 'effects': 'Generate a sparse 30-second electronic sound-design percussion sample pack for a game. No vocals, no speech, no melody or background music. Begin immediately with a short crisp airy whoosh and plastic smack, then dry digital clicks, a squishy comic bug pop, and a bright ascending electronic success chime. Clearly isolated short one-shot sounds separated by silence, minimal background, playful computer bug-swatting effects.'
}
def key():
 value = os.getenv('OPENROUTER_API_KEY')
 if not value:
  for line in (ROOT / '.env').read_text().splitlines():
   if line.startswith('OPENROUTER_API_KEY='): value = line.split('=',1)[1].strip().strip('\"\'')
 if not value: raise SystemExit('Set OPENROUTER_API_KEY in .env.')
 return value

def request(path, data=None):
 headers={'Authorization':'Bearer '+key(),'Content-Type':'application/json','X-Title':'AgentGames local assets'}
 req=urllib.request.Request('https://openrouter.ai/api/v1/'+path, data=json.dumps(data).encode() if data else None,headers=headers)
 return urllib.request.urlopen(req, timeout=180)

def generate(kind):
 OUT.mkdir(parents=True, exist_ok=True)
 ledger=json.loads(LEDGER.read_text()) if LEDGER.exists() else []
 month=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m')
 spent=sum(x['reserved_usd'] for x in ledger if x['datetime'].startswith(month))
 if spent+0.04>min(1.0,10.0): raise SystemExit('Local $1/month asset-generation cap reached. Ask the owner before raising it.')
 account=json.load(request('key'))['data']
 if float(account.get('usage_monthly',0))+0.04>10: raise SystemExit('Account monthly $10 budget reached.')
 item={'datetime':datetime.datetime.now(datetime.timezone.utc).isoformat(),'model':MODEL,'kind':kind,'reserved_usd':0.04,'status':'pending','prompt':PROMPTS[kind]}
 ledger.append(item);LEDGER.write_text(json.dumps(ledger,indent=2)+'\n')
 audio=[];generation_id=None;usage=None
 try:
  payload={'model':MODEL,'messages':[{'role':'user','content':PROMPTS[kind]}],'modalities':['text','audio'],'audio':{'format':'wav'},'stream':True}
  with request('chat/completions',payload) as response:
   for raw in response:
    line=raw.decode().strip()
    if not line.startswith('data: ') or line=='data: [DONE]': continue
    event=json.loads(line[6:])
    if event.get('error'): raise RuntimeError(str(event['error']))
    generation_id=event.get('id',generation_id);usage=event.get('usage',usage)
    for choice in event.get('choices',[]):
     delta=choice.get('delta',{})
     if delta.get('audio',{}).get('data'): audio.append(base64.b64decode(delta['audio']['data']))
     for part in delta.get('content',[]) if isinstance(delta.get('content'),list) else []:
      if part.get('type')=='audio' and part.get('audio',{}).get('data'): audio.append(base64.b64decode(part['audio']['data']))
  if not audio: raise RuntimeError('Provider returned no audio.')
  temp=ROOT/'artifacts';temp.mkdir(exist_ok=True)
  rawfile=temp/(kind+'.wav');rawfile.write_bytes(b''.join(audio))
  if kind=='music':
   subprocess.run(['ffmpeg','-y','-v','error','-i',str(rawfile),'-af','afade=t=in:d=0.08,afade=t=out:st=29.7:d=0.3','-c:a','libvorbis','-q:a','3',str(OUT/'music.ogg')],check=True)
  else:
   # Short samples derived directly from the generated sound-design clip.
   for name,start,duration in [('swat',0,0.45),('hit',2,0.35),('clear',5,0.8)]:
    subprocess.run(['ffmpeg','-y','-v','error','-ss',str(start),'-i',str(rawfile),'-t',str(duration),'-af','afade=t=out:st='+str(duration-0.07)+':d=0.07','-ac','1','-ar','22050',str(OUT/(name+'.wav'))],check=True)
  item.update(status='complete',generation_id=generation_id,usage=usage,files=['music.ogg'] if kind=='music' else ['swat.wav','hit.wav','clear.wav'])
  after=json.load(request('key'))['data']
  item['actual_account_delta_usd']=round(float(after.get('usage',0))-float(account.get('usage',0)),8)
  print(kind,'saved;',item['actual_account_delta_usd'],'USD account delta')
 except Exception as e:
  item.update(status='failed',error=str(e));raise
 finally: LEDGER.write_text(json.dumps(ledger,indent=2)+'\n')

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('kind',choices=PROMPTS);args=p.parse_args();generate(args.kind)
