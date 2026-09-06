--[[
    AUREA · Casa Circondariale (client)
]]

local inIsolamento = false
local cellaIsolamento = nil

-- ---------------------------------------------------------------------------
--  Isolamento
--
--  Il client tiene il detenuto in cella perché è lui che ha il ped fra le
--  mani, ma la restrizione è del server: se qualcuno aggira questo
--  controllo, esce dal perimetro e ita_giustizia gli contesta l'evasione.
-- ---------------------------------------------------------------------------
RegisterNetEvent('car:isolamento', function(attivo, cella, minuti, motivo)
    inIsolamento = attivo and true or false
    cellaIsolamento = cella and vector3(cella.x, cella.y, cella.z) or nil

    if not attivo then
        return exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🚪', durata = 10000,
            titolo = 'Fine isolamento', testo = 'Puoi tornare in sezione.',
        })
    end

    if cella then
        SetEntityCoords(PlayerPedId(), cella.x, cella.y, cella.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), cella.w or 0.0)
    end

    exports.aurea_ui:Notifica({
        tipo = 'errore', icona = '🚪', durata = 20000,
        titolo = ('Isolamento — %d minuti'):format(minuti or 0),
        testo = motivo and ('Rinvenuti: %s.'):format(motivo) or 'Sanzione disciplinare.',
    })
end)

CreateThread(function()
    while true do
        Wait(inIsolamento and 800 or 4000)
        if inIsolamento and cellaIsolamento then
            local ped = PlayerPedId()
            if #(GetEntityCoords(ped) - cellaIsolamento) > 4.0 then
                SetEntityCoords(ped, cellaIsolamento.x, cellaIsolamento.y, cellaIsolamento.z,
                    false, false, false, false)
                exports.aurea_ui:Notifica({
                    tipo = 'errore', icona = '🚪', durata = 5000,
                    titolo = 'Sei in isolamento',
                })
            end
        end
    end
end)

--- Al rientro in gioco: se l'isolamento è ancora in corso, riprende.
AddEventHandler('aurea:client:caricato', function()
    Wait(4000)
    local attivo, secondi = AUREA.Callback.Attendi('car:isolato')
    if attivo then
        inIsolamento = true
        cellaIsolamento = vector3(CAR.Disciplina.cellaIsolamento.x,
                                  CAR.Disciplina.cellaIsolamento.y,
                                  CAR.Disciplina.cellaIsolamento.z)
        exports.aurea_ui:Notifica({
            tipo = 'avviso', icona = '🚪', durata = 12000,
            titolo = 'Isolamento in corso',
            testo = ('Mancano %d minuti.'):format(math.ceil(secondi / 60)),
        })
    end
end)

-- ---------------------------------------------------------------------------
--  Sopravvitto
-- ---------------------------------------------------------------------------
local function apriSopravvitto()
    local listino, peculio, aperto = AUREA.Callback.Attendi('car:listino')

    if not aperto then
        return exports.aurea_ui:Notifica({
            tipo = 'avviso', icona = '🛒', titolo = 'Sopravvitto chiuso',
            testo = ('Apre dalle %d alle %d.'):format(CAR.Sopravvitto.orario.da, CAR.Sopravvitto.orario.a),
        })
    end

    local voci = {}
    for _, r in ipairs(listino or {}) do
        voci[#voci + 1] = {
            id = r.item, icona = '🛒', titolo = r.etichetta,
            descrizione = ('%s al pezzo'):format(AUREA.Util.Euro(r.prezzo)),
        }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Sopravvitto',
        sottotitolo = ('Peculio disponibile: %s'):format(AUREA.Util.Euro(peculio or 0)),
        voci = voci,
    })
    if not scelta then return end

    local risposte = exports.aurea_ui:Dialogo('Quanti pezzi?', {
        { etichetta = 'Quantità', tipo = 'number', valore = 1, min = 1, max = 10, obbligatorio = true },
    })
    if not risposte then return end

    local ok, messaggio = AUREA.Callback.Attendi('car:compra', scelta, tonumber(risposte[1]) or 1)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '🛒',
        titolo = ok and 'Acquisto registrato' or 'Non acquistato',
        testo = messaggio, durata = 10000,
    })
end

-- ---------------------------------------------------------------------------
--  Lavorazione
-- ---------------------------------------------------------------------------
local function lavora()
    local ok, risposta = AUREA.Callback.Attendi('car:lavora')
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🧰', testo = risposta, durata = 9000 })
    end

    if exports.aurea_ui:Progresso({
        etichetta = 'Lavorazione interna...', durata = risposta,
        anim = { dizionario = 'amb@world_human_hammering@male@base', nome = 'base' },
        blocca = { movimento = true },
    }) then
        local fatto, messaggio = AUREA.Callback.Attendi('car:concludiLavoro')
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '💶',
            titolo = 'Mercede', testo = messaggio, durata = 10000,
        })
    end
end

-- ---------------------------------------------------------------------------
--  Matricola: versamenti, ritiro deposito
-- ---------------------------------------------------------------------------
local function personaVicina()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, 5.0
    for _, id in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(id)
        if altro ~= ped then
            local d = #(coord - GetEntityCoords(altro))
            if d < distanza then migliore, distanza = GetPlayerServerId(id), d end
        end
    end
    return migliore
end

local function apriMatricola()
    local scelta = exports.aurea_ui:Menu({
        titolo = CAR.Matricola.nome,
        sottotitolo = 'Sportello',
        voci = {
            { id = 'versa', icona = '💶', titolo = 'Versa sul peculio di un detenuto',
              descrizione = 'Il detenuto deve essere allo sportello con te.' },
            { id = 'deposito', icona = '📦', titolo = 'Ritira gli effetti a deposito',
              descrizione = 'Solo se sei già stato scarcerato.' },
            { id = 'colloquio', icona = '👥', titolo = 'Chiedi un colloquio',
              descrizione = 'La richiesta si presenta in sala d\'attesa.' },
        },
    })

    if scelta == 'versa' then
        local d = personaVicina()
        if not d then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '💶', testo = 'Nessuno allo sportello con te.' })
        end
        local risposte = exports.aurea_ui:Dialogo('Versamento sul peculio', {
            { etichetta = 'Importo in euro', tipo = 'number', min = 1, max = 5000, obbligatorio = true },
        })
        if not risposte then return end

        local ok, messaggio = AUREA.Callback.Attendi('car:versa', d,
            AUREA.Util.ACentesimi(tonumber(risposte[1]) or 0))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '💶',
            titolo = ok and 'Versamento eseguito' or 'Non eseguito',
            testo = messaggio, durata = 10000,
        })

    elseif scelta == 'deposito' then
        local ok, messaggio = AUREA.Callback.Attendi('car:ritiraDeposito')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📦',
            titolo = ok and 'Deposito ritirato' or 'Non ritirato',
            testo = messaggio, durata = 10000,
        })

    elseif scelta == 'colloquio' then
        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '👥', durata = 9000,
            titolo = 'Sala d\'attesa',
            testo = 'Le richieste di colloquio si presentano in sala d\'attesa, non allo sportello.',
        })
    end
end

-- ---------------------------------------------------------------------------
--  Colloqui
-- ---------------------------------------------------------------------------
local function chiediColloquio()
    local risposte = exports.aurea_ui:Dialogo('Richiesta di colloquio', {
        { etichetta = 'Codice fiscale del detenuto', tipo = 'text', obbligatorio = true },
    })
    if not risposte then return end

    local ok, messaggio = AUREA.Callback.Attendi('car:chiediColloquio', tostring(risposte[1]))
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '👥',
        titolo = ok and 'Richiesta presentata' or 'Non presentata',
        testo = messaggio, durata = 14000,
    })
end

local function gestisciColloqui()
    local righe = AUREA.Callback.Attendi('car:colloquiPendenti')
    local voci = {}

    for _, r in ipairs(righe or {}) do
        voci[#voci + 1] = {
            id = tostring(r.id),
            icona = r.stato == 'autorizzato' and '✅' or '⏳',
            titolo = ('%s → %s %s'):format(r.visitatore_nome, r.nome or '?', r.cognome or ''),
            descrizione = r.stato == 'autorizzato' and 'Già autorizzato.' or 'In attesa di decisione.',
            disattivata = r.stato == 'autorizzato',
        }
    end
    if #voci == 0 then
        voci[1] = { id = 'x', icona = '👥', titolo = 'Nessuna richiesta pendente', disattivata = true }
    end

    local scelta = exports.aurea_ui:Menu({ titolo = 'Richieste di colloquio', voci = voci })
    if not scelta or scelta == 'x' then return end

    local decisione = exports.aurea_ui:Menu({
        titolo = 'Decisione della direzione',
        voci = {
            { id = 'si', icona = '✅', titolo = 'Autorizza il colloquio' },
            { id = 'no', icona = '⛔', titolo = 'Respingi' },
        },
    })
    if not decisione then return end

    local ok, messaggio = AUREA.Callback.Attendi('car:decidiColloquio', tonumber(scelta), decisione == 'si')
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '👥', testo = messaggio, durata = 9000,
    })
end

-- ---------------------------------------------------------------------------
--  Agenti: perquisizione e quadro detenuti
-- ---------------------------------------------------------------------------
RegisterCommand('perquisisci', function()
    local b = personaVicina()
    if not b then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔍', testo = 'Nessuno davanti a te.' })
    end

    if not exports.aurea_ui:Progresso({
        etichetta = 'Perquisizione...', durata = 8000, blocca = { movimento = true },
    }) then return end

    local ok, messaggio = AUREA.Callback.Attendi('car:perquisisci', b)
    exports.aurea_ui:Notifica({
        tipo = ok and 'avviso' or 'errore', icona = '🔍',
        titolo = 'Esito della perquisizione', testo = messaggio, durata = 16000,
    })
end, false)

RegisterCommand('detenuti', function()
    local righe = AUREA.Callback.Attendi('car:detenuti')
    local voci = {}
    for _, r in ipairs(righe or {}) do
        voci[#voci + 1] = {
            id = r.citizenid, icona = r.isolamento and '🚪' or '🔒',
            titolo = r.nome,
            descrizione = ('%s%s'):format(
                r.residui and ('residui %d minuti'):format(r.residui) or 'pena non calcolabile',
                r.isolamento and ' · in isolamento' or ''),
            disattivata = true,
        }
    end
    if #voci == 0 then
        voci[1] = { id = 'x', icona = '🔒', titolo = 'Nessun detenuto presente', disattivata = true }
    end
    exports.aurea_ui:Menu({ titolo = 'Quadro dei detenuti', voci = voci })
end, false)

-- ---------------------------------------------------------------------------
--  Contrabbando alla recinzione
-- ---------------------------------------------------------------------------
local function passaAllaRecinzione()
    local d = personaVicina()
    if not d then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🤝', testo = 'Dall\'altra parte non c\'è nessuno.' })
    end

    local risposte = exports.aurea_ui:Dialogo('Passa qualcosa attraverso la rete', {
        { etichetta = 'Nome tecnico dell\'oggetto', tipo = 'text', obbligatorio = true },
        { etichetta = 'Quantità', tipo = 'number', valore = 1, min = 1, max = 20, obbligatorio = true },
    })
    if not risposte then return end

    if not exports.aurea_ui:Progresso({
        etichetta = 'Passaggio attraverso la rete...', durata = CAR.Contrabbando.durata,
        blocca = { movimento = true },
    }) then return end

    local ok, messaggio = AUREA.Callback.Attendi('car:passa', d,
        tostring(risposte[1]):lower(), tonumber(risposte[2]) or 1)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '🤝',
        titolo = ok and 'Passato' or 'Non passato', testo = messaggio, durata = 11000,
    })
end

-- ---------------------------------------------------------------------------
--  Evasione
-- ---------------------------------------------------------------------------
local function lavoraSulVarco(v)
    local ok, risposta, nome = AUREA.Callback.Attendi('car:varco', v.id)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🧱', testo = risposta, durata = 11000 })
    end

    if not exports.aurea_ui:Progresso({
        etichetta = ('Lavori su: %s'):format(nome), durata = risposta,
        anim = { dizionario = 'amb@world_human_welding@male@base', nome = 'base' },
        blocca = { movimento = true },
    }) then
        return exports.aurea_ui:Notifica({ tipo = 'avviso', icona = '🧱', titolo = 'Interrotto',
            testo = 'Ti sei fermato a metà.' })
    end

    local fatto, uscita = AUREA.Callback.Attendi('car:evadi', v.id)
    if not fatto then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🧱', testo = uscita or 'Non ci sei riuscito.' })
    end

    DoScreenFadeOut(600)
    Wait(700)
    SetEntityCoords(PlayerPedId(), uscita.x, uscita.y, uscita.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), uscita.w or 0.0)
    Wait(400)
    DoScreenFadeIn(800)

    exports.aurea_ui:Notifica({
        tipo = 'errore', icona = '🏃', durata = 20000,
        titolo = 'Sei fuori',
        testo = 'Da adesso sei evaso: art. 385 c.p. Ti cercheranno, e la pena residua ti aspetta comunque.',
    })
end

-- ---------------------------------------------------------------------------
--  Punti sulla mappa e terzo occhio
-- ---------------------------------------------------------------------------
CreateThread(function()
    exports.aurea_target:AggiungiZona('car_matricola', CAR.Matricola.coord, 2.5, {
        { etichetta = CAR.Matricola.nome, icona = '🗄', azione = apriMatricola },
    })

    exports.aurea_target:AggiungiZona('car_sopravvitto', CAR.Sopravvitto.coord, 2.5, {
        { etichetta = 'Sopravvitto', icona = '🛒',
          condizione = function() return AUREA.PG and AUREA.PG.metadata and AUREA.PG.metadata.detenuto end,
          azione = apriSopravvitto },
    })

    exports.aurea_target:AggiungiZona('car_lavorazione', CAR.Lavorazione.coord, 3.0, {
        { etichetta = 'Lavorazione interna', icona = '🧰',
          condizione = function() return AUREA.PG and AUREA.PG.metadata and AUREA.PG.metadata.detenuto end,
          azione = lavora },
    })

    exports.aurea_target:AggiungiZona('car_attesa', CAR.Colloqui.salaAttesa, 3.0, {
        { etichetta = 'Chiedi un colloquio', icona = '👥', azione = chiediColloquio },
    })

    exports.aurea_target:AggiungiZona('car_sala', CAR.Colloqui.sala, CAR.Colloqui.raggio, {
        { etichetta = 'Richieste di colloquio', icona = '📋',
          lavoro = CAR.Lavoro, inServizio = true, azione = gestisciColloqui },
    })

    for n, p in ipairs(CAR.Contrabbando.punti) do
        exports.aurea_target:AggiungiZona('car_rete_' .. n, p.coord, CAR.Contrabbando.raggio, {
            { etichetta = 'Passa qualcosa attraverso la rete', icona = '🤝', azione = passaAllaRecinzione },
        })
    end

    for _, v in ipairs(CAR.Evasione.varchi) do
        exports.aurea_target:AggiungiZona('car_varco_' .. v.id, v.coord, 2.5, {
            {
                etichetta = v.nome, icona = '🧱',
                oggetto = v.attrezzo,
                condizione = function() return AUREA.PG and AUREA.PG.metadata and AUREA.PG.metadata.detenuto end,
                azione = function() lavoraSulVarco(v) end,
            },
        })
    end
end)
