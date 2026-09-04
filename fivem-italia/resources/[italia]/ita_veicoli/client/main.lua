--[[
    AUREA · Veicoli (client)
    Concessionarie, sportello bollo/RCA, centri revisione, depositeria.
]]

local U = AUREA.Util
local veicoloAnteprima = nil

-- ---------------------------------------------------------------------------
--  Blip
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, c in ipairs(VEI.Concessionarie) do
        local blip = AddBlipForCoord(c.coord.x, c.coord.y, c.coord.z)
        SetBlipSprite(blip, c.blip.sprite)
        SetBlipColour(blip, c.blip.colore)
        SetBlipScale(blip, c.blip.scala)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(c.nome)
        EndTextCommandSetBlipName(blip)
    end

    for _, r in ipairs(VEI.CentriRevisione) do
        local blip = AddBlipForCoord(r.coord.x, r.coord.y, r.coord.z)
        SetBlipSprite(blip, 446) SetBlipColour(blip, 5) SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(r.nome) EndTextCommandSetBlipName(blip)
    end

    for _, a in ipairs(VEI.Assicurazioni) do
        local blip = AddBlipForCoord(a.coord.x, a.coord.y, a.coord.z)
        SetBlipSprite(blip, 431) SetBlipColour(blip, 3) SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(a.nome) EndTextCommandSetBlipName(blip)
    end

    local dep = AddBlipForCoord(VEI.Depositeria.coord.x, VEI.Depositeria.coord.y, VEI.Depositeria.coord.z)
    SetBlipSprite(dep, 67) SetBlipColour(dep, 1) SetBlipScale(dep, 0.75)
    SetBlipAsShortRange(dep, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentString(VEI.Depositeria.nome) EndTextCommandSetBlipName(dep)
end)

-- ---------------------------------------------------------------------------
--  Interazioni
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())
        local mostrato = false

        for _, c in ipairs(VEI.Concessionarie) do
            if #(coord - c.coord) < 2.5 then
                attesa = 0 mostrato = true
                exports.aurea_ui:Prompt(true, c.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    menuConcessionaria(c)
                end
                break
            end
        end

        if not mostrato then
            for _, r in ipairs(VEI.CentriRevisione) do
                if #(coord - r.coord) < 2.5 then
                    attesa = 0 mostrato = true
                    exports.aurea_ui:Prompt(true, 'Centro Revisioni', 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        menuRevisione()
                    end
                    break
                end
            end
        end

        if not mostrato then
            for _, a in ipairs(VEI.Assicurazioni) do
                if #(coord - a.coord) < 2.5 then
                    attesa = 0 mostrato = true
                    exports.aurea_ui:Prompt(true, 'Agenzia Assicurativa', 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        menuAssicurazione()
                    end
                    break
                end
            end
        end

        if not mostrato and #(coord - VEI.Depositeria.coord) < 3.0 then
            attesa = 0 mostrato = true
            exports.aurea_ui:Prompt(true, 'Depositeria Giudiziaria', 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuDepositeria()
            end
        end

        if not mostrato then exports.aurea_ui:Prompt(false) end
        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Concessionaria con anteprima del veicolo
-- ---------------------------------------------------------------------------
local function pulisciAnteprima()
    if veicoloAnteprima and DoesEntityExist(veicoloAnteprima) then
        DeleteEntity(veicoloAnteprima)
    end
    veicoloAnteprima = nil
end

local function mostraAnteprima(concessionaria, modello)
    pulisciAnteprima()
    local hash = GetHashKey(modello)
    RequestModel(hash)
    local scadenza = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < scadenza do Wait(10) end
    if not HasModelLoaded(hash) then return end

    local p = concessionaria.anteprima
    veicoloAnteprima = CreateVehicle(hash, p.x, p.y, p.z, p.w, false, false)
    SetEntityInvincible(veicoloAnteprima, true)
    SetVehicleDoorsLocked(veicoloAnteprima, 6)
    FreezeEntityPosition(veicoloAnteprima, true)
    SetModelAsNoLongerNeeded(hash)
end

function menuConcessionaria(concessionaria)
    local catalogo = AUREA.Callback.Attendi('vei:catalogo', concessionaria.id) or {}
    if #catalogo == 0 then return end

    -- raggruppa per categoria
    local perCategoria = {}
    for _, v in ipairs(catalogo) do
        perCategoria[v.categoria] = perCategoria[v.categoria] or {}
        table.insert(perCategoria[v.categoria], v)
    end

    local vociCategorie = {}
    for _, cat in ipairs(concessionaria.categorie) do
        if perCategoria[cat] then
            vociCategorie[#vociCategorie + 1] = {
                id = cat, icona = '🚗',
                titolo = cat:sub(1, 1):upper() .. cat:sub(2),
                descrizione = ('%d modelli disponibili'):format(#perCategoria[cat]),
            }
        end
    end

    local categoria = exports.aurea_ui:Menu({
        titolo = concessionaria.nome,
        sottotitolo = 'IPT del 3% e primo bollo inclusi nel preventivo',
        voci = vociCategorie,
    })
    if not categoria then return pulisciAnteprima() end

    local voci = {}
    for _, v in ipairs(perCategoria[categoria]) do
        voci[#voci + 1] = {
            id = v.modello, icona = '🔑',
            titolo = v.nome,
            descrizione = ('%d kW · %s · bollo annuo %s'):format(v.kw, v.classe, U.Euro(v.bolloPrimoAnno)),
            valore = U.Euro(v.prezzo + v.ipt),
        }
    end

    local modello = exports.aurea_ui:Menu({
        titolo = categoria:sub(1, 1):upper() .. categoria:sub(2),
        sottotitolo = 'Prezzo comprensivo di imposta provinciale di trascrizione',
        voci = voci,
    })
    if not modello then return pulisciAnteprima() end

    mostraAnteprima(concessionaria, modello)

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Conferma acquisto',
        sottotitolo = 'La RCA non è obbligatoria all\'acquisto, ma senza non puoi circolare',
        voci = {
            { id = 'con_rca', icona = '🛡', titolo = 'Acquista con polizza RCA', descrizione = 'Copertura immediata per 365 giorni.' },
            { id = 'senza',   icona = '🚗', titolo = 'Acquista senza polizza', descrizione = 'Dovrai assicurarlo prima di metterti in strada.' },
            { id = 'annulla', icona = '↩', titolo = 'Annulla' },
        },
    })

    pulisciAnteprima()
    if not scelta or scelta == 'annulla' then return end

    local ok, messaggio = AUREA.Callback.Attendi('vei:acquista', modello, scelta == 'con_rca')
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        titolo = ok and 'Veicolo immatricolato' or 'Acquisto non riuscito',
        testo = messaggio, durata = 10000,
    })
end

-- ---------------------------------------------------------------------------
--  Sportello unico veicoli (bollo / RCA / revisione)
-- ---------------------------------------------------------------------------
local function scegliVeicolo(titolo, sottotitolo, filtro)
    local veicoli = AUREA.Callback.Attendi('vei:mieiVeicoli') or {}
    local voci = {}

    for _, v in ipairs(veicoli) do
        if not filtro or filtro(v) then
            local problemi = {}
            if v.bolloScaduto then problemi[#problemi + 1] = 'bollo' end
            if v.revisioneScaduta then problemi[#problemi + 1] = 'revisione' end
            if not v.assicurato then problemi[#problemi + 1] = 'RCA' end

            voci[#voci + 1] = {
                id = v.targa,
                icona = #problemi > 0 and '⚠' or '✅',
                titolo = ('%s — %s'):format(v.targa, v.nome),
                descrizione = ('Bollo %s · Revisione %s · RCA %s'):format(v.bolloData, v.revisioneData, v.rcaData),
                valore = #problemi > 0 and ('scaduti: ' .. table.concat(problemi, ', ')) or 'regolare',
            }
        end
    end

    if #voci == 0 then
        exports.aurea_ui:Notifica({ tipo = 'info', titolo = 'Nessun veicolo', testo = 'Non hai veicoli che richiedono questa operazione.' })
        return nil
    end

    return exports.aurea_ui:Menu({ titolo = titolo, sottotitolo = sottotitolo, voci = voci })
end

function menuRevisione()
    local scelta = exports.aurea_ui:Menu({
        titolo = 'Centro Revisioni',
        sottotitolo = 'Collaudo periodico e pagamento del bollo',
        voci = {
            { id = 'revisione', icona = '🔧', titolo = 'Revisione periodica', descrizione = 'Il veicolo deve essere in buone condizioni.', valore = U.Euro(VEI.Revisione.costo) },
            { id = 'bollo',     icona = '🧾', titolo = 'Pagamento del bollo', descrizione = 'Tassa automobilistica annuale.' },
        },
    })
    if not scelta then return end

    if scelta == 'bollo' then
        local targa = scegliVeicolo('Pagamento bollo', 'Seleziona il veicolo', nil)
        if not targa then return end
        local ok, messaggio = AUREA.Callback.Attendi('vei:pagaBollo', targa)
        return exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore', titolo = ok and 'Bollo pagato' or 'Pagamento rifiutato', testo = messaggio, durata = 9000 })
    end

    local targa = scegliVeicolo('Revisione periodica', 'Seleziona il veicolo da collaudare', nil)
    if not targa then return end

    -- Il veicolo va portato al centro: si legge lo stato di quello guidato
    local ped = PlayerPedId()
    local veicolo = GetVehiclePedIsIn(ped, false)
    local motore, carrozzeria
    if veicolo ~= 0 and GetVehicleNumberPlateText(veicolo):gsub('%s+', '') == targa then
        motore = GetVehicleEngineHealth(veicolo)
        carrozzeria = GetVehicleBodyHealth(veicolo)
    else
        return exports.aurea_ui:Notifica({
            tipo = 'errore', titolo = 'Veicolo assente',
            testo = 'Devi presentarti al centro a bordo del veicolo da revisionare.',
        })
    end

    local completato = exports.aurea_ui:Progresso({
        etichetta = 'Collaudo in corso...',
        durata = VEI.Revisione.duratsCollaudo,
        annullabile = true, blocca = { movimento = true, veicolo = true },
    })
    if not completato then return end

    local ok, messaggio = AUREA.Callback.Attendi('vei:revisione', targa, motore, carrozzeria)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        titolo = ok and 'Revisione superata' or 'Revisione non superata',
        testo = messaggio, durata = 10000,
    })
end

function menuAssicurazione()
    local targa = scegliVeicolo('Agenzia Assicurativa', 'Seleziona il veicolo da assicurare', nil)
    if not targa then return end

    local voci = {}
    for id, t in pairs(VEI.Assicurazione.tipi) do
        voci[#voci + 1] = { id = id, icona = '🛡', titolo = t.etichetta, descrizione = t.descrizione }
    end
    table.sort(voci, function(a, b) return a.id < b.id end)

    local tipo = exports.aurea_ui:Menu({
        titolo = 'Scelta della polizza',
        sottotitolo = 'Il premio dipende dalla potenza e dalla tua classe di merito',
        voci = voci,
    })
    if not tipo then return end

    local ok, messaggio = AUREA.Callback.Attendi('vei:assicura', targa, tipo)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        titolo = ok and 'Polizza attivata' or 'Polizza non attivata',
        testo = messaggio, durata = 10000,
    })
end

function menuDepositeria()
    local sequestrati = AUREA.Callback.Attendi('vei:sequestrati') or {}
    if #sequestrati == 0 then
        return exports.aurea_ui:Notifica({ tipo = 'info', titolo = 'Nessun veicolo in custodia', testo = 'Non risultano tuoi veicoli in depositeria.' })
    end

    local voci = {}
    for _, v in ipairs(sequestrati) do
        voci[#voci + 1] = {
            id = v.targa, icona = '🚔',
            titolo = ('%s — %s'):format(v.targa, v.nome),
            descrizione = ('In custodia da %d giorni'):format(v.giorni or 0),
            valore = U.Euro(v.costo),
        }
    end

    local targa = exports.aurea_ui:Menu({
        titolo = VEI.Depositeria.nome,
        sottotitolo = 'Il dissequestro richiede la posizione regolare sui verbali',
        voci = voci,
    })
    if not targa then return end

    local ok, messaggio = AUREA.Callback.Attendi('vei:dissequestra', targa)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        titolo = ok and 'Veicolo dissequestrato' or 'Dissequestro rifiutato',
        testo = messaggio, durata = 10000,
    })
end

-- ---------------------------------------------------------------------------
--  Rilevamento sinistri: urto violento con veicolo di proprietà
-- ---------------------------------------------------------------------------
CreateThread(function()
    local ultimaCarrozzeria = nil
    local ultimoSinistro = 0

    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped then
            local carrozzeria = GetVehicleBodyHealth(veicolo)
            if ultimaCarrozzeria and (ultimaCarrozzeria - carrozzeria) > 180
               and (GetGameTimer() - ultimoSinistro) > 60000 then
                ultimoSinistro = GetGameTimer()
                local danno = math.floor((ultimaCarrozzeria - carrozzeria) * 120)  -- centesimi
                TriggerServerEvent('vei:sinistro', GetVehicleNumberPlateText(veicolo), danno)
            end
            ultimaCarrozzeria = carrozzeria
        else
            ultimaCarrozzeria = nil
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Comando informativo
-- ---------------------------------------------------------------------------
RegisterCommand('miei_veicoli', function()
    CreateThread(function()
        local veicoli = AUREA.Callback.Attendi('vei:mieiVeicoli') or {}
        if #veicoli == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', titolo = 'Nessun veicolo', testo = 'Non risulti intestatario di veicoli.' })
        end
        local voci = {}
        for _, v in ipairs(veicoli) do
            voci[#voci + 1] = {
                id = v.targa, icona = v.stato == 'sequestrato' and '🚔' or '🚗',
                titolo = ('%s — %s'):format(v.targa, v.nome),
                descrizione = ('%s · %s · %d km'):format(v.garage, v.stato, v.km or 0),
                valore = ('Bollo %s'):format(v.bolloData),
            }
        end
        exports.aurea_ui:Menu({ titolo = 'Il tuo parco veicoli', sottotitolo = 'Dati del Pubblico Registro Automobilistico', voci = voci })
    end)
end, false)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then pulisciAnteprima() end
end)
