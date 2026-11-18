(() => {
  'use strict';

  const TRACKS = ['everyday', 'student', 'office', 'engineer', 'executive'];
  const PLATFORMS = ['GitHub', 'YouTube', 'Google Skills', 'Paid Course', 'Custom PDF'];
  const MAX = { title: 200, url: 2048, query: 1000, vault: 200 };
  const K = {
    track: 'learningcape_track',
    vault: 'learningcape_vault',
    consent: 'learningcape_ai_consent',
    mod: (id) => `mod_${id}`,
  };
  const ID_RE = /^[a-z0-9-]{1,20}$/;
  const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  const cfg = window.LEARNINGCAPE_CONFIG || {};
  const remoteConfigured =
    typeof cfg.SUPABASE_URL === 'string' && /^https:\/\//.test(cfg.SUPABASE_URL) &&
    !cfg.SUPABASE_URL.includes('YOUR-PROJECT') &&
    typeof cfg.SUPABASE_ANON_KEY === 'string' && cfg.SUPABASE_ANON_KEY.length > 20 &&
    !cfg.SUPABASE_ANON_KEY.includes('YOUR-') && !!(window.supabase && window.supabase.createClient);

  let sb = null;
  let user = null;
  let curriculum = null;
  let track = null;
  let vault = [];
  let toastTimer = null;

  const $ = (id) => document.getElementById(id);

  // ---- safe primitives -------------------------------------------------
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); return true; } catch { return false; } },
    del(k) { try { localStorage.removeItem(k); } catch { /* ignore */ } },
  };

  function h(tag, opts = {}, ...kids) {
    const n = document.createElement(tag);
    if (opts.cls) n.className = opts.cls;
    if (opts.text != null) n.textContent = String(opts.text);
    if (opts.attrs) for (const [k, v] of Object.entries(opts.attrs)) n.setAttribute(k, String(v));
    if (opts.props) Object.assign(n, opts.props);
    for (const c of kids) if (c) n.appendChild(c);
    return n;
  }

  function safeUrl(raw) {
    if (typeof raw !== 'string' || raw.length > MAX.url) return null;
    try {
      const u = new URL(raw.trim());
      return (u.protocol === 'https:' || u.protocol === 'http:') ? u.href : null;
    } catch { return null; }
  }

  function toast(msg) {
    const t = $('toast');
    t.textContent = msg;
    t.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.add('hidden'), 4000);
  }

  function cleanVaultItem(v) {
    if (!v || typeof v.id !== 'string' || typeof v.title !== 'string' || !PLATFORMS.includes(v.platform)) return null;
    return {
      id: v.id.slice(0, 64),
      title: v.title.slice(0, MAX.title),
      platform: v.platform,
      url: v.url ? safeUrl(v.url) : null,
      completed: v.completed === true,
    };
  }

  function loadVault() {
    try {
      const a = JSON.parse(store.get(K.vault) || '[]');
      return Array.isArray(a) ? a.map(cleanVaultItem).filter(Boolean).slice(0, MAX.vault) : [];
    } catch { return []; }
  }
  const saveVault = () => store.set(K.vault, JSON.stringify(vault));

  async function loadCurriculum() {
    try {
      const res = await fetch('curriculum.json', { credentials: 'same-origin' });
      if (!res.ok) throw new Error('status');
      const raw = await res.json();
      const out = {};
      for (const t of TRACKS) {
        const src = raw[t];
        if (!src || !Array.isArray(src.modules)) continue;
        out[t] = {
          title: String(src.title || t).slice(0, 120),
          subtitle: String(src.subtitle || '').slice(0, 300),
          modules: src.modules
            .filter((m) => m && ID_RE.test(m.id) && safeUrl(m.link))
            .map((m) => ({ id: m.id, title: String(m.title).slice(0, 200), desc: String(m.desc).slice(0, 400), link: safeUrl(m.link) })),
        };
      }
      return out;
    } catch { return null; }
  }

  // ---- views -----------------------------------------------------------
  function showView(name) {
    for (const v of ['intro', 'selector', 'dashboard']) $(`view-${v}`).classList.toggle('hidden', v !== name);
    const inDash = name === 'dashboard';
    $('active-track-badge').classList.toggle('hidden', !inDash);
    $('change-track-btn').classList.toggle('hidden', !inDash);
  }

  function showDashboard() {
    const info = curriculum && curriculum[track];
    showView('dashboard');
    if (!info) {
      $('dashboard-title').textContent = 'Curriculum unavailable';
      $('dashboard-subtitle').textContent = 'Could not load curriculum data. Reload the page.';
      $('tab-curriculum').replaceChildren();
      return;
    }
    $('dashboard-title').textContent = info.title;
    $('dashboard-subtitle').textContent = info.subtitle;
    $('active-track-badge').textContent = `Level: ${info.title.split(':')[0]}`;

    const cards = info.modules.map((mod) => {
      const done = store.get(K.mod(mod.id)) === 'true';
      const head = h('div', { cls: 'flex items-center justify-between mb-3' },
        h('span', { cls: 'text-xs font-mono px-2.5 py-1 rounded bg-slate-800 text-cyan-400 border border-slate-700', text: mod.id.toUpperCase() }),
        h('label', { cls: 'flex items-center space-x-2 cursor-pointer text-xs text-slate-400' },
          h('input', { cls: 'rounded bg-slate-800 border-slate-700 text-cyan-500 h-4 w-4', attrs: { type: 'checkbox', 'data-mod': mod.id }, props: { checked: done } }),
          h('span', { text: 'Completed' })));
      const body = h('div', {}, head,
        h('h3', { cls: 'text-lg font-bold text-white mb-2', text: mod.title }),
        h('p', { cls: 'text-slate-400 text-sm mb-4', text: mod.desc }));
      const foot = h('div', { cls: 'pt-4 border-t border-slate-800/60' },
        h('a', { cls: 'text-xs font-semibold text-cyan-400 hover:underline', text: 'Authoritative Source →',
          attrs: { href: mod.link, target: '_blank', rel: 'noopener noreferrer' } }));
      return h('div', { cls: 'bg-slate-900 border border-slate-800 rounded-xl p-6 flex flex-col justify-between' }, body, foot);
    });
    $('tab-curriculum').replaceChildren(...cards);
    updateProgress();
    renderVault();
  }

  function updateProgress() {
    const mods = (curriculum && curriculum[track] && curriculum[track].modules) || [];
    const done = mods.filter((m) => store.get(K.mod(m.id)) === 'true').length;
    const pct = mods.length ? Math.round((done / mods.length) * 100) : 0;
    $('progress-text').textContent = `${pct}%`;
    $('progress-bar').style.width = `${pct}%`; // CSSOM assignment is CSP-safe
  }

  function renderVault() {
    const c = $('vault-container');
    if (!vault.length) {
      c.replaceChildren(h('p', { cls: 'text-slate-500 text-sm col-span-2', text: 'Your vault is empty. Add your first external course or repository above.' }));
      return;
    }
    c.replaceChildren(...vault.map((item) => {
      const top = h('div', { cls: 'flex items-center justify-between mb-2' },
        h('span', { cls: 'text-xs font-mono px-2 py-0.5 rounded bg-slate-800 text-indigo-400 border border-slate-700', text: item.platform }),
        h('label', { cls: 'flex items-center space-x-2 text-xs text-slate-400 cursor-pointer' },
          h('input', { cls: 'rounded bg-slate-800 border-slate-700 text-cyan-500 h-4 w-4', attrs: { type: 'checkbox', 'data-vault': item.id }, props: { checked: item.completed } }),
          h('span', { text: 'Done' })));
      const main = h('div', {}, top, h('h4', { cls: 'text-base font-bold text-white mb-1', text: item.title }));
      if (item.url) main.appendChild(h('a', { cls: 'text-xs text-cyan-400 hover:underline truncate block mb-3', text: item.url,
        attrs: { href: item.url, target: '_blank', rel: 'noopener noreferrer nofollow' } }));
      const foot = h('div', { cls: 'flex justify-end pt-3 border-t border-slate-800/60' },
        h('button', { cls: 'text-xs text-rose-400 hover:underline', text: 'Remove', attrs: { type: 'button', 'data-action': 'delete-vault', 'data-id': item.id } }));
      return h('div', { cls: 'bg-slate-900 border border-slate-800 rounded-xl p-5 flex flex-col justify-between' }, main, foot);
    }));
  }

  function switchTab(tab) {
    const cur = tab === 'curriculum';
    $('tab-curriculum').classList.toggle('hidden', !cur);
    $('tab-vault').classList.toggle('hidden', cur);
    const on = 'px-4 py-2 rounded-lg text-sm font-semibold bg-cyan-500 text-slate-950 transition-colors';
    const off = 'px-4 py-2 rounded-lg text-sm font-semibold bg-slate-900 text-slate-400 hover:text-white transition-colors';
    $('tab-curriculum-btn').className = cur ? on : off;
    $('tab-vault-btn').className = cur ? off : on;
  }

  // ---- remote sync (best effort; local-first) ----------------------------
  async function remote(fn) {
    if (!sb || !user) return;
    try {
      const { error } = await fn();
      if (error) throw error;
    } catch {
      console.warn('sync_failed');
      toast('Saved on this device; cloud sync failed.');
    }
  }

  const syncProfile = () => remote(() => sb.from('user_profiles').upsert({ client_uuid: user.id, track_id: track }));
  const syncProgress = (modId, done) => remote(() => sb.from('user_progress')
    .upsert({ client_uuid: user.id, module_id: modId, subtask_id: 'default', is_completed: done }, { onConflict: 'client_uuid,module_id,subtask_id' }));
  const syncVaultInsert = (it) => UUID_RE.test(it.id) && track ? remote(async () => {
    const p = await sb.from('user_profiles').upsert({ client_uuid: user.id, track_id: track }); // FK parent must exist
    if (p.error) return p;
    return sb.from('user_sources').upsert({ id: it.id, client_uuid: user.id, title: it.title, platform: it.platform, url: it.url, completed: it.completed });
  }) : Promise.resolve();
  const syncVaultUpdate = (it) => remote(() => sb.from('user_sources').update({ completed: it.completed }).eq('id', it.id).eq('client_uuid', user.id));
  const syncVaultDelete = (id) => remote(() => sb.from('user_sources').delete().eq('id', id).eq('client_uuid', user.id));

  async function pushAll() {
    if (!track) return;
    await syncProfile();
    const mods = (curriculum && curriculum[track] && curriculum[track].modules) || [];
    for (const m of mods) if (store.get(K.mod(m.id)) === 'true') await syncProgress(m.id, true);
    for (const it of vault) await syncVaultInsert(it);
  }

  async function initRemote() {
    try {
      sb = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false },
      });
      let { data: { session } } = await sb.auth.getSession();
      if (!session) {
        const { data, error } = await sb.auth.signInAnonymously();
        if (error || !data.session) throw new Error('auth');
        session = data.session;
      }
      user = session.user;
      const { data: prof, error } = await sb.from('user_profiles').select('track_id').eq('client_uuid', user.id).maybeSingle();
      if (error) throw error;
      if (prof && TRACKS.includes(prof.track_id)) {
        track = prof.track_id;
        store.set(K.track, track);
        const [prog, src] = await Promise.all([
          sb.from('user_progress').select('module_id,is_completed').eq('client_uuid', user.id).eq('subtask_id', 'default'),
          sb.from('user_sources').select('id,title,platform,url,completed').eq('client_uuid', user.id).order('created_at'),
        ]);
        if (!prog.error) for (const r of prog.data) if (ID_RE.test(r.module_id)) store.set(K.mod(r.module_id), String(r.is_completed === true));
        if (!src.error) { vault = src.data.map(cleanVaultItem).filter(Boolean); saveVault(); }
        showDashboard();
      } else if (track) {
        await pushAll();
      }
    } catch {
      console.warn('remote_init_failed');
      sb = null; user = null;
      toast('Cloud sync unavailable; working on this device only.');
    }
  }

  // ---- chat --------------------------------------------------------------
  function openModal(id) { $(id).classList.remove('hidden'); }
  function closeModals() { for (const id of ['chat-modal', 'privacy-modal']) $(id).classList.add('hidden'); }

  function openChat() {
    const ok = store.get(K.consent) === 'granted';
    $('chat-consent').classList.toggle('hidden', ok);
    $('chat-body').classList.toggle('hidden', !ok);
    openModal('chat-modal');
    if (ok && !$('chat-messages').children.length) {
      addMsg('ai', 'Hello! I can recommend courses from the curated list for your level. I am an AI and can make mistakes.');
    }
  }

  function addMsg(who, text) {
    const mine = who === 'user';
    const box = h('div', { cls: mine ? 'bg-slate-800/40 rounded-xl p-4 ml-8' : 'bg-slate-800/80 rounded-xl p-4 mr-8 border border-cyan-500/30' },
      h('p', { cls: `font-semibold mb-1 ${mine ? 'text-slate-200' : 'text-cyan-400'}`, text: mine ? 'You' : 'LearningCape AI' }),
      h('p', { cls: 'whitespace-pre-wrap break-words', text }));
    const m = $('chat-messages');
    m.appendChild(box);
    m.scrollTop = m.scrollHeight;
  }

  async function sendChat() {
    const input = $('chat-input');
    const q = input.value.trim();
    if (!q) return;
    if (q.length > MAX.query) { toast(`Questions are limited to ${MAX.query} characters.`); return; }
    if (!sb || !user) { addMsg('ai', 'The assistant needs the cloud connection, which is not available right now.'); return; }
    if (!track) { addMsg('ai', 'Please select your level first.'); return; }
    addMsg('user', q);
    input.value = '';
    const btn = $('chat-send');
    btn.disabled = true;
    try {
      const { data, error } = await sb.functions.invoke('assistant_router', { body: { query: q, track_id: track } });
      if (error) {
        const s = error.context && error.context.status;
        addMsg('ai', s === 429 ? 'Hourly question limit reached. Please try again later.'
          : s === 401 ? 'Your session expired. Please reload the page.' : 'The assistant is unavailable right now.');
      } else {
        addMsg('ai', typeof data?.reply === 'string' && data.reply ? data.reply.slice(0, 4000) : 'No answer was returned.');
      }
    } catch {
      addMsg('ai', 'The assistant is unavailable right now.');
    } finally {
      btn.disabled = false;
    }
  }

  // ---- privacy: export + erase -------------------------------------------
  function exportData() {
    const progress = {};
    for (const t of TRACKS) for (const m of ((curriculum && curriculum[t] && curriculum[t].modules) || [])) {
      if (store.get(K.mod(m.id)) === 'true') progress[m.id] = true;
    }
    const blob = new Blob([JSON.stringify({ exported_at: new Date().toISOString(), track, progress, vault }, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = h('a', { attrs: { href: url, download: 'learningcape-export.json' } });
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  async function deleteAll() {
    if (!window.confirm('Permanently delete all your LearningCape data on this device and in the cloud? This cannot be undone.')) return;
    if (sb && user) {
      try {
        const { error } = await sb.functions.invoke('delete_account', { body: {} });
        if (error) throw error;
        await sb.auth.signOut();
      } catch {
        toast('Cloud deletion failed. Nothing was removed; please try again.');
        return;
      }
    }
    store.del(K.track); store.del(K.vault); store.del(K.consent);
    for (const t of TRACKS) for (const m of ((curriculum && curriculum[t] && curriculum[t].modules) || [])) store.del(K.mod(m.id));
    window.location.reload();
  }

  // ---- vault actions -----------------------------------------------------
  function addVaultItem() {
    const title = $('vault-title').value.trim();
    const platform = $('vault-platform').value;
    const rawUrl = $('vault-url').value.trim();
    if (!title || title.length > MAX.title) { toast('Enter a title (max 200 characters).'); return; }
    if (!PLATFORMS.includes(platform)) return;
    const url = rawUrl ? safeUrl(rawUrl) : null;
    if (rawUrl && !url) { toast('Enter a valid http(s) URL.'); return; }
    if (vault.length >= MAX.vault) { toast('Vault limit reached.'); return; }
    const item = { id: crypto.randomUUID(), title, platform, url, completed: false };
    vault.push(item);
    saveVault();
    $('vault-title').value = ''; $('vault-url').value = '';
    renderVault();
    syncVaultInsert(item);
  }

  // ---- events (delegated; no inline handlers) -----------------------------
  document.addEventListener('click', (e) => {
    const t = e.target.closest('[data-action]');
    if (!t) return;
    switch (t.dataset.action) {
      case 'goto-selector': showView('selector'); break;
      case 'select-track': {
        const id = t.dataset.track;
        if (!TRACKS.includes(id)) return;
        track = id; store.set(K.track, id); showDashboard(); switchTab('curriculum'); syncProfile();
        break;
      }
      case 'reset-track': track = null; store.del(K.track); showView('intro'); break;
      case 'tab': switchTab(t.dataset.tab === 'vault' ? 'vault' : 'curriculum'); break;
      case 'add-vault': addVaultItem(); break;
      case 'delete-vault': {
        vault = vault.filter((v) => v.id !== t.dataset.id); saveVault(); renderVault(); syncVaultDelete(t.dataset.id);
        break;
      }
      case 'open-chat': openChat(); break;
      case 'accept-chat': store.set(K.consent, 'granted'); openChat(); break;
      case 'send-chat': sendChat(); break;
      case 'open-privacy': openModal('privacy-modal'); break;
      case 'close-modals': closeModals(); break;
      case 'export-data': exportData(); break;
      case 'delete-data': deleteAll(); break;
    }
  });

  document.addEventListener('change', (e) => {
    const t = e.target;
    if (t.dataset && t.dataset.mod && ID_RE.test(t.dataset.mod)) {
      store.set(K.mod(t.dataset.mod), String(t.checked)); updateProgress(); syncProgress(t.dataset.mod, t.checked);
    } else if (t.dataset && t.dataset.vault) {
      const it = vault.find((v) => v.id === t.dataset.vault);
      if (it) { it.completed = t.checked; saveVault(); syncVaultUpdate(it); }
    }
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeModals();
    if (e.key === 'Enter' && e.target && e.target.id === 'chat-input') { e.preventDefault(); sendChat(); }
  });

  // ---- init --------------------------------------------------------------
  (async function init() {
    // Remove legacy keys from earlier versions (client UUID and fake auth flag are no longer used).
    store.del('learningcape_client_uuid'); store.del('learningcape_chatgpt_auth');
    curriculum = await loadCurriculum();
    const saved = store.get(K.track);
    track = TRACKS.includes(saved) ? saved : null;
    vault = loadVault();
    if (track) showDashboard(); else showView('intro');
    if (remoteConfigured) await initRemote();
  })();
})();
