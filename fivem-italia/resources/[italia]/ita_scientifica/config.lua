--[[
    AUREA · Polizia Scientifica — configurazione

    Il problema che risolve: fino a ieri, chi sparava di notte in un vicolo
    deserto era impunibile per definizione. Nessuno l'aveva visto, quindi
    non era successo niente. Qui la scena resta.

    Un colpo lascia un bossolo, e il bossolo porta la matricola dell'arma.
    Un ferito lascia sangue, e il sangue porta il DNA. Una porta forzata
    lascia impronte, se chi l'ha forzata non aveva i guanti.

    Ma la traccia da sola non dice un nome: dice solo che due cose
    coincidono. Perché un profilo genetico diventi un'identità bisogna che
    quel profilo sia già in banca dati, e ci finisce solo con il
    fotosegnalamento dell'art. 349 c.p.p., cioè quando qualcuno è già stato
    portato in caserma almeno una volta. Un incensurato resta ignoto.

    È questo che rende il lavoro della Scientifica una cosa lenta e non un
    pulsante: le tracce vanno trovate, fotografate, repertate, portate in
    laboratorio e confrontate, e il confronto può benissimo non dare
    nessuno.
]]

SCI = {}

SCI.Lavori = { 'carabinieri', 'polizia' }

--- Chi accede al laboratorio: dentro la polizia giudiziaria, il RIS è un
--- reparto a parte e non ci entra la pattuglia di quartiere.
SCI.GradoLaboratorio = 3

-- ---------------------------------------------------------------------------
--  Le tracce
--
--  durata:      minuti prima che la traccia si degradi e sparisca
--  analizzabile: cosa può dire il laboratorio
--  visibileSenzaKit: se si vede a occhio nudo (il bossolo sì, il DNA no)
-- ---------------------------------------------------------------------------
SCI.Tracce = {
    bossolo = {
        nome = 'Bossolo', icona = '🔩',
        descrizione = 'Involucro espulso dall\'arma. Porta le impronte del percussore.',
        durata = 180, visibileSenzaKit = true,
        analizzabile = 'balistica',
        minutiAnalisi = 6,
    },
    sangue = {
        nome = 'Traccia ematica', icona = '🩸',
        descrizione = 'Macchia di sangue. Il profilo genetico è confrontabile.',
        durata = 240, visibileSenzaKit = true,
        analizzabile = 'dna',
        minutiAnalisi = 12,
    },
    impronte = {
        nome = 'Impronte digitali', icona = '👆',
        descrizione = 'Latenti su superficie liscia. Si rilevano con la polvere.',
        durata = 300, visibileSenzaKit = false,
        analizzabile = 'dattiloscopia',
        minutiAnalisi = 8,
    },
    residui = {
        nome = 'Residui dello sparo', icona = '💨',
        descrizione = 'Particelle di piombo, bario e antimonio: stub.',
        durata = 90, visibileSenzaKit = false,
        analizzabile = 'stub',
        minutiAnalisi = 5,
    },
    pneumatici = {
        nome = 'Tracce di pneumatico', icona = '🛞',
        descrizione = 'Impronta di battistrada. Dice il mezzo, non chi guidava.',
        durata = 120, visibileSenzaKit = true,
        analizzabile = 'battistrada',
        minutiAnalisi = 4,
    },
}

-- ---------------------------------------------------------------------------
--  Rilievi sulla scena
-- ---------------------------------------------------------------------------
SCI.Rilievi = {
    -- La valigetta serve per vedere le tracce latenti
    kit = 'kit_rilievi',
    -- La macchina fotografica: la traccia va documentata prima di toccarla
    fotocamera = 'fotocamera',
    -- Il tampone per il prelievo biologico
    tampone = 'tampone_dna',

    -- Quanto lontano si vedono le tracce con il kit in mano
    raggio = 25.0,
    -- Quanto ci si deve avvicinare per repertare
    raggioReperto = 2.0,

    durataFoto = 4000,
    durataReperto = 9000,

    -- Il reperto non repertato entro questo tempo si degrada comunque:
    -- vedi SCI.Tracce[x].durata
    massimoTracceScena = 40,
}

-- ---------------------------------------------------------------------------
--  Chi lascia tracce e chi no
-- ---------------------------------------------------------------------------
SCI.Regole = {
    -- I guanti impediscono le impronte, non il DNA e non i residui
    guanti = 'guanti',

    -- Probabilità che uno sparo lasci un bossolo recuperabile.
    -- Le armi a tamburo non espellono: lì il bossolo resta dentro.
    probabilitaBossolo = 72,
    -- Probabilità che restino residui sulle mani di chi ha sparato
    probabilitaResidui = 85,
    -- Per quanti minuti i residui restano sulle mani di chi ha sparato
    minutiResiduiSulleMani = 45,
    -- Lavarsi le mani li toglie: qualunque interazione con l'acqua
    -- (autolavaggio, doccia) azzera il conteggio

    -- Probabilità che una porta forzata trattenga impronte utili
    probabilitaImpronteScasso = 55,

    -- Quanto sangue lascia un ferito, per ferita
    probabilitaSangue = 90,

    -- Un bossolo di arma clandestina non porta a nessun intestatario:
    -- la matricola è abrasa. Il laboratorio lo dice, e già è qualcosa.
    matricolaAbrasa = 'ABRASA',
}

-- ---------------------------------------------------------------------------
--  Fotosegnalamento (art. 349 c.p.p.)
--
--  Senza questo, la banca dati è vuota e ogni confronto è negativo.
--  È il collo di bottiglia voluto: la Scientifica lavora bene su chi è
--  già passato per la caserma.
-- ---------------------------------------------------------------------------
SCI.Fotosegnalamento = {
    -- Solo su chi è in stato di fermo o di arresto
    soloSeAmmanettato = true,
    durata = 12000,
    -- Il rilievo scade: se il soggetto non torna in caserma per anni,
    -- il cartellino resta comunque. In gioco non scade.
    postazioni = {
        { nome = 'Gabinetto di segnalamento — Commissariato',
          coord = vector3(447.1, -978.2, 30.7) },
        { nome = 'Gabinetto di segnalamento — Comando Carabinieri',
          coord = vector3(-441.3, 6015.5, 31.7) },
    },
}

-- ---------------------------------------------------------------------------
--  Laboratorio
-- ---------------------------------------------------------------------------
SCI.Laboratorio = {
    nome = 'Gabinetto Regionale di Polizia Scientifica',
    coord = vector3(452.8, -996.4, 30.7),
    raggio = 3.0,
    blip = { sprite = 498, colore = 38, scala = 0.8 },

    -- L'analisi non è istantanea: si avvia e il referto arriva dopo.
    -- I minuti sono in SCI.Tracce[x].minutiAnalisi.
    -- Quante analisi contemporanee regge il laboratorio
    postazioni = 4,
}

-- ---------------------------------------------------------------------------
--  Esito del confronto
-- ---------------------------------------------------------------------------
SCI.Esiti = {
    -- Il DNA degradato non sempre dà un profilo utile
    probabilitaProfiloUtile = 82,
    -- Le impronte parziali a volte non bastano per il confronto
    probabilitaImprontaUtile = 70,
    -- La balistica sul bossolo è quasi sempre leggibile
    probabilitaBalisticaUtile = 94,
}

--- Dati di una tipologia di traccia.
function SCI.GetTraccia(tipo)
    return SCI.Tracce[tipo]
end

--- Il laboratorio è a portata?
function SCI.InLaboratorio(coord)
    return #(coord - SCI.Laboratorio.coord) <= SCI.Laboratorio.raggio + 1.0
end

--- Una postazione di fotosegnalamento a portata, o nil.
function SCI.PostazioneVicina(coord, distanza)
    for _, p in ipairs(SCI.Fotosegnalamento.postazioni) do
        if #(coord - p.coord) <= (distanza or 3.0) then return p end
    end
    return nil
end
