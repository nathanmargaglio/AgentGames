'use strict';
const $ = (id) => document.getElementById(id);
const PAGE_SIZE = 4;
let games = [], changes = [], page = 0, historyRequest = 0;
const el = (tag, className, text) => { const n = document.createElement(tag); if (className) n.className = className; if (text !== undefined) n.textContent = text; return n; };
async function json(path) { const r = await fetch(path, {cache: 'no-cache'}); if (!r.ok) throw new Error(`Could not load ${path}`); return r.json(); }
function renderGames() {
  const query = $('search').value.trim().toLowerCase();
  const shown = games.filter(g => `${g.name} ${g.description} ${g.genre}`.toLowerCase().includes(query));
  $('game-count').textContent = String(shown.length).padStart(2, '0');
  $('game-list').replaceChildren();
  if (!shown.length) { $('game-list').append(el('p', 'empty', 'No games match that search. Try another word.')); return; }
  shown.forEach((g, i) => {
    const card = el('article', 'game-card');
    if (i) card.style.marginTop = '24px';
    const art = el('a', 'game-art'); art.href = g.entry; art.setAttribute('aria-label', `Play ${g.name}`);
    const image = el('img'); image.src = g.cover; image.alt = g.cover_alt || `${g.name} game artwork`; image.width = 1200; image.height = 800; image.loading = i === 0 ? 'eager' : 'lazy';
    art.append(image, el('span', 'art-label', `EXPERIMENT ${String(games.indexOf(g)+1).padStart(3,'0')} / ${g.status.toUpperCase()}`));
    const info = el('div', 'game-info'), meta = el('div', 'game-meta');
    meta.append(el('span', '', g.genre), el('span', 'badge', g.players));
    const details = el('div', 'game-details'); details.append(el('span', '', '⌨  Mouse + keyboard'), el('span', '', '⊞  Xbox controller'));
    const row = el('div', 'play-row'), play = el('a', 'play', 'Play Debug'); play.textContent = `Play ${g.name}`; play.href = g.entry; play.append(el('span', '', '↗'));
    const version = el('button', 'game-version', `v${g.version} · changes`); version.type = 'button'; version.setAttribute('aria-label', `${g.name} version ${g.version} release history`);
    version.addEventListener('click', () => { $('change-source').value = g.changes; loadChanges(g.changes); $('journal').scrollIntoView({behavior: 'smooth'}); });
    row.append(play, version); info.append(meta, el('h3', '', `${g.name}.`), el('p', '', g.description), details, row); card.append(art, info); $('game-list').append(card);
  });
}
async function loadChanges(path) {
  const request = ++historyRequest; page = 0;
  $('change-list').textContent = 'Loading changes…';
  try { const result = await json(path); if (request !== historyRequest) return; changes = result; renderChanges(); }
  catch (e) { if (request !== historyRequest) return; changes=[]; renderChanges(); $('change-list').textContent = 'Release history could not be loaded. Refresh to try again.'; }
}
function renderChanges() {
  const pages = Math.max(1, Math.ceil(changes.length/PAGE_SIZE));
  page = Math.min(page, pages-1); $('change-list').replaceChildren();
  changes.slice(page*PAGE_SIZE, (page+1)*PAGE_SIZE).forEach(c => {
    const entry = el('article', 'change'), top = el('div', 'change-top'), time = el('time');
    time.dateTime = c.datetime; time.textContent = new Intl.DateTimeFormat(undefined, {year:'numeric',month:'short',day:'numeric',timeZone:'UTC'}).format(new Date(c.datetime));
    time.title = c.datetime; top.append(el('strong', '', `v${c.version}`), time); entry.append(top, el('p', '', c.description)); $('change-list').append(entry);
  });
  $('page-info').textContent = `Page ${page+1} of ${pages}`; $('previous').disabled = page===0; $('next').disabled=page>=pages-1;
}
$('search').addEventListener('input', renderGames);
$('change-source').addEventListener('change', e => loadChanges(e.target.value));
$('previous').addEventListener('click', () => { page--; renderChanges(); });
$('next').addEventListener('click', () => { page++; renderChanges(); });
(async () => {
  try {
    const catalog = await json('web/catalog.json'); games = catalog.games;
    $('portal-version').textContent = `v${catalog.version}`; $('portal-version').setAttribute('aria-label', `AgentGames version ${catalog.version}`);
    for (const g of games) { const option = el('option', '', `${g.name} · v${g.version}`); option.value = g.changes; $('change-source').append(option); }
    renderGames(); await loadChanges('CHANGES.json');
  } catch(e) { $('game-list').textContent = 'The playground could not be loaded. Refresh to try again.'; }
})();
