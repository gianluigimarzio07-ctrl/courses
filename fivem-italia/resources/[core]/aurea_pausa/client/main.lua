--[[
    AUREA · Menu di pausa (client)

    Sostituisce il menu ESC. L'uscita ha un'attesa: serve a evitare che
    si esca dal server per togliersi da una situazione scomoda.
]]

local U = AUREA.Util
local aperto = false

CreateThread(function()
    while true do
        Wait(0)

        if IsPauseMenuActive() and not aperto then
            SetPauseMenuActive(false)
            aperto = true
            apri()
        end
    end
end)

function apri()
    CreateThread(function()
        local pg = AUREA.GetPG()

        local voci = {}
        for _, v in ipairs(PAU.Voci) do
            voci[#voci + 1] = { id = v.id, icona = v.icona, titolo = v.nome }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Pausa',
            sottotitolo = pg and ('%s %s'):format(pg.nome or '', pg.cognome or '') or 'AUREA · Italia Roleplay',
            voci = voci,
        })
        aperto = false
        if not scelta then return end

        if scelta == 'personaggio' then return personaggio() end
        if scelta == 'comandi' then return comandi() end
        if scelta == 'esci' then return esci() end

        for _, v in ipairs(PAU.Voci) do
            if v.id == scelta and v.comando then
                return ExecuteCommand(v.comando)
            end
        end
    end)
end

function personaggio()
    CreateThread(function()
        local pg = AUREA.GetPG()
        if not pg then return end

        exports.aurea_ui:Menu({
            titolo = ('%s %s'):format(pg.nome or '', pg.cognome or ''),
            sottotitolo = pg.cf or '',
            voci = {
                { id = '_l', icona = '💼',
                  titolo = AUREA.EtichettaLavoro(pg.lavoro.nome, pg.lavoro.grado),
                  descrizione = pg.lavoro.servizio and 'In servizio' or 'Fuori servizio',
                  disattivata = true },
                { id = '_d', icona = '💶',
                  titolo = ('Contanti %s · conto %s')
                      :format(U.Euro(pg.contanti or 0), U.Euro(pg.banca or 0)),
                  disattivata = true },
                { id = '_o', icona = '🏛',
                  titolo = pg.organizzazione and pg.organizzazione.tag ~= 'nessuna'
                      and ('Organizzazione: %s'):format(pg.organizzazione.tag)
                      or 'Nessuna organizzazione',
                  disattivata = true },
                { id = '_r', icona = '📍',
                  titolo = ('Residenza: %s'):format(pg.residenza or 'non dichiarata'),
                  disattivata = true },
            },
        })
    end)
end

function comandi()
    CreateThread(function()
        local sezione = exports.aurea_ui:Menu({
            titolo = 'Comandi e tasti',
            voci = {
                { id = 'tasti', icona = '⌨', titolo = 'Tasti' },
                { id = 'comandi', icona = '💬', titolo = 'Comandi in chat' },
            },
        })
        if not sezione then return end

        local righe = {}
        if sezione == 'tasti' then
            for _, t in ipairs(PAU.Tasti) do
                righe[#righe + 1] = { id = '_' .. #righe, icona = '›',
                                      titolo = t.tasto, descrizione = t.cosa, disattivata = true }
            end
        else
            for _, c in ipairs(PAU.Comandi) do
                righe[#righe + 1] = { id = '_' .. #righe, icona = '›',
                                      titolo = c.comando, descrizione = c.cosa, disattivata = true }
            end
        end

        exports.aurea_ui:Menu({
            titolo = sezione == 'tasti' and 'Tasti' or 'Comandi', voci = righe,
        })
    end)
end

function esci()
    CreateThread(function()
        -- Uscire mentre si è ammanettati o in una situazione è scorretto:
        -- l'attesa più lunga rende la fuga inutile.
        local ok, legato = pcall(function()
            return exports.aurea_interazioni:SonoAmmanettato()
        end)
        local inAzione = ok and legato == true

        local attesa = inAzione and PAU.Regole.secondiUscitaInAzione or PAU.Regole.secondiUscita

        local conferma = exports.aurea_ui:Menu({
            titolo = 'Uscire dal server',
            sottotitolo = inAzione
                and ('Sei in una situazione: l\'uscita richiede %d secondi.'):format(attesa)
                or ('L\'uscita richiede %d secondi.'):format(attesa),
            voci = {
                { id = 'si', icona = '🚪', titolo = 'Sì, esco' },
                { id = 'no', icona = '↩', titolo = 'Resto' },
            },
        })
        if conferma ~= 'si' then return end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Uscita dal server...', durata = attesa * 1000, annullabile = true,
        })
        if not completato then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🚪', titolo = 'Uscita annullata',
            })
        end

        TriggerServerEvent('pau:esci')
    end)
end
