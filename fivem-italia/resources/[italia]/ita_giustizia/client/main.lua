--[[
    AUREA · Giustizia (client) — manette, MDT, denunce
]]

local U = AUREA.Util
local ammanettato = false
local trascinatoDa = nil

-- ---------------------------------------------------------------------------
--  Blip
-- ---------------------------------------------------------------------------
CreateThread(function()
    local t = GIU.Tribunale
    local blip = AddBlipForCoord(t.coord.x, t.coord.y, t.coord.z)
    SetBlipSprite(blip, t.blip.sprite) SetBlipColour(blip, t.blip.colore)
    SetBlipScale(blip, t.blip.scala) SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentString(t.nome) EndTextCommandSetBlipName(blip)

    local c = GIU.Carcere
    local bc = AddBlipForCoord(c.ingresso.x, c.ingresso.y, c.ingresso.z)
    SetBlipSprite(bc, c.blip.sprite) SetBlipColour(bc, c.blip.colore)
    SetBlipScale(bc, c.blip.scala) SetBlipAsShortRange(bc, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentString(c.nome) EndTextCommandSetBlipName(bc)
end)

-- ---------------------------------------------------------------------------
--  Manette
-- ---------------------------------------------------------------------------
RegisterNetEvent('giu:ammanetta', function(agente)
    ammanettato = not ammanettato
    TriggerServerEvent('giu:ammanettato', ammanettato)

    local ped = PlayerPedId()
    if ammanettato then
        AUREA.CaricaAnim('mp_arresting')
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        SetEnableHandcuffs(ped, true)
        DisablePlayerFiring(PlayerId(), true)
        SetPedCanPlayGestureAnims(ped, false)

        exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '⛓', durata = 9000,
            titolo = 'Sei stato ammanettato',
            testo = ('%s ti ha bloccato. Non puoi usare le mani.'):format(agente or 'Un agente'),
        })
    else
        ClearPedTasks(ped)
        SetEnableHandcuffs(ped, false)
        DisablePlayerFiring(PlayerId(), false)
        SetPedCanPlayGestureAnims(ped, true)
        trascinatoDa = nil

        exports.aurea_ui:Notifica({ tipo = 'successo', icona = '🔓', titolo = 'Manette rimosse', testo = 'Sei libero di muoverti.' })
    end
end)

RegisterNetEvent('giu:trascina', function(agenteSrc)
    if not ammanettato then return end
    trascinatoDa = trascinatoDa and nil or agenteSrc
end)

CreateThread(function()
    while true do
        local attesa = 500
        if ammanettato then
            attesa = 0
            local ped = PlayerPedId()

            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 22, true) DisableControlAction(0, 21, true)
            DisableControlAction(0, 44, true) DisableControlAction(0, 37, true)
            DisableControlAction(0, 23, true) DisableControlAction(0, 75, true)

            if not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
                AUREA.CaricaAnim('mp_arresting')
                TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            if trascinatoDa then
                local agente = GetPlayerFromServerId(trascinatoDa)
                if agente ~= -1 then
                    local agentePed = GetPlayerPed(agente)
                    if #(GetEntityCoords(ped) - GetEntityCoords(agentePed)) < 12.0 then
                        AttachEntityToEntity(ped, agentePed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, false)
                    else
                        DetachEntity(ped, true, false)
                        trascinatoDa = nil
                    end
                end
            elseif IsEntityAttachedToAnyPed(ped) then
                DetachEntity(ped, true, false)
            end
        end
        Wait(attesa)
    end
end)

exports('Ammanettato', function() return ammanettato end)

-- ---------------------------------------------------------------------------
--  Azioni delle forze dell'ordine sulla persona vicina
-- ---------------------------------------------------------------------------
RegisterCommand('mdt', function()
    CreateThread(function()
        if not AUREA.PG then return end
        local valori = exports.aurea_ui:Dialogo('Banca dati interforze', {
            { etichetta = 'Codice fiscale o codice cittadino', tipo = 'text', obbligatorio = true },
        })
        if not valori then return end

        local dati, errore = AUREA.Callback.Attendi('giu:consulta', valori[1])
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Ricerca senza esito', testo = errore or 'Nessun risultato.' })
        end

        mostraFascicolo(dati)
    end)
end, false)
RegisterKeyMapping('mdt', 'Apri la banca dati interforze', 'keyboard', 'F7')

function mostraFascicolo(dati)
    local a = dati.anagrafica
    local voci = {
        { id = 'anagrafica', icona = '🪪', titolo = ('%s %s'):format(a.nome, a.cognome),
          descrizione = ('CF %s · nato il %s a %s · tel. %s'):format(a.cf, a.nascita, a.luogo, a.telefono),
          valore = dati.online and 'in zona' or 'non rintracciabile' },
    }

    if dati.patente then
        voci[#voci + 1] = { id = 'patente', icona = '🚗', titolo = 'Patente di guida',
            descrizione = ('N. %s · categorie %s'):format(dati.patente.numero, dati.patente.categorie),
            valore = dati.patente.ritirata and 'REVOCATA' or ('%d punti'):format(dati.patente.punti) }
    else
        voci[#voci + 1] = { id = 'nopatente', icona = '🚫', titolo = 'Nessuna patente conseguita', disattivata = true }
    end

    if dati.detenzione then
        voci[#voci + 1] = { id = 'detenuto', icona = '🔒', titolo = 'Attualmente detenuto',
            descrizione = dati.detenzione.motivo,
            valore = ('%d/%d min'):format(dati.detenzione.minuti_scontati, dati.detenzione.minuti_totali) }
    end

    voci[#voci + 1] = { id = 'precedenti', icona = '⚖', titolo = 'Precedenti penali',
        descrizione = ('%d iscrizioni nel casellario'):format(#dati.precedenti) }

    voci[#voci + 1] = { id = 'verbali', icona = '📄', titolo = 'Verbali pendenti',
        descrizione = ('%d verbali aperti'):format(#dati.verbali) }

    voci[#voci + 1] = { id = 'veicoli', icona = '🚙', titolo = 'Veicoli intestati',
        descrizione = ('%d veicoli al PRA'):format(#dati.veicoli) }

    local scelta = exports.aurea_ui:Menu({
        titolo = ('Fascicolo — %s %s'):format(a.nome, a.cognome),
        sottotitolo = ('Codice cittadino %s'):format(a.citizenid),
        voci = voci,
    })
    if not scelta then return end

    local dettaglio = {}
    if scelta == 'precedenti' then
        for _, p in ipairs(dati.precedenti) do
            dettaglio[#dettaglio + 1] = { id = p.id, icona = '⚖', titolo = ('%s — %s'):format(p.articolo, p.reato),
                descrizione = ('%s · %s'):format(p.quando, p.agente or 'ufficio'), valore = p.stato }
        end
    elseif scelta == 'verbali' then
        for _, v in ipairs(dati.verbali) do
            dettaglio[#dettaglio + 1] = { id = v.id, icona = '📄', titolo = ('%s — %s'):format(v.articolo, v.descrizione),
                descrizione = ('%s · %s'):format(v.luogo or 'n.d.', v.emessa), valore = U.Euro(v.dovuto) }
        end
    elseif scelta == 'veicoli' then
        for _, v in ipairs(dati.veicoli) do
            dettaglio[#dettaglio + 1] = { id = v.targa, icona = '🚙', titolo = v.targa,
                descrizione = v.modello, valore = v.stato }
        end
    else
        return
    end

    if #dettaglio == 0 then
        dettaglio[1] = { id = 'v', icona = '—', titolo = 'Nessuna voce registrata', disattivata = true }
    end

    exports.aurea_ui:Menu({ titolo = 'Dettaglio', sottotitolo = ('%s %s'):format(a.nome, a.cognome), voci = dettaglio })
end

-- ---------------------------------------------------------------------------
--  Arresto
-- ---------------------------------------------------------------------------
RegisterCommand('arresta', function()
    CreateThread(function()
        local bersaglio = giocatoreVicino(5.0)
        if not bersaglio then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati al soggetto.' })
        end

        local codici = {}
        while true do
            local voci = {}
            for codice, r in pairs(AUREA.Reati) do
                local giaScelto = false
                for _, c in ipairs(codici) do if c == codice then giaScelto = true break end end
                voci[#voci + 1] = {
                    id = codice, icona = giaScelto and '✅' or '⚖',
                    titolo = r.nome, descrizione = r.articolo,
                    valore = ('%d min'):format(r.pena),
                    ordine = r.gravita,
                }
            end
            table.sort(voci, function(x, y)
                if x.ordine ~= y.ordine then return x.ordine > y.ordine end
                return x.titolo < y.titolo
            end)

            local minuti, ammenda = AUREA.CalcolaPena(codici)
            table.insert(voci, 1, {
                id = '__procedi', icona = '🔒',
                titolo = #codici > 0 and 'Procedi all\'arresto' or 'Seleziona i capi d\'imputazione',
                descrizione = #codici > 0 and ('%d capi · %d minuti · ammenda %s'):format(#codici, minuti, U.Euro(ammenda)) or nil,
                disattivata = #codici == 0,
            })
            if #codici > 0 then
                table.insert(voci, 2, { id = '__azzera', icona = '↩', titolo = 'Azzera la selezione' })
            end

            local scelta = exports.aurea_ui:Menu({
                titolo = 'Capi d\'imputazione',
                sottotitolo = 'La continuazione riduce la pena cumulata',
                voci = voci,
            })
            if not scelta then return end

            if scelta == '__azzera' then
                codici = {}
            elseif scelta == '__procedi' then
                break
            else
                local trovato = false
                for i, c in ipairs(codici) do
                    if c == scelta then table.remove(codici, i) trovato = true break end
                end
                if not trovato then codici[#codici + 1] = scelta end
            end
        end

        local valori = exports.aurea_ui:Dialogo('Verbale di arresto', {
            { etichetta = 'Note per il fascicolo', tipo = 'textarea', segnaposto = 'Circostanze del fermo, testimoni, sequestri...' },
        })

        local ok, messaggio = AUREA.Callback.Attendi('giu:arresta', bersaglio, codici, valori and valori[1] or nil)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🔒', titolo = ok and 'Arresto eseguito' or 'Arresto rifiutato',
            testo = messaggio, durata = 12000,
        })
    end)
end, false)

function giocatoreVicino(raggio)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    for _, altro in ipairs(GetActivePlayers()) do
        local altroPed = GetPlayerPed(altro)
        if altroPed ~= ped and #(coord - GetEntityCoords(altroPed)) < (raggio or 3.0) then
            return GetPlayerServerId(altro)
        end
    end
    return nil
end

RegisterCommand('trascina', function()
    local bersaglio = giocatoreVicino(3.0)
    if not bersaglio then
        return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati alla persona.' })
    end
    TriggerServerEvent('giu:trascinaRichiesta', bersaglio)
end, false)

-- ---------------------------------------------------------------------------
--  Denunce
-- ---------------------------------------------------------------------------
RegisterCommand('denuncia', function()
    CreateThread(function()
        local valori = exports.aurea_ui:Dialogo('Denuncia-querela', {
            { etichetta = 'Oggetto', tipo = 'text', segnaposto = 'Es. Furto di veicolo', obbligatorio = true },
            { etichetta = 'Esposizione dei fatti', tipo = 'textarea',
              segnaposto = 'Descrivi quando, dove e come si sono svolti i fatti.', obbligatorio = true },
            { etichetta = 'Codice fiscale del denunciato (se noto)', tipo = 'text' },
        })
        if not valori then return end

        local ok, messaggio = AUREA.Callback.Attendi('giu:denuncia', valori[1], valori[2], valori[3])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '📋', titolo = ok and 'Denuncia protocollata' or 'Denuncia non accettata',
            testo = messaggio, durata = 11000,
        })
    end)
end, false)

RegisterCommand('denunce', function()
    CreateThread(function()
        local denunce = AUREA.Callback.Attendi('giu:denunce') or {}
        if #denunce == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', titolo = 'Nessuna denuncia', testo = 'Non ci sono denunce da esaminare.' })
        end

        local voci = {}
        for _, d in ipairs(denunce) do
            voci[#voci + 1] = {
                id = d.id, icona = '📋', titolo = d.oggetto,
                descrizione = ('Da %s %s · %s'):format(d.nome_d or '?', d.cognome_d or '', d.quando),
                valore = d.stato,
            }
        end

        local id = exports.aurea_ui:Menu({ titolo = 'Denunce protocollate', sottotitolo = 'Seleziona per leggere', voci = voci })
        if not id then return end

        for _, d in ipairs(denunce) do
            if d.id == id then
                exports.aurea_ui:Notifica({
                    tipo = 'info', icona = '📋', durata = 22000,
                    titolo = ('Denuncia n. %d — %s'):format(d.id, d.oggetto),
                    testo = ('%s\n\nDenunciante: %s %s\nDenunciato: %s'):format(
                        d.corpo, d.nome_d or '?', d.cognome_d or '',
                        d.nome_s and (d.nome_s .. ' ' .. d.cognome_s) or 'ignoto'),
                })
                break
            end
        end
    end)
end, false)
