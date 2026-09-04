--[[
    AUREA · Applicazione dell'aspetto (client)

    Un solo posto che sa tradurre la struttura salvata sul database in
    chiamate native, e viceversa. Tutto il resto passa da qui.
]]

Aspetto = {}

--- Struttura di partenza per un personaggio nuovo.
function Aspetto.Predefinito(sesso)
    local tratti = {}
    for i = 0, 19 do tratti[tostring(i)] = 0.0 end

    local sovrapposizioni = {}
    for _, s in ipairs(ASP.Sovrapposizioni) do
        sovrapposizioni[tostring(s.id)] = { indice = 255, opacita = 1.0, colore = 0, coloreSecondario = 0 }
    end

    return {
        modello = sesso == 'F' and 'mp_f_freemode_01' or 'mp_m_freemode_01',
        eredita = { padre = 0, madre = 21, mix = 0.5, mixPelle = 0.5 },
        tratti = tratti,
        sovrapposizioni = sovrapposizioni,
        capelli = { drawable = 0, texture = 0, colore = 0, coloreSecondario = 0 },
        componenti = {
            ['1'] = { drawable = 0, texture = 0 },
            ['3'] = { drawable = 15, texture = 0 },
            ['4'] = { drawable = sesso == 'F' and 3 or 1, texture = 0 },
            ['5'] = { drawable = 0, texture = 0 },
            ['6'] = { drawable = 1, texture = 0 },
            ['7'] = { drawable = 0, texture = 0 },
            ['8'] = { drawable = sesso == 'F' and 14 or 15, texture = 0 },
            ['9'] = { drawable = 0, texture = 0 },
            ['10'] = { drawable = 0, texture = 0 },
            ['11'] = { drawable = sesso == 'F' and 34 or 17, texture = 0 },
        },
        accessori = {
            ['0'] = { drawable = -1, texture = 0 },
            ['1'] = { drawable = -1, texture = 0 },
            ['2'] = { drawable = -1, texture = 0 },
            ['6'] = { drawable = -1, texture = 0 },
            ['7'] = { drawable = -1, texture = 0 },
        },
        tatuaggi = {},
    }
end

--- Carica il modello e lo applica al giocatore.
function Aspetto.CaricaModello(modello)
    local hash = GetHashKey(modello)
    if not IsModelInCdimage(hash) then return false end

    RequestModel(hash)
    local scadenza = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < scadenza do Wait(10) end
    if not HasModelLoaded(hash) then return false end

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    SetPedDefaultComponentVariation(PlayerPedId())
    return true
end

--- Applica una struttura completa al ped del giocatore.
function Aspetto.Applica(dati, cambiaModello)
    if not dati then return end

    if cambiaModello ~= false and dati.modello then
        local attuale = GetEntityModel(PlayerPedId())
        if attuale ~= GetHashKey(dati.modello) then
            if not Aspetto.CaricaModello(dati.modello) then return end
        end
    end

    local ped = PlayerPedId()

    -- Eredità genetica
    if dati.eredita then
        SetPedHeadBlendData(ped,
            math.floor(dati.eredita.padre or 0), math.floor(dati.eredita.madre or 21), 0,
            math.floor(dati.eredita.padre or 0), math.floor(dati.eredita.madre or 21), 0,
            dati.eredita.mix + 0.0, dati.eredita.mixPelle + 0.0, 0.0, false)
    end

    -- Tratti somatici
    for indice, valore in pairs(dati.tratti or {}) do
        SetPedFaceFeature(ped, tonumber(indice), (tonumber(valore) or 0.0) + 0.0)
    end

    -- Sovrapposizioni
    for id, s in pairs(dati.sovrapposizioni or {}) do
        local n = tonumber(id)
        SetPedHeadOverlay(ped, n, math.floor(s.indice or 255), (s.opacita or 1.0) + 0.0)

        local tipoColore = 0
        for _, def in ipairs(ASP.Sovrapposizioni) do
            if def.id == n then tipoColore = def.colore break end
        end
        if tipoColore > 0 then
            SetPedHeadOverlayColor(ped, n, tipoColore,
                math.floor(s.colore or 0), math.floor(s.coloreSecondario or 0))
        end
    end

    -- Capelli
    if dati.capelli then
        SetPedComponentVariation(ped, 2,
            math.floor(dati.capelli.drawable or 0), math.floor(dati.capelli.texture or 0), 0)
        SetPedHairColor(ped, math.floor(dati.capelli.colore or 0), math.floor(dati.capelli.coloreSecondario or 0))
    end

    -- Abbigliamento
    for id, c in pairs(dati.componenti or {}) do
        SetPedComponentVariation(ped, tonumber(id),
            math.floor(c.drawable or 0), math.floor(c.texture or 0), 0)
    end

    -- Accessori
    for id, a in pairs(dati.accessori or {}) do
        local drawable = math.floor(a.drawable or -1)
        if drawable < 0 then
            ClearPedProp(ped, tonumber(id))
        else
            SetPedPropIndex(ped, tonumber(id), drawable, math.floor(a.texture or 0), true)
        end
    end

    -- Tatuaggi
    ClearPedDecorations(ped)
    for _, t in ipairs(dati.tatuaggi or {}) do
        AddPedDecorationFromHashes(ped, GetHashKey(t.collezione), GetHashKey(t.nome))
    end
end

exports('Applica', Aspetto.Applica)

--- Legge dal ped corrente la struttura da salvare.
function Aspetto.Leggi(esistente)
    local ped = PlayerPedId()
    local dati = esistente or {}

    dati.modello = GetEntityModel(ped) == GetHashKey('mp_f_freemode_01')
        and 'mp_f_freemode_01' or 'mp_m_freemode_01'

    dati.componenti = dati.componenti or {}
    for _, c in ipairs(ASP.Componenti) do
        dati.componenti[tostring(c.id)] = {
            drawable = GetPedDrawableVariation(ped, c.id),
            texture = GetPedTextureVariation(ped, c.id),
        }
    end

    dati.accessori = dati.accessori or {}
    for _, a in ipairs(ASP.Accessori) do
        dati.accessori[tostring(a.id)] = {
            drawable = GetPedPropIndex(ped, a.id),
            texture = GetPedPropTextureIndex(ped, a.id),
        }
    end

    dati.capelli = dati.capelli or {}
    dati.capelli.drawable = GetPedDrawableVariation(ped, 2)
    dati.capelli.texture = GetPedTextureVariation(ped, 2)

    return dati
end

exports('Leggi', Aspetto.Leggi)

--- Indossa una divisa di servizio senza perdere il resto dell'aspetto.
function Aspetto.IndossaDivisa(lavoro, sesso)
    local divisa = ASP.Divise[lavoro]
    if not divisa then return false end

    local set = divisa[sesso == 'F' and 'F' or 'M']
    if not set then return false end

    local ped = PlayerPedId()
    for componente, valori in pairs(set) do
        SetPedComponentVariation(ped, componente, valori[1], valori[2], 0)
    end

    return true, divisa.nome
end

exports('IndossaDivisa', Aspetto.IndossaDivisa)
