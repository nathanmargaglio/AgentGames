import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
const delay = ms => new Promise(resolve => setTimeout(resolve,ms));
const state = page => page.evaluate(() => window.agentgamesState);
async function aimAndSwat(page) {
  const game = await state(page);
  if (game.mode !== 'playing' || !game.bug_state.length) return;
  const nearest = game.bug_state.reduce((best,bug) => {
    const distance = (bug.p[0]-game.position[0])**2+(bug.p[2]-game.position[2])**2;
    return distance < best.distance ? {distance,bug} : best;
  }, {distance:Infinity}).bug;
  const dx = nearest.p[0]-game.position[0], dz = nearest.p[2]-game.position[2];
  const yaw = Math.atan2(-dx,-dz), pitch = Math.atan2(nearest.p[1]-game.position[1]-.65,Math.hypot(dx,dz));
  const error = Math.atan2(Math.sin(yaw-game.rotation[0]),Math.cos(yaw-game.rotation[0]));
  const clamp = value => Math.max(-1,Math.min(1,value));
  await page.evaluate(({move,x,y})=>{
    window.coopPad.axes = [0,move,x,y];
    window.coopPad.buttons[7] = {pressed:true,touched:true,value:1};
  },{move:Math.abs(error)<.4 && Math.hypot(dx,dz)>2 ? -.7 : 0,x:clamp(-error*2.5),y:clamp(-(pitch-game.rotation[1])*2.5)});
}
const waitMode = (page,mode) => page.waitForFunction(mode => window.agentgamesState?.mode === mode,mode,{timeout:60000});
export async function testCoop(browser,base,errors,{ignoreHTTPSErrors=false,network="auto"}={}) {
  // Separate browser windows allow both game canvases to stay focused during co-op.
  const guestBrowser = await chromium.launch({channel:'chromium',headless:true,args:['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const hostContext = await browser.newContext({viewport:{width:1440,height:900},ignoreHTTPSErrors,permissions:['clipboard-read','clipboard-write']});
  const guestContext = await guestBrowser.newContext({viewport:{width:1440,height:900},ignoreHTTPSErrors,permissions:['clipboard-read','clipboard-write']});
  for (const context of [hostContext,guestContext]) {
    await context.addInitScript(({lan})=>{
      const NativeConnection = window.RTCPeerConnection;
      window.rtcConfigurations = [];
      window.RTCPeerConnection = class extends NativeConnection {
        constructor(configuration={}) {
          if (lan && configuration.iceServers?.length) throw new Error('LAN attempted public address discovery');
          super(configuration);
          window.rtcConfigurations.push(JSON.parse(JSON.stringify(configuration)));
        }
      };
    },{lan:network==='lan'});
  }
  const host = await hostContext.newPage(), guest = await guestContext.newPage();
  try {
    for (const page of [host,guest]) {
      page.on('pageerror',e=>errors.push(e.message));
      page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
    }
    const url = new URL('games/debug/play/',base).href;
    console.log(`Browser: co-op pairing (${network})`);
    await host.goto(url); await waitMode(host,'title');
    await host.locator('#canvas').focus();
    await host.keyboard.press('ArrowDown'); await host.keyboard.press('Enter');
    await waitMode(host,'lobby');
    assert.equal(await host.evaluate(()=>window.rtcConfigurations.length),0,'Host chooses a mode before address discovery');
    if (network === 'lan') await host.locator('#coop-lan').click();
    await host.waitForFunction(network=>window.agentgamesState.network===network,network);
    await host.screenshot({path:`artifacts/debug-coop-${network}-setup.png`});
    await host.locator('#coop-invite').click();
    await host.waitForFunction(()=>document.getElementById('coop-output')?.value.length>0,null,{timeout:30000});
    const offer = await host.locator('#coop-output').inputValue();
    assert.equal(JSON.parse(offer).type,'offer');
    assert.equal(JSON.parse(offer).network,network);
    assert.ok(JSON.parse(offer).candidates.length>0,'Invitation bundles ICE network addresses');
    await host.locator('#coop-copy-link').click();
    const link = await host.evaluate(()=>navigator.clipboard.readText());
    assert.ok(link.includes('#invite='));
    await guest.goto(link); await waitMode(guest,'lobby');
    assert.equal(await guest.evaluate(()=>location.hash),'','Private invitation removed from URL');
    await guest.waitForFunction(()=>document.getElementById('coop-output')?.value.length>0,null,{timeout:30000});
    await guest.locator('#coop-copy').click();
    const answer = await guest.evaluate(()=>navigator.clipboard.readText());
    assert.equal(JSON.parse(answer).type,'answer');
    assert.equal(JSON.parse(answer).network,network,'Guest inherits the invitation mode');
    for (const page of [host,guest]) {
      const configurations=await page.evaluate(()=>window.rtcConfigurations);
      assert.ok(configurations.length>0);
      if (network==='lan') assert.ok(configurations.every(config=>!config.iceServers?.length),'LAN initializes no public discovery servers');
      else assert.ok(configurations.some(config=>config.iceServers?.length),'Automatic retains public address discovery');
    }
    if (network==='lan') {
      for (const code of [offer,answer]) assert.ok(JSON.parse(code).candidates.every(candidate=>candidate.candidate.split(' ')[7]==='host'),'LAN offers only local interface candidates');
    }
    await host.locator('#coop-input').fill('invalid code');
    await host.locator('#coop-connect').click();
    await host.waitForFunction(()=>document.getElementById('coop-status').textContent.includes('Invalid code'));
    const mismatched=JSON.parse(answer); mismatched.network=network==='lan'?'auto':'lan';
    await host.locator('#coop-input').fill(JSON.stringify(mismatched)); await host.locator('#coop-connect').click();
    await host.waitForFunction(()=>document.getElementById('coop-status').textContent.includes('Connection modes do not match'));
    await host.locator('#coop-input').fill(answer); await host.locator('#coop-connect').click();
    await Promise.all([host,guest].map(page=>page.waitForFunction(()=>window.agentgamesState?.connected,null,{timeout:60000})));
    assert.equal(await host.locator('#coop-start').isDisabled(),true,'Host waits for guest readiness');
    await guest.locator('#coop-ready').click();
    await host.waitForFunction(()=>!document.getElementById('coop-start').disabled);
    await host.screenshot({path:'artifacts/debug-coop-connected.png'});
    await host.locator('#coop-start').click();
    await Promise.all([waitMode(host,'playing'),waitMode(guest,'playing')]);
    for (const page of [host,guest]) {
      const initial = await state(page);
      assert.equal(initial.bugs,9,'Co-op has nine first-round bugs'); assert.equal(initial.wave,1);
      assert.equal(initial.teammate.length,3,'Teammate is visible');
    }
    // Each agent walks forward and uses the real swat input. Both kills reach the same host state.
    await guest.locator('#canvas').click({position:{x:720,y:450}});
    await Promise.all([host.keyboard.down('w'),guest.keyboard.down('w')]); await delay(700);
    await Promise.all([host.keyboard.up('w'),guest.keyboard.up('w')]);
    await Promise.all([host.mouse.down(),guest.mouse.down()]);
    await host.waitForFunction(()=>window.agentgamesState?.kills.every(count=>count>0),null,{timeout:30000});
    await guest.waitForFunction(()=>window.agentgamesState?.kills.every(count=>count>0),null,{timeout:30000});
    console.log('Browser: both agents swat; shared score and bugs');
    await Promise.all([host.mouse.up(),guest.mouse.up()]);
    // Pause, inspect an exactly frozen shared snapshot, then resume both agents.
    if ((await state(guest)).mode === 'playing') {
      await guest.keyboard.press('Escape');
      await Promise.all([waitMode(host,'paused'),waitMode(guest,'paused')]);
      await delay(350);
      const paused = await state(host), mirrored = await state(guest);
      assert.equal(mirrored.score,paused.score); assert.equal(mirrored.bugs,paused.bugs);
      assert.deepEqual(mirrored.kills,paused.kills);
      await delay(800);
      assert.equal((await state(host)).remaining,paused.remaining,'Guest pause stops host clock');
      await guest.keyboard.press('Enter'); await Promise.all([waitMode(host,'playing'),waitMode(guest,'playing')]);
    }
    // Use actual emulated gamepad aim/movement to pursue stragglers and finish the round.
    for (const page of [host,guest]) {
      await page.evaluate(()=>{
        window.coopPad = {id:'Xbox 360 Controller (XInput STANDARD GAMEPAD)',index:0,connected:true,mapping:'standard',axes:[0,0,0,0],buttons:Array.from({length:17},()=>({pressed:false,touched:false,value:0})),timestamp:0};
        Object.defineProperty(navigator,'getGamepads',{value:()=>{window.coopPad.timestamp=performance.now();return [window.coopPad]}});
        const event = new Event('gamepadconnected'); Object.defineProperty(event,'gamepad',{value:window.coopPad}); window.dispatchEvent(event);
      });
    }
    for (let step=0;step<160 && (await state(host)).mode==='playing';step++) {
      await Promise.all([aimAndSwat(host),aimAndSwat(guest)]); await delay(120);
    }
    for (const page of [host,guest]) await page.evaluate(()=>{window.coopPad.axes=[0,0,0,0];window.coopPad.buttons[7]={pressed:false,touched:false,value:0};});
    assert.equal((await state(host)).mode,'upgrade','Both real input agents can clear the round');
    await waitMode(guest,'upgrade');
    assert.equal((await state(guest)).bugs,0);
    assert.equal((await state(host)).score,(await state(guest)).score);
    await host.screenshot({path:'artifacts/debug-coop-upgrade.png'});
    await host.keyboard.press('1');
    await Promise.all([host,guest].map(page=>page.waitForFunction(()=>window.agentgamesState?.wave===2 && window.agentgamesState.power===2)));
    assert.equal((await state(guest)).bugs,12,'Co-op wave two scales to twelve bugs');
    // Host focus loss must pause both and survive until the host explicitly resumes.
    await host.evaluate(()=>window.dispatchEvent(new Event('blur')));
    await Promise.all([waitMode(host,'paused'),waitMode(guest,'paused')]);
    await host.keyboard.press('Enter'); await Promise.all([waitMode(host,'playing'),waitMode(guest,'playing')]);
    await guest.screenshot({path:'artifacts/debug-coop-playing.png'});
    await guest.close(); await waitMode(host,'disconnected');
    const stopped = (await state(host)).remaining; await delay(500);
    assert.equal((await state(host)).remaining,stopped,'Disconnect stops the run');
    await host.keyboard.press('Enter'); await waitMode(host,'lobby');
    assert.equal((await state(host)).network,network,'Retry keeps the chosen mode');
    await host.locator('#coop-invite').click();
    await host.waitForFunction(()=>document.getElementById('coop-output')?.value.length>0,null,{timeout:30000});
    assert.notEqual(await host.locator('#coop-output').inputValue(),offer,'Retry makes a fresh invitation');
    await host.locator('#coop-leave').click(); await waitMode(host,'title');
    assert.equal((await state(host)).role,'solo');
    console.log(`Browser: co-op ${network} PASS (private link/code pairing, readiness, both swat, shared waves/upgrades, guest pause, focus pause, disconnect/retry).`);
  } catch (error) {
    for (const [name,page] of [['host',host],['guest',guest]]) if (!page.isClosed()) { console.log(name,await state(page)); await page.screenshot({path:`artifacts/debug-coop-failure-${name}.png`}); }
    throw error;
  } finally { await hostContext.close(); await guestContext.close(); await guestBrowser.close(); }
}
