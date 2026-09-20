--[[
    AUREA · Tiro a Segno Nazionale (configurazione)

    UNA RISORSA CHE ESISTE PER UN CERTIFICATO

    In Italia il porto d'armi non lo dà la Questura a chi lo chiede: lo dà
    a chi ha già in mano un pezzo di carta rilasciato da un'altra parte,
    il CERTIFICATO DI IDONEITÀ AL MANEGGIO DELLE ARMI. Lo rilascia la
    sezione del Tiro a Segno Nazionale, che non è un ufficio pubblico: è
    un poligono, con un istruttore dentro.

    È una separazione che sembra burocratica e invece è il punto: lo Stato
    non verifica se sai sparare, verifica che qualcuno che sa sparare
    abbia detto che sai sparare. E quel qualcuno è una persona, in un
    posto, che ci mette la firma.

    Da qui passano due cose che il server già faceva:

    · il porto d'armi della Questura (ita_questura),
    · il decreto di guardia particolare giurata (ita_sicurezza).

    Senza il certificato, nessuna delle due si ottiene più. È la ragione
    per cui il poligono non è un passatempo.
]]

TSN = {}

TSN.Lavoro = 'tsn'

-- ---------------------------------------------------------------------------
--  Il poligono
-- ---------------------------------------------------------------------------
TSN.Sezione = {
    nome = 'Sezione del Tiro a Segno Nazionale',
    coord = vector3(16.4, -1108.2, 29.8),
    raggio = 2.4,
    blip = { sprite = 313, colore = 40, scala = 0.7 },

    -- Le piazzole di tiro: si spara da qui, non da dove capita
    linee = {
        vector3(21.2, -1099.8, 29.8),
        vector3(24.8, -1099.8, 29.8),
        vector3(28.4, -1099.8, 29.8),
    },
    raggioLinea = 2.0,
}

-- ---------------------------------------------------------------------------
--  Iscrizione
-- ---------------------------------------------------------------------------
TSN.Iscrizione = {
    quota = 8500,
    giorniValidita = 180,
}

-- ---------------------------------------------------------------------------
--  Le lezioni
--
--  Il certificato non si compra: si fanno le lezioni, e ogni lezione ha
--  un punteggio. Chi spara male ripete.
-- ---------------------------------------------------------------------------
TSN.Lezione = {
    costo = 4200,
    colpi = 10,
    durataSecondi = 45,

    -- Punteggio minimo perché la lezione conti
    punteggioMinimo = 55,

    -- Quante lezioni valide servono per il certificato
    lezioniPerCertificato = 3,

    -- Compenso dell'istruttore presente sulla linea
    compensoIstruttore = 2800,

    -- Con l'istruttore in servizio si spara meglio: è il senso di avere
    -- qualcuno che ti corregge la posizione.
    bonusIstruttore = 18,
}

-- ---------------------------------------------------------------------------
--  Certificato
-- ---------------------------------------------------------------------------
TSN.Certificato = {
    costo = 6500,
    giorniValidita = 120,
    secondiRilascio = 20,
}

--- Il punteggio di una serie: media pesata dei colpi, fra 0 e 100.
--- Il sorteggio sta sul server e non è mai il client a dire quanto ha
--- fatto: un punteggio dichiarato dal client sarebbe un certificato
--- dichiarato dal client, e quindi un porto d'armi dichiarato dal client.
function TSN.Serie(colpi, conIstruttore)
    local totale = 0
    for _ = 1, colpi do
        totale = totale + math.random(0, 10)
    end
    local punteggio = math.floor((totale / (colpi * 10)) * 100)
    if conIstruttore then punteggio = punteggio + TSN.Lezione.bonusIstruttore end
    return math.min(100, punteggio), totale
end
