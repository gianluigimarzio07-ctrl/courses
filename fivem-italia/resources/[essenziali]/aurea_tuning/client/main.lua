--[[
    AUREA · Elaborazione (client)
]]

local U = AUREA.Util
local modificheProposte = {}

-- ---------------------------------------------------------------------------
--  Blip
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, o in ipairs(TUN.Officine) do
        local b = AddBlipForCoord(o.coord.x, o.coord.y, o.coord.z)
        SetBlipSprite(b, 446) SetBlipColour(b, 46) SetBlipScale(b, 0.7)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(o.nome) EndTextCommandSetBlipName(b)
    end
end)

-- ---------------------------------------------------------------------------
--  Interazione
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local veicolo = GetVehiclePedIsIn(ped, false)
        local officina = nil
        local clandestina = false

        for _, o in ipairs(TUN.Officine) do
            if #(coord - o.coord) < 4.0 then officina = o break end
        end
        if not officina and #(coord - TUN.Clandestina.coord) < 4.0 then
            officina = TUN.Clandestina
            clandestina = true
        end

        if officina then
            attesa = 0
            if veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped then
                exports.aurea_ui:Prompt(true, officina.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    apriOfficina(officina, veicolo, clandestina)
                end
            else
                exports.aurea_ui:Prompt(true, ('%s — entra con il veicolo'):format(officina.nome), 'E')
            end
        elseif #(coord - TUN.Motorizzazione.coord) < 2.5 then
            attesa = 0
            exports.aurea_ui:Prompt(true, TUN.Motorizzazione.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuOmologazione()
            end
        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Officina
-- ---------------------------------------------------------------------------
function apriOfficina(officina, veicolo, clandestina)
    CreateThread(function()
        local targa = GetVehicleNumberPlateText(veicolo):gsub('%s+', '')
        local stato, errore = AUREA.Callback.Attendi('tun:statoVeicolo', targa)
        if not stato then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Veicolo sconosciuto', testo = errore })
        end

        modificheProposte = {}
        SetVehicleModKit(veicolo, 0)

        while true do
            local voci = {}

            if stato.fuoriNorma then
                voci[#voci + 1] = {
                    id = '__avviso', icona = '⚠',
                    titolo = 'Veicolo fuori norma',
                    descrizione = 'Le modifiche meccaniche non sono annotate sulla carta di circolazione.',
                    disattivata = true,
                }
            end

            voci[#voci + 1] = { id = '__estetica', icona = '🎨', titolo = 'Estetica',
                descrizione = 'Colori, cerchi, carrozzeria. Nessuna omologazione richiesta.' }
            voci[#voci + 1] = { id = '__meccanica', icona = '⚙', titolo = 'Meccanica',
                descrizione = clandestina
                    and 'Nessuna certificazione: il veicolo resterà irregolare.'
                    or 'Va omologata alla Motorizzazione dopo il lavoro.' }

            local quante = 0
            for _ in pairs(modificheProposte) do quante = quante + 1 end
            if quante > 0 then
                voci[#voci + 1] = { id = '__conferma', icona = '✅',
                    titolo = 'Conferma il preventivo',
                    descrizione = ('%d modifiche in lavorazione'):format(quante) }
                voci[#voci + 1] = { id = '__annulla', icona = '↩', titolo = 'Annulla tutto' }
            end

            local scelta = exports.aurea_ui:Menu({
                titolo = officina.nome,
                sottotitolo = ('%s%s'):format(targa,
                    clandestina and ' · nessuna fattura, nessuna domanda' or ''),
                voci = voci,
            })

            if not scelta then
                ripristina(veicolo, stato.modifiche)
                return
            end

            if scelta == '__annulla' then
                modificheProposte = {}
                ripristina(veicolo, stato.modifiche)

            elseif scelta == '__conferma' then
                local ok, messaggio, avviso, definitive = AUREA.Callback.Attendi(
                    'tun:applica', targa, modificheProposte, clandestina)

                if ok then
                    TriggerServerEvent('gar:salvaProprieta', targa, leggiVeicolo(veicolo))
                    stato.modifiche = definitive or stato.modifiche
                    modificheProposte = {}
                else
                    ripristina(veicolo, stato.modifiche)
                end

                exports.aurea_ui:Notifica({
                    tipo = ok and 'successo' or 'errore',
                    icona = '🔧', titolo = ok and 'Lavoro eseguito' or 'Lavoro rifiutato',
                    testo = messaggio, durata = 10000,
                })

                if avviso then
                    exports.aurea_ui:Notifica({
                        tipo = 'avviso', icona = '⚠', durata = 16000,
                        titolo = 'Modifiche da omologare', testo = avviso,
                    })
                end
                return

            elseif scelta == '__estetica' then
                menuVoci(veicolo, TUN.Estetiche, 'Estetica', 'Modifiche libere, nessuna pratica')

            elseif scelta == '__meccanica' then
                menuVoci(veicolo, TUN.Meccaniche, 'Meccanica',
                    clandestina and 'Il veicolo resterà fuori norma' or 'Da omologare dopo il lavoro')
            end
        end
    end)
end

function menuVoci(veicolo, elenco, titolo, sottotitolo)
    local voci = {}
    for _, m in ipairs(elenco) do
        local proposto = modificheProposte[m.id]
        voci[#voci + 1] = {
            id = m.id,
            icona = proposto ~= nil and '✅' or '🔧',
            titolo = m.nome,
            descrizione = m.descrizione,
            valore = U.Euro(m.prezzo),
        }
    end

    local scelta = exports.aurea_ui:Menu({ titolo = titolo, sottotitolo = sottotitolo, voci = voci })
    if not scelta then return end

    local voce = TUN.GetEstetica(scelta) or TUN.GetMeccanica(scelta)
    if not voce then return end

    scegliValore(veicolo, voce)
end

function scegliValore(veicolo, voce)
    if voce.interruttore then
        local attivo = modificheProposte[voce.id] == true
        modificheProposte[voce.id] = not attivo
        ToggleVehicleMod(veicolo, voce.indice, not attivo)
        return
    end

    if voce.tipo == 'colore' then
        local valori = exports.aurea_ui:Dialogo(voce.nome, {
            { etichetta = 'Indice colore (0-159)', tipo = 'number', valore = 0, min = 0, max = 159 },
        })
        if not valori then return end

        local colore = math.floor(U.Clamp(tonumber(valori[1]) or 0, 0, 159))
        modificheProposte[voce.id] = colore
        applicaAnteprima(veicolo, voce.id, colore)
        return
    end

    if voce.tipo == 'vetri' then
        local valori = exports.aurea_ui:Dialogo('Oscuramento dei vetri', {
            { etichetta = 'Grado (0 nessuno, 1 leggero, 2-4 scuro)', tipo = 'number', valore = 0, min = 0, max = 4 },
        })
        if not valori then return end
        local grado = math.floor(U.Clamp(tonumber(valori[1]) or 0, 0, 4))
        modificheProposte[voce.id] = grado
        SetVehicleWindowTint(veicolo, grado)
        return
    end

    if voce.tipo == 'livrea' then
        local massimo = GetVehicleLiveryCount(veicolo) - 1
        if massimo < 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', titolo = 'Nessuna livrea', testo = 'Questo modello non ne prevede.' })
        end
        local valori = exports.aurea_ui:Dialogo('Livrea', {
            { etichetta = ('Numero (0-%d)'):format(massimo), tipo = 'number', valore = 0, min = 0, max = massimo },
        })
        if not valori then return end
        local livrea = math.floor(U.Clamp(tonumber(valori[1]) or 0, 0, massimo))
        modificheProposte[voce.id] = livrea
        SetVehicleLivery(veicolo, livrea)
        return
    end

    -- Modifiche a indice
    local massimo = GetNumVehicleMods(veicolo, voce.indice) - 1
    if massimo < 0 then
        return exports.aurea_ui:Notifica({
            tipo = 'info', titolo = 'Non disponibile',
            testo = ('Questo modello non ammette la modifica "%s".'):format(voce.nome),
        })
    end

    local valori = exports.aurea_ui:Dialogo(voce.nome, {
        { etichetta = ('Livello (0-%d, -1 di serie)'):format(massimo),
          tipo = 'number', valore = 0, min = -1, max = massimo },
    })
    if not valori then return end

    local livello = math.floor(U.Clamp(tonumber(valori[1]) or -1, -1, massimo))
    modificheProposte[voce.id] = livello
    SetVehicleMod(veicolo, voce.indice, livello, false)
end

function applicaAnteprima(veicolo, id, valore)
    local primario, secondario = GetVehicleColours(veicolo)
    local perla, cerchi = GetVehicleExtraColours(veicolo)

    if id == 'colorePrimario' then SetVehicleColours(veicolo, valore, secondario)
    elseif id == 'coloreSecondario' then SetVehicleColours(veicolo, primario, valore)
    elseif id == 'coloreCerchi' then SetVehicleExtraColours(veicolo, perla, valore)
    end
end

function ripristina(veicolo, modifiche)
    if not modifiche then return end
    SetVehicleModKit(veicolo, 0)

    for _, m in ipairs(TUN.Estetiche) do
        local valore = modifiche[m.id]
        if m.tipo == 'mod' then
            SetVehicleMod(veicolo, m.indice, valore or -1, false)
        elseif m.tipo == 'vetri' then
            SetVehicleWindowTint(veicolo, valore or 0)
        elseif m.tipo == 'livrea' and valore then
            SetVehicleLivery(veicolo, valore)
        end
    end

    for _, m in ipairs(TUN.Meccaniche) do
        local valore = modifiche[m.id]
        if m.interruttore then
            ToggleVehicleMod(veicolo, m.indice, valore == true)
        else
            SetVehicleMod(veicolo, m.indice, valore or -1, false)
        end
    end

    if modifiche.colorePrimario then
        SetVehicleColours(veicolo, modifiche.colorePrimario, modifiche.coloreSecondario or modifiche.colorePrimario)
    end
end

function leggiVeicolo(veicolo)
    local mod = {}
    for i = 0, 48 do
        local valore = GetVehicleMod(veicolo, i)
        if valore ~= -1 then mod[tostring(i)] = valore end
    end
    local primario, secondario = GetVehicleColours(veicolo)
    local perla, cerchi = GetVehicleExtraColours(veicolo)

    return {
        colorePrimario = primario, coloreSecondario = secondario,
        colorePerla = perla, coloreCerchi = cerchi,
        finestrini = GetVehicleWindowTint(veicolo),
        livrea = GetVehicleLivery(veicolo),
        turbo = IsToggleModOn(veicolo, 18),
        mod = mod,
    }
end

-- ---------------------------------------------------------------------------
--  Omologazione
-- ---------------------------------------------------------------------------
function menuOmologazione()
    CreateThread(function()
        local veicoli = AUREA.Callback.Attendi('vei:mieiVeicoli') or {}

        local voci = {}
        for _, v in ipairs(veicoli) do
            local stato = AUREA.Callback.Attendi('tun:statoVeicolo', v.targa)
            if stato and stato.fuoriNorma then
                voci[#voci + 1] = {
                    id = v.targa, icona = '⚠',
                    titolo = ('%s — %s'):format(v.targa, v.nome),
                    descrizione = 'Modifiche non annotate sulla carta di circolazione',
                    valore = U.Euro(TUN.Motorizzazione.costoPratica),
                }
            end
        end

        if #voci == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'successo', icona = '✅',
                titolo = 'Nessuna pratica pendente',
                testo = 'Tutti i tuoi veicoli sono in regola.',
            })
        end

        local targa = exports.aurea_ui:Menu({
            titolo = TUN.Motorizzazione.nome,
            sottotitolo = 'Annotazione delle modifiche ex art. 78 CdS',
            voci = voci,
        })
        if not targa then return end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Collaudo delle modifiche in corso...',
            durata = TUN.Motorizzazione.durataCollaudo,
            annullabile = true, blocca = { movimento = true },
        })
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('tun:omologa', targa)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '📋', titolo = ok and 'Omologazione registrata' or 'Pratica respinta',
            testo = messaggio, durata = 13000,
        })
    end)
end
