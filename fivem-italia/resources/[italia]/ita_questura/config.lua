--[[
    AUREA · Questura — Divisione Polizia Amministrativa (configurazione)

    LE LICENZE DI POLIZIA

    C'è una categoria di cose che in Italia non si comprano e non si
    chiedono al Comune: si chiedono alla Questura, e la Questura può dire
    di no senza doversi giustificare troppo. Si chiamano licenze di
    polizia e stanno tutte nel TULPS, un testo unico del 1931 che è ancora
    lì e regge mezzo paese.

    Tre in particolare contano, qui:

    · IL PASSAPORTO. Art. 3 della legge 1185/1967: non si rilascia a chi
      ha procedimenti penali pendenti. Non è un dettaglio burocratico —
      è il motivo per cui in Italia chi è indagato non può andarsene.

    · IL PORTO D'ARMI. Serve il certificato di idoneità al maneggio delle
      armi, che rilascia il Tiro a Segno Nazionale e non la Questura. Due
      uffici diversi per una cosa sola: è il motivo per cui ita_tsn esiste.

    · LA LICENZA DI PUBBLICO SPETTACOLO (art. 68 TULPS). Senza, un locale
      non può fare serate. Con, ma senza rispettare la capienza, la
      licenza la si perde.

    E POI IL DASPO

    Il divieto di accesso ai luoghi in cui si svolgono manifestazioni.
    Nato per gli stadi (L. 401/1989), oggi si applica anche ai locali e
    alle aree urbane. È un provvedimento del Questore, non di un giudice:
    non serve una condanna, basta la pericolosità. Chi ce l'ha, alla porta
    di una discoteca non entra — e il buttafuori che lo fa entrare risponde
    con il locale.
]]

QUE = {}

QUE.Lavoro = 'polizia'
QUE.Permesso = 'tulps'

-- ---------------------------------------------------------------------------
--  Lo sportello
-- ---------------------------------------------------------------------------
QUE.Sportello = {
    nome = 'Questura — Ufficio Polizia Amministrativa',
    coord = vector3(441.6, -978.4, 30.7),
    raggio = 2.4,
    blip = { sprite = 60, colore = 38, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  Passaporto
-- ---------------------------------------------------------------------------
QUE.Passaporto = {
    costo = 11600,          -- contributo amministrativo + bollo
    giorniValidita = 3650,
    secondiIstruttoria = 25,

    -- Art. 3 L. 1185/1967: con un procedimento penale aperto il
    -- passaporto non si rilascia, e se ce l'hai te lo ritirano.
    ostativoConProcedimentiAperti = true,
}

-- ---------------------------------------------------------------------------
--  Porto d'armi
-- ---------------------------------------------------------------------------
QUE.PortoArmi = {
    tipi = {
        { id = 'sportivo', nome = 'Porto d\'armi per uso sportivo',
          costo = 15000, giorni = 180,
          descrizione = 'Consente il trasporto scarico verso il poligono.' },
        { id = 'caccia',   nome = 'Licenza di porto di fucile per uso caccia',
          costo = 18000, giorni = 180,
          descrizione = 'Vale anche come titolo per la detenzione.' },
        { id = 'difesa',   nome = 'Porto d\'armi per difesa personale',
          costo = 42000, giorni = 90,
          descrizione = 'Il più difficile: serve un motivo, e il Questore lo valuta.' },
    },

    -- Il certificato del Tiro a Segno è indispensabile: senza, non se ne
    -- parla. Lo rilascia ita_tsn.
    richiedeCertificatoTSN = true,

    -- Gravità massima nel casellario compatibile con il rilascio
    gravitaMassima = 1,

    -- Reati che escludono per sempre
    reatiOstativi = { '628', '629', '416bis', '575', '582', '73', '336' },

    secondiIstruttoria = 30,
}

function QUE.GetTipoPortoArmi(id)
    for _, t in ipairs(QUE.PortoArmi.tipi) do
        if t.id == id then return t end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Licenza di pubblico spettacolo (art. 68 TULPS)
-- ---------------------------------------------------------------------------
QUE.LicenzaSpettacolo = {
    costo = 68000,
    giorniValidita = 60,
    secondiIstruttoria = 35,

    -- Chi la chiede deve avere un locale intestato: è il gestore, non
    -- un tizio qualunque.
    richiedeGestione = true,
}

-- ---------------------------------------------------------------------------
--  DASPO
-- ---------------------------------------------------------------------------
QUE.Daspo = {
    oreDefault = 120,
    oreMassime = 1440,

    -- Luoghi tipici: servono solo a proporre qualcosa nel menu, il
    -- Questore può scrivere quello che vuole.
    luoghi = {
        'Locali notturni',
        'Stadio comunale',
        'Centro storico',
        'Zona portuale',
        'Esercizi pubblici',
    },
}
