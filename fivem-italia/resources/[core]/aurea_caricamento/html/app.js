// AUREA · schermata di caricamento
// I consigli girano mentre il gioco carica: è l'unico momento in cui
// qualcuno li legge davvero.

const CONSIGLI = [
  'Qui le regole italiane sono la meccanica di gioco, non l\'ambientazione. Il codice della strada, il fisco e i documenti contano davvero.',
  'Tieni premuto il tasto destro del mouse per il "terzo occhio": punta una cosa e ti dice che ci puoi fare.',
  'Quello che scrivi in chat lo sente solo chi ti sta vicino. Usa /me per le azioni e /fai per descrivere l\'ambiente.',
  'Senza patente non si guida, senza assicurazione il veicolo si sequestra. Passa dall\'autoscuola prima di mettere le mani sul volante.',
  'Il denaro che spendi non sparisce: finisce nell\'erario, che paga stipendi pubblici e sussidi. L\'economia è chiusa.',
  'Nessuna rapina parte se non ci sono abbastanza agenti in servizio. Una rapina senza inseguimento non è roleplay, è un bancomat.',
  'Il sindaco lo eleggono i giocatori, e mentre governa decide sul serio: tasse, ZTL, sussidi.',
  'La droga qui è un problema di aritmetica: tagliare moltiplica la merce e abbassa la purezza. Troppo pura ammazza il cliente.',
  'Il tuo personaggio non sa quello che sai tu. Se l\'hai letto su Discord, lui lo ignora.',
  'Perdere fa parte del gioco. Un arresto o un\'auto rubata sono storie, non ingiustizie.',
  'Al Centro per l\'Impiego si trova un lavoro in due minuti. Da lì si costruisce il resto.',
  'La testata pubblica quello che succede, e chi viene raccontato male ha la rettifica e la querela. La cronaca esiste.',
  'Se qualcosa non torna, apri un ticket con /ticket. Non serve avere ragione per chiedere.',
  'Un cane trascurato scappa e non torna. È l\'unica cosa che si perde per disattenzione e non per una scelta sbagliata.',
  'Le piazze di spaccio si tengono in due: con una vedetta al suo posto si guadagna di più e si rischia meno.',
];

const elemento = document.getElementById('consiglio');
let indice = Math.floor(Math.random() * CONSIGLI.length);

function mostra() {
  elemento.classList.add('esce');
  setTimeout(() => {
    indice = (indice + 1) % CONSIGLI.length;
    elemento.textContent = CONSIGLI[indice];
    elemento.classList.remove('esce');
  }, 500);
}

elemento.textContent = CONSIGLI[indice];
setInterval(mostra, 7000);
