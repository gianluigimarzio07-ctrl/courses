--[[
    AUREA · Serrature — configurazione

    Senza questo un server non esiste: chiunque entra nell'armeria del
    commissariato, nel caveau della banca, nella cella. Qui ogni porta ha
    una regola su chi può aprirla, e la regola la verifica il server.

    Il fatto che una porta si veda chiusa sul tuo schermo non basta: se il
    client potesse decidere da solo, basterebbe un trainer. Ogni apertura
    passa dal server, che controlla lavoro, grado, chiavi e prossimità.
]]

POR = {}

POR.Regole = {
    distanzaMassima = 2.5,
    -- Quanto ci mette una porta a richiudersi da sola, se configurata
    secondiAutochiusura = 20,
    -- Scassinare una porta: chi ci prova, con cosa, e quanto rumore fa
    grimaldello = 'grimaldello',
    durataScasso = 20000,
    probabilitaRiuscita = 35,
    probabilitaRotturaAttrezzo = 40,
    probabilitaAllarme = 60,
}

--- Ogni voce è una porta o un gruppo di porte che si aprono insieme.
---
---   modello   · hash del prop della porta
---   coord     · dove sta
---   doppia    · un secondo battente che si muove con il primo
---   lavori    · chi la può aprire dal lato del servizio
---   grado     · grado minimo, se serve
---   oggetto   · una chiave nell'inventario apre comunque
---   bloccata  · stato iniziale
---   scassinabile · se un grimaldello ci può provare
POR.Porte = {
    -- Commissariato
    {
        id = 'commissariato_ingresso', nome = 'Ingresso commissariato',
        modello = 'v_ilev_ph_gendoor004', coord = vector3(434.7, -983.2, 30.8),
        lavori = { 'polizia', 'carabinieri', 'guardia_finanza' },
        bloccata = false, autochiusura = true,
    },
    {
        id = 'commissariato_celle', nome = 'Blocco celle',
        modello = 'v_ilev_ph_cellgate', coord = vector3(478.0, -1013.0, 26.3),
        lavori = { 'polizia', 'carabinieri', 'penitenziaria' },
        bloccata = true,
    },
    {
        id = 'commissariato_armeria', nome = 'Armeria',
        modello = 'v_ilev_ph_gendoor004', coord = vector3(453.2, -980.0, 30.7),
        lavori = { 'polizia', 'carabinieri', 'guardia_finanza' },
        grado = 3, bloccata = true,
        -- L'armeria non si scassina: è blindata
        scassinabile = false,
    },
    {
        id = 'commissariato_reperti', nome = 'Sala reperti',
        modello = 'v_ilev_ph_gendoor004', coord = vector3(474.5, -991.5, 30.7),
        lavori = { 'polizia', 'carabinieri', 'guardia_finanza' },
        grado = 2, bloccata = true, scassinabile = false,
    },

    -- Banca
    {
        id = 'banca_caveau', nome = 'Caveau',
        modello = 'v_ilev_bk_vaultdoor', coord = vector3(261.9, 220.0, 106.5),
        lavori = { 'agenzia_entrate' }, grado = 2,
        bloccata = true, scassinabile = false,
    },
    {
        id = 'banca_retro', nome = 'Retro della banca',
        modello = 'v_ilev_bk_gate2', coord = vector3(253.0, 224.0, 101.9),
        lavori = { 'agenzia_entrate' },
        bloccata = true,
    },

    -- Ospedale
    {
        id = 'ospedale_farmacia', nome = 'Armadio farmaceutico',
        modello = 'v_ilev_ph_gendoor004', coord = vector3(308.0, -595.0, 43.3),
        lavori = { '118', 'medico' },
        bloccata = true,
    },
    {
        id = 'ospedale_obitorio', nome = 'Obitorio',
        modello = 'v_ilev_ph_gendoor004', coord = vector3(273.0, -1360.0, 24.5),
        lavori = { '118', 'medico', 'carabinieri', 'polizia' },
        bloccata = true,
    },

    -- Tribunale e carcere
    {
        id = 'tribunale_aula', nome = 'Aula di udienza',
        modello = 'v_ilev_ph_gendoor004', coord = vector3(-551.0, -200.0, 38.2),
        lavori = { 'giudice', 'avvocato', 'carabinieri', 'polizia', 'penitenziaria' },
        bloccata = false, autochiusura = true,
    },
    {
        id = 'carcere_ingresso', nome = 'Ingresso penitenziario',
        modello = 'prop_gate_prison_01', coord = vector3(1845.0, 2604.0, 44.6),
        lavori = { 'penitenziaria', 'carabinieri', 'polizia' },
        bloccata = true, scassinabile = false,
    },
    {
        id = 'carcere_bracci', nome = 'Bracci detentivi',
        modello = 'prop_gate_prison_01', coord = vector3(1770.0, 2564.0, 45.6),
        lavori = { 'penitenziaria' },
        bloccata = true, scassinabile = false,
    },

    -- Attività private: le apre chi ci lavora
    {
        id = 'officina', nome = 'Officina',
        modello = 'prop_gate_airport_01', coord = vector3(-337.0, -136.0, 39.0),
        lavori = { 'meccanico' }, bloccata = true,
    },
    {
        id = 'redazione', nome = 'Redazione',
        modello = 'v_ilev_ph_gendoor004', coord = vector3(-598.4, -929.4, 23.9),
        lavori = { 'giornalista' }, bloccata = true,
    },
}

function POR.GetPorta(id)
    for _, p in ipairs(POR.Porte) do
        if p.id == id then return p end
    end
    return nil
end

function POR.PortaVicina(coord)
    local migliore, distanza = nil, POR.Regole.distanzaMassima
    for _, p in ipairs(POR.Porte) do
        local d = #(coord - p.coord)
        if d < distanza then migliore, distanza = p, d end
    end
    return migliore
end
