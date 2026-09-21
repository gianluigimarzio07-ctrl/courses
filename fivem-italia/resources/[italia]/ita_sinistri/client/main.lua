--[[
    AUREA · Sinistri stradali (client)

    Il rilevamento dell'urto sta qui perché solo il client sa quando due
    lamiere si toccano. Ma il client dice una cosa sola — "ho sbattuto
    contro quella targa" — e tutto il resto lo decide il server.
]]

local U = AUREA.Util

local ultimoUrto = 0

-- ---------------------------------------------------------------------------
--  Il modulo blu, da compilare sul posto
-- ---------------------------------------------------------------------------
local function apriConstatazione(sorgenteAltro, targaMia, targaAltra)
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = 'Constatazione amichevole',
            sottotitolo = sorgenteAltro and 'Il modulo blu vale solo se lo firmano tutti e due'
                                         or 'Nessuna controparte identificata',
            voci = {
                { id = 'compila', icona = '📋', titolo = 'Compila il modulo',
                  descrizione = sorgenteAltro
                      and 'Firmi tu adesso; poi deve firmare l\'altro. Se firmate insieme, si liquida in fretta.'
                      or 'Senza controparte il danno lo stima comunque un perito.' },
                { id = 'lascia', icona = '🚶', titolo = 'Lascia perdere',
                  descrizione = 'Niente modulo. Ognuno si tiene il suo danno.' },
            },
        })
        if scelta ~= 'compila' then return end

        local ok, messaggio = AUREA.Callback.Attendi('sin:apri', sorgenteAltro, targaMia, targaAltra)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📋',
            titolo = 'Sinistro', testo = tostring(messaggio), durata = 20000 })
    end)
end

-- ---------------------------------------------------------------------------
--  Rilevamento dell'urto
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(400)

        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped then
            local velocita = GetEntitySpeed(veicolo) * 3.6

            if velocita >= SIN.Rilevamento.velocitaMinima
               and HasEntityCollidedWithAnything(veicolo)
               and (GetGameTimer() - ultimoUrto) > SIN.Rilevamento.raffreddamentoSecondi * 1000 then

                -- C'è un altro veicolo con un conducente qui intorno?
                local coord = GetEntityCoords(veicolo)
                local sorgenteAltro, targaAltra

                for _, giocatore in ipairs(GetActivePlayers()) do
                    local altroPed = GetPlayerPed(giocatore)
                    if altroPed ~= ped then
                        local altroVeicolo = GetVehiclePedIsIn(altroPed, false)
                        if altroVeicolo ~= 0 and altroVeicolo ~= veicolo
                           and #(coord - GetEntityCoords(altroPed)) <= SIN.Rilevamento.distanza then
                            sorgenteAltro = GetPlayerServerId(giocatore)
                            targaAltra = (GetVehicleNumberPlateText(altroVeicolo) or ''):gsub('%s+$', '')
                            break
                        end
                    end
                end

                if sorgenteAltro then
                    ultimoUrto = GetGameTimer()
                    apriConstatazione(sorgenteAltro,
                        (GetVehicleNumberPlateText(veicolo) or ''):gsub('%s+$', ''), targaAltra)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Firmare
-- ---------------------------------------------------------------------------
local function miei()
    CreateThread(function()
        local righe, minutiLimite = AUREA.Callback.Attendi('sin:miei')
        righe = righe or {}

        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '📋',
                titolo = 'Sinistri', testo = 'Non hai sinistri aperti.', durata = 10000 })
        end

        local voci = {}
        for _, s in ipairs(righe) do
            local controparte = s.sonoA and (s.nome_b or 'nessuna controparte')
                                        or (s.nome_a or '—')
            local stato
            if s.stato == 'contestato' then
                stato = 'CONTESTATO: le versioni non coincidono, serve il perito.'
            elseif s.stato == 'firmato' then
                stato = 'Firmato da entrambi. In attesa di perizia.'
            elseif s.stato == 'in_perizia' then
                stato = ('Periziato: %s e %s. In attesa di liquidazione.')
                    :format(U.Euro(s.danni_a), U.Euro(s.danni_b))
            elseif s.miaFirma then
                stato = 'Hai firmato. Manca l\'altra firma.'
            elseif s.scaduto then
                stato = ('Scaduto: erano %d minuti.'):format(minutiLimite or 0)
            else
                stato = ('Da firmare — restano %d minuti.')
                    :format(math.max(0, (minutiLimite or 0) - (s.minuti or 0)))
            end

            voci[#voci + 1] = {
                id = (not s.miaFirma and not s.scaduto and s.stato ~= 'in_perizia')
                    and tostring(s.id) or 'x',
                disattivata = s.miaFirma or s.scaduto or s.stato == 'in_perizia',
                icona = s.stato == 'contestato' and '⚠' or '📋',
                titolo = ('N. %d — %s contro %s'):format(s.id, s.targa_a, s.targa_b or '—'),
                descrizione = ('Con: %s\n%s'):format(controparte, stato),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'I tuoi sinistri',
            sottotitolo = 'La constatazione vale se la firmano tutti e due',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        local vociResp = {}
        for _, r in ipairs(SIN.Responsabilita) do
            vociResp[#vociResp + 1] = {
                id = r.id, icona = '✎', titolo = r.nome,
                descrizione = 'Se l\'altro dichiara il contrario, il sinistro diventa contestato.',
            }
        end

        local responsabile = exports.aurea_ui:Menu({
            titolo = 'Chi ha torto',
            sottotitolo = 'Va detta la stessa cosa da tutti e due',
            voci = vociResp })
        if not responsabile then return end

        local ok, messaggio = AUREA.Callback.Attendi('sin:firma', tonumber(scelta), responsabile)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📋',
            titolo = 'Constatazione', testo = tostring(messaggio), durata = 20000 })
    end)
end

-- ---------------------------------------------------------------------------
--  L'agenzia
-- ---------------------------------------------------------------------------
local function agenzia()
    CreateThread(function()
        local coda = AUREA.Callback.Attendi('sin:coda')
        if not coda then
            return miei()
        end

        if #coda == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '📐',
                titolo = 'Agenzia', testo = 'Nessun sinistro in attesa di perizia.' })
        end

        local voci = {}
        for _, s in ipairs(coda) do
            voci[#voci + 1] = {
                id = tostring(s.id),
                icona = s.stato == 'contestato' and '⚠' or '📐',
                titolo = ('N. %d — %s contro %s'):format(s.id, s.targa_a, s.targa_b or '—'),
                descrizione = ('%s e %s\n%s · avvenuto %d minuti fa\nResponsabilità: %s')
                    :format(s.nome_a or '—', s.nome_b or 'nessuna controparte',
                            s.stato, s.minuti or 0,
                            s.responsabile == 'da_accertare' and 'da accertare' or s.responsabile),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Sinistri da periziare',
            sottotitolo = 'Il danno si misura sul mezzo, non sul racconto',
            voci = voci,
        })
        if not scelta then return end

        local r = exports.aurea_ui:Dialogo('Danni dichiarati dalle parti', {
            { etichetta = 'Dichiarato dal primo conducente (centesimi)', tipo = 'number' },
            { etichetta = 'Dichiarato dal secondo (centesimi)', tipo = 'number' },
        })
        if not r then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Rilievi e stima',
            durata = SIN.Perizia.durataSecondi * 1000, annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('sin:perizia',
            tonumber(scelta), tonumber(r[1]), tonumber(r[2]))

        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📐',
                titolo = 'Perizia', testo = tostring(esito), durata = 14000 })
        end

        exports.aurea_ui:Notifica({
            tipo = esito.frode and 'errore' or 'successo', icona = '📐',
            titolo = ('Perizia sul sinistro n. %d'):format(esito.id),
            testo = ('Danni accertati: %s e %s.%s%s%s')
                :format(U.Euro(esito.stimaA), U.Euro(esito.stimaB),
                        esito.totaleA and '\nPrimo veicolo antieconomico.' or '',
                        esito.totaleB and '\nSecondo veicolo antieconomico.' or '',
                        esito.frode and '\n\nDICHIARAZIONE FUORI SCALA: fascicolo aperto, art. 642 c.p.' or ''),
            durata = 24000 })

        -- Liquidazione, se ne ho il grado
        local liquida = exports.aurea_ui:Menu({
            titolo = 'Liquidare adesso?',
            sottotitolo = 'Serve il grado di perito capo',
            voci = {
                { id = 'si', icona = '💶', titolo = 'Liquida il sinistro',
                  descrizione = 'Paga chi ha torto, o la sua compagnia se ce l\'ha.' },
                { id = 'no', icona = '⏳', titolo = 'Rimanda',
                  descrizione = 'Resta in perizia.' },
            } })
        if liquida ~= 'si' then return end

        local okL, messaggio = AUREA.Callback.Attendi('sin:liquida', esito.id)
        exports.aurea_ui:Notifica({
            tipo = okL and 'successo' or 'errore', icona = '💶',
            titolo = 'Liquidazione', testo = tostring(messaggio), durata = 22000 })
    end)
end

RegisterCommand('sinistri', miei, false)
RegisterCommand('perizia', agenzia, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(SIN.Agenzia.coord)
    SetBlipSprite(b, SIN.Agenzia.blip.sprite)
    SetBlipColour(b, SIN.Agenzia.blip.colore)
    SetBlipScale(b, SIN.Agenzia.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Agenzia infortunistica')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('sin_agenzia', SIN.Agenzia.coord, SIN.Agenzia.raggio, {
        { etichetta = 'I tuoi sinistri', icona = '📋', azione = miei },
        { etichetta = 'Perizie in attesa', icona = '📐',
          lavoro = SIN.Lavoro, inServizio = true, azione = agenzia },
    })
end)
