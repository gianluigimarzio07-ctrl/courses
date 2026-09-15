--[[
    AUREA · Intercettazioni (client)

    Tre schermate: chiedere un decreto, deciderlo, leggerlo. Il contenuto
    del brogliaccio arriva solo quando il server ha già verificato che
    spetti a chi lo chiede — e solo se sei in sala d'ascolto.
]]

local function chiediDecreto()
    CreateThread(function()
        -- L'elenco lo decide INT.Ammesso, non una lista scritta a mano qui:
        -- se domani cambia la soglia, questo menu cambia da solo.
        local reati = {}
        for codice, r in pairs(AUREA.Reati) do
            if INT.Ammesso(codice) then
                reati[#reati + 1] = { id = codice, icona = '⚖',
                    titolo = r.nome, descrizione = ('%s · gravità %d'):format(r.articolo, r.gravita),
                    ordine = -r.gravita }
            end
        end
        table.sort(reati, function(a, b)
            if a.ordine ~= b.ordine then return a.ordine < b.ordine end
            return a.titolo < b.titolo
        end)

        local reato = exports.aurea_ui:Menu({
            titolo = 'Richiesta di intercettazione',
            sottotitolo = 'Per quale ipotesi di reato',
            voci = reati,
        })
        if not reato then return end

        local r = exports.aurea_ui:Dialogo('Decreto di intercettazione', {
            { etichetta = 'Utenza da sottoporre ad ascolto', tipo = 'text',
              segnaposto = 'numero di telefono', obbligatorio = true },
            { etichetta = 'Motivazione (perché è indispensabile)', tipo = 'text',
              segnaposto = 'almeno quindici caratteri', obbligatorio = true },
        })
        if not r or not r[1] then return end

        local urgenza = exports.aurea_ui:Menu({
            titolo = 'Come procedere',
            sottotitolo = 'Il giudice può non essere disponibile',
            voci = {
                { id = 'no', icona = '⚖', titolo = 'Chiedi il decreto al giudice',
                  descrizione = 'L\'ascolto parte solo quando lui firma. È la strada sicura.' },
                { id = 'si', icona = '⚠', titolo = 'Procedi d\'urgenza (art. 267 c.2 c.p.p.)',
                  descrizione = ('Ascolti subito, ma senza convalida entro %d minuti tutto è inutilizzabile.')
                      :format(INT.Decreto.convalidaMinuti) },
            },
        })
        if not urgenza then return end

        local ok, messaggio = AUREA.Callback.Attendi('int:chiedi', r[1], reato, r[2], urgenza == 'si')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎧',
            titolo = 'Procura', testo = tostring(messaggio), durata = 24000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Il brogliaccio
-- ---------------------------------------------------------------------------
local function leggiBrogliaccio(id)
    CreateThread(function()
        local b, errore = AUREA.Callback.Attendi('int:brogliaccio', id)
        if not b then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🎧', titolo = 'Brogliaccio',
                testo = errore or 'Non disponibile.', durata = 12000 })
        end

        local voci = {}
        if not b.utilizzabile then
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '🗑',
                titolo = 'Materiale non utilizzabile',
                descrizione = 'Manca la convalida, o il decreto è decaduto. Si può leggere, non si può usare.' }
        end

        for _, r in ipairs(b.righe) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true,
                icona = r.tipo == 'sms' and '💬' or '📞',
                titolo = ('%s — %s'):format(r.quando, r.destinatario),
                descrizione = r.tipo == 'sms' and r.contenuto
                    or ('%s · durata %d secondi'):format(r.contenuto, r.secondi or 0),
            }
        end

        if #b.righe == 0 then
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '🔇',
                titolo = 'Nessun traffico registrato',
                descrizione = 'Da quando il decreto è attivo, l\'utenza non ha comunicato.' }
        end

        exports.aurea_ui:Menu({
            titolo = ('Brogliaccio — utenza %s'):format(b.numero),
            sottotitolo = INT.Stati[b.stato] and INT.Stati[b.stato].nome or b.stato,
            voci = voci,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Sala d'ascolto
-- ---------------------------------------------------------------------------
local function sala()
    CreateThread(function()
        local miei = AUREA.Callback.Attendi('int:miei') or {}
        local voci = {}

        for _, d in ipairs(miei) do
            local s = INT.Stati[d.stato] or { icona = '?', nome = d.stato }
            voci[#voci + 1] = {
                id = tostring(d.id), icona = s.icona,
                titolo = ('Utenza %s — %s'):format(d.numero, d.nomeReato),
                descrizione = ('%s · %d intercettazioni raccolte · richiesta da %s')
                    :format(s.nome, d.pezzi, d.richiedente_nome),
            }
        end

        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '🎧',
                titolo = 'Nessun decreto a tuo nome' }
        end
        voci[#voci + 1] = { id = 'nuovo', icona = '➕', titolo = 'Chiedi un nuovo decreto' }

        local scelta = exports.aurea_ui:Menu({
            titolo = INT.Sala.nome,
            sottotitolo = 'Il brogliaccio si legge solo qui',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end
        if scelta == 'nuovo' then return chiediDecreto() end

        leggiBrogliaccio(tonumber(scelta))
    end)
end

-- ---------------------------------------------------------------------------
--  Il giudice
-- ---------------------------------------------------------------------------
RegisterCommand('decreti', function()
    CreateThread(function()
        local pendenti = AUREA.Callback.Attendi('int:pendenti') or {}
        if #pendenti == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '⚖', titolo = 'Procura',
                testo = 'Nessuna richiesta in attesa.' })
        end

        local voci = {}
        for _, d in ipairs(pendenti) do
            voci[#voci + 1] = {
                id = tostring(d.id),
                icona = d.stato == 'urgenza' and '⚠' or '⏳',
                titolo = ('Utenza %s — %s'):format(d.numero, d.bersaglio),
                descrizione = ('%s (%s) · chiesta da %s%s\n%s'):format(
                    d.reato, d.articolo, d.richiedente,
                    d.minutiConvalida and (' · CONVALIDA ENTRO %d MIN'):format(d.minutiConvalida) or '',
                    d.motivazione or ''),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Richieste di intercettazione',
            sottotitolo = 'Gravi indizi e indispensabilità, art. 267 c.p.p.',
            voci = voci,
        })
        if not scelta then return end

        local esito = exports.aurea_ui:Menu({
            titolo = 'Decisione',
            voci = {
                { id = 'si', icona = '✔', titolo = 'Autorizza' },
                { id = 'no', icona = '✖', titolo = 'Respingi' },
            },
        })
        if not esito then return end

        local ok, messaggio = AUREA.Callback.Attendi('int:decidi', tonumber(scelta), esito == 'si')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⚖',
            titolo = 'Procura', testo = tostring(messaggio), durata = 14000,
        })
    end)
end, false)

RegisterCommand('intercettazioni', sala, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(INT.Sala.coord)
    SetBlipSprite(b, INT.Sala.blip.sprite)
    SetBlipColour(b, INT.Sala.blip.colore)
    SetBlipScale(b, INT.Sala.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(INT.Sala.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('int_sala', INT.Sala.coord, INT.Sala.raggio, {
        { etichetta = 'Sala d\'ascolto', icona = '🎧',
          lavori = { 'carabinieri', 'polizia', 'guardia_finanza', 'giudice' },
          azione = sala },
    })
end)
