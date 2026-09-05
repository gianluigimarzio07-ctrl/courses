--[[
    AUREA · Manutenzione rete elettrica — configurazione

    I guasti non li inventa un timer: nascono quando qualcuno fa saltare
    un quadro durante un colpo, quando c'è un temporale, o per usura. E
    finché non li ripara qualcuno, quella zona resta al buio — davvero:
    i lampioni si spengono per tutti quelli che sono lì.
]]

ELE = {}

ELE.Lavoro = 'elettricista'

ELE.Sede = {
    nome = 'Officina elettrica',
    coord = vector3(716.0, 130.0, 80.9),
    mezzi = { vector4(708.0, 126.0, 80.6, 240.0) },
    modello = 'utillitruck2',
    blip = { sprite = 354, colore = 5, scala = 0.7 },
}

--- Le cabine che alimentano le zone della città.
ELE.Cabine = {
    { id = 'centro',    nome = 'Cabina del centro',      coord = vector3(-538.0, -60.0, 42.0),  zona = 'Centro' },
    { id = 'porto',     nome = 'Cabina portuale',        coord = vector3(797.0, -2380.0, 30.0), zona = 'Zona portuale' },
    { id = 'vespucci',  nome = 'Cabina di Vespucci',     coord = vector3(-1230.0, -1300.0, 5.0),zona = 'Lungomare' },
    { id = 'industriale', nome = 'Cabina industriale',   coord = vector3(720.0, -960.0, 25.0),  zona = 'Zona industriale' },
    { id = 'nord',      nome = 'Cabina nord',            coord = vector3(1690.0, 4880.0, 42.0), zona = 'Paese nord' },
}

ELE.Guasti = {
    -- Quanto è probabile che nasca un guasto spontaneo, per controllo
    probabilitaSpontanea = 12,
    minutiControllo = 45,
    -- Il maltempo li rende più probabili
    moltiplicatoreMaltempo = 3,

    tipi = {
        { id = 'fusibile',   nome = 'Fusibile bruciato',       durata = 15000, paga = 32000,
          oggetto = 'componenti_elettronici', quantita = 1 },
        { id = 'cavo',       nome = 'Cavo tranciato',          durata = 26000, paga = 58000,
          oggetto = 'rame', quantita = 2 },
        { id = 'trasformatore', nome = 'Trasformatore guasto', durata = 40000, paga = 95000,
          oggetto = 'componenti_elettronici', quantita = 3 },
    },

    -- Quanti guasti aperti al massimo insieme
    massimoAperti = 3,
    -- Se nessuno interviene, dopo un po' interviene la ditta esterna
    minutiPrimaDellaDitta = 30,
}

ELE.Regole = {
    distanzaIntervento = 5.0,
    -- Lavorare sotto tensione senza staccare è pericoloso
    probabilitaScossa = 18,
    dannoScossa = 25,
}

function ELE.GetCabina(id)
    for _, c in ipairs(ELE.Cabine) do
        if c.id == id then return c end
    end
    return nil
end

function ELE.GetTipoGuasto(id)
    for _, t in ipairs(ELE.Guasti.tipi) do
        if t.id == id then return t end
    end
    return nil
end
