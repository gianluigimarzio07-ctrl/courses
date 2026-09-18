--[[
    AUREA · Misure di prevenzione — configurazione

    IL PEZZO CHE MANCAVA ALLA GIUSTIZIA

    ita_giustizia arresta e condanna. ita_famiglie accumula calore e apre
    il fascicolo associativo. Ma in Italia la cosa che alle organizzazioni
    fa davvero male non è la galera: è il sequestro.

    IL PRINCIPIO, CHE È SEMPLICE E DEVASTANTE

    D.Lgs. 159/2011, il codice antimafia. Se una persona ha un patrimonio
    SPROPORZIONATO rispetto al reddito che ha dichiarato, e non riesce a
    giustificarne la provenienza, quel patrimonio si sequestra. Non serve
    una condanna. Non serve provare che quella casa è frutto di un reato
    preciso: basta che non torni il conto.

    Qui il conto lo fa il server, e lo fa con numeri che esistono già:
    quanto hai dichiarato al fisco da una parte, quanto valgono case,
    veicoli, conti e cripto dall'altra.

    LE TRE FASI

        proposta      la avanza la DDA, e apre il contraddittorio
        giustificazione  il proposto ha un tempo per spiegare
        confisca      quello che non ha giustificato passa allo Stato

    E POI LA COSA CHE CONTA DAVVERO

    Il bene confiscato non sparisce e non viene venduto all'asta: va in
    RIUTILIZZO SOCIALE. Diventa la sede di un'associazione, un alloggio
    per chi non ne ha, la mensa della parrocchia. È la legge Rognoni-La
    Torre, ed è la ragione per cui in Italia si confisca invece di
    multare: perché la cosa tolta si vede.
]]

ANT = {}

-- Chi propone la misura: la Direzione Distrettuale Antimafia, cioè un
-- magistrato, su segnalazione della polizia giudiziaria.
ANT.Magistratura = 'giudice'
ANT.PoliziaGiudiziaria = { 'carabinieri', 'polizia', 'guardia_finanza' }

-- ---------------------------------------------------------------------------
--  La sede
-- ---------------------------------------------------------------------------
ANT.Sede = {
    nome = 'Direzione Distrettuale Antimafia',
    coord = vector3(252.4, -430.6, 48.1),
    raggio = 2.3,
    blip = { sprite = 526, colore = 27, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  Presupposti
-- ---------------------------------------------------------------------------
ANT.Presupposti = {
    -- Calore minimo dell'organizzazione di appartenenza
    caloreMinimo = 45,
    -- Oppure: gravità cumulata nel casellario
    gravitaCumulata = 8,
    -- La sproporzione che fa scattare la misura: patrimonio oltre questa
    -- volta il reddito dichiarato
    sproporzione = 2.5,
    -- Sotto questo patrimonio non si procede: non si sequestra la spesa
    patrimonioMinimo = 5000000,     -- 50.000 €
}

-- ---------------------------------------------------------------------------
--  Il contraddittorio
-- ---------------------------------------------------------------------------
ANT.Contraddittorio = {
    -- Quanto tempo ha il proposto per giustificare, in minuti
    minuti = 30,
    -- Cosa vale come giustificazione: il reddito dichiarato al fisco nel
    -- periodo, più le fatture emesse, più le vincite tracciate
    -- Ogni euro giustificato salva un euro di patrimonio.
    fonti = { 'redditi', 'fatture', 'vincite' },
}

-- ---------------------------------------------------------------------------
--  Cosa si aggredisce, e in che ordine
--
--  Prima il liquido, poi i beni mobili, poi gli immobili. È l'ordine
--  vero, ed è anche quello che fa meno danni a chi non c'entra.
-- ---------------------------------------------------------------------------
ANT.Ordine = { 'banca', 'cripto', 'veicoli', 'immobili' }

ANT.Valori = {
    -- Quanto conta un veicolo ai fini del patrimonio: il valore di
    -- listino, scontato dell'usura presunta
    scontoVeicolo = 0.65,
}

-- ---------------------------------------------------------------------------
--  Sorveglianza speciale
--
--  La misura personale: obblighi che restano addosso.
-- ---------------------------------------------------------------------------
ANT.Sorveglianza = {
    durataMinuti = 120,
    -- Non può portare armi
    vietaArmi = true,
    -- Non può stare fuori la notte: se lo trovano, è violazione
    coprifuocoDalle = 23,
    coprifuocoAlle = 6,
    -- La violazione è un reato autonomo
    reatoViolazione = '385',
    -- E fa decadere ogni licenza
    revocaLicenze = true,
}

-- ---------------------------------------------------------------------------
--  Riutilizzo sociale
--
--  Le destinazioni possibili di un immobile confiscato. Chi le assegna è
--  il Comune: è una scelta politica, e deve restare tale.
-- ---------------------------------------------------------------------------
ANT.Riutilizzo = {
    { id = 'alloggio', nome = 'Alloggio popolare',
      descrizione = 'Assegnato a chi non ha casa. Torna nel patrimonio comunale.' },
    { id = 'mensa', nome = 'Mensa solidale',
      descrizione = 'Rifornisce la dispensa della parrocchia.',
      porzioni = 120 },
    { id = 'associazione', nome = 'Sede di associazione',
      descrizione = 'Diventa la sede del gruppo comunale di protezione civile.' },
    { id = 'presidio', nome = 'Presidio delle forze dell\'ordine',
      descrizione = 'Un posto in più dove si vede una divisa.' },
}

function ANT.GetRiutilizzo(id)
    for _, r in ipairs(ANT.Riutilizzo) do
        if r.id == id then return r end
    end
end

--- Il testo che spiega la sproporzione, per il decreto.
function ANT.Motivazione(patrimonio, reddito, giustificato)
    local scoperto = math.max(0, patrimonio - reddito - giustificato)
    return ('Patrimonio accertato %s a fronte di redditi dichiarati %s%s. Quota non giustificata: %s.')
        :format(AUREA.Util.Euro(patrimonio), AUREA.Util.Euro(reddito),
                giustificato > 0 and (' e giustificazioni per ' .. AUREA.Util.Euro(giustificato)) or '',
                AUREA.Util.Euro(scoperto)), scoperto
end
