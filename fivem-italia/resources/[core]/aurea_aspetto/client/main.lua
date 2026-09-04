--[[
    AUREA · Aspetto (client)
    Editor, negozi, barbiere, tatuatore, armadio.
]]

local U = AUREA.Util
local aperto = false
local camera = nil
local datiOriginali = nil
local esitoEditor = nil
local mioAspetto = nil

-- ---------------------------------------------------------------------------
--  Catalogo dei tatuaggi
-- ---------------------------------------------------------------------------
local TATUAGGI = {
    { collezione = 'mpbeach_overlays', nome = 'MP_Beach_Tat_000_M', etichetta = 'Onda sul petto',     zona = 'ZONE_TORSO' },
    { collezione = 'mpbeach_overlays', nome = 'MP_Beach_Tat_002_M', etichetta = 'Rosa dei venti',     zona = 'ZONE_TORSO' },
    { collezione = 'mpbeach_overlays', nome = 'MP_Beach_Tat_005_M', etichetta = 'Ancora',             zona = 'ZONE_LEFT_ARM' },
    { collezione = 'mpbeach_overlays', nome = 'MP_Beach_Tat_009_M', etichetta = 'Rondine',            zona = 'ZONE_RIGHT_ARM' },
    { collezione = 'mpbeach_overlays', nome = 'MP_Beach_Tat_013_M', etichetta = 'Tribale sul braccio',zona = 'ZONE_LEFT_ARM' },
    { collezione = 'mpbusiness_overlays', nome = 'MP_Buis_M_Tat_000', etichetta = 'Scritta sul collo', zona = 'ZONE_HEAD' },
    { collezione = 'mpbusiness_overlays', nome = 'MP_Buis_M_Tat_003', etichetta = 'Croce sulla schiena', zona = 'ZONE_TORSO_BACK' },
    { collezione = 'mpbusiness_overlays', nome = 'MP_Buis_M_Tat_007', etichetta = 'Manica intera',    zona = 'ZONE_RIGHT_ARM' },
    { collezione = 'mphipster_overlays', nome = 'MP_Hip_M_Tat_000',  etichetta = 'Geometrico',        zona = 'ZONE_TORSO' },
    { collezione = 'mphipster_overlays', nome = 'MP_Hip_M_Tat_010',  etichetta = 'Bussola',           zona = 'ZONE_LEFT_LEG' },
    { collezione = 'mphipster_overlays', nome = 'MP_Hip_M_Tat_017',  etichetta = 'Serpente',          zona = 'ZONE_RIGHT_LEG' },
    { collezione = 'mpluxe_overlays',    nome = 'MP_LUXE_TAT_004_M', etichetta = 'Leone',             zona = 'ZONE_TORSO_BACK' },
    { collezione = 'mpluxe_overlays',    nome = 'MP_LUXE_TAT_015_M', etichetta = 'Aquila',            zona = 'ZONE_TORSO' },
    { collezione = 'mpchristmas2_overlays', nome = 'MP_Xmas2_M_Tat_002', etichetta = 'Teschio',       zona = 'ZONE_RIGHT_ARM' },
    { collezione = 'mpchristmas2_overlays', nome = 'MP_Xmas2_M_Tat_016', etichetta = 'Fiori',         zona = 'ZONE_LEFT_ARM' },
}

-- ---------------------------------------------------------------------------
--  Camera dell'editor
-- ---------------------------------------------------------------------------
local altezzaCamera = 0.65
local distanzaCamera = 1.5
local angoloCamera = 0.0

local function creaCamera()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)

    camera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        coord.x, coord.y, coord.z, 0.0, 0.0, 0.0, 40.0, false, 0)
    SetCamActive(camera, true)
    RenderScriptCams(true, false, 600, true, true)
end

local function aggiornaCamera()
    if not camera then return end
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading + angoloCamera)

    SetCamCoord(camera,
        coord.x + math.sin(-rad) * distanzaCamera,
        coord.y + math.cos(-rad) * distanzaCamera,
        coord.z + altezzaCamera)
    PointCamAtCoord(camera, coord.x, coord.y, coord.z + altezzaCamera)
end

local function distruggiCamera()
    if camera then
        RenderScriptCams(false, true, 600, true, true)
        DestroyCam(camera, false)
        camera = nil
    end
    angoloCamera, distanzaCamera, altezzaCamera = 0.0, 1.5, 0.65
end

CreateThread(function()
    while true do
        local attesa = 300
        if aperto and camera then
            attesa = 0
            aggiornaCamera()

            if IsControlPressed(0, 34) then angoloCamera = angoloCamera - 1.6 end   -- A
            if IsControlPressed(0, 35) then angoloCamera = angoloCamera + 1.6 end   -- D
            if IsControlPressed(0, 32) then altezzaCamera = math.min(1.3, altezzaCamera + 0.01) end
            if IsControlPressed(0, 33) then altezzaCamera = math.max(-0.2, altezzaCamera - 0.01) end
            if IsControlJustPressed(0, 241) then distanzaCamera = math.max(0.6, distanzaCamera - 0.12) end
            if IsControlJustPressed(0, 242) then distanzaCamera = math.min(3.2, distanzaCamera + 0.12) end

            DisableAllControlActions(0)
            EnableControlAction(0, 34, true) EnableControlAction(0, 35, true)
            EnableControlAction(0, 32, true) EnableControlAction(0, 33, true)
            EnableControlAction(0, 241, true) EnableControlAction(0, 242, true)
        end
        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Massimi disponibili per il modello corrente
-- ---------------------------------------------------------------------------
local function calcolaMassimi(dati)
    local ped = PlayerPedId()
    local massimi = { capelli = math.max(0, GetNumberOfPedDrawableVariations(ped, 2) - 1) }

    for _, c in ipairs(ASP.Componenti) do
        massimi['componenti_' .. c.id] = math.max(0, GetNumberOfPedDrawableVariations(ped, c.id) - 1)
        local corrente = dati.componenti[tostring(c.id)]
        if corrente then
            massimi[('tex_componenti_%d_%d'):format(c.id, corrente.drawable)] =
                math.max(0, GetNumberOfPedTextureVariations(ped, c.id, corrente.drawable) - 1)
        end
    end

    for _, a in ipairs(ASP.Accessori) do
        massimi['accessori_' .. a.id] = math.max(0, GetNumberOfPedPropDrawableVariations(ped, a.id) - 1)
        local corrente = dati.accessori[tostring(a.id)]
        if corrente and corrente.drawable >= 0 then
            massimi[('tex_accessori_%d_%d'):format(a.id, corrente.drawable)] =
                math.max(0, GetNumberOfPedPropTextureVariations(ped, a.id, corrente.drawable) - 1)
        end
    end

    return massimi
end

-- ---------------------------------------------------------------------------
--  Apertura dell'editor
-- ---------------------------------------------------------------------------

--- Apre l'editor. Restituisce (confermato, dati, costo) — bloccante.
---@param modalita 'creazione'|'abbigliamento'|'barbiere'|'tatuatore'|'chirurgia'
function ApriEditor(modalita, dati, opzioni)
    if aperto then return false end
    opzioni = opzioni or {}

    aperto = true
    esitoEditor = nil
    datiOriginali = U.CopiaProfonda(dati)

    Aspetto.Applica(dati)
    Wait(150)
    creaCamera()

    -- Schede visibili secondo la modalità
    local schede = {}
    local function aggiungi(id, nome) schede[#schede + 1] = { id = id, nome = nome } end

    if modalita == 'creazione' or modalita == 'chirurgia' then
        aggiungi('eredita', 'Eredità')
        aggiungi('tratti', 'Volto')
        aggiungi('volto', 'Dettagli')
        aggiungi('capelli', 'Capelli')
    end
    if modalita == 'creazione' or modalita == 'abbigliamento' then
        aggiungi('componenti', 'Abbigliamento')
        aggiungi('accessori', 'Accessori')
    end
    if modalita == 'barbiere' then
        aggiungi('capelli', 'Capelli')
        aggiungi('volto', 'Barba e trucco')
    end
    if modalita == 'tatuatore' then
        aggiungi('tatuaggi', 'Tatuaggi')
    end

    -- Sovrapposizioni pertinenti alla sede
    local sovrapposizioni = {}
    for _, s in ipairs(ASP.Sovrapposizioni) do
        local pertinente = (modalita == 'creazione' or modalita == 'chirurgia')
            or (modalita == 'barbiere' and s.sede == 'barbiere')
        if pertinente then
            sovrapposizioni[#sovrapposizioni + 1] = {
                id = s.id, nome = s.nome, colore = s.colore,
                massimo = math.max(0, GetPedHeadOverlayNum(s.id) - 1),
            }
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        azione = 'apri',
        modalita = modalita,
        titolo = opzioni.titolo or 'Aspetto',
        sottotitolo = opzioni.sottotitolo or '',
        dati = dati,
        schede = schede,
        componenti = ASP.Componenti,
        accessori = ASP.Accessori,
        sovrapposizioni = sovrapposizioni,
        tratti = ASP.Tratti,
        zoneTatuaggi = ASP.ZoneTatuaggi,
        tatuaggiDisponibili = TATUAGGI,
        massimi = calcolaMassimi(dati),
        prezzi = ASP.Prezzi,
    })

    while esitoEditor == nil do Wait(50) end

    SetNuiFocus(false, false)
    distruggiCamera()
    aperto = false

    local esito = esitoEditor
    esitoEditor = nil

    if not esito.confermato then
        Aspetto.Applica(datiOriginali)
    end

    return esito.confermato, esito.dati, esito.costo or 0
end

-- ---------------------------------------------------------------------------
--  Callback NUI
-- ---------------------------------------------------------------------------
RegisterNUICallback('anteprima', function(payload, cb)
    if payload.dati then
        Aspetto.Applica(payload.dati, false)
        SendNUIMessage({ azione = 'massimi', massimi = calcolaMassimi(payload.dati) })
    end
    cb({ ok = true })
end)

RegisterNUICallback('conferma', function(payload, cb)
    esitoEditor = { confermato = true, dati = payload.dati, costo = payload.costo or 0 }
    cb({ ok = true })
end)

RegisterNUICallback('annulla', function(_, cb)
    esitoEditor = { confermato = false }
    cb({ ok = true })
end)

-- ---------------------------------------------------------------------------
--  Creazione del personaggio: invocata da aurea_spawn
-- ---------------------------------------------------------------------------
exports('CreaAspetto', function(sesso)
    local dati = Aspetto.Predefinito(sesso)
    Aspetto.CaricaModello(dati.modello)
    Wait(200)

    local confermato, risultato = ApriEditor('creazione', dati, {
        titolo = 'Il tuo personaggio',
        sottotitolo = 'Queste scelte non si cambiano facilmente: prenditi il tempo che serve.',
    })

    return confermato and risultato or dati
end)

exports('ApriEditor', ApriEditor)

-- ---------------------------------------------------------------------------
--  Caricamento dell'aspetto all'ingresso in gioco
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(1200)
        local salvato = AUREA.Callback.Attendi('asp:mio')
        if salvato then
            mioAspetto = salvato
            Aspetto.Applica(salvato)
        end
    end)
end)

RegisterNetEvent('asp:applica', function(dati)
    mioAspetto = dati
    Aspetto.Applica(dati)
end)

--- Editor completo concesso dallo staff, senza addebito.
RegisterNetEvent('asp:editorGratuito', function()
    CreateThread(function()
        local dati = mioAspetto or Aspetto.Leggi(Aspetto.Predefinito(AUREA.PG and AUREA.PG.sesso or 'M'))

        local confermato, risultato = ApriEditor('creazione', U.CopiaProfonda(dati), {
            titolo = 'Modifica concessa dallo staff',
            sottotitolo = 'Nessun addebito per questa sessione',
        })
        if not confermato then return end

        TriggerServerEvent('asp:salvaCreazione', risultato)
        mioAspetto = risultato
        Aspetto.Applica(risultato)

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '✨', titolo = 'Aspetto aggiornato',
            testo = 'Le modifiche sono state salvate.',
        })
    end)
end)

-- ---------------------------------------------------------------------------
--  Blip e interazioni
-- ---------------------------------------------------------------------------
CreateThread(function()
    local function blip(coord, sprite, colore, nome)
        local b = AddBlipForCoord(coord.x, coord.y, coord.z)
        SetBlipSprite(b, sprite) SetBlipColour(b, colore)
        SetBlipScale(b, 0.65) SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(nome) EndTextCommandSetBlipName(b)
    end

    for _, n in ipairs(ASP.Negozi) do blip(n.coord, 73, 3, n.nome) end
    for _, b in ipairs(ASP.Barbieri) do blip(b.coord, 71, 4, b.nome) end
    for _, t in ipairs(ASP.Tatuatori) do blip(t.coord, 75, 1, t.nome) end
    blip(ASP.Chirurgia.coord, 61, 2, ASP.Chirurgia.nome)
end)

CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())
        local trovato = false

        for _, n in ipairs(ASP.Negozi) do
            if #(coord - n.coord) < 2.2 then
                trovato = true attesa = 0
                exports.aurea_ui:Prompt(true, n.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    menuNegozio(n)
                end
                break
            end
        end

        if not trovato then
            for _, b in ipairs(ASP.Barbieri) do
                if #(coord - b.coord) < 2.2 then
                    trovato = true attesa = 0
                    exports.aurea_ui:Prompt(true, b.nome, 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        apriSede('barbiere', b.nome, 'Taglio, barba e trucco')
                    end
                    break
                end
            end
        end

        if not trovato then
            for _, t in ipairs(ASP.Tatuatori) do
                if #(coord - t.coord) < 2.2 then
                    trovato = true attesa = 0
                    exports.aurea_ui:Prompt(true, t.nome, 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        apriSede('tatuatore', t.nome, 'I tatuaggi restano: pensaci bene')
                    end
                    break
                end
            end
        end

        if not trovato and #(coord - ASP.Chirurgia.coord) < 2.2 then
            trovato = true attesa = 0
            exports.aurea_ui:Prompt(true, ASP.Chirurgia.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuChirurgia()
            end
        end

        if not trovato then exports.aurea_ui:Prompt(false) end
        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Negozio di abbigliamento
-- ---------------------------------------------------------------------------
function menuNegozio(negozio)
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = negozio.nome,
            sottotitolo = negozio.lusso and 'Capi sartoriali, prezzi da sartoria' or 'Prezzi al pubblico',
            voci = {
                { id = 'compra', icona = '👔', titolo = 'Prova e acquista',
                  descrizione = ('%s a capo, %s ad accessorio'):format(
                      U.Euro(negozio.lusso and ASP.Prezzi.capoLusso or ASP.Prezzi.capo),
                      U.Euro(negozio.lusso and ASP.Prezzi.accessorioLusso or ASP.Prezzi.accessorio)) },
                { id = 'armadio', icona = '🚪', titolo = 'I tuoi completi',
                  descrizione = 'Cambia con un completo già salvato.' },
                { id = 'salva', icona = '💾', titolo = 'Salva il completo che indossi' },
            },
        })
        if not scelta then return end

        if scelta == 'compra' then
            apriSede('abbigliamento', negozio.nome, negozio.lusso and 'Sartoria' or 'Abbigliamento', negozio.lusso)
        elseif scelta == 'armadio' then
            menuArmadio()
        elseif scelta == 'salva' then
            salvaCompleto()
        end
    end)
end

--- Apre l'editor in una sede commerciale e gestisce il pagamento.
function apriSede(modalita, titolo, sottotitolo, lusso)
    CreateThread(function()
        local dati = mioAspetto or Aspetto.Leggi(Aspetto.Predefinito(AUREA.PG and AUREA.PG.sesso or 'M'))

        local confermato, risultato, costo = ApriEditor(modalita, U.CopiaProfonda(dati), {
            titolo = titolo, sottotitolo = sottotitolo,
        })
        if not confermato then return end

        -- Il prezzo lo ricalcola il server: qui è solo indicativo
        local ok, messaggio = AUREA.Callback.Attendi('asp:salva', risultato, modalita, lusso == true)

        if ok then
            mioAspetto = risultato
            Aspetto.Applica(risultato)
        else
            Aspetto.Applica(dati)
        end

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '👔', titolo = ok and 'Fatto' or 'Operazione rifiutata',
            testo = messaggio, durata = 9000,
        })
    end)
end

function menuChirurgia()
    CreateThread(function()
        local conferma = exports.aurea_ui:Menu({
            titolo = ASP.Chirurgia.nome,
            sottotitolo = 'Rifare il volto è un intervento serio',
            voci = {
                { id = 'si', icona = '🏥', titolo = 'Procedi con l\'intervento',
                  descrizione = 'Potrai rifare lineamenti, eredità e capelli.',
                  valore = U.Euro(ASP.Chirurgia.costo) },
                { id = 'no', icona = '↩', titolo = 'Ci ripenso' },
            },
        })
        if conferma ~= 'si' then return end

        apriSede('chirurgia', 'Chirurgia estetica', 'Il tuo volto, rifatto da capo')
    end)
end

-- ---------------------------------------------------------------------------
--  Armadio
-- ---------------------------------------------------------------------------
function menuArmadio()
    CreateThread(function()
        local completi = AUREA.Callback.Attendi('asp:completi') or {}

        if #completi == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🚪', titolo = 'Armadio vuoto',
                testo = 'Salva un completo per ritrovarlo qui.',
            })
        end

        local voci = {}
        for _, c in ipairs(completi) do
            voci[#voci + 1] = {
                id = c.id, icona = '👔', titolo = c.nome,
                descrizione = ('Salvato il %s'):format(c.quando),
            }
        end

        local id = exports.aurea_ui:Menu({
            titolo = 'I tuoi completi',
            sottotitolo = ('%d/%d slot occupati'):format(#completi, ASP.Armadio.completiMassimi),
            voci = voci,
        })
        if not id then return end

        local azione = exports.aurea_ui:Menu({
            titolo = 'Completo',
            voci = {
                { id = 'indossa', icona = '👔', titolo = 'Indossa' },
                { id = 'elimina', icona = '🗑', titolo = 'Elimina dall\'armadio' },
            },
        })
        if not azione then return end

        if azione == 'indossa' then
            local dati = AUREA.Callback.Attendi('asp:indossaCompleto', id)
            if dati then
                mioAspetto = dati
                Aspetto.Applica(dati)
                exports.aurea_ui:Notifica({ tipo = 'successo', icona = '👔', titolo = 'Completo indossato' })
            end
        else
            AUREA.Callback.Attendi('asp:eliminaCompleto', id)
            exports.aurea_ui:Notifica({ tipo = 'info', icona = '🗑', titolo = 'Completo eliminato' })
        end
    end)
end

function salvaCompleto()
    CreateThread(function()
        local valori = exports.aurea_ui:Dialogo('Salva il completo', {
            { etichetta = 'Nome del completo', tipo = 'text', segnaposto = 'Es. Abito da lavoro', obbligatorio = true },
        })
        if not valori then return end

        local dati = Aspetto.Leggi(U.CopiaProfonda(mioAspetto or {}))
        local ok, messaggio = AUREA.Callback.Attendi('asp:salvaCompleto', valori[1], dati)

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '💾', titolo = ok and 'Completo salvato' or 'Salvataggio rifiutato',
            testo = messaggio, durata = 8000,
        })
    end)
end

RegisterCommand('armadio', function() menuArmadio() end, false)

-- ---------------------------------------------------------------------------
--  Divise di servizio
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:servizio:cambiato', function() end)

RegisterNetEvent('asp:divisa', function(lavoro, inServizio)
    if inServizio then
        local ok, nome = Aspetto.IndossaDivisa(lavoro, AUREA.PG and AUREA.PG.sesso or 'M')
        if ok then
            exports.aurea_ui:Notifica({ tipo = 'successo', icona = '👮', titolo = nome, testo = 'Sei in divisa.' })
        end
    elseif mioAspetto then
        Aspetto.Applica(mioAspetto)
        exports.aurea_ui:Notifica({ tipo = 'info', icona = '👔', titolo = 'Abiti civili', testo = 'Hai smesso la divisa.' })
    end
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        distruggiCamera()
    end
end)
