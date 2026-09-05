// AUREA · Musica — riproduzione lato NUI.
// Il Lua decide che volume dare; qui si riproduce e basta.

const lettori = new Map();
let apiPronta = false;

// L'API di YouTube va caricata una volta sola
const tag = document.createElement('script');
tag.src = 'https://www.youtube.com/iframe_api';
document.head.appendChild(tag);
window.onYouTubeIframeAPIReady = () => { apiPronta = true; };

function idYouTube(url) {
  const m = String(url).match(/(?:v=|youtu\.be\/|embed\/)([A-Za-z0-9_-]{11})/);
  return m ? m[1] : null;
}

function riproduci({ id, url, volume, da }) {
  ferma(id);

  const video = idYouTube(url);
  if (!video) return;

  const contenitore = document.createElement('div');
  contenitore.id = `lettore-${id}`;
  document.getElementById('lettori').appendChild(contenitore);

  const crea = () => {
    const p = new YT.Player(contenitore.id, {
      height: '1', width: '1', videoId: video,
      playerVars: { autoplay: 1, controls: 0, disablekb: 1, start: Math.floor(da || 0) },
      events: {
        onReady: (e) => {
          e.target.setVolume(Math.round((volume || 0) * 100));
          e.target.playVideo();
        },
      },
    });
    lettori.set(id, p);
  };

  if (apiPronta) crea();
  else {
    const attesa = setInterval(() => {
      if (apiPronta) { clearInterval(attesa); crea(); }
    }, 250);
  }
}

function impostaVolume(id, volume) {
  const p = lettori.get(id);
  if (p && p.setVolume) p.setVolume(Math.round(Math.max(0, Math.min(1, volume)) * 100));
}

function ferma(id) {
  const p = lettori.get(id);
  if (p && p.destroy) p.destroy();
  lettori.delete(id);
  const el = document.getElementById(`lettore-${id}`);
  if (el) el.remove();
}

window.addEventListener('message', (evento) => {
  const d = evento.data || {};
  if (d.azione === 'riproduci') riproduci(d);
  else if (d.azione === 'volume') impostaVolume(d.id, d.volume);
  else if (d.azione === 'ferma') ferma(d.id);
});
