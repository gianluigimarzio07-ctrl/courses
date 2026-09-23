--[[
    AUREA · Mercato rionale (client)

    Il cliente al banco lo annuncia il server. Qui si disegna l'attesa —
    un pannello con che cosa vuole, quanto paga e il tempo che scorre — e
    si mandano indietro due sole decisioni: vendere battendo lo scontrino,
    o vendere senza batterlo.

    Il conto delle vendite non lo tiene il client. Se lo tenesse, il
    controllo della Finanza sarebbe una chiacchierata fra il banco e sé
    stesso.
]]

local U = AUREA.Util

local clienteAttuale = nil
local scadenzaCliente = 0

-- ---------------------------------------------------------------------------
--  Il cliente al banco
-- ---------------------------------------------------------------------------
RegisterNetEvent('mer:cliente', function(dati)
    clienteAttuale = dati
    scadenzaCliente = GetGameTimer() + (dati.secondi or 30) * 1000

    exports.aurea_ui:Notifica({
        tipo = 'info', icona = '🧺', durata = 6000,
        titolo = 'Un cliente al banco',
        testo = ('Vuole %d × %s%s.\n%s')
            :format(dati.quantita, dati.etichetta,
                    dati.certificazione and (' ' .. dati.certificazione) or '',
                    U.Euro(dati.totale)),
    })
end)

RegisterNetEvent('mer:clientePerso', function()
    if not clienteAttuale then return end
    clienteAttuale = nil
    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '🚶', durata = 6000,
        titolo = 'Cliente perso',
        testo = 'Si è stancato di aspettare e ha girato l\'angolo.',
    })
end)

RegisterNetEvent('mer:chiuso', function(motivo)
    clienteAttuale = nil
    exports.aurea_ui:Notifica({
        tipo = 'errore', icona = '🏪', durata = 18000,
        titolo = 'Banco chiuso', testo = tostring(motivo or ''),
    })
end)

--- Il pannello dell'attesa. Si disegna solo quando c'è un cliente, così
--- il thread non consuma niente per chi non sta al mercato.
CreateThread(function()
    while true do
        if clienteAttuale then
            local residuo = math.max(0, (scadenzaCliente - GetGameTimer()) / 1000)
            if residuo <= 0 then
                clienteAttuale = nil
            else
                SetTextFont(4)
                SetTextScale(0.0, 0.42)
                SetTextColour(255, 255, 255, 220)
                SetTextCentre(true)
                SetTextOutline()
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(
                    ('%d × %s%s   —   %s   —   %ds\n~b~[E]~w~ con scontrino     ~o~[G]~w~ senza')
                        :format(clienteAttuale.quantita, clienteAttuale.etichetta,
                                clienteAttuale.certificazione
                                    and (' (' .. clienteAttuale.certificazione .. ')') or '',
                                U.Euro(clienteAttuale.totale), math.floor(residuo)))
                EndTextCommandDisplayText(0.5, 0.82)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function vendi(battere)
    CreateThread(function()
        if not clienteAttuale then return end
        clienteAttuale = nil

        local ok, esito = AUREA.Callback.Attendi('mer:vendi', battere)
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🧺',
                titolo = 'Vendita', testo = tostring(esito), durata = 10000 })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = battere and '🧾' or '💶',
            durata = 9000,
            titolo = battere and 'Scontrino battuto' or 'Venduto senza scontrino',
            testo = ('Incassati %s%s\nBattute %d · non battute %d')
                :format(U.Euro(esito.incassato),
                        battere and (' su %s lordi'):format(U.Euro(esito.lordo)) or '',
                        esito.battute, esito.nonBattute),
        })
    end)
end

CreateThread(function()
    while true do
        Wait(0)
        if clienteAttuale then
            if IsControlJustReleased(0, 38) then      -- E
                vendi(true)
            elseif IsControlJustReleased(0, 47) then  -- G
                vendi(false)
            end
        else
            Wait(300)
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Lo sportello del mercato
-- ---------------------------------------------------------------------------
local function sportello(m)
    CreateThread(function()
        local s = AUREA.Callback.Attendi('mer:sportello', m.id)
        if not s then return end

        local voci = {}

        if not s.licenza then
            voci[#voci + 1] = {
                id = 'licenza', icona = '📜', titolo = MER.Licenza.etichetta,
                descrizione = ('%s. Senza questa non si apre nessun banco.')
                    :format(U.Euro(s.costoLicenza)),
            }
        else
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '✅',
                titolo = 'Autorizzazione in regola',
            }
        end

        if s.mio then
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '🏪',
                titolo = ('Il tuo posteggio: %s'):format(s.mio.id),
                descrizione = ('Canone %s · concessione per altri %d minuti.\nApri il banco sul posto con /banco.')
                    :format(U.Euro(s.mio.canone), s.mio.minutiResidui),
            }
        else
            for _, p in ipairs(s.liberi) do
                voci[#voci + 1] = {
                    id = 'p:' .. p.id, icona = '📍',
                    titolo = ('Posteggio %s'):format(p.id),
                    descrizione = ('Canone %s, iscritto a ruolo: arriva la cartella, non si paga qui.')
                        :format(U.Euro(p.canone)),
                }
            end
            if #s.liberi == 0 then
                voci[#voci + 1] = {
                    id = 'x', disattivata = true, icona = '🚫',
                    titolo = 'Nessun posteggio libero',
                    descrizione = 'Sono tutti assegnati. Aspetta che una concessione scada.',
                }
            end
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = s.nome, sottotitolo = 'Sportello del mercato', voci = voci })
        if not scelta or scelta == 'x' then return end

        if scelta == 'licenza' then
            local ok, messaggio = AUREA.Callback.Attendi('mer:licenza')
            return exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore',
                icona = '📜', titolo = 'Sportello', testo = tostring(messaggio), durata = 16000 })
        end

        if scelta:sub(1, 2) == 'p:' then
            local ok, messaggio = AUREA.Callback.Attendi('mer:assegna', scelta:sub(3))
            return exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore',
                icona = '🏪', titolo = 'Posteggio', testo = tostring(messaggio), durata = 20000 })
        end
    end)
end

-- ---------------------------------------------------------------------------
--  Il banco
-- ---------------------------------------------------------------------------
local function banco()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('mer:stato')
        if not s then return end

        if s.aperto then
            local voci = {
                { id = 'x', disattivata = true, icona = '🏪',
                  titolo = ('%s — posteggio %s'):format(s.banco, s.posteggio),
                  descrizione = ('Aperto da %d minuti · %d pezzi in mostra\nFascia %s (afflusso ×%.2f)\nIncassato %s · battute %d, non battute %d%s')
                      :format(s.minuti, s.pezzi, s.fascia, s.afflusso,
                              U.Euro(s.incassato), s.battute, s.nonBattute,
                              s.alimentare and ('\nIgiene del banco %d/100'):format(s.igiene) or '') },
            }
            if s.alimentare and s.igiene < 100 then
                voci[#voci + 1] = {
                    id = 'sanifica', icona = '🧽', titolo = 'Sanificare il banco',
                    descrizione = ('Serve un detergente. Riporta l\'igiene su, e sotto %d gli alimentari si fermano.')
                        :format(MER.Igiene.soglia),
                }
            end
            voci[#voci + 1] = {
                id = 'chiudi', icona = '⏹', titolo = 'Chiudere il banco',
                descrizione = 'Si smonta e si va a casa.',
            }

            local scelta = exports.aurea_ui:Menu({
                titolo = 'Il tuo banco', sottotitolo = 'Mercato rionale', voci = voci })

            if scelta == 'sanifica' then
                if not exports.aurea_ui:Progresso({
                    etichetta = 'Sanificazione del banco',
                    durata = MER.Igiene.secondi * 1000, annullabile = true }) then return end
                local ok, messaggio = AUREA.Callback.Attendi('mer:sanifica')
                return exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore',
                    icona = '🧽', titolo = 'Igiene', testo = tostring(messaggio), durata = 12000 })
            end

            if scelta == 'chiudi' then
                local ok, esito = AUREA.Callback.Attendi('mer:chiudi')
                if not ok then return end
                clienteAttuale = nil
                return exports.aurea_ui:Notifica({
                    tipo = 'info', icona = '🏪', durata = 18000,
                    titolo = 'Banco chiuso',
                    testo = ('%d minuti di mercato.\nIncassato %s · %d scontrini battuti, %d no.')
                        :format(esito.minuti, U.Euro(esito.incassato),
                                esito.battute, esito.nonBattute),
                })
            end
            return
        end

        -- Il banco è chiuso: si scegle che cosa vendere
        local voci = {}
        for id, b in pairs(MER.Banchi) do
            voci[#voci + 1] = {
                id = id, icona = b.icona, titolo = b.etichetta,
                descrizione = ('%s\n%s')
                    :format(table.concat(b.items, ', '),
                            b.alimentare and 'Alimentare: il banco si sporca vendendo.'
                                          or 'Non alimentare: nessun vincolo di igiene.'),
            }
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Aprire il banco', sottotitolo = 'Che merce si mette in mostra', voci = voci })
        if not scelta then return end

        local ok, esito = AUREA.Callback.Attendi('mer:apri', scelta)
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🏪',
                titolo = 'Banco', testo = tostring(esito), durata = 14000 })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🏪', durata = 22000,
            titolo = ('%s — posteggio %s'):format(esito.banco, esito.posteggio),
            testo = ('%d pezzi in mostra. Fascia %s, afflusso ×%.2f.\nI clienti arrivano da soli: [E] per vendere con scontrino, [G] senza.')
                :format(esito.pezzi, esito.fascia, esito.afflusso),
        })
    end)
end

-- ---------------------------------------------------------------------------
--  I controlli
-- ---------------------------------------------------------------------------
local function piuVicino(raggio)
    local mio, trovato, minima = PlayerPedId(), nil, raggio
    for _, p in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(p)
        if ped ~= mio and ped ~= 0 then
            local d = #(GetEntityCoords(mio) - GetEntityCoords(ped))
            if d < minima then
                minima = d
                trovato = GetPlayerServerId(p)
            end
        end
    end
    return trovato
end

local function controllo()
    CreateThread(function()
        local bersaglio = piuVicino(6.0)
        if not bersaglio then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🧾',
                titolo = 'Controllo', testo = 'Nessuno davanti a te.', durata = 10000 })
        end

        if not exports.aurea_ui:Progresso({
            etichetta = 'Controllo dei corrispettivi', durata = 5000, annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('mer:controlla', bersaglio)
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🧾',
                titolo = 'Controllo', testo = tostring(esito), durata = 14000 })
        end

        local righe = {
            ('Esercente: %s'):format(esito.esercente),
            ('Vendite della sessione: %d'):format(esito.totali),
            ('Senza scontrino: %d (%d%%)'):format(esito.nonBattute, esito.quota),
        }
        if esito.sanzione > 0 then
            righe[#righe + 1] = ''
            righe[#righe + 1] = ('Imponibile sottratto %s'):format(U.Euro(esito.imponibileNon or 0))
            righe[#righe + 1] = ('Sanzione %s'):format(U.Euro(esito.sanzione))
        end
        if esito.sospeso then
            righe[#righe + 1] = 'BANCO CHIUSO D\'AUTORITÀ.'
        end

        exports.aurea_ui:Notifica({
            tipo = esito.sanzione > 0 and 'errore' or 'successo',
            icona = '🧾', titolo = 'Controllo dei corrispettivi',
            testo = table.concat(righe, '\n'), durata = 26000,
        })
    end)
end

local function abusivo()
    CreateThread(function()
        local bersaglio = piuVicino(6.0)
        if not bersaglio then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🚫',
                titolo = 'Abusivismo', testo = 'Nessuno davanti a te.', durata = 10000 })
        end

        local ok, esito = AUREA.Callback.Attendi('mer:abusivo', bersaglio)
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🚫',
                titolo = 'Abusivismo', testo = tostring(esito), durata = 14000 })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🚫', durata = 22000,
            titolo = 'Commercio abusivo contestato',
            testo = ('%s — %s.\nSanzione %s.%s')
                :format(esito.persona, esito.motivo, U.Euro(esito.importo),
                        esito.sequestrati > 0
                            and ('\nSequestrati %d pezzi di merce.'):format(esito.sequestrati)
                            or '\nNiente da sequestrare.'),
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Comandi e zone
-- ---------------------------------------------------------------------------
RegisterCommand('banco', banco, false)
RegisterCommand('scontrini', controllo, false)
RegisterCommand('abusivo', abusivo, false)

AddEventHandler('aurea:client:caricato', function()
    for _, m in ipairs(MER.Mercati) do
        local b = AddBlipForCoord(m.ufficio)
        SetBlipSprite(b, m.blip.sprite)
        SetBlipColour(b, m.blip.colore)
        SetBlipScale(b, m.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(m.nome)
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('mer_' .. m.id, m.ufficio, m.raggio, {
            { etichetta = 'Sportello del mercato', icona = '🏪',
              azione = function() sportello(m) end },
        })

        for _, p in ipairs(m.posteggi) do
            exports.aurea_target:AggiungiZona('mer_p_' .. p.id, p.coord, 2.0, {
                { etichetta = ('Posteggio %s'):format(p.id), icona = '🧺', azione = banco },
            })
        end
    end
end)
