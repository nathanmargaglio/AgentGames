import {chromium} from '@playwright/test';
import {testCoop} from './browser-coop.mjs';
import {spawn} from 'node:child_process';
import {mkdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
const external = process.env.AGENTGAMES_TEST_URL;
const port = 8873;
const base = external || `http://127.0.0.1:${port}/AgentGames/`;
const server = external ? null : spawn('python3',['tools/serve.py','--port',String(port)],{stdio:'ignore'});
let browser;
async function delay(ms) { await new Promise(r=>setTimeout(r,ms)); }
try {
  if(server) { for(let i=0;i<40;i++){ try { if((await fetch(base)).ok)break; }catch{} await delay(100); } }
  await mkdir('artifacts',{recursive:true});
  browser = await chromium.launch({channel:'chromium',headless:true,args:['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const page = await browser.newPage({viewport:{width:1440,height:1000}}), errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{ if(m.type()==='error')errors.push(m.text()); });
  page.on('response',r=>{if(r.status()>=400)errors.push(`${r.status()} ${r.url()}`)});
  console.log('Browser: portal');
  await page.goto(base);
  await page.waitForSelector('.game-card');
  await page.locator('.game-art img').evaluate(image=>image.decode());
  assert.equal(await page.locator('#portal-version').textContent(),`v${(await (await fetch(new URL('web/catalog.json',base))).json()).version}`);
  await page.screenshot({path:'artifacts/portal.png',fullPage:true});
  await page.locator('#search').fill('no such game');
  assert.match(await page.locator('#game-list').textContent(),/No games match/);
  await page.locator('#search').fill('debug');
  await page.locator('.game-version').click();
  await page.waitForFunction(()=>document.getElementById('change-list').textContent.includes('First playable'));
  assert.match(await page.locator('#change-source option:checked').textContent(),/Debug/);
  // Exercise real pagination using a fixture; production initially has one release.
  if(!external) {
    await page.route('**/CHANGES.json',route=>route.fulfill({json:Array.from({length:9},(_,i)=>({version:`0.1.${9-i}`,datetime:'2026-09-30T20:00:00Z',description:`Fixture ${i}`}))}));
    await page.locator('#change-source').selectOption('CHANGES.json');
    await page.waitForFunction(()=>document.getElementById('page-info').textContent==='Page 1 of 3');
    await page.locator('#next').click(); assert.equal(await page.locator('#page-info').textContent(),'Page 2 of 3');
    await page.locator('#next').click(); assert.equal(await page.locator('.change').count(),1);
    assert.equal(await page.locator('#next').isDisabled(),true);
    await page.locator('#previous').click();assert.equal(await page.locator('.change').count(),4);
    await page.unroute('**/CHANGES.json');
  }
  await page.setViewportSize({width:390,height:844});
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),true);
  await page.screenshot({path:'artifacts/portal-mobile.png',fullPage:true});
  await page.setViewportSize({width:1440,height:900});
  console.log('Browser: keyboard/mouse game');
  await page.locator('.play').click();
  await page.waitForFunction(()=>window.agentgamesState?.mode==='title',null,{timeout:90000});
  await page.screenshot({path:'artifacts/debug-title.png'});
  await page.locator('#canvas').focus();await page.keyboard.press('Enter');
  await page.waitForFunction(()=>window.agentgamesState?.mode==='playing');
  const initial=await page.evaluate(()=>window.agentgamesState);
  assert.equal(initial.wave,1);assert.equal(initial.bugs,6);
  await page.waitForFunction(()=>document.pointerLockElement!==null);
  await page.keyboard.down('w');await delay(700);await page.keyboard.up('w');await delay(350);
  const moved=await page.evaluate(()=>window.agentgamesState);
  assert.ok(moved.position[2]<initial.position[2]-1,'W moves forward');
  const yaw=moved.rotation[0];await page.mouse.move(820,450);await delay(350);
  assert.notEqual((await page.evaluate(()=>window.agentgamesState)).rotation[0],yaw,'Mouse turns camera');
  // Turn back toward the aisle, and hold the real swat input while bugs approach.
  await page.mouse.move(720,450);await page.mouse.down();
  await page.waitForFunction(()=>window.agentgamesState?.score>0,null,{timeout:30000});
  await page.mouse.up();
  await page.screenshot({path:'artifacts/debug-playing.png'});
  if ((await page.evaluate(()=>window.agentgamesState.mode))==='playing') {
    await page.keyboard.press('Escape');await page.waitForFunction(()=>window.agentgamesState?.mode==='paused');
    const stopped=(await page.evaluate(()=>window.agentgamesState)).remaining;await delay(800);
    assert.equal((await page.evaluate(()=>window.agentgamesState)).remaining,stopped,'Pause stops the clock');
    await page.keyboard.press('Enter');await page.waitForFunction(()=>window.agentgamesState?.mode==='playing');
  }
  // Fresh browser context with the standard Xbox Gamepad API shape.
  console.log('Browser: Xbox gamepad');
  await page.close();
  const padContext = await browser.newContext({viewport:{width:1440,height:900}});
  await padContext.addInitScript(()=>{
    window.testPad={id:'Xbox 360 Controller (XInput STANDARD GAMEPAD)',index:0,connected:true,mapping:'standard',axes:[0,0,0,0],buttons:Array.from({length:17},()=>({pressed:false,touched:false,value:0})),timestamp:0};
    Object.defineProperty(navigator,'getGamepads',{value:()=>{window.testPad.timestamp=performance.now();return [window.testPad]}});
    window.padButton=(index,down)=>{window.testPad.buttons[index]={pressed:down,touched:down,value:down?1:0}};
  });
  const padPage = await padContext.newPage();padPage.on('pageerror',e=>errors.push(e.message));
  await padPage.goto(new URL('games/debug/play/',base).href);
  await padPage.waitForFunction(()=>window.agentgamesState?.mode==='title',null,{timeout:90000});
  await padPage.evaluate(()=>{const event=new Event('gamepadconnected');Object.defineProperty(event,'gamepad',{value:window.testPad});window.dispatchEvent(event);window.padButton(0,true)});
  await delay(300);await padPage.evaluate(()=>window.padButton(0,false));
  await padPage.waitForFunction(()=>window.agentgamesState?.mode==='playing');
  console.log('Browser: Xbox A starts game');
  const padStart=await padPage.evaluate(()=>window.agentgamesState);
  await padPage.evaluate(()=>{window.testPad.axes[1]=-1;window.testPad.axes[2]=0.45});await delay(900);
  await padPage.evaluate(()=>window.testPad.axes=[0,0,0,0]);await delay(350);
  const padMoved=await padPage.evaluate(()=>window.agentgamesState);
  assert.ok(padMoved.position[2]<padStart.position[2]-1,'Xbox left stick moves');
  assert.notEqual(padMoved.rotation[0],padStart.rotation[0],'Xbox right stick looks');
  await padPage.evaluate(()=>window.testPad.axes[2]=-0.45);await delay(900);
  await padPage.evaluate(()=>{window.testPad.axes[2]=0;window.padButton(7,true)});
  await padPage.waitForFunction(()=>window.agentgamesState?.score>0,null,{timeout:30000});
  await padPage.evaluate(()=>window.padButton(7,false));
  console.log('Browser: Xbox sticks and RT swat pass');
  await padPage.evaluate(()=>window.padButton(9,true));await delay(300);await padPage.evaluate(()=>window.padButton(9,false));
  await padPage.waitForFunction(()=>window.agentgamesState?.mode==='paused');
  await padPage.evaluate(()=>window.padButton(0,true));await delay(300);await padPage.evaluate(()=>window.padButton(0,false));
  await padPage.waitForFunction(()=>window.agentgamesState?.mode==='playing');
  // Xbox also selects Host co-op and navigates/cancels the native pairing controls.
  async function pulsePad(index) {
    await padPage.evaluate(index=>window.padButton(index,true),index); await delay(180);
    await padPage.evaluate(index=>window.padButton(index,false),index); await delay(180);
  }
  await pulsePad(9); await padPage.waitForFunction(()=>window.agentgamesState?.mode==='paused');
  await pulsePad(13); await pulsePad(13); await pulsePad(0);
  await padPage.waitForFunction(()=>window.agentgamesState?.mode==='over');
  await pulsePad(13); await pulsePad(0);
  await padPage.waitForFunction(()=>window.agentgamesState?.mode==='title');
  await pulsePad(13); await pulsePad(0);
  await padPage.waitForFunction(()=>window.agentgamesState?.mode==='lobby');
  const beforeFocus = await padPage.evaluate(()=>document.activeElement.id);
  await pulsePad(13);
  assert.notEqual(await padPage.evaluate(()=>document.activeElement.id),beforeFocus,'Xbox navigates pairing controls');
  await pulsePad(1); await padPage.waitForFunction(()=>window.agentgamesState?.mode==='title');
  console.log('Browser: Xbox co-op menus pass');
  await padContext.close();
  await testCoop(browser,base,errors);
  assert.deepEqual(errors,[],`Browser errors: ${errors.join('\n')}`);
  console.log('Browser checks: PASS (portal, mobile layout, histories, pagination, WebGL, keyboard/mouse, swatting, pause, emulated Xbox menu/sticks/RT, two-player WebRTC co-op).');
} finally {await browser?.close();server?.kill();}
