--[[
    AUREA · Banca (client)
]]

local U = AUREA.Util

CreateThread(function()
    for _, f in ipairs(BANCA.Filiali) do
        local blip = AddBlipForCoord(f.coord.x, f.coord.y, f.coord.z)
        SetBlipSprite(blip, 108)
        SetBlipColour(blip, 2)
        SetBlipScale(blip, 0.75)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(f.nome)
        EndTextCommandSetBlipName(blip)
    end
end)

-- ---------------------------------------------------------------------------
--  Interazione con filiali e sportelli automatici
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())
        local trovato = false

        for _, f in ipairs(BANCA.Filiali) do
            if #(coord - f.coord) < 2.2 then
                trovato = true attesa = 0
                exports.aurea_ui:Prompt(true, f.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    menuBanca(false)
                end
                break
            end
        end

        if not trovato then
            for _, s in ipairs(BANCA.Sportelli) do
                if #(coord - s) < 1.6 then
                    trovato = true attesa = 0
                    exports.aurea_ui:Prompt(true, 'Sportello automatico', 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        menuBanca(true)
                    end
                    break
                end
            end
        end

        if not trovato then exports.aurea_ui:Prompt(false) end
        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Menu
-- ---------------------------------------------------------------------------
function menuBanca(daSportello)
    local s = AUREA.Callback.Attendi('banca:situazione')
    if not s then return end

    local voci = {
        { id = 'preleva', icona = '💸', titolo = 'Preleva contanti',
          descrizione = daSportello and ('Gratuito fino a %s, poi 1,5%%'):format(U.Euro(BANCA.Commissioni.prelievoGratuitoFinoA)) or 'Nessuna commissione allo sportello.',
          valore = U.Euro(s.saldo) },
        { id = 'versa', icona = '💰', titolo = 'Versa contanti',
          descrizione = 'I versamenti rilevanti vengono segnalati.',
          valore = U.Euro(s.contanti) },
        { id = 'bonifico', icona = '🏦', titolo = 'Disponi un bonifico',
          descrizione = ('Commissione %s · istantaneo %s'):format(U.Euro(BANCA.Commissioni.bonifico), U.Euro(BANCA.Commissioni.bonificoIstantaneo)) },
        { id = 'movimenti', icona = '📊', titolo = 'Movimenti del conto',
          descrizione = ('Ultime %d operazioni'):format(#s.movimenti) },
    }

    if not daSportello then
        voci[#voci + 1] = { id = 'mutuo', icona = '📈', titolo = 'Richiedi un finanziamento',
            descrizione = ('Merito creditizio: %s · tasso %.2f%%'):format(s.meritoEtichetta, s.tasso) }
        if #s.mutui > 0 then
            voci[#voci + 1] = { id = 'mieiMutui', icona = '📋', titolo = 'I tuoi finanziamenti',
                descrizione = ('%d posizioni aperte'):format(#s.mutui) }
        end
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = daSportello and 'Sportello automatico' or 'Filiale bancaria',
        sottotitolo = ('IBAN %s · saldo %s'):format(s.iban, U.Euro(s.saldo)),
        voci = voci,
    })
    if not scelta then return end

    if scelta == 'preleva' or scelta == 'versa' then
        local valori = exports.aurea_ui:Dialogo(
            scelta == 'preleva' and 'Prelievo' or 'Versamento',
            { { etichetta = 'Importo in euro', tipo = 'text', segnaposto = '100.00', obbligatorio = true } })
        if not valori then return end

        local ok, messaggio = AUREA.Callback.Attendi(
            scelta == 'preleva' and 'banca:preleva' or 'banca:versa', valori[1], daSportello)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🏦', titolo = ok and 'Operazione eseguita' or 'Operazione rifiutata',
            testo = messaggio, durata = 8000,
        })

    elseif scelta == 'bonifico' then
        local valori = exports.aurea_ui:Dialogo('Bonifico bancario', {
            { etichetta = 'IBAN del beneficiario', tipo = 'text', segnaposto = 'IT00A0000000000000000000000', obbligatorio = true },
            { etichetta = 'Importo in euro', tipo = 'text', segnaposto = '250.00', obbligatorio = true },
            { etichetta = 'Causale', tipo = 'text', segnaposto = 'Es. saldo fattura 12/2026' },
            { etichetta = 'Modalità', tipo = 'select', opzioni = {
                { valore = 'ordinario', etichetta = ('Ordinario (%s)'):format(U.Euro(BANCA.Commissioni.bonifico)) },
                { valore = 'istantaneo', etichetta = ('Istantaneo (%s)'):format(U.Euro(BANCA.Commissioni.bonificoIstantaneo)) },
            } },
        })
        if not valori then return end

        local ok, messaggio = AUREA.Callback.Attendi('banca:bonifico', valori[1], valori[2], valori[3], valori[4] == 'istantaneo')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🏦', titolo = ok and 'Bonifico disposto' or 'Bonifico rifiutato',
            testo = messaggio, durata = 9000,
        })

    elseif scelta == 'movimenti' then
        local voci2 = {}
        for _, m in ipairs(s.movimenti) do
            voci2[#voci2 + 1] = {
                id = m.momento,
                icona = m.importo > 0 and '⬆' or '⬇',
                titolo = m.causale,
                descrizione = ('%s%s'):format(m.quando, m.controparte and (' · ' .. m.controparte) or ''),
                valore = ('%s%s'):format(m.importo > 0 and '+' or '', U.Euro(m.importo)),
            }
        end
        if #voci2 == 0 then
            voci2[1] = { id = 'v', icona = '—', titolo = 'Nessun movimento', disattivata = true }
        end
        exports.aurea_ui:Menu({ titolo = 'Estratto conto', sottotitolo = s.iban, voci = voci2 })

    elseif scelta == 'mutuo' then
        local valori = exports.aurea_ui:Dialogo('Richiesta di finanziamento', {
            { etichetta = 'Importo richiesto in euro', tipo = 'text', segnaposto = '15000.00', obbligatorio = true },
            { etichetta = 'Numero di rate', tipo = 'number', valore = 12, min = 3, max = BANCA.Mutui.rateMassime },
            { etichetta = 'Finalità', tipo = 'text', segnaposto = 'Es. acquisto veicolo' },
        })
        if not valori then return end

        local ok, messaggio = AUREA.Callback.Attendi('banca:richiediMutuo', valori[1], valori[2], valori[3])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '📈', titolo = ok and 'Finanziamento approvato' or 'Richiesta respinta',
            testo = messaggio, durata = 12000,
        })

    elseif scelta == 'mieiMutui' then
        local voci2 = {}
        for _, m in ipairs(s.mutui) do
            voci2[#voci2 + 1] = {
                id = m.id,
                icona = m.stato == 'attivo' and '📈' or '⚠',
                titolo = m.oggetto,
                descrizione = ('Rata %d di %d · prossima il %s · stato: %s'):format(
                    m.rate_pagate, m.rate_totali, m.prossimaIT, m.stato),
                valore = ('residuo %s'):format(U.Euro(m.residuo)),
            }
        end

        local id = exports.aurea_ui:Menu({
            titolo = 'I tuoi finanziamenti',
            sottotitolo = 'Seleziona per estinguere anticipatamente',
            voci = voci2,
        })
        if not id then return end

        local ok, messaggio = AUREA.Callback.Attendi('banca:estingui', id)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '📈', titolo = ok and 'Estinzione eseguita' or 'Estinzione rifiutata',
            testo = messaggio, durata = 9000,
        })
    end
end

RegisterCommand('iban', function()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('banca:situazione')
        if not s then return end
        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🏦', durata = 12000,
            titolo = 'Il tuo IBAN',
            testo = ('%s\nSaldo %s · merito creditizio: %s'):format(s.iban, U.Euro(s.saldo), s.meritoEtichetta),
        })
    end)
end, false)
