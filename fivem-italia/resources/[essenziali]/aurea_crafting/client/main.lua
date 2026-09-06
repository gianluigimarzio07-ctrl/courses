--[[
    AUREA · Banchi da lavoro (client)
]]

local function apriSmontaggio()
    local righe, motivo = AUREA.Callback.Attendi('cra:smontabili')
    if motivo then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔩', testo = motivo })
    end

    local voci = {}
    for _, r in ipairs(righe or {}) do
        voci[#voci + 1] = {
            id = r.item, icona = '🔩',
            titolo = ('%s (ne hai %d)'):format(r.etichetta, r.quantita),
            descrizione = ('Recuperi: %s'):format(r.resa),
        }
    end
    if #voci == 0 then
        voci[1] = { id = 'x', icona = '🔩', titolo = 'Non hai niente di smontabile', disattivata = true }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Smontaggio',
        sottotitolo = ('Si recupera circa il %d%% del materiale'):format(math.floor(CRA.Smontaggio.resa * 100)),
        voci = voci,
    })
    if not scelta or scelta == 'x' then return end

    local ok, durata = AUREA.Callback.Attendi('cra:smonta', scelta)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔩', testo = durata, durata = 10000 })
    end

    if exports.aurea_ui:Progresso({
        etichetta = 'Smontaggio in corso...', durata = durata,
        anim = { dizionario = 'amb@world_human_hammering@male@base', nome = 'base' },
        blocca = { movimento = true },
    }) then
        local fatto, messaggio = AUREA.Callback.Attendi('cra:concludiSmontaggio', scelta)
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '🔩',
            titolo = fatto and 'Smontato' or 'Non smontato',
            testo = messaggio, durata = 11000,
        })
    end
end

local function apriBanco(banco)
    local ricette, motivo = AUREA.Callback.Attendi('cra:ricette', banco.id)
    if motivo then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔧', testo = motivo, durata = 10000 })
    end

    local voci = {}
    for _, r in ipairs(ricette or {}) do
        voci[#voci + 1] = {
            id = r.id,
            icona = r.illecito and '🕳' or '🔧',
            titolo = ('%dx %s'):format(r.quantita, r.etichetta),
            descrizione = r.fattibile
                and ('Serve: %s'):format(r.ingredienti)
                or ('Ti manca: %s'):format(r.mancanti),
            disattivata = not r.fattibile,
        }
    end

    table.insert(voci, { id = 'smonta', icona = '🔩', titolo = 'Smonta qualcosa',
                         descrizione = 'Riduci un oggetto nei suoi materiali.' })

    local scelta = exports.aurea_ui:Menu({
        titolo = banco.nome,
        sottotitolo = banco.illecito and 'Quello che si fa qui è tutto illecito.' or nil,
        voci = voci,
    })
    if not scelta then return end
    if scelta == 'smonta' then return apriSmontaggio() end

    local risposte = exports.aurea_ui:Dialogo('Quante volte?', {
        { etichetta = 'Ripetizioni', tipo = 'number', valore = 1,
          min = 1, max = CRA.Regole.massimoPerVolta, obbligatorio = true },
    })
    if not risposte then return end

    local ok, durata, volte = AUREA.Callback.Attendi('cra:avvia', scelta, tonumber(risposte[1]) or 1)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔧', testo = durata, durata = 13000 })
    end

    if exports.aurea_ui:Progresso({
        etichetta = 'Lavorazione in corso...', durata = durata, annullabile = true,
        anim = { dizionario = 'amb@world_human_hammering@male@base', nome = 'base' },
        blocca = { movimento = true },
    }) then
        local fatto, messaggio = AUREA.Callback.Attendi('cra:concludi', scelta, volte)
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '🔧',
            titolo = fatto and 'Prodotto' or 'Lavorazione fallita',
            testo = messaggio, durata = 11000,
        })
    else
        exports.aurea_ui:Notifica({ tipo = 'avviso', icona = '🔧',
            titolo = 'Interrotto', testo = 'Il materiale non è stato consumato.' })
    end
end

CreateThread(function()
    for _, b in ipairs(CRA.Banchi) do
        if b.blip then
            local blip = AddBlipForCoord(b.coord)
            SetBlipSprite(blip, b.blip.sprite)
            SetBlipColour(blip, b.blip.colore)
            SetBlipScale(blip, b.blip.scala)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(b.nome)
            EndTextCommandSetBlipName(blip)
        end

        exports.aurea_target:AggiungiZona('cra_' .. b.id, b.coord, b.raggio, {
            {
                etichetta = b.nome, icona = b.illecito and '🕳' or '🔧',
                lavoro = b.lavoro, lavori = b.lavori,
                azione = function() apriBanco(b) end,
            },
        })
    end
end)
