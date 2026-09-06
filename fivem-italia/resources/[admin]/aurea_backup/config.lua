--[[
    AUREA · Copie di sicurezza — configurazione

    Va detto con onestà cosa è e cosa non è.

    Questo NON sostituisce mysqldump. Un backup vero del database si fa
    dal sistema operativo, con mysqldump e una rotazione fuori dalla
    macchina: se il disco muore, è quello che salva il server, e va
    configurato lo stesso. Nel README c'è come.

    Questo è l'altra cosa, quella che mysqldump da solo non copre bene:
    un'istantanea leggibile dei dati che contano di più — personaggi,
    conti, veicoli, inventari, imprese, immobili — scritta in JSON dentro
    la cartella della risorsa, ogni tot minuti, con rotazione. Serve a
    rispondere alle domande che arrivano davvero: "mi è sparita la
    macchina", "avevo cinquantamila euro in banca", "ieri avevo quel
    documento nell'inventario". Con un dump SQL di quindici ore prima
    quelle domande si risolvono male; con dodici istantanee dell'ultima
    giornata si risolvono in un minuto.

    E fa una cosa che mysqldump non fa: se qualcosa va storto durante la
    copia, lo dice sul canale staff invece di fallire in silenzio.
]]

BCK = {}

-- ---------------------------------------------------------------------------
--  Quando
-- ---------------------------------------------------------------------------
BCK.Cadenza = {
    -- Ogni quanti minuti si scrive un'istantanea
    minuti = 30,
    -- Quante istantanee si tengono prima di riscrivere sopra la più vecchia
    -- (30 minuti x 24 = mezza giornata di storia)
    quante = 24,
    -- La prima copia parte dopo questo tempo dall'avvio: serve a non
    -- pesare sul boot, quando il server è già occupato a caricare tutto
    ritardoAvvioMinuti = 5,
}

-- ---------------------------------------------------------------------------
--  Cosa
--
--  L'ordine conta: si copia prima quello che serve per ricostruire
--  l'identità, poi quello che le si attacca intorno.
--
--  righeMassime protegge la memoria del server: una tabella che è
--  cresciuta oltre quel numero viene troncata alle righe più recenti e la
--  cosa viene detta nel registro, non nascosta.
-- ---------------------------------------------------------------------------
BCK.Tabelle = {
    { nome = 'personaggi', ordine = 'ultimo_uso DESC',  righeMassime = 5000 },
    { nome = 'conti',      ordine = 'id DESC',          righeMassime = 5000 },
    { nome = 'inventari',  ordine = 'id DESC',          righeMassime = 8000 },
    { nome = 'veicoli',    ordine = 'id DESC',          righeMassime = 8000 },
    { nome = 'immobili',   ordine = 'id DESC',          righeMassime = 2000 },
    { nome = 'imprese',    ordine = 'id DESC',          righeMassime = 2000 },
    { nome = 'armi',       ordine = 'id DESC',          righeMassime = 4000 },
    { nome = 'patenti',    ordine = 'citizenid ASC',    righeMassime = 5000 },
    { nome = 'casellario', ordine = 'id DESC',          righeMassime = 5000 },
    { nome = 'mutui',      ordine = 'id DESC',          righeMassime = 2000 },
    { nome = 'organizzazioni', ordine = 'id DESC',      righeMassime = 500 },
}

-- ---------------------------------------------------------------------------
--  Dove
-- ---------------------------------------------------------------------------
BCK.Cartella = 'copie'

-- ---------------------------------------------------------------------------
--  Chi
-- ---------------------------------------------------------------------------
BCK.Permessi = {
    -- Gruppo minimo per lanciare una copia a mano e per consultare
    gruppo = 'admin',
    -- Gruppo minimo per leggere il contenuto di una copia (dati personali
    -- di tutti: non è roba da moderatore)
    gruppoLettura = 'gestore',
}

-- ---------------------------------------------------------------------------
--  Avvisi
-- ---------------------------------------------------------------------------
BCK.Avvisi = {
    -- Avvisa lo staff in gioco a ogni copia riuscita
    aOgniCopia = false,
    -- Avvisa sempre se una copia fallisce
    suErrore = true,
}
