// Adaptador móvil de FFoundryCon para Foundry VTT. Lo inyecta
// lib/features/player/pages/foundry_sheet_page.dart tras cada carga de página,
// precedido por `const FFC = {actorId, css};`. Idempotente; no envía nada
// de vuelta a la app.
(() => {
  if (window.__ffcAdapter) return;
  window.__ffcAdapter = true;

  // Sin canvas: client setting de Foundry guardado en localStorage. Si estamos
  // en /game y aún no estaba activo, recargar para que Foundry lo lea al iniciar.
  if (localStorage.getItem('core.noCanvas') !== 'true') {
    localStorage.setItem('core.noCanvas', 'true');
    if (location.pathname.endsWith('/game')) {
      location.reload();
      return;
    }
  }

  let viewport = document.querySelector('meta[name="viewport"]');
  if (!viewport) {
    viewport = document.createElement('meta');
    viewport.name = 'viewport';
    document.head.appendChild(viewport);
  }
  viewport.content = 'width=device-width, initial-scale=1';

  const style = document.createElement('style');
  style.id = 'ffc-style';
  style.textContent = FFC.css;
  document.head.appendChild(style);

  // Avisos de resolución mínima de Foundry (1024×700): en el teléfono siempre
  // saltan y no aportan. Se cortan en Notifications#notify (el mensaje puede
  // llegar como clave i18n) y, si alguno ya se mostró antes de inyectar, se
  // ocultan en el DOM (re-chequeando tras el render, el texto puede llegar
  // después del nodo).
  const usabilityNotice =
    /1024\s*px|resolution|resoluci[oó]n|Chromium version|modern JavaScript features/i;
  const isUsabilityNotice = (message) => {
    if (typeof message !== 'string') return false;
    const text = window.game?.i18n?.localize?.(message) ?? message;
    return usabilityNotice.test(message) || usabilityNotice.test(text);
  };
  const Notifications =
    window.CONFIG?.ui?.notifications ?? window.foundry?.applications?.ui?.Notifications;
  if (Notifications?.prototype?.notify && !Notifications.prototype.__ffc) {
    const notify = Notifications.prototype.notify;
    Notifications.prototype.notify = function (message, ...rest) {
      if (isUsabilityNotice(message)) return null;
      return notify.call(this, message, ...rest);
    };
    Notifications.prototype.__ffc = true;
  }
  const hideNotice = (n) => {
    const el = n.nodeType === 1 ? n.closest('.notification') : null;
    if (el && usabilityNotice.test(el.textContent)) el.style.display = 'none';
  };
  const scanNotices = () =>
    document.querySelectorAll('.notification').forEach(hideNotice);
  scanNotices();
  new MutationObserver((records) => {
    if (records.some((r) => r.target.closest?.('#notifications'))) {
      requestAnimationFrame(scanNotices);
    }
  }).observe(document.body, { childList: true, subtree: true });

  if (!location.pathname.endsWith('/game')) return;
  document.body.classList.add('ffc-mobile');

  // Pantalla de carga hasta que se abre la hoja (Foundry tarda en inicializar
  // el mundo). Se quita al renderizar la hoja de personaje, si no hay
  // personaje, o a los 60 s como red de seguridad.
  const loading = document.createElement('div');
  loading.id = 'ffc-loading';
  const spinner = document.createElement('div');
  spinner.className = 'ffc-spinner';
  const loadingText = document.createElement('span');
  loadingText.textContent = 'Cargando hoja…';
  loading.append(spinner, loadingText);
  document.body.appendChild(loading);
  const hideLoading = () => loading.remove();
  setTimeout(hideLoading, 60000);

  const openChat = () => {
    const sidebar = window.ui?.sidebar;
    try {
      sidebar?.expand?.();
      if (sidebar?.changeTab) sidebar.changeTab('chat', 'primary');
      else sidebar?.activateTab?.('chat');
    } catch (e) {
      console.warn('FFoundryCon: no se pudo abrir el chat', e);
    }
  };

  const toggle = document.createElement('button');
  toggle.id = 'ffc-chat-toggle';
  toggle.type = 'button';
  // Burbuja con ícono (Font Awesome viene con Foundry): chat / volver a hoja.
  // El ícono va en un <i>: con las clases fa-* en el <button>, la regla de
  // fuente de botones de Foundry le gana y se ve el glifo roto.
  const icon = (name) => {
    const i = document.createElement('i');
    i.className = `fa-solid ${name}`;
    i.inert = true;
    return i;
  };
  toggle.replaceChildren(icon('fa-comment'));
  toggle.setAttribute('aria-label', 'Chat');
  const setChatOpen = (open) => {
    document.body.classList.toggle('ffc-chat-open', open);
    toggle.replaceChildren(icon(open ? 'fa-scroll' : 'fa-comment'));
    toggle.setAttribute('aria-label', open ? 'Hoja' : 'Chat');
    if (open) openChat();
  };
  toggle.addEventListener('click', () =>
    setChatOpen(!document.body.classList.contains('ffc-chat-open')),
  );
  document.body.appendChild(toggle);

  // Todo mensaje propio (tiradas, tarjetas de items, texto) abre el chat: ahí
  // sigue el flujo (MidiQOL espera el botón de ataque/daño si no auto-tira) y
  // con el chat oculto parecía que no pasaba nada. Se baja hasta el mensaje.
  Hooks.on('createChatMessage', (message) => {
    if (!message.isAuthor) return;
    setChatOpen(true);
    setTimeout(() => ui.chat?.scrollBottom?.({ waitImages: true }), 100);
  });

  // Hojas de actor/item (ApplicationV2): marcar con `ffc-sheet` en cada render
  // para el layout móvil de adapter.css. Nunca mover nodos de Foundry: AppV2
  // re-renderiza por parts (`data-application-part`) y los reemplaza; solo se
  // agregan elementos propios (`ffc-*`), re-creados en cada render.
  const isDocSheet = (app) => {
    const DocumentSheetV2 = foundry.applications?.api?.DocumentSheetV2;
    const type = app.document?.documentName;
    return (
      !!DocumentSheetV2 &&
      app instanceof DocumentSheetV2 &&
      (type === 'Actor' || type === 'Item')
    );
  };

  // Retrato chico junto al nombre (el de la sidebar se oculta por CSS). El
  // click delega en el retrato original (editar imagen / ver arte).
  const addHeaderPortrait = (app, el) => {
    const header = el.querySelector('.sheet-header');
    const img = app.document?.img;
    if (!header || !img || !el.querySelector('.sidebar .portrait')) return;
    let portrait = header.querySelector('.ffc-portrait');
    if (!portrait) {
      portrait = document.createElement('img');
      portrait.className = 'ffc-portrait';
      portrait.alt = '';
      portrait.addEventListener('click', () =>
        el.querySelector('.sidebar .portrait > :is(img, video)')?.click(),
      );
      header.prepend(portrait);
    }
    if (portrait.getAttribute('src') !== img) portrait.src = img;
  };

  // Header colapsable: al scrollear el cuerpo (.main-content, que dnd5e
  // re-crea en cada render, por eso se escucha en captura sobre la hoja).
  const watchScroll = (el) => {
    if (el.dataset.ffcScroll) return;
    el.dataset.ffcScroll = '1';
    el.addEventListener(
      'scroll',
      (ev) => {
        const body = ev.target;
        if (!body.classList?.contains('main-content')) return;
        // Histéresis, y sin colapsar si el contenido apenas scrollea (al
        // achicarse el header el scroll volvería a 0 y oscilaría).
        if (
          body.scrollTop > 48 &&
          body.scrollHeight - body.clientHeight > 240
        ) {
          el.classList.add('ffc-header-collapsed');
        } else if (body.scrollTop < 8) {
          el.classList.remove('ffc-header-collapsed');
        }
      },
      { capture: true, passive: true },
    );
  };

  // Botones propios en el header de ventana, que es parte del marco y
  // sobrevive a los re-renders de parts.
  const addHeaderButton = (el, cls, icon, tooltip, onClick) => {
    const header = el.querySelector('.window-header');
    if (!header || header.querySelector(`.${cls}`)) return;
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `header-control icon fa-solid ${icon} ${cls}`;
    btn.dataset.tooltip = tooltip;
    btn.addEventListener('click', (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      onClick();
    });
    const title = header.querySelector('.window-title');
    if (title) title.after(btn);
    else header.prepend(btn);
  };

  const adaptSheet = (app, el) => {
    if (!el || !isDocSheet(app)) return;
    el.classList.add('ffc-sheet');
    addHeaderPortrait(app, el);
    watchScroll(el);
    // Solo hoja de personaje (tiene sidebar).
    if (!el.querySelector('.sidebar')) return;
    hideLoading();
    addHeaderButton(el, 'ffc-sidebar-toggle', 'fa-chart-simple', 'Estadísticas', () =>
      el.classList.toggle('ffc-sidebar-open'),
    );
  };

  Hooks.on('renderApplicationV2', (app, el) => adaptSheet(app, el));
  for (const app of foundry.applications?.instances?.values?.() ?? []) {
    adaptSheet(app, app.element);
  }

  // iOS WebKit no convierte long-press en `contextmenu` (Android sí): sin esto
  // no hay menús contextuales de items/efectos.
  const isIOS =
    /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (isIOS) {
    let timer = null;
    let start = null;
    let suppressClick = false;
    const cancel = () => {
      clearTimeout(timer);
      timer = null;
    };
    document.addEventListener(
      'touchstart',
      (ev) => {
        cancel();
        // Un long-press puede no generar click: no arrastrar la supresión.
        suppressClick = false;
        if (ev.touches.length !== 1) return;
        const t = ev.touches[0];
        start = { x: t.clientX, y: t.clientY, target: ev.target };
        timer = setTimeout(() => {
          timer = null;
          suppressClick = true;
          start.target.dispatchEvent(
            new MouseEvent('contextmenu', {
              bubbles: true,
              cancelable: true,
              clientX: start.x,
              clientY: start.y,
              button: 2,
            }),
          );
        }, 500);
      },
      { passive: true },
    );
    document.addEventListener(
      'touchmove',
      (ev) => {
        const t = ev.touches[0];
        if (start && Math.hypot(t.clientX - start.x, t.clientY - start.y) > 10) {
          cancel();
        }
      },
      { passive: true },
    );
    document.addEventListener('touchend', cancel, { passive: true });
    document.addEventListener('touchcancel', cancel, { passive: true });
    // El tap que termina el long-press no debe además activar el item.
    document.addEventListener(
      'click',
      (ev) => {
        if (!suppressClick) return;
        suppressClick = false;
        ev.preventDefault();
        ev.stopPropagation();
      },
      true,
    );
  }

  // Manda el usuario logueado en Foundry: su personaje asignado; si no tiene,
  // el elegido en la app solo si es dueño (puede ser otro usuario del reader).
  const openSheet = () => {
    const user = game.user;
    const selected = FFC.actorId && game.actors?.get(FFC.actorId);
    const actor =
      user?.character ||
      (selected?.isOwner ? selected : null) ||
      (!user?.isGM &&
        game.actors?.find((a) => a.type === 'character' && a.isOwner));
    if (!actor) {
      hideLoading();
      ui.notifications?.warn('FFoundryCon: personaje no encontrado');
      return;
    }
    actor.sheet?.render(true);
  };

  // Sin canvas no hay tokens dibujados (`TokenDocument#object` es null) y
  // MidiQOL los necesita: arma el del atacante desde el prototypeToken con
  // `parent: canvas.scene` (null → PlaceableObject lo rechaza) y resuelve los
  // objetivos con `fromUuidSync(uuid).object`. Se usan tokens solo en memoria:
  // nunca dibujados ni guardados, y sin tocar `_object`, así `rendered` sigue
  // en false y Foundry no les manda actualizaciones de canvas.
  const memTokens = new WeakMap();
  const patchNoCanvasTokens = () => {
    const Base = CONFIG.Token?.objectClass;
    if (Base && !Object.hasOwn(Base, '__ffcNoCanvas')) {
      class FfcToken extends Base {
        constructor(document, ...rest) {
          const scene = game.scenes?.active ?? game.scenes?.contents?.[0];
          if (document && !document.isEmbedded && scene) {
            document = new document.constructor(document.toObject(), {
              parent: scene,
            });
          }
          super(document, ...rest);
          if (!memTokens.has(this.document)) memTokens.set(this.document, this);
        }
      }
      FfcToken.__ffcNoCanvas = true;
      CONFIG.Token.objectClass = FfcToken;
    }

    let proto = CONFIG.Token?.documentClass?.prototype;
    while (proto && !Object.hasOwn(proto, 'object')) {
      proto = Object.getPrototypeOf(proto);
    }
    if (!proto || Object.hasOwn(proto, '__ffcObject')) return;
    const object = Object.getOwnPropertyDescriptor(proto, 'object');
    Object.defineProperty(proto, 'object', {
      configurable: true,
      get() {
        return object.get.call(this) ?? memTokens.get(this) ?? null;
      },
    });
    proto.__ffcObject = true;
  };

  const memToken = (doc) =>
    memTokens.get(doc) ?? new CONFIG.Token.objectClass(doc);

  // Selector de objetivos: tokens vivos y visibles de la escena activa
  // (combatientes y hostiles primero). Tocar uno lo agrega/saca de `game.user.targets`, que es
  // de donde MidiQOL toma los objetivos al usar una actividad.
  const targetsPanel = document.createElement('div');
  targetsPanel.id = 'ffc-targets';
  document.body.appendChild(targetsPanel);

  // Botón flotante (sobre hoja y chat), arriba del de chat.
  const targetsToggle = document.createElement('button');
  targetsToggle.id = 'ffc-targets-toggle';
  targetsToggle.type = 'button';
  targetsToggle.addEventListener('click', () => openTargets());
  document.body.appendChild(targetsToggle);

  const updateTargetsBadge = () => {
    const n = game.user?.targets?.size ?? 0;
    targetsToggle.textContent = n ? `🎯 ${n}` : '🎯';
  };
  updateTargetsBadge();
  // MidiQOL u otros módulos pueden cambiar los objetivos (p.ej. destargetear
  // tras el ataque).
  Hooks.on('targetToken', (user) => {
    if (user === game.user) updateTargetsBadge();
  });

  const broadcastTargets = () => {
    game.user.broadcastActivity?.({ targets: game.user.targets.ids });
    updateTargetsBadge();
  };

  const targetCandidates = () => {
    const scene = game.scenes?.active;
    if (!scene) return [];
    const combatants = new Map(
      game.combat?.scene?.id === scene.id
        ? game.combat.combatants.map((c) => [c.tokenId, c])
        : [],
    );
    const inCombat = new Set(combatants.keys());
    const dead = CONFIG.specialStatusEffects?.DEFEATED ?? 'dead';
    // Sin canvas no hay visión: se excluye lo que el jugador no vería (token u
    // combatiente ocultos, invisibles/escondidos ajenos) y los muertos.
    const targetable = (t) => {
      const statuses = t.actor.statuses ?? new Set();
      const c = combatants.get(t.id);
      if (t.hidden || t.isSecret || c?.hidden) return false;
      if (statuses.has(dead) || c?.isDefeated) return false;
      if (!t.isOwner && (statuses.has('invisible') || statuses.has('hiding'))) {
        return false;
      }
      return true;
    };
    const rank = (t) =>
      (inCombat.has(t.id) ? 0 : 10) +
      ({ [-1]: 0, 0: 1, 1: 2 }[t.disposition] ?? 3);
    return scene.tokens
      .filter((t) => t.actor && targetable(t))
      .sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
  };

  // Pestañas: aliados (disposición amistosa) y enemigos (hostiles y
  // neutrales). Recuerda la última elegida mientras viva la página.
  const targetTabs = [
    { id: 'enemies', label: 'Enemigos', match: (t) => t.disposition !== 1 },
    { id: 'allies', label: 'Aliados', match: (t) => t.disposition === 1 },
  ];
  let targetTab = 'enemies';

  const renderTargets = () => {
    const targeted = new Set(game.user.targets.ids);
    const candidates = targetCandidates();
    const tab = targetTabs.find((x) => x.id === targetTab);
    const rows = candidates.filter(tab.match).map((t) => {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = 'ffc-target';
      row.classList.toggle('active', targeted.has(t.id));
      row.dataset.disposition = String(t.disposition);
      const img = document.createElement('img');
      img.src = t.texture?.src ?? t.actor.img;
      img.alt = '';
      const name = document.createElement('span');
      name.textContent = t.name;
      row.append(img, name);
      row.addEventListener('click', () => {
        const token = memToken(t);
        if (game.user.targets.has(token)) game.user.targets.delete(token);
        else game.user.targets.add(token);
        broadcastTargets();
        renderTargets();
      });
      return row;
    });

    const header = document.createElement('header');
    const title = document.createElement('h3');
    title.textContent = 'Objetivos';
    // Limpiar y cerrar abajo, donde están las burbujas de objetivos y chat
    // (ocultas con el panel abierto).
    const clear = document.createElement('button');
    clear.type = 'button';
    clear.className = 'ffc-targets-clear';
    clear.textContent = 'Limpiar';
    clear.addEventListener('click', () => {
      game.user.targets.clear();
      broadcastTargets();
      renderTargets();
    });
    const close = document.createElement('button');
    close.type = 'button';
    close.className = 'ffc-targets-close';
    close.setAttribute('aria-label', 'Cerrar');
    close.append(icon('fa-xmark'));
    close.addEventListener('click', () =>
      document.body.classList.remove('ffc-targets-open'),
    );
    header.append(title);

    const tabs = document.createElement('nav');
    tabs.className = 'ffc-target-tabs';
    for (const x of targetTabs) {
      const b = document.createElement('button');
      b.type = 'button';
      b.classList.toggle('active', x.id === targetTab);
      const n = candidates.filter((t) => x.match(t) && targeted.has(t.id)).length;
      b.textContent = n ? `${x.label} (${n})` : x.label;
      b.addEventListener('click', () => {
        targetTab = x.id;
        renderTargets();
      });
      tabs.append(b);
    }

    const list = document.createElement('div');
    list.className = 'ffc-target-list';
    if (rows.length) list.append(...rows);
    else list.textContent = 'No hay tokens en esta lista.';
    targetsPanel.replaceChildren(header, tabs, list, clear, close);
  };

  function openTargets() {
    renderTargets();
    document.body.classList.add('ffc-targets-open');
  }

  const onReady = () => {
    patchNoCanvasTokens();
    openSheet();
  };
  if (window.game?.ready) onReady();
  else Hooks.once('ready', onReady);
})();
