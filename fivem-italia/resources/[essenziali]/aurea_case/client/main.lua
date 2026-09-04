--[[
    AUREA · Immobili (client)
]]

local U = AUREA.Util
local immobili = {}
local dentro = nil       -- dati dell'immobile in cui ci si trova

-- ---------------------------------------------------------------------------
--  Caricamento degli ingressi
-- ---------------------------------------------------------------------------
local function caricaImmobili()
    CreateThread(function()
        immobili = AUREA.Callback.Attendi('casa:elenco', false) or {}
        local miei = AUREA.Callback.Attendi('casa:elenco', true) or {}

        for _, m in ipairs(miei) do
            local presente = false
            for _, i in ipairs(immobili) do
                if i.id == m.id then presente = true break end
            end
            if not presente then immobili[#immobili + 1] = m end
        end

        for _, i in ipairs(immobili) do
            if i.ingresso and i.eProprietario then
                local blip = AddBlipForCoord(i.ingresso.x, i.ingresso.y, i.ingresso.z)
                SetBlipSprite(blip, 40)
                SetBlipColour(blip, 2)
                SetBlipScale(blip, 0.6)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(i.nome)
                EndTextCommandSetBlipName(blip)
            end
        end
    end)
end

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function() Wait(3500) caricaImmobili() end)
end)

CreateThread(function()
    local a = CASA.Agenzia
    local blip = AddBlipForCoord(a.coord.x, a.coord.y, a.coord.z)
    SetBlipSprite(blip, a.blip.sprite)
    SetBlipColour(blip, a.blip.colore)
    SetBlipScale(blip, a.blip.scala)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(a.nome)
    EndTextCommandSetBlipName(blip)
end)

-- ---------------------------------------------------------------------------
--  Interazione
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())

        if dentro then
            attesa = 0
            local interno = CASA.GetInterno(dentro.interno)
            local i = interno.ingresso

            if #(coord - vector3(i.x, i.y, i.z)) < 1.6 then
                exports.aurea_ui:Prompt(true, 'Esci', 'E')
                if IsControlJustReleased(0, 38) then esci() end
            elseif dentro.deposito and #(coord - vector3(dentro.deposito.x, dentro.deposito.y, dentro.deposito.z)) < 1.6 then
                exports.aurea_ui:Prompt(true, 'Deposito di casa', 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    TriggerEvent('inv:apriEsterno', ('casa:%d'):format(dentro.idImmobile), {
                        tipo = 'immobile',
                        capienza = dentro.capienzaDeposito,
                        pesoMax = dentro.pesoDeposito,
                        etichetta = ('Deposito · %s'):format(dentro.nome),
                    })
                end
            elseif dentro.guardaroba and #(coord - vector3(dentro.guardaroba.x, dentro.guardaroba.y, dentro.guardaroba.z)) < 1.6 then
                exports.aurea_ui:Prompt(true, 'Guardaroba', 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    exports.aurea_ui:Notifica({ tipo = 'info', icona = '👔', titolo = 'Guardaroba', testo = 'Cambia il tuo abbigliamento salvato.' })
                end
            else
                exports.aurea_ui:Prompt(false)
                attesa = 400
            end

        else
            local vicino = nil
            for _, i in ipairs(immobili) do
                if i.ingresso and #(coord - vector3(i.ingresso.x, i.ingresso.y, i.ingresso.z)) < 1.8 then
                    vicino = i break
                end
            end

            if vicino then
                attesa = 0
                exports.aurea_ui:Prompt(true, vicino.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    menuIngresso(vicino)
                end
            elseif #(coord - CASA.Agenzia.coord) < 2.2 then
                attesa = 0
                exports.aurea_ui:Prompt(true, CASA.Agenzia.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    menuAgenzia()
                end
            else
                exports.aurea_ui:Prompt(false)
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Ingresso
-- ---------------------------------------------------------------------------
function menuIngresso(immobile)
    CreateThread(function()
        local voci = { { id = 'entra', icona = '🚪', titolo = 'Entra', descrizione = immobile.indirizzo } }

        if immobile.eProprietario then
            voci[#voci + 1] = { id = 'serratura', icona = '🔒', titolo = 'Apri o chiudi la serratura' }
            voci[#voci + 1] = { id = 'chiavi', icona = '🔑', titolo = 'Cedi le chiavi alla persona vicina' }
            voci[#voci + 1] = { id = 'affitta', icona = '📄', titolo = 'Loca l\'immobile alla persona vicina' }
            voci[#voci + 1] = { id = 'vendi', icona = '💰', titolo = 'Vendi all\'agenzia',
                valore = U.Euro(math.floor(immobile.prezzo * CASA.Regole.scontoRivendita)) }
        elseif not immobile.proprietario then
            voci[#voci + 1] = { id = 'acquista', icona = '💶', titolo = 'Acquista questo immobile',
                descrizione = ('Prezzo %s + imposta di registro %s + provvigione %s'):format(
                    U.Euro(immobile.prezzo), U.Euro(immobile.imposte), U.Euro(immobile.provvigione)),
                valore = U.Euro(immobile.prezzo + immobile.imposte + immobile.provvigione) }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = immobile.nome,
            sottotitolo = ('%s · %s'):format(immobile.internoEtichetta, immobile.indirizzo),
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'entra' then
            entra(immobile.id)

        elseif scelta == 'acquista' then
            local ok, messaggio = AUREA.Callback.Attendi('casa:acquista', immobile.id)
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '🏠', titolo = ok and 'Rogito registrato' or 'Acquisto rifiutato',
                testo = messaggio, durata = 11000,
            })
            if ok then caricaImmobili() end

        elseif scelta == 'vendi' then
            local ok, messaggio = AUREA.Callback.Attendi('casa:vendi', immobile.id)
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '🏠', titolo = ok and 'Immobile venduto' or 'Vendita rifiutata',
                testo = messaggio, durata = 10000,
            })
            if ok then caricaImmobili() end

        elseif scelta == 'serratura' then
            local ok, messaggio = AUREA.Callback.Attendi('casa:serratura', immobile.id)
            exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore', icona = '🔒', titolo = 'Serratura', testo = messaggio })

        elseif scelta == 'chiavi' or scelta == 'affitta' then
            local bersaglio = giocatoreVicino()
            if not bersaglio then
                return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati alla persona.' })
            end

            if scelta == 'chiavi' then
                local ok, messaggio = AUREA.Callback.Attendi('casa:cediChiavi', immobile.id, bersaglio)
                exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore', icona = '🔑', titolo = 'Chiavi', testo = messaggio, durata = 8000 })
            else
                local valori = exports.aurea_ui:Dialogo('Contratto di locazione', {
                    { etichetta = 'Canone per periodo (euro)', tipo = 'text', segnaposto = '450.00', obbligatorio = true },
                })
                if not valori then return end
                local ok, messaggio = AUREA.Callback.Attendi('casa:affitta', immobile.id, bersaglio, valori[1])
                exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore', icona = '📄', titolo = 'Locazione', testo = messaggio, durata = 9000 })
            end
        end
    end)
end

function giocatoreVicino()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    for _, altro in ipairs(GetActivePlayers()) do
        local altroPed = GetPlayerPed(altro)
        if altroPed ~= ped and #(coord - GetEntityCoords(altroPed)) < 3.0 then
            return GetPlayerServerId(altro)
        end
    end
    return nil
end

function entra(idImmobile)
    local dati, errore = AUREA.Callback.Attendi('casa:entra', idImmobile)
    if not dati then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔒', titolo = 'Accesso negato', testo = errore or 'Riprova.' })
    end

    DoScreenFadeOut(400)
    Wait(450)

    local ped = PlayerPedId()
    SetEntityCoords(ped, dati.ingresso.x, dati.ingresso.y, dati.ingresso.z, false, false, false, false)
    SetEntityHeading(ped, dati.ingresso.h)
    dentro = dati

    Wait(400)
    DoScreenFadeIn(500)

    exports.aurea_ui:Notifica({ tipo = 'info', icona = '🏠', titolo = dati.nome, testo = 'Sei in casa.' })
end

function esci()
    CreateThread(function()
        exports.aurea_ui:Prompt(false)
        local uscita = AUREA.Callback.Attendi('casa:esci')
        DoScreenFadeOut(400)
        Wait(450)

        if uscita then
            local ped = PlayerPedId()
            SetEntityCoords(ped, uscita.x, uscita.y, uscita.z, false, false, false, false)
            SetEntityHeading(ped, uscita.h or 0.0)
        end

        dentro = nil
        Wait(400)
        DoScreenFadeIn(500)
    end)
end

-- ---------------------------------------------------------------------------
--  Agenzia immobiliare
-- ---------------------------------------------------------------------------
function menuAgenzia()
    CreateThread(function()
        local inVendita = AUREA.Callback.Attendi('casa:elenco', false) or {}
        local miei = AUREA.Callback.Attendi('casa:elenco', true) or {}

        local sezione = exports.aurea_ui:Menu({
            titolo = CASA.Agenzia.nome,
            sottotitolo = 'Compravendita e locazioni',
            voci = {
                { id = 'vendita', icona = '🏘', titolo = 'Immobili in vendita', descrizione = ('%d disponibili'):format(#inVendita) },
                { id = 'miei', icona = '🏠', titolo = 'Il tuo patrimonio', descrizione = ('%d immobili'):format(#miei), disattivata = #miei == 0 },
            },
        })
        if not sezione then return end

        local elenco = sezione == 'vendita' and inVendita or miei
        local voci = {}
        for _, i in ipairs(elenco) do
            voci[#voci + 1] = {
                id = i.id, icona = i.tipo == 'villa' and '🏛' or i.tipo == 'attico' and '🌆' or '🏠',
                titolo = i.nome,
                descrizione = ('%s · %s · rendita catastale %s'):format(i.internoEtichetta, i.indirizzo, U.Euro(i.rendita_catastale)),
                valore = U.Euro(i.prezzo),
            }
        end

        local id = exports.aurea_ui:Menu({
            titolo = sezione == 'vendita' and 'Immobili in vendita' or 'Il tuo patrimonio',
            sottotitolo = sezione == 'vendita' and 'Il prezzo esposto è al netto di imposte e provvigione' or 'IMU e TARI vengono liquidate periodicamente',
            voci = voci,
        })
        if not id then return end

        for _, i in ipairs(elenco) do
            if i.id == id then
                if i.ingresso then SetNewWaypoint(i.ingresso.x, i.ingresso.y) end
                exports.aurea_ui:Notifica({
                    tipo = 'info', icona = '📍', durata = 8000,
                    titolo = i.nome, testo = ('Navigatore impostato su %s.'):format(i.indirizzo),
                })
                break
            end
        end
    end)
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and dentro then
        TriggerServerEvent('casa:uscitaForzata')
    end
end)
