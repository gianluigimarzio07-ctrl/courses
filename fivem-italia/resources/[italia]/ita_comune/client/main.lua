--[[
    AUREA · Comune (client)

    Lo sportello del Municipio: anagrafe, matrimoni, seggio elettorale
    e — per chi è stato eletto — la stanza dei bottoni.
]]

local U = AUREA.Util
local proposta = nil     -- proposta di matrimonio ricevuta

-- ---------------------------------------------------------------------------
--  Blip e sale
-- ---------------------------------------------------------------------------
CreateThread(function()
    local blip = AddBlipForCoord(COM.Sede.coord.x, COM.Sede.coord.y, COM.Sede.coord.z)
    SetBlipSprite(blip, COM.Sede.blip.sprite)
    SetBlipColour(blip, COM.Sede.blip.colore)
    SetBlipScale(blip, COM.Sede.blip.scala)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(COM.Sede.nome)
    EndTextCommandSetBlipName(blip)
end)

-- ---------------------------------------------------------------------------
--  Sportello
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())

        if #(coord - COM.Sede.coord) < 2.2 then
            attesa = 0
            exports.aurea_ui:Prompt(true, 'Sportello del Comune', 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                apriSportello()
            end
        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

function apriSportello()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('com:servizi')
        if not dati then return end

        local voci = {}

        if dati.sindaco then
            voci[#voci + 1] = {
                id = '_sindaco', icona = '🏛', titolo = ('Sindaco in carica: %s'):format(dati.sindaco),
                descrizione = 'Le delibere del Comune valgono per tutti.', disattivata = true,
            }
        end

        if dati.matrimonio then
            voci[#voci + 1] = {
                id = '_stato', icona = '💍',
                titolo = ('Coniugato/a con %s'):format(dati.matrimonio.coniuge),
                descrizione = ('%s — dal %s'):format(dati.matrimonio.regime, dati.matrimonio.quando),
                disattivata = true,
            }
        end

        for _, s in ipairs(dati.servizi) do
            voci[#voci + 1] = {
                id = 'srv:' .. s.id, icona = '📄', titolo = s.nome,
                descrizione = s.descrizione,
                valore = s.costo > 0 and U.Euro(s.costo) or 'gratuito',
            }
        end

        voci[#voci + 1] = { id = 'nozze', icona = '💍', titolo = 'Ufficio matrimoni',
                            descrizione = 'Promesse, celebrazioni e separazioni.' }
        voci[#voci + 1] = { id = 'seggio', icona = '🗳', titolo = 'Seggio elettorale',
                            descrizione = 'Candidature, voto e risultati.' }
        voci[#voci + 1] = { id = 'delibere', icona = '🏛', titolo = 'Sala della giunta',
                            descrizione = 'Le leve che il sindaco può manovrare.' }

        local scelta = exports.aurea_ui:Menu({
            titolo = COM.Sede.nome,
            sottotitolo = 'Uffici anagrafici e sala consiliare',
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'nozze' then return menuNozze() end
        if scelta == 'seggio' then return menuSeggio() end
        if scelta == 'delibere' then return menuDelibere() end

        local id = scelta:match('^srv:(.+)$')
        if id then richiediServizio(id) end
    end)
end

function richiediServizio(id)
    local servizio = COM.GetServizio(id)
    if not servizio then return end

    local dato = nil

    if id == 'cambio_nome' then
        local risposta = exports.aurea_ui:Dialogo('Istanza di cambio del nome', {
            { etichetta = 'Nome richiesto', tipo = 'text',
              segnaposto = 'Come vuoi essere chiamato', obbligatorio = true },
        })
        if not risposta or not risposta[1] then return end
        dato = risposta[1]
    end

    if servizio.costo > 0 then
        local conferma = exports.aurea_ui:Menu({
            titolo = servizio.nome,
            sottotitolo = ('Diritti di segreteria: %s'):format(U.Euro(servizio.costo)),
            voci = {
                { id = 'si', icona = '✅', titolo = 'Paga e procedi' },
                { id = 'no', icona = '↩', titolo = 'Annulla' },
            },
        })
        if conferma ~= 'si' then return end
    end

    local ok, messaggio = AUREA.Callback.Attendi('com:richiediServizio', id, dato)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        icona = ok and '📄' or '🚫',
        titolo = servizio.nome, testo = messaggio, durata = 12000,
    })
end

-- ---------------------------------------------------------------------------
--  Matrimoni
-- ---------------------------------------------------------------------------
function menuNozze()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = 'Ufficio matrimoni',
            sottotitolo = 'Il rito richiede la presenza di entrambi e di un celebrante',
            voci = {
                { id = 'proponi', icona = '💍', titolo = 'Chiedi la mano a chi ti sta accanto',
                  descrizione = 'La promessa si deposita qui, il rito si celebra dopo.' },
                { id = 'divorzio', icona = '💔', titolo = 'Domanda di separazione',
                  descrizione = ('Spese: %s. In comunione i saldi si dividono.'):format(U.Euro(COM.Matrimonio.costoDivorzio)) },
                { id = 'celebra', icona = '🎩', titolo = 'Celebra un matrimonio',
                  descrizione = 'Riservato agli ufficiali di stato civile.' },
            },
        })
        if not scelta then return end

        if scelta == 'proponi' then
            local bersaglio = giocatoreVicino(COM.Matrimonio.distanzaSposi)
            if not bersaglio then
                return exports.aurea_ui:Notifica({
                    tipo = 'errore', icona = '💍', titolo = 'Non c\'è nessuno accanto a te',
                    testo = 'Avvicinati alla persona a cui vuoi chiedere la mano.',
                })
            end

            local regimi = {}
            for id, r in pairs(COM.Matrimonio.regimi) do
                regimi[#regimi + 1] = { id = id, icona = '📜', titolo = r.nome, descrizione = r.descrizione }
            end
            table.sort(regimi, function(a, b) return a.titolo < b.titolo end)

            local regime = exports.aurea_ui:Menu({
                titolo = 'Regime patrimoniale',
                sottotitolo = 'Si sceglie prima della proposta e vale per tutto il matrimonio',
                voci = regimi,
            })
            if not regime then return end

            local ok, messaggio = AUREA.Callback.Attendi('com:proponi', bersaglio, regime)
            exports.aurea_ui:Notifica({
                tipo = ok and 'info' or 'errore', icona = '💍',
                titolo = 'Proposta di matrimonio', testo = messaggio, durata = 11000,
            })

        elseif scelta == 'divorzio' then
            local conferma = exports.aurea_ui:Menu({
                titolo = 'Domanda di separazione',
                sottotitolo = 'La decisione è definitiva',
                voci = {
                    { id = 'si', icona = '💔', titolo = 'Deposita la domanda' },
                    { id = 'no', icona = '↩', titolo = 'Ci ripenso' },
                },
            })
            if conferma ~= 'si' then return end

            local ok, messaggio = AUREA.Callback.Attendi('com:divorzio')
            exports.aurea_ui:Notifica({
                tipo = ok and 'avviso' or 'errore', icona = '💔',
                titolo = 'Separazione', testo = messaggio, durata = 13000,
            })

        elseif scelta == 'celebra' then
            celebra()
        end
    end)
end

function celebra()
    local sposi = giocatoriVicini(COM.Matrimonio.distanzaSposi + 2.0, 2)
    if #sposi < 2 then
        return exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '🎩', titolo = 'Servono due sposi',
            testo = 'Devono essere entrambi davanti a te.',
        })
    end

    local completato = exports.aurea_ui:Progresso({
        etichetta = 'Lettura degli articoli del codice civile...',
        durata = COM.Matrimonio.durataRito,
        annullabile = true,
        anim = { dizionario = 'missfbi_s4mop', nome = 'stand_talk_loop_a_male1' },
        blocca = { movimento = true },
    })
    if not completato then return end

    local ok, messaggio = AUREA.Callback.Attendi('com:celebra', sposi[1], sposi[2])
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '💍',
        titolo = 'Celebrazione', testo = messaggio, durata = 13000,
    })
end

RegisterNetEvent('com:propostaRicevuta', function(daSrc, nomeMittente, regime)
    local r = COM.Matrimonio.regimi[regime]
    proposta = { da = daSrc, scadenza = GetGameTimer() + 55000 }

    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '💍', durata = 20000,
        titolo = ('%s ti chiede di sposarlo'):format(nomeMittente),
        testo = ('Regime proposto: %s. Premi Y per accettare, N per rifiutare.'):format(r and r.nome or regime),
    })
end)

CreateThread(function()
    while true do
        local attesa = 500

        if proposta then
            attesa = 0

            if GetGameTimer() > proposta.scadenza then
                proposta = nil
            elseif IsControlJustReleased(0, 246) then      -- Y
                proposta = nil
                rispondiProposta(true)
            elseif IsControlJustReleased(0, 249) then      -- N
                proposta = nil
                rispondiProposta(false)
            end
        end

        Wait(attesa)
    end
end)

function rispondiProposta(accettata)
    CreateThread(function()
        local ok, messaggio = AUREA.Callback.Attendi('com:rispondiProposta', accettata)
        if not ok then return end
        exports.aurea_ui:Notifica({
            tipo = accettata and 'successo' or 'info',
            icona = accettata and '💍' or '💔',
            titolo = 'Proposta di matrimonio', testo = messaggio, durata = 13000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Seggio elettorale
-- ---------------------------------------------------------------------------
local ETICHETTA_FASE = {
    chiusa = 'Nessuna tornata in corso',
    campagna = 'Campagna elettorale — le candidature sono aperte',
    voto = 'Seggi aperti — si vota',
}

function menuSeggio()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('com:elezioni')
        if not dati then return end

        local voci = {
            { id = '_fase', icona = '🗳', titolo = ETICHETTA_FASE[dati.fase] or dati.fase,
              descrizione = dati.sindaco and ('Sindaco in carica: %s'):format(dati.sindaco) or 'Nessun sindaco in carica',
              disattivata = true },
        }

        if dati.fase == 'campagna' and dati.eCandidabile then
            voci[#voci + 1] = {
                id = 'candidati', icona = '✍', titolo = 'Deposita la tua candidatura',
                descrizione = 'Serve la fedina pulita dai reati gravi.',
                valore = U.Euro(dati.cauzione),
            }
        end

        if #dati.candidati == 0 then
            voci[#voci + 1] = { id = '_vuoto', icona = '—', titolo = 'Nessun candidato', disattivata = true }
        end

        for _, c in ipairs(dati.candidati) do
            local puoVotare = dati.fase == 'voto' and not dati.giaVotato
            voci[#voci + 1] = {
                id = 'voto:' .. c.id,
                icona = '👤',
                titolo = ('%s %s'):format(c.nome, c.cognome),
                descrizione = (c.programma ~= '' and c.programma or 'Non ha depositato un programma.'),
                valore = dati.fase == 'voto' and (puoVotare and 'vota' or 'hai già votato')
                    or ('%d voti'):format(c.voti or 0),
                disattivata = not puoVotare,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Seggio elettorale',
            sottotitolo = 'Un cittadino, un voto',
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'candidati' then
            local risposta = exports.aurea_ui:Dialogo('Candidatura a sindaco', {
                { etichetta = 'Programma elettorale', tipo = 'textarea',
                  segnaposto = 'Cosa farai da sindaco', obbligatorio = true },
            })
            if not risposta or not risposta[1] then return end

            local ok, messaggio = AUREA.Callback.Attendi('com:candidati', risposta[1])
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🗳',
                titolo = 'Candidatura', testo = messaggio, durata = 12000,
            })
        end

        local id = scelta:match('^voto:(%d+)$')
        if id then
            local ok, messaggio = AUREA.Callback.Attendi('com:vota', tonumber(id))
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🗳',
                titolo = 'Urna', testo = messaggio, durata = 12000,
            })
        end
    end)
end

-- ---------------------------------------------------------------------------
--  Sala della giunta
-- ---------------------------------------------------------------------------
function menuDelibere()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('com:leve')
        if not dati then return end

        local voci = {
            { id = '_cassa', icona = '🏦', titolo = ('Cassa comunale: %s'):format(U.Euro(dati.cassa)),
              descrizione = 'Alimentata dall\'addizionale e dai diritti di segreteria.',
              disattivata = true },
        }

        for _, l in ipairs(dati.leve) do
            local valore = l.opzioni and tostring(l.valore)
                or (l.id == 'addizionale' and ('%s%%'):format(l.valore) or U.Euro(tonumber(l.valore) or 0))

            voci[#voci + 1] = {
                id = 'leva:' .. l.id, icona = '⚙', titolo = l.nome,
                descrizione = l.descrizione, valore = valore,
                disattivata = not dati.eSindaco,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Sala della giunta',
            sottotitolo = dati.eSindaco and 'Le tue delibere valgono da subito'
                or ('Solo il sindaco delibera%s'):format(dati.sindaco and (' — in carica: ' .. dati.sindaco) or ''),
            voci = voci,
        })
        if not scelta then return end

        local id = scelta:match('^leva:(.+)$')
        if not id then return end

        local def = COM.LeveSindaco[id]
        if not def then return end

        local valore
        if def.opzioni then
            local opzioni = {}
            for _, o in ipairs(def.opzioni) do
                opzioni[#opzioni + 1] = { id = o, icona = '•', titolo = o }
            end
            valore = exports.aurea_ui:Menu({ titolo = def.nome, sottotitolo = def.descrizione, voci = opzioni })
        else
            local etichetta = id == 'addizionale'
                and ('Punti percentuali (da %d a %d)'):format(def.minimo, def.massimo)
                or ('Importo in centesimi (da %s a %s)'):format(U.Euro(def.minimo), U.Euro(def.massimo))

            local risposta = exports.aurea_ui:Dialogo(def.nome, {
                { etichetta = etichetta, tipo = 'number', valore = def.predefinito,
                  min = def.minimo, max = def.massimo, obbligatorio = true },
            })
            valore = risposta and risposta[1]
        end
        if not valore then return end

        local ok, messaggio = AUREA.Callback.Attendi('com:impostaLeva', id, valore)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏛',
            titolo = 'Delibera', testo = messaggio, durata = 12000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Istanze, per gli uffici
-- ---------------------------------------------------------------------------
RegisterCommand('istanze', function()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('com:istanze')
        if not righe or #righe == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '📋', titolo = 'Protocollo',
                testo = 'Non ci sono istanze in esame.',
            })
        end

        local voci = {}
        for _, r in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(r.id), icona = '📋',
                titolo = ('%s %s'):format(r.nome, r.cognome),
                descrizione = ('%s → "%s"'):format(r.tipo:gsub('_', ' '), r.contenuto),
                valore = r.quando,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Istanze in esame',
            sottotitolo = 'Ogni decisione resta agli atti',
            voci = voci,
        })
        if not scelta then return end

        local decisione = exports.aurea_ui:Menu({
            titolo = 'Decisione',
            voci = {
                { id = 'accogli', icona = '✅', titolo = 'Accogli l\'istanza' },
                { id = 'respingi', icona = '🚫', titolo = 'Respingi l\'istanza' },
            },
        })
        if not decisione then return end

        local ok, messaggio = AUREA.Callback.Attendi('com:decidiIstanza', tonumber(scelta), decisione == 'accogli')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📋',
            titolo = 'Protocollo', testo = messaggio, durata = 10000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function giocatoreVicino(raggio)
    local vicini = giocatoriVicini(raggio, 1)
    return vicini[1]
end

--- Restituisce fino a `quanti` server id di giocatori entro il raggio, dal più vicino.
function giocatoriVicini(raggio, quanti)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local trovati = {}

    for _, altro in ipairs(GetActivePlayers()) do
        local altroPed = GetPlayerPed(altro)
        if altroPed ~= ped then
            local distanza = #(coord - GetEntityCoords(altroPed))
            if distanza < raggio then
                trovati[#trovati + 1] = { src = GetPlayerServerId(altro), distanza = distanza }
            end
        end
    end

    table.sort(trovati, function(a, b) return a.distanza < b.distanza end)

    local out = {}
    for n = 1, math.min(quanti or 1, #trovati) do out[n] = trovati[n].src end
    return out
end
