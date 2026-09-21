--[[
    AUREA · A.R.P.A. (client)

    Il tecnico sceglie la matrice e aspetta. Il numero che legge non lo
    ha scelto lui e non lo può cambiare: è la sola cosa che rende una
    misura una misura.
]]

local U = AUREA.Util

local function campiona()
    CreateThread(function()
        local voci = {}
        for id, m in pairs(ARPA.Matrici) do
            voci[#voci + 1] = {
                id = id, icona = '🔬', titolo = m.nome,
                descrizione = ('Limite %d %s · %s\nSanzione per superamento grave: %s')
                    :format(m.limite, m.unita, m.norma, U.Euro(m.sanzione)),
            }
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        local matrice = exports.aurea_ui:Menu({
            titolo = 'Campionamento',
            sottotitolo = 'Si misura quello che c\'è, non quello che dicono',
            voci = voci,
        })
        if not matrice then return end

        local m = ARPA.GetMatrice(matrice)

        local r = exports.aurea_ui:Dialogo('Verbale di campionamento', {
            { etichetta = 'A cosa si riferisce (cantiere, locale, sito). Vuoto = coordinate',
              tipo = 'text' },
        })
        if not r then return end

        if not exports.aurea_ui:Progresso({
            etichetta = ('Campionamento — %s'):format(m.nome),
            durata = m.durataSecondi * 1000, annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('arpa:campiona', matrice, r[1])
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔬',
                titolo = 'A.R.P.A.', testo = tostring(esito), durata = 12000 })
        end

        local tipo = esito.esito == 'conforme' and 'successo'
            or (esito.esito == 'grave' and 'errore' or 'avviso')

        local coda
        if esito.esito == 'conforme' then
            coda = 'Nei limiti. Nessun rilievo.'
        elseif esito.esito == 'grave' then
            coda = ('Superamento grave: sanzione %s e fascicolo.'):format(U.Euro(esito.sanzione))
        else
            coda = ('Prescrizione: %s\nHai %d minuti per rientrare, poi la sanzione raddoppia.')
                :format(esito.prescrizione, esito.minuti)
        end

        exports.aurea_ui:Notifica({
            tipo = tipo, icona = '🔬',
            titolo = ('%s — %d %s'):format(esito.matrice, esito.valore, esito.unita),
            testo = ('Limite di legge: %d %s (%s).\n%s')
                :format(esito.limite, esito.unita, esito.norma, coda),
            durata = 24000,
        })
    end)
end

local function prescrizioni()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('arpa:prescrizioni')
        if not s then return end

        local voci = {}

        for _, p in ipairs(s.mie) do
            local m = ARPA.GetMatrice(p.tipo)
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '⚠',
                titolo = ('A tuo carico — %s'):format(m and m.nome or p.tipo),
                descrizione = ('%s\n%s\nRestano %d minuti.')
                    :format(p.bersaglio, p.descrizione, math.max(0, p.minuti or 0)),
            }
        end

        for _, p in ipairs(s.tutte) do
            local m = ARPA.GetMatrice(p.tipo)
            voci[#voci + 1] = {
                id = s.tecnico and tostring(p.id) or 'x',
                disattivata = not s.tecnico,
                icona = '📋',
                titolo = ('%s — %s'):format(m and m.nome or p.tipo, p.bersaglio),
                descrizione = ('%s\nResponsabile: %s · restano %d minuti%s')
                    :format(p.descrizione, p.responsabile or 'non individuato',
                            math.max(0, p.minuti or 0),
                            s.tecnico and '\nVerifica l\'ottemperanza.' or ''),
            }
        end

        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '✅',
                        titolo = 'Nessuna prescrizione aperta' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Prescrizioni',
            sottotitolo = 'Rientrare costa meno che non rientrare',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Verifica di ottemperanza',
            durata = 25000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('arpa:verifica', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🔬',
            titolo = 'Verifica', testo = tostring(messaggio), durata = 18000 })
    end)
end

local function registro()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('arpa:registro')
        if not righe then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔬',
                titolo = 'A.R.P.A.', testo = 'Riservato ai tecnici in servizio.' })
        end

        local voci = {}
        for _, r in ipairs(righe) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true,
                icona = r.esito == 'conforme' and '✅' or (r.esito == 'grave' and '☣' or '⚠'),
                titolo = ('%s — %d %s'):format(r.nomeMatrice, r.valore, r.unita),
                descrizione = ('%s · limite %d\n%s · %d minuti fa%s')
                    :format(r.bersaglio, r.limite, r.tecnico or '—', r.minutiFa or 0,
                            (r.sanzione or 0) > 0 and ('\nSanzione ' .. U.Euro(r.sanzione)) or ''),
            }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '🔬', titolo = 'Nessun controllo registrato' }
        end

        exports.aurea_ui:Menu({ titolo = 'Registro dei campionamenti',
            sottotitolo = 'Gli ultimi venticinque', voci = voci })
    end)
end

local function sede()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = ARPA.Sede.nome,
            sottotitolo = 'Campionamenti, prescrizioni, registro',
            voci = {
                { id = 'prescrizioni', icona = '⚠', titolo = 'Prescrizioni aperte',
                  descrizione = 'Le tue, e quelle da verificare se sei un tecnico.' },
                { id = 'registro', icona = '📋', titolo = 'Registro dei campionamenti',
                  descrizione = 'Riservato ai tecnici.' },
            },
        })
        if scelta == 'prescrizioni' then return prescrizioni() end
        if scelta == 'registro' then return registro() end
    end)
end

RegisterCommand('arpa', sede, false)
RegisterCommand('campiona', campiona, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(ARPA.Sede.coord)
    SetBlipSprite(b, ARPA.Sede.blip.sprite)
    SetBlipColour(b, ARPA.Sede.blip.colore)
    SetBlipScale(b, ARPA.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('A.R.P.A.')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('arpa_sede', ARPA.Sede.coord, ARPA.Sede.raggio, {
        { etichetta = 'Dipartimento A.R.P.A.', icona = '🔬', azione = sede },
    })
end)
