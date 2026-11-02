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

  if (!location.pathname.endsWith('/game')) return;
  document.body.classList.add('ffc-mobile');

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
  toggle.textContent = 'Chat';
  toggle.addEventListener('click', () => {
    const open = document.body.classList.toggle('ffc-chat-open');
    toggle.textContent = open ? 'Hoja' : 'Chat';
    if (open) openChat();
  });
  document.body.appendChild(toggle);

  const openSheet = () => {
    const actor =
      (FFC.actorId && game.actors?.get(FFC.actorId)) || game.user?.character;
    if (!actor) {
      ui.notifications?.warn('FFoundryCon: personaje no encontrado');
      return;
    }
    actor.sheet?.render(true);
  };

  if (window.game?.ready) openSheet();
  else Hooks.once('ready', openSheet);
})();
