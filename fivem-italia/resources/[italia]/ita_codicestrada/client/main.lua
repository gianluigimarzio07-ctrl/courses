--[[
    AUREA · Codice della Strada (client)
    Sportelli Motorizzazione e Ufficio Verbali, pannello personale delle multe.
]]

local U = AUREA.Util
local puntiCorrenti = nil

-- ---------------------------------------------------------------------------
--  Blip degli sportelli
-- ---------------------------------------------------------------------------
CreateThread(function()
    local function creaBlip(cfg, coord)
        local blip = AddBlipForCoord(coord.x, coord.y, coord.z)
        SetBlipSprite(blip, cfg.sprite)
        SetBlipColour(blip, cfg.colore)
        SetBlipScale(blip, cfg.scala)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(cfg.nome)
        EndTextCommandSetBlipName(blip)
    end

    creaBlip(CDS.Motorizzazione.blip, CDS.Motorizzazione.coord)
    creaBlip(CDS.SportelloVerbali.blip, CDS.SportelloVerbali.coord)
end)

-- ---------------------------------------------------------------------------
--  Interazione con gli sportelli
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())

        local dMotorizzazione = #(coord - CDS.Motorizzazione.coord)
        local dVerbali = #(coord - CDS.SportelloVerbali.coord)

        if dMotorizzazione < 2.2 then
            attesa = 0
            exports.aurea_ui:Prompt(true, 'Motorizzazione Civile', 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuMotorizzazione()
            end
        elseif dVerbali < 2.2 then
            attesa = 0
            exports.aurea_ui:Prompt(true, 'Ufficio Verbali', 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuVerbali()
            end
        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Menu Motorizzazione
-- ---------------------------------------------------------------------------
function menuMotorizzazione()
    local patente = AUREA.Callback.Attendi('cds:miaPatente')

    local voci = {}

    if patente then
        voci[#voci + 1] = {
            id = 'stato', icona = '🪪',
            titolo = 'La tua patente',
            descrizione = ('N. %s · categorie %s%s'):format(
                patente.numero,
                patente.categorie ~= '' and patente.categorie or 'nessuna',
                patente.neopatentato == 1 and ' · neopatentato' or ''),
            valore = ('%d punti'):format(patente.punti),
        }

        if patente.punti < CDS.Regole.puntiMassimi then
            voci[#voci + 1] = {
                id = 'corso', icona = '📚',
                titolo = 'Corso di recupero punti',
                descrizione = ('Recuperi %d punti in %d minuti.'):format(CDS.Regole.puntiCorso, CDS.Regole.durataCorsoMinuti),
                valore = U.Euro(CDS.Regole.costoCorso),
            }
        end

        voci[#voci + 1] = {
            id = 'duplicato', icona = '🖨',
            titolo = 'Duplicato della patente',
            descrizione = 'Se hai perso il documento fisico.',
            valore = U.Euro(CDS.Motorizzazione.costoDuplicato),
        }
    end

    for _, cat in ipairs(CDS.Motorizzazione.categorie) do
        local posseduta = patente and patente.categorie:find(cat.id, 1, true) ~= nil
        voci[#voci + 1] = {
            id = 'esame:' .. cat.id,
            icona = posseduta and '✅' or '📝',
            titolo = ('Esame categoria %s'):format(cat.id),
            descrizione = posseduta and 'Già conseguita.' or cat.etichetta,
            valore = posseduta and '—' or U.Euro(cat.costo),
            disattivata = posseduta,
        }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Motorizzazione Civile',
        sottotitolo = 'Patenti, esami e recupero punti',
        voci = voci,
    })
    if not scelta then return end

    if scelta == 'corso' then
        local pagato = AUREA.Callback.Attendi('cds:iniziaCorso')
        if not pagato then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Iscrizione rifiutata', testo = pagato == false and 'Fondi insufficienti.' or 'Non idoneo al corso.' })
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Corso di recupero punti in aula...',
            durata = CDS.Regole.durataCorsoMinuti * 1000,
            annullabile = true,
            anim = { dizionario = 'timetable@ron@ig_3_couch', nome = 'base' },
            blocca = { movimento = true },
        })
        AUREA.Callback.Attendi('cds:concludiCorso', completato)

    elseif scelta == 'duplicato' then
        AUREA.Callback.Attendi('cds:duplicatoPatente')

    elseif type(scelta) == 'string' and scelta:sub(1, 6) == 'esame:' then
        local categoria = scelta:sub(7)
        esameGuida(categoria)
    end
end

--- Esame: quiz a risposta multipla, poi prova pratica come progresso
function esameGuida(categoria)
    local domande = AUREA.Callback.Attendi('cds:domandeEsame', categoria)
    if not domande then
        return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Esame non disponibile', testo = 'Requisiti non soddisfatti o fondi insufficienti.' })
    end

    local corrette = 0
    for i, d in ipairs(domande) do
        local voci = {}
        for n, risposta in ipairs(d.risposte) do
            voci[#voci + 1] = { id = n, icona = string.char(64 + n), titolo = risposta }
        end
        local scelta = exports.aurea_ui:Menu({
            titolo = ('Quiz teoria — domanda %d di %d'):format(i, #domande),
            sottotitolo = d.testo,
            voci = voci,
        })
        if scelta == d.corretta then corrette = corrette + 1 end
    end

    local soglia = math.ceil(#domande * 0.75)
    if corrette < soglia then
        AUREA.Callback.Attendi('cds:esitoEsame', categoria, false, corrette)
        return exports.aurea_ui:Notifica({
            tipo = 'errore', titolo = 'Esame teorico non superato',
            testo = ('Risposte corrette %d su %d (ne servivano %d).'):format(corrette, #domande, soglia),
            durata = 8000,
        })
    end

    exports.aurea_ui:Notifica({ tipo = 'successo', titolo = 'Teoria superata', testo = 'Ora la prova pratica.' })

    local pratica = exports.aurea_ui:Progresso({
        etichetta = 'Prova pratica con l\'esaminatore...',
        durata = 20000, annullabile = true, blocca = { movimento = true },
    })

    AUREA.Callback.Attendi('cds:esitoEsame', categoria, pratica, corrette)
end

-- ---------------------------------------------------------------------------
--  Menu Verbali
-- ---------------------------------------------------------------------------
function menuVerbali()
    local multe = AUREA.Callback.Attendi('cds:mieMulte') or {}

    if #multe == 0 then
        return exports.aurea_ui:Notifica({ tipo = 'successo', titolo = 'Nessun verbale pendente', testo = 'La tua posizione è regolare.' })
    end

    local voci = {}
    local totale = 0
    for _, m in ipairs(multe) do
        totale = totale + m.dovuto
        voci[#voci + 1] = {
            id = m.id,
            icona = m.scontato and '⏳' or '📄',
            titolo = ('%s — %s'):format(m.articolo, m.descrizione),
            descrizione = ('%s · %s%s'):format(
                m.luogo or 'luogo non indicato',
                m.emessa,
                m.punti_decurtati > 0 and (' · −%d punti'):format(m.punti_decurtati) or ''),
            valore = m.scontato
                and ('%s (−30%%)'):format(U.Euro(m.dovuto))
                or U.Euro(m.dovuto),
        }
    end

    table.insert(voci, 1, {
        id = 'tutte', icona = '💳',
        titolo = 'Paga tutti i verbali',
        descrizione = ('%d verbali aperti'):format(#multe),
        valore = U.Euro(totale),
    })

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Ufficio Verbali',
        sottotitolo = 'Sconto del 30% entro 5 giorni dalla notifica',
        voci = voci,
    })
    if not scelta then return end

    local ok, messaggio = AUREA.Callback.Attendi('cds:pagaMulte', scelta)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        titolo = ok and 'Pagamento eseguito' or 'Pagamento rifiutato',
        testo = messaggio,
        durata = 6000,
    })
end

-- ---------------------------------------------------------------------------
--  Comandi giocatore
-- ---------------------------------------------------------------------------
RegisterCommand('multe', function()
    CreateThread(function()
        local multe = AUREA.Callback.Attendi('cds:mieMulte') or {}
        if #multe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'successo', titolo = 'Nessun verbale', testo = 'Non hai multe pendenti.' })
        end
        local totale = 0
        for _, m in ipairs(multe) do totale = totale + m.dovuto end
        exports.aurea_ui:Notifica({
            tipo = 'avviso', titolo = ('%d verbali aperti'):format(#multe),
            testo = ('Totale dovuto %s. Sportello verbali per il pagamento.'):format(U.Euro(totale)),
            durata = 9000,
        })
    end)
end, false)

RegisterCommand('patente', function()
    CreateThread(function()
        local p = AUREA.Callback.Attendi('cds:miaPatente')
        if not p then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessuna patente', testo = 'Rivolgiti alla Motorizzazione Civile.' })
        end
        exports.aurea_ui:Notifica({
            tipo = p.punti <= 5 and 'errore' or (p.punti <= 10 and 'avviso' or 'info'),
            titolo = ('Patente %s'):format(p.numero),
            testo = ('Categorie: %s · %d punti · scadenza %s%s'):format(
                p.categorie ~= '' and p.categorie or 'nessuna',
                p.punti, p.scadenza,
                p.ritirata == 1 and ' · RITIRATA' or (p.sospesa and ' · SOSPESA' or '')),
            durata = 9000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Aggiornamenti dal server
-- ---------------------------------------------------------------------------
RegisterNetEvent('cds:puntiAggiornati', function(punti)
    puntiCorrenti = punti
    TriggerEvent('aurea:hud:patente', punti)
end)

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(3000)
        local p = AUREA.Callback.Attendi('cds:miaPatente')
        if p then
            puntiCorrenti = p.punti
            TriggerEvent('aurea:hud:patente', p.punti)
        end
    end)
end)

--- Verbale notificato in tempo reale (autovelox, ZTL, tutor)
RegisterNetEvent('cds:verbaleNotificato', function(v)
    exports.aurea_ui:Notifica({
        tipo = 'errore',
        icona = '📷',
        titolo = ('Verbale %s'):format(v.articolo),
        testo = ('%s · %s%s\nPaghi %s entro %d giorni, poi %s.'):format(
            v.descrizione, v.luogo,
            v.punti > 0 and (' · −' .. v.punti .. ' punti') or '',
            U.Euro(v.scontato), CDS.Regole.scontoGiorni, U.Euro(v.importo)),
        durata = 14000,
    })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)
