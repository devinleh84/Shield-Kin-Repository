// Shield-Kin menu. SHK_Core pushes state with window.shkState(json) and the page
// answers through window.shk(command), which Magelight turns into a ModEvent.
//   "close" | "refresh"
//   "f|<formId>|<verb>|<arg>"   one follower
//   "p|<verb>"                  whole party
//   "r|<formId>|<verb>"         registry (dismissed followers)
//   "s|<key>|<value>"           settings
(function () {
  'use strict';

  var MODES = ['Following', 'Waiting', 'Relaxing nearby', 'At home', 'At camp', 'Relaxing', 'Selling'];
  var ORDERS = [
    { m: 0, t: 'Follow me' },
    { m: 1, t: 'Wait here' },
    { m: 2, t: 'Relax nearby', s: 'stays close to you' },
    { m: 5, t: 'Relax here', s: 'stays at this spot' },
    { m: 3, t: 'Go home', s: 'needs a home', home: true },
    { m: 4, t: 'Join camp', s: 'at the party camp' }
  ];
  var DISTS = [{ v: 0, t: 'Close' }, { v: 1, t: 'Normal' }, { v: 2, t: 'Far' }];
  var STYLES = [
    { v: 0, t: 'Their own', s: 'keeps their usual style' },
    { v: 1, t: 'Warrior', s: 'melee' },
    { v: 2, t: 'Archer', s: 'bows' },
    { v: 3, t: 'Mage', s: 'spells' },
    { v: 4, t: 'Healer', s: 'heals the party' },
    { v: 5, t: 'Tank', s: 'holds the line' }
  ];
  var STANCES = [
    { v: 0, t: 'Balanced' },
    { v: 1, t: 'Aggressive', s: 'attacks on sight' },
    { v: 2, t: 'Defensive', s: 'fights back only' },
    { v: 3, t: 'Passive', s: 'never fights' }
  ];
  var PROTS = [
    { v: 0, t: 'Mortal', s: 'can die' },
    { v: 1, t: 'Protected', s: 'only you can kill them' },
    { v: 2, t: 'Essential', s: 'cannot die' }
  ];
  var OUTFITS = ['Travel', 'Town', 'Home', 'Sleep', 'Combat'];

  // JavaScript key codes to DirectInput scan codes (what Papyrus RegisterForKey uses).
  var DIK = {
    Escape: 1, Digit1: 2, Digit2: 3, Digit3: 4, Digit4: 5, Digit5: 6, Digit6: 7, Digit7: 8,
    Digit8: 9, Digit9: 10, Digit0: 11, Minus: 12, Equal: 13, Backspace: 14, Tab: 15,
    KeyQ: 16, KeyW: 17, KeyE: 18, KeyR: 19, KeyT: 20, KeyY: 21, KeyU: 22, KeyI: 23, KeyO: 24,
    KeyP: 25, BracketLeft: 26, BracketRight: 27, Enter: 28, ControlLeft: 29, KeyA: 30,
    KeyS: 31, KeyD: 32, KeyF: 33, KeyG: 34, KeyH: 35, KeyJ: 36, KeyK: 37, KeyL: 38,
    Semicolon: 39, Quote: 40, Backquote: 41, ShiftLeft: 42, Backslash: 43, KeyZ: 44,
    KeyX: 45, KeyC: 46, KeyV: 47, KeyB: 48, KeyN: 49, KeyM: 50, Comma: 51, Period: 52,
    Slash: 53, ShiftRight: 54, NumpadMultiply: 55, AltLeft: 56, Space: 57, CapsLock: 58,
    F1: 59, F2: 60, F3: 61, F4: 62, F5: 63, F6: 64, F7: 65, F8: 66, F9: 67, F10: 68,
    NumLock: 69, ScrollLock: 70, Numpad7: 71, Numpad8: 72, Numpad9: 73, NumpadSubtract: 74,
    Numpad4: 75, Numpad5: 76, Numpad6: 77, NumpadAdd: 78, Numpad1: 79, Numpad2: 80,
    Numpad3: 81, Numpad0: 82, NumpadDecimal: 83, F11: 87, F12: 88, NumpadEnter: 156,
    ControlRight: 157, NumpadDivide: 181, AltRight: 184, Pause: 197, Home: 199,
    ArrowUp: 200, PageUp: 201, ArrowLeft: 203, ArrowRight: 205, End: 207, ArrowDown: 208,
    PageDown: 209, Insert: 210, Delete: 211
  };
  // Older engines only fill keyCode; map the common ones.
  var KEYCODE = {
    27: 'Escape', 9: 'Tab', 13: 'Enter', 32: 'Space', 8: 'Backspace', 45: 'Insert', 46: 'Delete',
    36: 'Home', 35: 'End', 33: 'PageUp', 34: 'PageDown', 37: 'ArrowLeft', 38: 'ArrowUp',
    39: 'ArrowRight', 40: 'ArrowDown', 19: 'Pause', 145: 'ScrollLock', 144: 'NumLock',
    186: 'Semicolon', 187: 'Equal', 188: 'Comma', 189: 'Minus', 190: 'Period', 191: 'Slash',
    192: 'Backquote', 219: 'BracketLeft', 220: 'Backslash', 221: 'BracketRight', 222: 'Quote'
  };
  // Keys the game or Magelight already owns.
  var RESERVED = { 1: 'Escape closes menus', 201: 'PageUp is the Magelight UI key' };

  function codeOf(e) {
    if (e.code && DIK[e.code]) return e.code;
    var k = e.keyCode;
    if (k >= 112 && k <= 123) return 'F' + (k - 111);
    if (k >= 65 && k <= 90) return 'Key' + String.fromCharCode(k);
    if (k >= 48 && k <= 57) return 'Digit' + (k - 48);
    if (k >= 96 && k <= 105) return 'Numpad' + (k - 96);
    return KEYCODE[k] || '';
  }

  function keyName(dik) {
    for (var c in DIK) {
      if (DIK[c] === dik) {
        return c.replace(/^Key/, '').replace(/^Digit/, '').replace(/^Numpad/, 'Num ')
          .replace(/Left$/, ' (L)').replace(/Right$/, ' (R)').replace(/^Arrow/, '');
      }
    }
    return 'Key ' + dik;
  }

  // --- state ---------------------------------------------------------------

  var S = null;           // last state from Papyrus
  var view = 'roster';
  var selId = 0;
  var sub = 'orders';
  var listening = false;  // waiting for a new hotkey

  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // Simple changes show at once instead of waiting for Papyrus, which is slow while the
  // game is paused. Each command carries a number; the state echoes the last one handled
  // as "ack", so a state built before a change cannot undo it on screen.
  var seq = 0;
  var pending = [];

  function send(cmd) {
    seq += 1;
    if (predict(cmd)) {
      pending.push({ seq: seq, cmd: cmd });
      render();
    }
    if (typeof window.shk === 'function') window.shk(cmd + '|' + seq);
    else mock(cmd);
  }

  var QUICK = ['mode', 'dist', 'style', 'stance', 'prot', 'outfitauto'];
  var PARTY = { follow: 0, wait: 1, sandbox: 2, breakcamp: 0 };

  // Applies a command to the local state when its result is known in advance.
  function predict(cmd) {
    if (!S) return false;
    var p = cmd.split('|');
    if (p[0] === 's') {
      S.settings[p[1]] = p[1] === 'theme' ? p[2] : Number(p[2]);
      return true;
    }
    if (p[0] === 'f' && QUICK.indexOf(p[2]) >= 0) {
      var f = find(Number(p[1]));
      if (!f) return false;
      if (p[2] === 'mode' && f.mode === 6) f.merchant = '';
      f[p[2]] = Number(p[3]);
      return true;
    }
    if (p[0] === 'p' && PARTY[p[1]] != null) {
      S.followers.forEach(function (f) { f.mode = PARTY[p[1]]; f.merchant = ''; });
      return true;
    }
    return false;
  }

  var toastTimer = 0;
  function toast(msg) {
    var t = $('toast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.classList.remove('show'); }, 2200);
  }

  function find(id) {
    if (!S) return null;
    for (var i = 0; i < S.followers.length; i++) if (S.followers[i].id === id) return S.followers[i];
    return null;
  }

  // --- rendering -----------------------------------------------------------

  window.shkState = function (json) {
    try {
      S = typeof json === 'string' ? JSON.parse(json) : json;
    } catch (e) {
      toast('Bad state: ' + e.message);
      return;
    }
    S.followers = S.followers || [];
    S.others = S.others || [];
    S.registry = S.registry || [];
    S.settings = S.settings || {};
    var ack = S.ack || 0;
    pending = pending.filter(function (x) { return x.seq > ack; });
    pending.forEach(function (x) { predict(x.cmd); });
    if (S.focus) {
      selId = S.focus;
      view = 'roster';
    }
    if (!find(selId)) selId = S.followers.length ? S.followers[0].id : 0;
    render();
  };

  function render() {
    if (!S) return;
    var st = S.settings;
    document.body.className = 'theme-' + (st.theme === 'paper' ? 'paper' : 'vellum');
    $('book').style.setProperty('--scale', (st.scale || 100) / 100);
    $('cap-count').textContent = S.followers.length;
    $('cap-max').textContent = '/ ' + S.max;
    $('count-registry').textContent = S.registry.length;
    $('foot-key').textContent = keyName(st.key || 65);

    var tabs = document.querySelectorAll('.tab');
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].setAttribute('aria-selected', tabs[i].getAttribute('data-view') === view ? 'true' : 'false');
    }
    $('view-roster').hidden = view !== 'roster';
    $('view-registry').hidden = view !== 'registry';
    $('view-settings').hidden = view !== 'settings';

    if (view === 'roster') { renderRoster(); renderPage(); }
    else if (view === 'registry') renderRegistry();
    else renderSettings();
  }

  function bars(f) {
    var h = '<div class="bars"><div class="bar hp"><i style="width:' + (f.hp || 0) + '%"></i></div>';
    if (f.mp != null) h += '<div class="bar mp"><i style="width:' + f.mp + '%"></i></div>';
    if (f.sp != null) h += '<div class="bar sp"><i style="width:' + f.sp + '%"></i></div>';
    return h + '</div>';
  }

  function statusOf(f) {
    var s = MODES[f.mode] || 'Following';
    if (f.mode === 6 && f.merchant) s = 'Selling to ' + f.merchant;
    var tags = '';
    if (f.combat) tags += '<span class="tag fight">fighting</span>';
    if (f.prot === 2) tags += '<span class="tag ess">essential</span>';
    return esc(s) + tags;
  }

  function renderRoster() {
    var h = '';
    if (!S.followers.length) {
      h = '<div class="empty">No one is sworn to you yet. Ask someone to follow you, or recall a ' +
        'follower from the Registry.</div>';
    } else {
      h += '<h3>Sworn</h3>';
      S.followers.forEach(function (f) {
        h += '<div class="kin' + (f.id === selId ? ' sel' : '') + '" data-id="' + f.id + '">' +
          '<span class="nm">' + esc(f.name) + '</span><span class="lv">Lv ' + f.lvl + '</span>' +
          '<span class="st">' + statusOf(f) + '</span><span></span>' + bars(f) + '</div>';
      });
    }
    if (S.others.length) {
      h += '<h3>Travelling with you (other mods)</h3>';
      S.others.forEach(function (o) {
        h += '<div class="kin other"><span class="nm">' + esc(o.name) + '</span><span class="lv">Lv ' +
          o.lvl + '</span><span class="st">' + esc(o.race) + '</span><span></span>' +
          bars({ hp: o.hp }) + '</div>';
      });
    }
    $('roster').innerHTML = h;
  }

  function choices(list, cur, verb, f, extra) {
    var h = '<div class="choices">';
    list.forEach(function (c) {
      var v = c.v != null ? c.v : c.m;
      var dis = extra && extra(c) === false;
      h += '<button class="choice' + (v === cur ? ' on' : '') + '"' + (dis ? ' disabled' : '') +
        ' data-cmd="f|' + f.id + '|' + verb + '|' + v + '">' + esc(c.t) +
        (c.s ? '<small>' + esc(c.s) + '</small>' : '') + '</button>';
    });
    return h + '</div>';
  }

  function renderPage() {
    var f = find(selId);
    var p = $('page');
    if (!f) {
      p.innerHTML = '<div class="empty">Pick someone from the roster to see their orders.</div>';
      return;
    }
    var away = f.away > 0 ? Math.round(f.away / 70) + ' m away' : '';
    var h = '<div class="page-head"><h2>' + esc(f.name) + '</h2>' +
      '<span class="meta">' + esc([f.race, f.cls, 'level ' + f.lvl].filter(Boolean).join(', ')) +
      (f.bonus ? ' (+' + f.bonus + ' levelled)' : '') + (away ? ', ' + away : '') + '</span>' +
      '<div class="acts">' +
      '<button class="btn" data-cmd="f|' + f.id + '|summon|0">Summon</button>' +
      '<button class="btn" data-cmd="f|' + f.id + '|trade|0">Trade gear</button>' +
      '<button class="btn danger" data-confirm="Part ways with ' + esc(f.name) + '?" data-cmd="f|' +
      f.id + '|dismiss|0">Dismiss</button></div></div>';

    h += '<div class="vitals">' +
      '<div>Health ' + f.hp + '%<div class="bar hp"><i style="width:' + f.hp + '%"></i></div></div>' +
      '<div>Magicka ' + f.mp + '%<div class="bar mp"><i style="width:' + f.mp + '%"></i></div></div>' +
      '<div>Stamina ' + f.sp + '%<div class="bar sp"><i style="width:' + f.sp + '%"></i></div></div></div>';

    var subs = [['orders', 'Orders'], ['combat', 'Combat'], ['outfits', 'Outfits'], ['home', 'Home'], ['sell', 'Sell']];
    h += '<div class="subtabs">';
    subs.forEach(function (s) {
      h += '<button class="subtab' + (sub === s[0] ? ' on' : '') + '" data-sub="' + s[0] + '">' + s[1] + '</button>';
    });
    h += '</div><div class="sheet">' + sheet(f) + '</div>';
    p.innerHTML = h;
  }

  function sheet(f) {
    if (sub === 'orders') {
      return '<div class="field"><span class="lbl">Orders</span>' +
        choices(ORDERS, f.mode, 'mode', f, function (c) { return !c.home || !!f.home; }) +
        (f.mode === 6 ? '<p class="hint">Currently on a selling errand. Any order cancels it.</p>' : '') +
        '</div><div class="field"><span class="lbl">Follow distance</span>' +
        choices(DISTS, f.dist, 'dist', f) + '</div>';
    }
    if (sub === 'combat') {
      return '<div class="field"><span class="lbl">Combat style</span>' + choices(STYLES, f.style, 'style', f) +
        '<p class="hint">Healers cast restoration spells they know on whoever is hurt worst.</p></div>' +
        '<div class="field"><span class="lbl">Stance</span>' + choices(STANCES, f.stance, 'stance', f) + '</div>' +
        '<div class="field"><span class="lbl">Protection</span>' + choices(PROTS, f.prot, 'prot', f) + '</div>';
    }
    if (sub === 'outfits') {
      var h = '<div class="field"><span class="lbl">Change outfits by place</span><div class="choices">' +
        '<button class="choice' + (f.outfitauto ? ' on' : '') + '" data-cmd="f|' + f.id + '|outfitauto|1">Automatic</button>' +
        '<button class="choice' + (!f.outfitauto ? ' on' : '') + '" data-cmd="f|' + f.id + '|outfitauto|0">Manual</button>' +
        '</div><p class="hint">Save what they wear now into a set. Empty sets are skipped.</p></div>' +
        '<table class="outfits">';
      OUTFITS.forEach(function (n, i) {
        var c = (f.outfits || [])[i] || 0;
        h += '<tr' + (f.outfitnow === i ? ' class="now"' : '') + '><td class="n">' + n + '</td>' +
          '<td class="c">' + (c ? c + ' item' + (c === 1 ? '' : 's') : 'empty') + '</td><td class="a">' +
          '<button class="btn" data-cmd="f|' + f.id + '|outfitsave|' + i + '">Save worn</button> ' +
          '<button class="btn"' + (c ? '' : ' disabled') + ' data-cmd="f|' + f.id + '|outfitwear|' + i + '">Wear</button> ' +
          '<button class="btn danger"' + (c ? '' : ' disabled') + ' data-cmd="f|' + f.id + '|outfitclear|' + i + '">Clear</button>' +
          '</td></tr>';
      });
      return h + '</table>';
    }
    if (sub === 'home') {
      return '<div class="ledger-box">' + (f.home
        ? 'Home: <b>' + esc(f.home) + '</b>. When dismissed or sent home they live there.'
        : 'No home yet. Stand where they should live and set it here.') + '</div>' +
        '<div class="choices"><button class="btn" data-cmd="f|' + f.id + '|sethome|0">Make home here</button>' +
        '<button class="btn"' + (f.home ? '' : ' disabled') + ' data-cmd="f|' + f.id + '|mode|3">Go home</button>' +
        '<button class="btn danger"' + (f.home ? '' : ' disabled') + ' data-cmd="f|' + f.id + '|clearhome|0">Forget home</button></div>';
    }
    // sell
    var busy = f.mode === 6;
    return '<div class="ledger-box">' +
      (f.sell ? 'Carrying <b>' + f.sell + '</b> item' + (f.sell === 1 ? '' : 's') + ' to sell.' : 'Nothing to sell yet.') +
      (busy ? '<br>On the way to <b>' + esc(f.merchant || 'a merchant') + '</b>.' : '') +
      '<br><span class="hint">Hand items over, then send them to the nearest merchant. The gold comes back to you; ' +
      'their Speech improves the price.</span></div><div class="choices">' +
      '<button class="btn" data-cmd="f|' + f.id + '|give|0">Hand over items</button>' +
      '<button class="btn"' + (f.sell && !busy ? '' : ' disabled') + ' data-cmd="f|' + f.id + '|sell|0">Go sell</button>' +
      (busy ? '<button class="btn danger" data-cmd="f|' + f.id + '|sellcancel|0">Call back</button>' : '') +
      '<button class="btn danger"' + (f.sell && !busy ? '' : ' disabled') + ' data-cmd="f|' + f.id + '|sellclear|0">Return items</button></div>';
  }

  function renderRegistry() {
    if (!S.registry.length) {
      $('registry').innerHTML = '<div class="empty">No dismissed followers.</div>';
      return;
    }
    var h = '';
    S.registry.forEach(function (r) {
      h += '<div class="card"><div class="nm">' + esc(r.name) + '</div><div class="meta">' +
        esc(r.race) + ', level ' + r.lvl + (r.home ? ', lives at ' + esc(r.home) : ', no home') + '</div>' +
        '<div class="acts"><button class="btn" data-cmd="r|' + r.id + '|recall"' +
        (S.followers.length >= S.max ? ' disabled' : '') + '>Recall</button>' +
        '<button class="btn" data-cmd="r|' + r.id + '|summon">Summon</button>' +
        (r.home ? '<button class="btn" data-cmd="r|' + r.id + '|clearhome">Clear home</button>' : '') +
        '<button class="btn danger" data-confirm="Forget ' + esc(r.name) + ' and their settings?" data-cmd="r|' +
        r.id + '|forget">Forget</button></div></div>';
    });
    $('registry').innerHTML = h;
  }

  function row(title, desc, ctl) {
    return '<div class="set-row"><div class="txt"><b>' + title + '</b><span>' + desc + '</span></div>' +
      '<div class="ctl">' + ctl + '</div></div>';
  }
  function toggle(k, on) {
    return '<button class="toggle' + (on ? ' on' : '') + '" data-cmd="s|' + k + '|' + (on ? 0 : 1) + '"></button>';
  }
  function stepper(k, v, step, min, max, fmt) {
    return '<button class="step" data-cmd="s|' + k + '|' + Math.max(min, v - step) + '">&minus;</button>' +
      '<span class="val">' + fmt(v) + '</span>' +
      '<button class="step" data-cmd="s|' + k + '|' + Math.min(max, v + step) + '">+</button>';
  }

  function renderSettings() {
    var st = S.settings;
    var h = '';
    h += row('Menu hotkey', 'Opens this menu. Looking at a follower opens their page.',
      '<button class="keycap' + (listening ? ' listening' : '') + '" id="keycap">' +
      (listening ? 'Press a key' : esc(keyName(st.key || 65))) + '</button>' +
      (st.key !== 65 ? '<button class="btn" data-cmd="s|key|65">Reset</button>' : ''));
    h += row('Catch-up distance', 'Following followers left this far behind are brought to you. Off disables it.',
      stepper('catchup', st.catchup, 500, 0, 10000, function (v) { return v ? Math.round(v / 70) + ' m' : 'Off'; }));
    h += row('Default follow distance', 'Used for newly sworn followers.',
      '<div class="choices">' + DISTS.map(function (d) {
        return '<button class="choice' + (st.dist === d.v ? ' on' : '') + '" data-cmd="s|dist|' + d.v + '">' + d.t + '</button>';
      }).join('') + '</div>');
    h += row('Levelling', 'Followers gain levels with you, up to a share of your level.', toggle('level', st.level));
    if (st.level) {
      h += row('Level share', 'Highest level a follower reaches, as a share of yours.',
        stepper('levelpct', st.levelpct, 5, 50, 100, function (v) { return v + '%'; }));
    }
    h += row('Automatic outfits', 'Default for new followers: change saved outfits by place.', toggle('autooutfit', st.autooutfit));
    h += row('Lesser power', 'Gives you the "Shield-Kin" power, which opens this menu. Aim at a follower to open their page.',
      toggle('power', st.power !== 0));
    h += row('Notifications', 'Short messages in the corner of the screen.', toggle('notify', st.notify));
    h += row('Menu size', 'Scale of this window.',
      stepper('scale', st.scale, 5, 70, 130, function (v) { return v + '%'; }));
    h += row('Theme', 'Look of this menu.',
      '<div class="choices"><button class="choice' + (st.theme !== 'paper' ? ' on' : '') +
      '" data-cmd="s|theme|vellum">Dark Vellum</button><button class="choice' + (st.theme === 'paper' ? ' on' : '') +
      '" data-cmd="s|theme|paper">Ink on Paper</button></div>');
    $('settings').innerHTML = h;
  }

  // --- input ---------------------------------------------------------------

  document.addEventListener('click', function (e) {
    var t = e.target;
    while (t && t !== document && !t.getAttribute('data-cmd') && !t.getAttribute('data-view') &&
      !t.getAttribute('data-party') && !t.getAttribute('data-sub') && !t.getAttribute('data-id') &&
      t.id !== 'btn-close' && t.id !== 'keycap') {
      t = t.parentNode;
    }
    if (!t || t === document || t.disabled) return;

    if (t.id === 'btn-close') { send('close'); return; }
    if (t.id === 'keycap') { listening = !listening; renderSettings(); return; }

    var v = t.getAttribute('data-view');
    if (v) { view = v; listening = false; render(); return; }
    var sb = t.getAttribute('data-sub');
    if (sb) { sub = sb; renderPage(); return; }
    var id = t.getAttribute('data-id');
    if (id) { selId = Number(id); renderRoster(); renderPage(); return; }
    var party = t.getAttribute('data-party');
    if (party) { send('p|' + party); toast(t.textContent); return; }

    var cmd = t.getAttribute('data-cmd');
    var ask = t.getAttribute('data-confirm');
    if (ask) {
      if (t.getAttribute('data-armed') !== '1') {
        t.setAttribute('data-armed', '1');
        var old = t.textContent;
        t.textContent = 'Click again';
        toast(ask);
        setTimeout(function () { t.removeAttribute('data-armed'); t.textContent = old; }, 3000);
        return;
      }
    }
    send(cmd);
  });

  document.addEventListener('keydown', function (e) {
    if (listening) {
      e.preventDefault();
      var c = codeOf(e);
      var dik = DIK[c];
      if (!dik) { toast('That key cannot be bound.'); return; }
      if (RESERVED[dik]) { toast(RESERVED[dik] + '.'); return; }
      listening = false;
      send('s|key|' + dik);
      toast('Hotkey set to ' + keyName(dik));
      return;
    }
    if (S && DIK[codeOf(e)] === (S.settings.key || 65)) {
      e.preventDefault();
      send('close');
    }
  });

  // --- browser preview -----------------------------------------------------
  // Opened outside the game there is no window.shk, so fake a small party.

  function mock(cmd) {
    if (!S) return;
    var p = cmd.split('|');
    if (p[0] === 'close') { toast('(preview) close'); return; }
    S.ack = seq;
    if (p[0] === 's') {
      // predicted
    } else if (p[0] === 'f') {
      var f = find(Number(p[1]));
      var n = Number(p[3]);
      if (!f) return;
      if (QUICK.indexOf(p[2]) >= 0) { /* predicted */ }
      else if (p[2] === 'sethome') f.home = 'Breezehome';
      else if (p[2] === 'clearhome') f.home = '';
      else if (p[2] === 'outfitsave') f.outfits[n] = 4;
      else if (p[2] === 'outfitclear') f.outfits[n] = 0;
      else if (p[2] === 'outfitwear') f.outfitnow = n;
      else if (p[2] === 'give') f.sell += 3;
      else if (p[2] === 'sell') { f.mode = 6; f.merchant = 'Belethor'; }
      else if (p[2] === 'sellcancel') { f.mode = 0; f.merchant = ''; }
      else if (p[2] === 'sellclear') f.sell = 0;
      else if (p[2] === 'dismiss') {
        S.followers = S.followers.filter(function (x) { return x !== f; });
        S.registry.push({ id: f.id, name: f.name, race: f.race, lvl: f.lvl, home: f.home });
      }
    } else if (p[0] === 'r' && p[2] === 'forget') {
      S.registry = S.registry.filter(function (x) { return x.id !== Number(p[1]); });
    }
    S.focus = 0;
    window.shkState(S);
  }

  if (typeof window.shk !== 'function') {
    window.shkState({
      v: 1, focus: 0, max: 30,
      settings: { key: 65, catchup: 3000, level: 0, levelpct: 90, notify: 1, autooutfit: 1, dist: 1, scale: 100, theme: 'vellum', power: 1 },
      followers: [
        { id: 1, name: 'Lydia', race: 'Nord', cls: 'Warrior', lvl: 18, hp: 82, mp: 40, sp: 65, mode: 0, dist: 1, style: 5, stance: 0, prot: 2, away: 210, combat: 0, home: 'Breezehome', outfitauto: 1, outfitnow: 0, outfits: [5, 3, 0, 2, 0], sell: 0, bonus: 0 },
        { id: 2, name: 'Marcurio', race: 'Imperial', cls: 'Mage', lvl: 16, hp: 100, mp: 72, sp: 90, mode: 1, dist: 2, style: 3, stance: 2, prot: 1, away: 3400, combat: 0, home: '', outfitauto: 0, outfitnow: -1, outfits: [0, 0, 0, 0, 0], sell: 6, bonus: 0 },
        { id: 3, name: 'Jenassa', race: 'Dark Elf', cls: 'Thief', lvl: 15, hp: 34, mp: 60, sp: 20, mode: 0, dist: 0, style: 2, stance: 1, prot: 0, away: 400, combat: 1, home: '', outfitauto: 1, outfitnow: 4, outfits: [3, 0, 0, 0, 4], sell: 0, bonus: 2 }
      ],
      others: [{ id: 9, name: 'Meeko', race: 'Dog', lvl: 5, hp: 100 }],
      registry: [{ id: 4, name: 'Uthgerd the Unbroken', race: 'Nord', lvl: 20, home: 'Jorrvaskr' }]
    });
  } else {
    send('refresh');
  }
})();
