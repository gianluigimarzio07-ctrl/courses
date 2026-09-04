--[[
    AUREA · Territori (server)

    Un territorio si conquista restandoci dentro con più uomini di chi lo
    difende. La contesa è pubblica: le forze dell'ordine la vedono e possono
    intervenire, e alza sensibilmente il calore di chi la promuove.
]]

local U = AUREA.Util
local contese = {}      -- [codice] = { attaccante, difensore, inizio, punti }

-- ---------------------------------------------------------------------------
--  Avvio di una contesa
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fam:contendi', function(src, rispondi, codice)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local org = Famiglie.Di(g)
    if not org then return rispondi(false, 'Non fai parte di alcuna organizzazione.') end
    if not FAM.GradoHaPermesso(g.organizzazione.grado, 'territori') then
        return rispondi(false, 'Il tuo grado non consente di aprire una contesa.')
    end

    local zona = FAM.Territori[codice]
    if not zona then return rispondi(false, 'Territorio non riconosciuto.') end
    if contese[codice] then return rispondi(false, 'Il territorio è già conteso in questo momento.') end

    local territorio = MySQL.single.await('SELECT * FROM territori WHERE codice = ?', { codice })
    if not territorio then return rispondi(false, 'Territorio non censito.') end
    if territorio.org_id == org.id then return rispondi(false, 'Il territorio è già vostro.') end

    if territorio.ultima_contesa then
        local trascorsi = os.time() - math.floor(territorio.ultima_contesa / 1000)
        if trascorsi < FAM.Contesa.raffreddamentoMinuti * 60 then
            return rispondi(false, ('Il territorio è ancora sotto tensione. Riprova fra %d minuti.'):format(
                math.ceil((FAM.Contesa.raffreddamentoMinuti * 60 - trascorsi) / 60)))
        end
    end

    -- Servono uomini sul posto
    local presenti = 0
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.organizzazione.tag == org.tag then
            local d = #(GetEntityCoords(GetPlayerPed(altro.source)) - zona.coord)
            if d <= zona.raggio then presenti = presenti + 1 end
        end
    end
    if presenti < FAM.Contesa.minimoPartecipanti then
        return rispondi(false, ('Servono almeno %d affiliati sul posto. Ne risultano %d.'):format(
            FAM.Contesa.minimoPartecipanti, presenti))
    end

    contese[codice] = {
        attaccanteId = org.id,
        attaccanteTag = org.tag,
        difensoreId = territorio.org_id,
        inizio = os.time(),
        punti = { [org.id] = 0 },
    }
    if territorio.org_id then contese[codice].punti[territorio.org_id] = territorio.controllo end

    Famiglie.Calore(org.tag, FAM.Calore.perAttivita.contesa, 'contesa territoriale')

    -- Tutti lo sanno: gli affiliati e le forze dell'ordine
    TriggerClientEvent('fam:contesaAvviata', -1, {
        codice = codice, nome = zona.nome,
        coord = { x = zona.coord.x, y = zona.coord.y, z = zona.coord.z },
        raggio = zona.raggio,
        minuti = FAM.Contesa.durataMinuti,
        attaccante = org.nome,
    })

    exports.aurea_ui:NotificaLavoro('carabinieri', {
        tipo = 'errore', icona = '🚨', durata = 16000,
        titolo = 'Tensione fra gruppi criminali',
        testo = ('Segnalati assembramenti sospetti in %s.'):format(zona.nome),
    }, true)

    AUREA.Log('giustizia', 'avviso', g, ('contesa avviata su %s da %s'):format(codice, org.tag))
    rispondi(true, ('Contesa avviata su %s. Tenete la zona per %d minuti.'):format(zona.nome, FAM.Contesa.durataMinuti))
end)

-- ---------------------------------------------------------------------------
--  Svolgimento
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)

        for codice, contesa in pairs(contese) do
            local zona = FAM.Territori[codice]

            -- Conteggio dei presenti per organizzazione
            local presenti = {}
            for _, g in pairs(AUREA.Giocatori) do
                if g.organizzazione.tag ~= 'nessuna' and not g.metadata.detenuto then
                    local d = #(GetEntityCoords(GetPlayerPed(g.source)) - zona.coord)
                    if d <= zona.raggio then
                        local org = Famiglie.Get(g.organizzazione.tag)
                        if org then presenti[org.id] = (presenti[org.id] or 0) + 1 end
                    end
                end
            end

            for orgId, quanti in pairs(presenti) do
                contesa.punti[orgId] = (contesa.punti[orgId] or 0) + quanti * FAM.Contesa.puntiPerMembro
            end

            local trascorsi = (os.time() - contesa.inizio) / 60

            if trascorsi >= FAM.Contesa.durataMinuti then
                -- Vince chi ha accumulato più punti
                local vincitore, migliore = nil, -1
                for orgId, punti in pairs(contesa.punti) do
                    if punti > migliore then vincitore, migliore = orgId, punti end
                end

                local controllo = math.floor(U.Clamp(migliore, 0, 100))

                if vincitore and controllo >= FAM.Contesa.sogliaConquista then
                    MySQL.update.await([[
                        UPDATE territori SET org_id = ?, controllo = ?, ultima_contesa = NOW() WHERE codice = ?
                    ]], { vincitore, controllo, codice })

                    local org = MySQL.single.await('SELECT tag, nome FROM organizzazioni WHERE id = ?', { vincitore })
                    TriggerClientEvent('fam:contesaConclusa', -1, {
                        codice = codice, nome = zona.nome,
                        vincitore = org and org.nome or 'ignoti', controllo = controllo,
                    })
                    AUREA.Log('giustizia', 'avviso', nil, ('%s conquistato da %s (%d%%)'):format(codice, org and org.tag or '?', controllo))
                else
                    MySQL.update.await('UPDATE territori SET ultima_contesa = NOW() WHERE codice = ?', { codice })
                    TriggerClientEvent('fam:contesaConclusa', -1, {
                        codice = codice, nome = zona.nome, vincitore = nil,
                    })
                end

                contese[codice] = nil
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Rendite dei territori
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(180000)
    while true do
        Wait(FAM.Contesa.minutiRendita * 60000)

        local territori = MySQL.query.await([[
            SELECT t.codice, t.nome, t.controllo, t.rendita_oraria, t.org_id, o.tag, o.calore
            FROM territori t JOIN organizzazioni o ON o.id = t.org_id
            WHERE t.org_id IS NOT NULL AND o.attiva = 1
        ]]) or {}

        for _, t in ipairs(territori) do
            local rendita = math.floor(t.rendita_oraria * (t.controllo / 100) * (FAM.Contesa.minutiRendita / 60))

            -- Il calore alto attira controlli e comprime i proventi
            if t.calore >= FAM.Calore.sogliaControlli then
                rendita = math.floor(rendita * FAM.Calore.penalitaRendita)
            end

            if rendita > 0 then
                MySQL.update('UPDATE organizzazioni SET cassa = cassa + ? WHERE id = ?', { rendita, t.org_id })
                Famiglie.Calore(t.tag, FAM.Calore.perAttivita.rendita, 'rendita territoriale')

                for _, g in pairs(AUREA.Giocatori) do
                    if g.organizzazione.tag == t.tag and FAM.GradoHaPermesso(g.organizzazione.grado, 'territori') then
                        TriggerClientEvent('aurea:ui:notifica', g.source, {
                            tipo = 'info', icona = '🩸', durata = 8000,
                            titolo = ('Rendita da %s'):format(t.nome),
                            testo = ('%s versati in cassa%s'):format(U.Euro(rendita),
                                t.calore >= FAM.Calore.sogliaControlli and ' (ridotta per l\'attenzione delle forze dell\'ordine)' or ''),
                        })
                    end
                end
            end

            -- Il controllo si erode se nessuno presidia
            MySQL.update('UPDATE territori SET controllo = GREATEST(0, controllo - 2) WHERE codice = ?', { t.codice })
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Mappa dei territori
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fam:territori', function(src, rispondi)
    local righe = MySQL.query.await([[
        SELECT t.codice, t.nome, t.controllo, t.rendita_oraria, o.nome AS organizzazione, o.colore
        FROM territori t LEFT JOIN organizzazioni o ON o.id = t.org_id
        ORDER BY t.rendita_oraria DESC
    ]]) or {}

    for _, t in ipairs(righe) do
        local zona = FAM.Territori[t.codice]
        if zona then
            t.coord = { x = zona.coord.x, y = zona.coord.y, z = zona.coord.z }
            t.raggio = zona.raggio
        end
        t.inContesa = contese[t.codice] ~= nil
    end

    rispondi(righe)
end)
