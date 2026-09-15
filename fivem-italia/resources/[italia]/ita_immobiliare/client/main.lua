--[[
    AUREA · Agenzia immobiliare (client)

    La vetrina, le proposte e le visite. Il giudizio sul prezzo — congruo,
    alto, basso — arriva dal server insieme all'annuncio: è l'agenzia che
    stima, non il client che tira a indovinare.
]]

local function tono(giudizio)
    if giudizio == 'alto' then return '🔺' end
    if giudizio == 'basso' then return '🔻' end
    return '🏠'
end

local function apriVetrina(perVisita)
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('imm:vetrina') or {}
        local voci = {}

        for _, a in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(a.id), icona = tono(a.giudizio),
                titolo = ('%s — %s'):format(a.nome, AUREA.Util.Euro(a.prezzo)),
                descrizione = ('%s · %s · di %s\n%s%s'):format(
                    a.tipo, a.indirizzo, a.venditore or '—', a.spiegazione,
                    (a.nota or '') ~= '' and ('\n"%s"'):format(a.nota) or ''),
            }
        end

        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '🏠',
                titolo = 'Vetrina vuota', descrizione = 'Nessun immobile in vendita fra privati.' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = perVisita and 'Quale immobile far vedere' or 'Vetrina',
            sottotitolo = perVisita and 'Il visitatore deve essere con te'
                or 'Prezzi fatti dai proprietari, giudizio dell\'agenzia',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        if perVisita then return perVisita(tonumber(scelta)) end

        local r = exports.aurea_ui:Dialogo('Proposta d\'acquisto', {
            { etichetta = 'La tua offerta in euro', tipo = 'number', min = 1, obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('imm:proponi', tonumber(scelta), tonumber(r[1]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏠',
            titolo = 'Agenzia', testo = tostring(messaggio), durata = 18000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Il proprietario
-- ---------------------------------------------------------------------------
local function pubblica()
    CreateThread(function()
        local miei = AUREA.Callback.Attendi('not:vendibili') or {}
        local voci = {}
        for _, i in ipairs(miei) do
            if not i.perProcura then
                voci[#voci + 1] = { id = tostring(i.id), icona = '🏠', titolo = i.nome,
                    descrizione = ('%s · %s · valore di listino %s'):format(
                        i.tipo, i.indirizzo, AUREA.Util.Euro(i.prezzo)),
                    disattivata = i.inquilino ~= nil }
            end
        end
        if #voci == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🏠',
                titolo = 'Nessun immobile', testo = 'Non possiedi immobili da mettere in vendita.' })
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Conferisci l\'incarico',
            sottotitolo = ('Diritti %s · resta in vetrina %d minuti')
                :format(AUREA.Util.Euro(IMM.Annunci.dirittiPubblicazione), IMM.Annunci.durataMinuti),
            voci = voci,
        })
        if not scelta then return end

        local r = exports.aurea_ui:Dialogo('Annuncio', {
            { etichetta = 'Prezzo richiesto in euro', tipo = 'number', min = 1, obbligatorio = true },
            { etichetta = 'Nota per chi guarda', tipo = 'text', segnaposto = 'facoltativa' },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('imm:pubblica', tonumber(scelta), tonumber(r[1]), r[2])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏠',
            titolo = 'Agenzia', testo = tostring(messaggio), durata = 18000,
        })
    end)
end

RegisterCommand('proposte', function()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('imm:proposte') or {}
        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🏠',
                titolo = 'Proposte', testo = 'Nessuna proposta sui tuoi immobili.' })
        end

        local voci = {}
        for _, p in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(p.id), icona = '💰',
                titolo = ('%s — %s'):format(p.immobile, AUREA.Util.Euro(p.offerta)),
                descrizione = ('da %s · chiedevi %s · caparra versata %s'):format(
                    p.compratore or '—', AUREA.Util.Euro(p.richiesto), AUREA.Util.Euro(p.caparra)),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Proposte ricevute',
            sottotitolo = 'Accettare conclude l\'affare: la provvigione è dovuta',
            voci = voci,
        })
        if not scelta then return end

        local esito = exports.aurea_ui:Menu({
            titolo = 'Rispondi',
            voci = {
                { id = 'si', icona = '✔', titolo = 'Accetto',
                  descrizione = ('Provvigione %d%% a testa, poi si va dal notaio.')
                      :format(math.floor(IMM.Provvigione.quota * 100)) },
                { id = 'no', icona = '✖', titolo = 'Rifiuto', descrizione = 'La caparra torna al proponente.' },
            },
        })
        if not esito then return end

        local ok, messaggio = AUREA.Callback.Attendi('imm:rispondi', tonumber(scelta), esito == 'si')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏠',
            titolo = 'Agenzia', testo = tostring(messaggio), durata = 20000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  L'agente
-- ---------------------------------------------------------------------------
local function vicini(titolo)
    local elenco, ped = {}, PlayerPedId()
    local coord = GetEntityCoords(ped)
    for _, p in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(p)
        if altro ~= ped and #(coord - GetEntityCoords(altro)) <= IMM.Visite.distanzaAgente then
            elenco[#elenco + 1] = { id = tostring(GetPlayerServerId(p)), icona = '👤',
                titolo = ('ID %d'):format(GetPlayerServerId(p)) }
        end
    end
    if #elenco == 0 then
        exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔑', titolo = titolo,
            testo = 'Non c\'è nessuno abbastanza vicino.' })
        return nil
    end
    return exports.aurea_ui:Menu({ titolo = titolo, voci = elenco })
end

local function stima()
    apriVetrina(function(idAnnuncio)
        CreateThread(function()
            -- L'annuncio porta con sé l'immobile: la stima si chiede su
            -- quello, non su un id che il client si inventa.
            local righe = AUREA.Callback.Attendi('imm:vetrina') or {}
            local immobileId
            for _, a in ipairs(righe) do
                if a.id == idAnnuncio then immobileId = a.immobile_id end
            end
            if not immobileId then return end

            local v = AUREA.Callback.Attendi('imm:stima', immobileId)
            if not v then
                return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📐',
                    titolo = 'Stima', testo = 'Il tuo grado non abilita alla stima.' })
            end

            exports.aurea_ui:Menu({
                titolo = ('Stima — %s'):format(v.nome),
                sottotitolo = 'Valori di riferimento',
                voci = {
                    { id = 'x', disattivata = true, icona = '🏷', titolo = 'Valore di listino',
                      descrizione = AUREA.Util.Euro(v.listino) },
                    { id = 'x', disattivata = true, icona = '📊', titolo = 'Media dei rogiti su questo tipo',
                      descrizione = v.mercato and AUREA.Util.Euro(v.mercato)
                          or 'Nessun atto registrato: il mercato non ha ancora detto niente.' },
                    { id = 'x', disattivata = true, icona = '🧾', titolo = 'Rendita catastale',
                      descrizione = AUREA.Util.Euro(v.rendita or 0) },
                },
            })
        end)
    end)
end

local function accompagna()
    apriVetrina(function(idAnnuncio)
        CreateThread(function()
            local chi = vicini('Chi accompagni')
            if not chi then return end
            local ok, messaggio = AUREA.Callback.Attendi('imm:visita', idAnnuncio, tonumber(chi))
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🔑',
                titolo = 'Visita', testo = tostring(messaggio), durata = 14000,
            })
        end)
    end)
end

-- ---------------------------------------------------------------------------
--  Sportello
-- ---------------------------------------------------------------------------
local function sportello()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = IMM.Agenzia.nome,
            sottotitolo = 'Vendita fra privati, con la mediazione',
            voci = {
                { id = 'vetrina', icona = '🏠', titolo = 'Guarda la vetrina',
                  descrizione = 'E fai una proposta: serve una caparra del 5%.' },
                { id = 'pubblica', icona = '📢', titolo = 'Metti in vendita un tuo immobile' },
                { id = 'proposte', icona = '💰', titolo = 'Le proposte che hai ricevuto' },
                { id = 'visita', icona = '🔑', titolo = 'Accompagna una visita',
                  descrizione = 'Solo per gli agenti abilitati.' },
                { id = 'stima', icona = '📐', titolo = 'Stima un immobile in vetrina',
                  descrizione = 'Listino, media dei rogiti e rendita catastale. Agenti senior.' },
            },
        })

        if scelta == 'vetrina' then return apriVetrina(nil) end
        if scelta == 'pubblica' then return pubblica() end
        if scelta == 'visita' then return accompagna() end
        if scelta == 'stima' then return stima() end
        if scelta == 'proposte' then return ExecuteCommand('proposte') end
    end)
end

RegisterCommand('immobiliare', sportello, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(IMM.Agenzia.coord)
    SetBlipSprite(b, IMM.Agenzia.blip.sprite)
    SetBlipColour(b, IMM.Agenzia.blip.colore)
    SetBlipScale(b, IMM.Agenzia.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(IMM.Agenzia.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('imm_agenzia', IMM.Agenzia.coord, IMM.Agenzia.raggio, {
        { etichetta = 'Agenzia immobiliare', icona = '🏠', azione = sportello },
    })
end)
