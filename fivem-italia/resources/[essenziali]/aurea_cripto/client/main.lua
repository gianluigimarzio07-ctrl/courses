--[[
    AUREA · Criptovalute (client)

    Solo la vetrina. Il prezzo arriva dal server e non si tocca: quello che
    si disegna qui è già successo altrove.
]]

local quadro = {}

RegisterNetEvent('crp:quadro', function(nuovo)
    quadro = nuovo or {}
end)

-- ---------------------------------------------------------------------------
--  Il grafico
--
--  Un grafico a barre fatto di caratteri. Non è elegante, ma sta dentro un
--  menu di testo e si legge: si vede se la moneta sta salendo o scendendo,
--  che è l'unica cosa che serve sapere.
-- ---------------------------------------------------------------------------
local function sparkline(storico)
    if not storico or #storico < 2 then return 'dati insufficienti' end

    local minimo, massimo = math.huge, -math.huge
    for _, v in ipairs(storico) do
        if v < minimo then minimo = v end
        if v > massimo then massimo = v end
    end
    if massimo <= minimo then return string.rep('▄', math.min(#storico, 24)) end

    local livelli = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' }
    local pezzi = {}
    local dal = math.max(1, #storico - 23)

    for n = dal, #storico do
        local q = (storico[n] - minimo) / (massimo - minimo)
        pezzi[#pezzi + 1] = livelli[math.max(1, math.min(#livelli, math.floor(q * #livelli) + 1))]
    end

    return table.concat(pezzi)
end

-- ---------------------------------------------------------------------------
--  Exchange
-- ---------------------------------------------------------------------------
local function operaSu(moneta, extra, alloSportello)
    local voci = {
        { id = 'compra', icona = '⬆', titolo = 'Compra',
          descrizione = ('Commissione %.1f%%'):format(extra.commissione / 10) },
        { id = 'vendi', icona = '⬇', titolo = 'Vendi',
          descrizione = ('Ne hai %s (%s)'):format(
              CRP.FormattaQuantita(moneta.quantita), AUREA.Util.Euro(moneta.controvalore)),
          disattivata = moneta.quantita <= 0 },
        { id = 'invia', icona = '➡', titolo = 'Trasferisci a qualcuno',
          descrizione = 'Deve essere davanti a te.', disattivata = moneta.quantita <= 0 },
    }

    if alloSportello and moneta.accettaNero then
        table.insert(voci, 2, {
            id = 'nero', icona = '💵', titolo = 'Compra in contanti non tracciati',
            descrizione = ('Cambio al %d%% · massimo %s per operazione. Lo sportello compila una segnalazione.')
                :format(math.floor((moneta.scontoNero or 0.75) * 100),
                        AUREA.Util.Euro(extra.massimoNero)),
        })
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = ('%s (%s)'):format(moneta.nome, moneta.simbolo),
        sottotitolo = ('%s · %+.2f%%\n%s\n%s')
            :format(AUREA.Util.Euro(moneta.prezzo), moneta.variazione,
                    sparkline(moneta.storico), moneta.descrizione),
        voci = voci,
    })
    if not scelta then return end

    if scelta == 'compra' or scelta == 'nero' then
        local risposte = exports.aurea_ui:Dialogo(
            scelta == 'nero' and 'Acquisto in contanti non tracciati' or 'Acquisto', {
                { etichetta = 'Quanti euro vuoi investire', tipo = 'number',
                  min = 1, max = 500000, obbligatorio = true },
            })
        if not risposte then return end

        local ok, messaggio = AUREA.Callback.Attendi('crp:compra', moneta.id,
            AUREA.Util.ACentesimi(tonumber(risposte[1]) or 0), scelta == 'nero')

        return exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🪙',
            titolo = ok and 'Acquisto eseguito' or 'Non eseguito',
            testo = messaggio, durata = 16000,
        })
    end

    if scelta == 'vendi' then
        local risposte = exports.aurea_ui:Dialogo('Vendita', {
            { etichetta = ('Quanti millesimi (ne hai %d)'):format(moneta.quantita),
              tipo = 'number', valore = moneta.quantita,
              min = 1, max = moneta.quantita, obbligatorio = true },
        })
        if not risposte then return end

        local ok, messaggio = AUREA.Callback.Attendi('crp:vendi', moneta.id, tonumber(risposte[1]) or 0)
        return exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🪙',
            titolo = ok and 'Vendita eseguita' or 'Non eseguita',
            testo = messaggio, durata = 16000,
        })
    end

    if scelta == 'invia' then
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local destinatario, distanza = nil, 4.0

        for _, id in ipairs(GetActivePlayers()) do
            local altro = GetPlayerPed(id)
            if altro ~= ped then
                local d = #(coord - GetEntityCoords(altro))
                if d < distanza then destinatario, distanza = GetPlayerServerId(id), d end
            end
        end

        if not destinatario then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🪙',
                testo = 'Nessuno davanti a te.' })
        end

        local risposte = exports.aurea_ui:Dialogo('Trasferimento', {
            { etichetta = ('Quanti millesimi (ne hai %d)'):format(moneta.quantita),
              tipo = 'number', min = 1, max = moneta.quantita, obbligatorio = true },
        })
        if not risposte then return end

        local ok, messaggio = AUREA.Callback.Attendi('crp:trasferisci',
            moneta.id, tonumber(risposte[1]) or 0, destinatario)

        return exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🪙',
            titolo = ok and 'Trasferito' or 'Non trasferito',
            testo = messaggio, durata = 14000,
        })
    end
end

local function apriExchange(alloSportello)
    local righe, extra = AUREA.Callback.Attendi('crp:quadro')
    if not righe then return end

    if extra and extra.sequestrato then
        return exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '🪙', durata = 16000,
            titolo = 'Portafoglio sotto sequestro',
            testo = 'La Guardia di Finanza ha bloccato le tue operazioni.',
        })
    end

    local totale = 0
    local voci = {}

    for _, m in ipairs(righe) do
        totale = totale + m.controvalore
        voci[#voci + 1] = {
            id = m.id,
            icona = m.variazione > 1 and '📈' or (m.variazione < -1 and '📉' or '🪙'),
            titolo = ('%s — %s (%+.2f%%)')
                :format(m.simbolo, AUREA.Util.Euro(m.prezzo), m.variazione),
            descrizione = ('%s\n%s%s'):format(
                sparkline(m.storico),
                m.quantita > 0
                    and ('Ne hai %s = %s'):format(CRP.FormattaQuantita(m.quantita),
                                                  AUREA.Util.Euro(m.controvalore))
                    or 'Non ne hai',
                (alloSportello and m.accettaNero) and ' · accetta contante' or ''),
        }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = alloSportello and CRP.Exchange.nome or 'Exchange — applicazione',
        sottotitolo = ('Portafoglio: %s%s')
            :format(AUREA.Util.Euro(totale),
                    alloSportello and '' or '  ·  in nero si opera solo allo sportello'),
        voci = voci,
    })
    if not scelta then return end

    for _, m in ipairs(righe) do
        if m.id == scelta then return operaSu(m, extra, alloSportello) end
    end
end

RegisterCommand('cripto', function() apriExchange(false) end, false)

-- ---------------------------------------------------------------------------
--  Guardia di Finanza
-- ---------------------------------------------------------------------------
local function movimentiDi(citizenid, nome)
    local righe = AUREA.Callback.Attendi('crp:movimenti', citizenid)

    local voci = {}
    for _, r in ipairs(righe or {}) do
        local m = CRP.GetMoneta(r.moneta)
        voci[#voci + 1] = {
            id = 'r',
            icona = r.nero == 1 and '💵' or (r.verso == 'acquisto' and '⬆' or
                    (r.verso == 'vendita' and '⬇' or '➡')),
            titolo = ('%s %s %s'):format(r.verso, CRP.FormattaQuantita(r.quantita),
                                         m and m.simbolo or r.moneta),
            descrizione = ('Controvalore %s · %s%s')
                :format(AUREA.Util.Euro(r.controvalore), tostring(r.momento),
                        r.controparte and (' · controparte ' .. r.controparte) or ''),
            disattivata = true,
        }
    end
    if #voci == 0 then
        voci[1] = { id = 'x', icona = '🔎', titolo = 'Nessun movimento', disattivata = true }
    end

    exports.aurea_ui:Menu({
        titolo = ('Movimenti — %s'):format(nome),
        sottotitolo = 'Consultazione registrata agli atti',
        voci = voci,
    })
end

RegisterCommand('uif', function()
    local righe, motivo, soglia = AUREA.Callback.Attendi('crp:sospetti')
    if motivo then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔎', testo = motivo, durata = 10000 })
    end

    local voci = {}
    for _, r in ipairs(righe or {}) do
        local nome = ('%s %s'):format(r.nome or '?', r.cognome or '')
        voci[#voci + 1] = {
            id = r.citizenid,
            icona = r.sequestrato == 1 and '🔒' or (r.attenzione >= (soglia or 100) and '🟥' or '🟨'),
            titolo = nome,
            descrizione = ('Attenzione %d%s · ultima segnalazione %s')
                :format(r.attenzione,
                        r.sequestrato == 1 and ' · SEQUESTRATO' or '',
                        tostring(r.ultima_segnalazione or 'n.d.')),
        }
    end
    if #voci == 0 then
        voci[1] = { id = 'x', icona = '🔎', titolo = 'Nessuna segnalazione pendente', disattivata = true }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Unità di informazione finanziaria',
        sottotitolo = 'Portafogli con operazioni sospette',
        voci = voci,
    })
    if not scelta or scelta == 'x' then return end

    local nome = 'soggetto'
    local sequestrato = false
    for _, r in ipairs(righe) do
        if r.citizenid == scelta then
            nome = ('%s %s'):format(r.nome or '?', r.cognome or '')
            sequestrato = r.sequestrato == 1
        end
    end

    local azione = exports.aurea_ui:Menu({
        titolo = nome,
        voci = {
            { id = 'movimenti', icona = '📒', titolo = 'Consulta i movimenti' },
            { id = 'sequestra', icona = '🔒',
              titolo = sequestrato and 'Revoca il sequestro' or 'Disponi il sequestro',
              descrizione = sequestrato and 'Il portafoglio torna operativo.'
                  or 'Serve un fascicolo aperto. Il saldo confluisce all\'erario.' },
        },
    })
    if not azione then return end

    if azione == 'movimenti' then return movimentiDi(scelta, nome) end

    local ok, messaggio = AUREA.Callback.Attendi('crp:sequestra', scelta, sequestrato)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '🔒',
        titolo = 'Provvedimento', testo = messaggio, durata = 16000,
    })
end, false)

-- ---------------------------------------------------------------------------
--  Lo sportello fisico
-- ---------------------------------------------------------------------------
CreateThread(function()
    local b = CRP.Exchange.blip
    local blip = AddBlipForCoord(CRP.Exchange.coord)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.colore)
    SetBlipScale(blip, b.scala)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Exchange criptovalute')
    EndTextCommandSetBlipName(blip)

    exports.aurea_target:AggiungiZona('crp_exchange', CRP.Exchange.coord, CRP.Exchange.raggio, {
        { etichetta = 'Exchange criptovalute', icona = '🪙',
          azione = function() apriExchange(true) end },
    })
end)
