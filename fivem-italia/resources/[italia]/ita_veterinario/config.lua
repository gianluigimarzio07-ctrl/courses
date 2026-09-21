--[[
    AUREA · Ambulatorio veterinario (configurazione)

    UN CANE CHE NON SI POTEVA CURARE

    aurea_animali fa già la parte difficile: l'adozione, il microchip,
    l'anagrafe canina, la fame, l'affetto, la fuga. Un animale nel server
    è una cosa viva con dei bisogni.

    Quello che non aveva era un medico. L'ambulatorio esisteva come
    coordinata e come prezzo del microchip, e basta: un cane non si
    poteva ammalare, curare o vaccinare, e soprattutto nessuno poteva
    fargli del male in un modo che avesse una conseguenza.

    TRE COSE, IN ORDINE DI IMPORTANZA

    1. LE VACCINAZIONI. Hanno una scadenza, e la scadenza conta: un
       animale non in regola non può entrare in certi posti e il suo
       proprietario è sanzionabile. È la parte noiosa e quella che
       tiene in piedi tutto il resto.

    2. LE CURE. Un animale trascurato — fame a zero, affetto a zero —
       si ammala. Si porta in ambulatorio, si paga, guarisce.

    3. IL MALTRATTAMENTO. Art. 544-ter c.p., che in Italia è un reato
       vero con pena detentiva, e non un illecito amministrativo. Chi
       tiene un animale alla fame lo commette, e un veterinario o una
       pattuglia possono accertarlo. L'animale si sequestra.

    La terza è l'unica ragione per cui questa risorsa vale la pena: un
    server dove gli animali sono oggetti è un server dove maltrattarli
    è gratis.
]]

VET = {}

VET.Lavoro = 'veterinario'

VET.Ambulatorio = {
    nome = 'Ambulatorio veterinario',
    -- Lo stesso punto che aurea_animali usa già per il microchip: è lo
    -- stesso ambulatorio, non un secondo.
    coord = vector3(1698.0, 3584.0, 35.6),
    raggio = 2.6,
    blip = { sprite = 442, colore = 2, scala = 0.65 },
}

-- ---------------------------------------------------------------------------
--  Vaccinazioni
-- ---------------------------------------------------------------------------
VET.Vaccini = {
    { id = 'antirabbica', nome = 'Antirabbica',
      costo = 18000, giorni = 120, obbligatorio = true,
      descrizione = 'Obbligatoria. Senza, l\'animale non è in regola.' },
    { id = 'trivalente', nome = 'Trivalente',
      costo = 12000, giorni = 90, obbligatorio = false,
      descrizione = 'Cimurro, epatite, parvovirosi.' },
    { id = 'leishmaniosi', nome = 'Leishmaniosi',
      costo = 26000, giorni = 150, obbligatorio = false,
      descrizione = 'Consigliata, e cara.' },
}

function VET.GetVaccino(id)
    for _, v in ipairs(VET.Vaccini) do
        if v.id == id then return v end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Visite e cure
-- ---------------------------------------------------------------------------
VET.Visita = {
    costo = 24000,
    durataSecondi = 25,
    compensoVeterinario = 0.40,

    -- Sotto queste soglie l'animale sta male
    fameCritica = 25,
    affettoCritico = 20,

    -- La cura riporta i bisogni a questi valori
    fameDopoCura = 85,
    affettoDopoCura = 55,
}

-- ---------------------------------------------------------------------------
--  Maltrattamento (art. 544-ter c.p.)
-- ---------------------------------------------------------------------------
VET.Maltrattamento = {
    -- Sotto queste soglie, e da abbastanza tempo, non è distrazione:
    -- è maltrattamento.
    fameSoglia = 12,
    affettoSoglia = 10,

    reato = '544t',

    -- Chi può accertarlo: il veterinario in servizio e le forze
    -- dell'ordine. Il veterinario ha l'obbligo di segnalare quello che
    -- vede, e qui funziona uguale.
    lavoriAbilitati = { 'veterinario', 'carabinieri', 'polizia' },

    -- L'animale si sequestra e si affida
    sequestro = true,
    sanzione = 120000,
}

--- L'animale sta male abbastanza da essere un caso di maltrattamento?
function VET.Maltrattato(fame, affetto)
    return (tonumber(fame) or 100) <= VET.Maltrattamento.fameSoglia
        or (tonumber(affetto) or 100) <= VET.Maltrattamento.affettoSoglia
end

--- L'animale sta male abbastanza da aver bisogno di un veterinario?
function VET.Malato(fame, affetto)
    return (tonumber(fame) or 100) <= VET.Visita.fameCritica
        or (tonumber(affetto) or 100) <= VET.Visita.affettoCritico
end
