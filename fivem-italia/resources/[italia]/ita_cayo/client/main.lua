--[[
    AUREA · Punta Corvo (client)
]]

local U = AUREA.Util
local occupato = false
local colpoAttivo = nil     -- { sospetto, ... }
local blipObiettivi = {}
local blipIsola = nil

-- ---------------------------------------------------------------------------
--  Blip dell'isola e del punto di osservazione
-- ---------------------------------------------------------------------------
CreateThread(function()
    local i = CAY.Isola
    blipIsola = AddBlipForCoord(i.centro.x, i.centro.y, i.centro.z)
    SetBlipSprite(blipIsola, i.blip.sprite)
    SetBlipColour(blipIsola, i.blip.colore)
    SetBlipScale(blipIsola, i.blip.scala)
    SetBlipAsShortRange(blipIsola, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(i.nome)
    EndTextCommandSetBlipName(blipIsola)
end)

local function pulisciObiettivi()
    for _, b in ipairs(blipObiettivi) do RemoveBlip(b) end
    blipObiettivi = {}
end

local function segnaObiettivo(coord, nome, sprite, colore)
    local b = AddBlipForCoord(coord.x, coord.y, coord.z)
    SetBlipSprite(b, sprite or 1)
    SetBlipColour(b, colore or 5)
    SetBlipScale(b, 0.75)
    SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(nome)
    EndTextCommandSetBlipName(b)
    blipObiettivi[#blipObiettivi + 1] = b
    return b
end

-- ---------------------------------------------------------------------------
--  1. RICOGNIZIONE
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1200
        local coord = GetEntityCoords(PlayerPedId())

        if CAY.SullIsola(coord) and not occupato and not colpoAttivo then
            for _, b in ipairs(CAY.Ricognizione.bersagli) do
                if #(coord - b.coord) < CAY.Ricognizione.distanzaScatto then
                    attesa = 0
                    exports.aurea_ui:Prompt(true, ('Fotografa: %s'):format(b.nome), 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        fotografa(b)
                    end
                    break
                end
            end
        end

        Wait(attesa)
    end
end)

function fotografa(bersaglio)
    CreateThread(function()
        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = ('Scatto: %s'):format(bersaglio.nome),
            durata = CAY.Ricognizione.durataScatto,
            annullabile = true,
            anim = { dizionario = 'amb@world_human_paparazzi@male@base', nome = 'base' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('cay:fotografa', bersaglio.id)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📷',
            titolo = ok and 'Ricognizione' or 'Scatto inutile',
            testo = messaggio, durata = 12000,
        })
    end)
end

RegisterCommand('ricognizione', function()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('cay:ricognizione')
        if not dati then return end

        local voci = {
            { id = '_st', icona = dati.pronta and '🟢' or '🔴',
              titolo = dati.pronta and 'Ricognizione completa'
                  or ('Mancano %d sopralluoghi obbligatori'):format(dati.mancanti),
              descrizione = ('Le foto restano valide %d minuti.'):format(dati.validitaMinuti),
              disattivata = true },
        }

        for _, b in ipairs(dati.bersagli) do
            voci[#voci + 1] = {
                id = b.id, icona = b.fatta and '📸' or (b.obbligatorio and '❗' or '·'),
                titolo = b.nome,
                descrizione = b.fatta
                    and ('Fotografato da %s. %s'):format(b.da, b.sblocca)
                    or b.sblocca,
                valore = b.fatta and ('%d min'):format(b.minutiResidui)
                    or (b.obbligatorio and 'obbligatorio' or 'facoltativo'),
                disattivata = b.fatta,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ('Ricognizione — %s'):format(CAY.Isola.nome),
            sottotitolo = 'Ogni foto apre un\'opzione. Senza le obbligatorie non si parte.',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        local b = CAY.GetBersaglio(scelta)
        if b then
            pulisciObiettivi()
            segnaObiettivo(b.coord, b.nome, 1, 5)
            exports.aurea_ui:Notifica({
                tipo = 'info', icona = '📍', durata = 10000,
                titolo = b.nome, testo = 'Segnato sulla mappa. Vacci con la fotocamera.',
            })
        end
    end)
end, false)

-- ---------------------------------------------------------------------------
--  2 e 3. PIANIFICAZIONE
-- ---------------------------------------------------------------------------
RegisterCommand('puntacorvo', function()
    CreateThread(function()
        if colpoAttivo then return mostraStato() end

        local dati = AUREA.Callback.Attendi('cay:pianificazione')
        if not dati then return end

        local voci = {}

        if dati.inCorso then
            voci[#voci + 1] = { id = '_x', icona = '🔴', titolo = 'C\'è già un colpo in corso',
                                disattivata = true }
        elseif dati.minutiAttesa > 0 then
            voci[#voci + 1] = { id = '_x', icona = '⏳',
                                titolo = ('Alla villa hanno cambiato le serrature'),
                                descrizione = ('Si può riprovare fra %d minuti.'):format(dati.minutiAttesa),
                                disattivata = true }
        end

        voci[#voci + 1] = { id = 'ricognizione', icona = '📷', titolo = 'Ricognizione',
                            descrizione = 'Cosa sappiamo dell\'isola.' }
        voci[#voci + 1] = { id = 'attrezzatura', icona = '🎒', titolo = 'Attrezzatura',
                            descrizione = 'Cosa hai addosso e cosa manca.' }

        for _, a in ipairs(dati.approcci) do
            voci[#voci + 1] = {
                id = 'app:' .. a.id, icona = '🚤', titolo = a.nome,
                descrizione = a.disponibile and a.descrizione or a.motivo,
                valore = ('sospetto +%d'):format(a.sospettoIniziale),
                disattivata = not a.disponibile or dati.inCorso or dati.minutiAttesa > 0,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = CAY.Isola.nome,
            sottotitolo = ('Squadra da %d a %d persone, tutte insieme al momento della partenza')
                :format(dati.squadraMinima, dati.squadraMassima),
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'ricognizione' then return ExecuteCommand('ricognizione') end

        if scelta == 'attrezzatura' then
            local elenco = {}
            for _, e in ipairs(dati.attrezzatura) do
                elenco[#elenco + 1] = {
                    id = e.item, icona = e.presente and '✅' or (e.obbligatorio and '❗' or '·'),
                    titolo = e.etichetta, descrizione = e.nota,
                    valore = e.obbligatorio and 'obbligatorio' or 'facoltativo',
                    disattivata = true,
                }
            end
            return exports.aurea_ui:Menu({
                titolo = 'Attrezzatura', sottotitolo = 'Si compra al mercato nero, o si ruba',
                voci = elenco,
            })
        end

        local idApproccio = scelta:match('^app:(.+)$')
        if not idApproccio then return end

        local conferma = exports.aurea_ui:Menu({
            titolo = 'Si parte?',
            sottotitolo = 'Chi è vicino a te in questo momento entra nella squadra',
            voci = {
                { id = 'si', icona = '🏝', titolo = 'Andiamo' },
                { id = 'no', icona = '↩', titolo = 'Aspettiamo' },
            },
        })
        if conferma ~= 'si' then return end

        local ok, messaggio = AUREA.Callback.Attendi('cay:avvia', idApproccio)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏝',
            titolo = ok and 'Colpo avviato' or 'Non si parte',
            testo = messaggio, durata = 15000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Durante il colpo
-- ---------------------------------------------------------------------------
RegisterNetEvent('cay:inizio', function(dati)
    colpoAttivo = { sospetto = dati.sospetto }

    pulisciObiettivi()
    segnaObiettivo(vector3(dati.punto.x, dati.punto.y, dati.punto.z),
        'Punto di ritrovo', 1, 2)

    exports.aurea_ui:Notifica({
        tipo = 'successo', icona = '🏝', durata = 20000,
        titolo = ('Punta Corvo — %s'):format(dati.approccio),
        testo = ('Squadra: %s. Usa /colpo per lo stato.'):format(table.concat(dati.squadra, ', ')),
    })
end)

RegisterNetEvent('cay:sospetto', function(valore, motivo)
    if not colpoAttivo then colpoAttivo = {} end
    colpoAttivo.sospetto = valore

    if motivo and motivo ~= 'il tempo passa' then
        exports.aurea_ui:Notifica({
            tipo = valore >= CAY.Sospetto.sogliaAllarme and 'avviso' or 'info',
            icona = '📈', durata = 7000,
            titolo = ('Sospetto %d%%'):format(valore), testo = motivo,
        })
    end
end)

RegisterNetEvent('cay:fine', function()
    colpoAttivo = nil
    pulisciObiettivi()
end)

--- La barra del sospetto, visibile solo mentre si è in azione.
CreateThread(function()
    while true do
        if colpoAttivo and colpoAttivo.sospetto then
            local frazione = math.min(1.0, colpoAttivo.sospetto / CAY.Sospetto.massimo)
            local allarme = colpoAttivo.sospetto >= CAY.Sospetto.sogliaAllarme

            DrawRect(0.5, 0.055, 0.22, 0.038, 0, 0, 0, 170)
            DrawRect(0.39 + (0.22 * frazione) / 2, 0.055, 0.22 * frazione, 0.038,
                allarme and 190 or 200, allarme and 30 or 150, 30, 220)

            SetTextFont(4)
            SetTextScale(0.34, 0.34)
            SetTextColour(255, 255, 255, 255)
            SetTextCentre(true)
            SetTextDropShadow()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('SOSPETTO  %d%%'):format(colpoAttivo.sospetto))
            EndTextCommandDisplayText(0.5, 0.045)

            Wait(0)
        else
            Wait(700)
        end
    end
end)

function mostraStato()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('cay:stato')
        if not s then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🏝', titolo = 'Punta Corvo',
                testo = 'Nessun colpo in corso a cui tu partecipi.',
            })
        end

        local voci = {
            { id = '_s', icona = s.allarme and '🚨' or '📈',
              titolo = ('Sospetto %d%% su %d'):format(s.sospetto, CAY.Sospetto.massimo),
              descrizione = s.allarme and 'La villa è in allarme: muovetevi.'
                  or ('Sopra il %d%% gli uomini si mettono in moto.'):format(s.soglia),
              valore = s.approccio, disattivata = true },
        }

        for _, f in ipairs(s.fasi) do
            voci[#voci + 1] = {
                id = 'fase:' .. f.id,
                icona = f.fatta and '✅' or (f.aperta and '▶' or '🔒'),
                titolo = f.nome, descrizione = f.nota,
                disattivata = f.fatta or not f.aperta,
            }
        end

        if s.fasi[#s.fasi].fatta then
            voci[#voci + 1] = {
                id = 'primario', icona = '📕', titolo = s.primario,
                descrizione = 'È questo che vale il viaggio.',
                valore = s.primarioPreso and 'preso' or nil,
                disattivata = s.primarioPreso,
            }
            for _, b in ipairs(s.bottini) do
                voci[#voci + 1] = {
                    id = 'bot:' .. b.id, icona = '💰', titolo = b.nome,
                    descrizione = ('Costa tempo e alza il sospetto di %d.'):format(b.sospetto),
                    valore = b.preso and 'svuotato' or nil,
                    disattivata = b.preso,
                }
            end
        end

        if s.rientro then
            voci[#voci + 1] = {
                id = 'rientro', icona = '⚓', titolo = ('Rientro: %s'):format(s.rientro.nome),
                descrizione = 'Segna il punto di consegna sulla mappa.',
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = CAY.Isola.nome, sottotitolo = 'Stato del colpo', voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'rientro' then
            pulisciObiettivi()
            segnaObiettivo(vector3(s.rientro.x, s.rientro.y, s.rientro.z), s.rientro.nome, 356, 2)
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '⚓', titolo = 'Rientro',
                testo = ('Il ricettatore aspetta a %s.'):format(s.rientro.nome), durata = 11000,
            })
        end

        if scelta == 'primario' then return prendiPrimario() end

        local idFase = scelta:match('^fase:(.+)$')
        if idFase then
            -- Se sei lontano, ti segno il punto invece di farti perdere tempo
            local f = CAY.GetFase(idFase)
            if f and #(GetEntityCoords(PlayerPedId()) - f.coord) > 8.0 then
                pulisciObiettivi()
                segnaObiettivo(f.coord, f.nome, 1, 5)
                return exports.aurea_ui:Notifica({
                    tipo = 'info', icona = '📍', titolo = f.nome,
                    testo = 'Segnato sulla mappa.', durata = 9000,
                })
            end
            return eseguiFase(idFase)
        end

        local idBottino = scelta:match('^bot:(.+)$')
        if idBottino then prendiSecondario(idBottino) end
    end)
end

RegisterCommand('colpo', function() mostraStato() end, false)

function eseguiFase(idFase)
    CreateThread(function()
        if occupato then return end

        local ok, dati = AUREA.Callback.Attendi('cay:avviaFase', idFase)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔒', titolo = 'Non ora', testo = tostring(dati), durata = 11000,
            })
        end

        occupato = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = dati.conAttrezzo and ('%s (con %s)'):format(dati.nome, dati.attrezzo) or dati.nome,
            durata = dati.durata, annullabile = true,
            anim = { dizionario = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', nome = 'machinic_loop_mechandplayer' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completata then
            return exports.aurea_ui:Notifica({
                tipo = 'avviso', icona = '⚠', titolo = 'Interrotto',
                testo = 'Il lavoro è da rifare da capo.', durata = 9000,
            })
        end

        local fatto, messaggio = AUREA.Callback.Attendi('cay:concludiFase')
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = fatto and '✅' or '🚫',
            titolo = 'Punta Corvo', testo = messaggio, durata = 12000,
        })
    end)
end

function prendiPrimario()
    CreateThread(function()
        if occupato then return end

        local ok, durata = AUREA.Callback.Attendi('cay:prendiPrimario')
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📕', titolo = 'Non ora', testo = tostring(durata), durata = 10000,
            })
        end

        occupato = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Svuotamento della cassaforte...', durata = durata, annullabile = true,
            blocca = { movimento = true },
        })
        occupato = false
        if not completata then return end

        local fatto, messaggio = AUREA.Callback.Attendi('cay:concludiPrimario')
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '📕',
            titolo = fatto and 'Libro mastro' or 'Niente da fare',
            testo = messaggio, durata = 16000,
        })
    end)
end

function prendiSecondario(id)
    CreateThread(function()
        if occupato then return end

        local s = CAY.GetSecondario(id)
        if s and s.coord and #(GetEntityCoords(PlayerPedId()) - s.coord) > 10.0 then
            pulisciObiettivi()
            segnaObiettivo(s.coord, s.nome, 1, 5)
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '📍', titolo = s.nome, testo = 'Segnato sulla mappa.', durata = 9000,
            })
        end

        local ok, durata = AUREA.Callback.Attendi('cay:prendiSecondario', id)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '💰', titolo = 'Non ora', testo = tostring(durata), durata = 10000,
            })
        end

        occupato = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Carico del borsone...', durata = durata, annullabile = true,
            blocca = { movimento = true },
        })
        occupato = false
        if not completata then return end

        local fatto, messaggio = AUREA.Callback.Attendi('cay:concludiSecondario')
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '💰',
            titolo = 'Bottino', testo = messaggio, durata = 12000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Rientro e consegna
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1500
        local coord = GetEntityCoords(PlayerPedId())

        if #(coord - CAY.Rientro.punto) < CAY.Rientro.raggio and not occupato then
            attesa = 0
            exports.aurea_ui:Prompt(true, ('%s — piazza la merce'):format(CAY.Rientro.nome), 'G')
            if IsControlJustReleased(0, 47) then
                exports.aurea_ui:Prompt(false)
                CreateThread(function()
                    local ok, messaggio = AUREA.Callback.Attendi('cay:consegna')
                    exports.aurea_ui:Notifica({
                        tipo = ok and 'successo' or 'errore', icona = '⚓',
                        titolo = ok and 'Merce piazzata' or 'Nessun affare',
                        testo = messaggio, durata = 16000,
                    })
                end)
            end
        end

        Wait(attesa)
    end
end)

--- Consegnare il libro mastro alle forze dell'ordine invece di venderlo.
RegisterCommand('consegnamastro', function()
    CreateThread(function()
        local agente = giocatoreVicino(3.5)
        if not agente then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📕', titolo = 'Nessuno accanto a te',
                testo = 'Serve un pubblico ufficiale in servizio.',
            })
        end

        local conferma = exports.aurea_ui:Menu({
            titolo = 'Consegnare il libro mastro',
            sottotitolo = 'Rinunci ai soldi. In cambio la Procura ha i nomi — e i nomi si sanno.',
            voci = {
                { id = 'si', icona = '📕', titolo = 'Consegnalo' },
                { id = 'no', icona = '↩', titolo = 'Ci ripenso' },
            },
        })
        if conferma ~= 'si' then return end

        local ok, messaggio = AUREA.Callback.Attendi('cay:consegnaAutorita', agente)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📕',
            titolo = 'Libro mastro', testo = messaggio, durata = 18000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function giocatoreVicino(raggio)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, raggio

    for _, altro in ipairs(GetActivePlayers()) do
        local altroPed = GetPlayerPed(altro)
        if altroPed ~= ped then
            local d = #(coord - GetEntityCoords(altroPed))
            if d < distanza then migliore, distanza = GetPlayerServerId(altro), d end
        end
    end
    return migliore
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    pulisciObiettivi()
    if blipIsola then RemoveBlip(blipIsola) end
end)
