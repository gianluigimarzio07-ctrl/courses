--[[
    AUREA · Fisco (client)
    Sportelli Agenzia delle Entrate e Camera di Commercio.
]]

local U = AUREA.Util

CreateThread(function()
    for _, s in pairs(FISCO.Sportelli) do
        local blip = AddBlipForCoord(s.coord.x, s.coord.y, s.coord.z)
        SetBlipSprite(blip, s.blip.sprite)
        SetBlipColour(blip, s.blip.colore)
        SetBlipScale(blip, s.blip.scala)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(s.nome)
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())

        if #(coord - FISCO.Sportelli.agenziaEntrate.coord) < 2.5 then
            attesa = 0
            exports.aurea_ui:Prompt(true, 'Agenzia delle Entrate', 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuAgenziaEntrate()
            end
        elseif #(coord - FISCO.Sportelli.cameraCommercio.coord) < 2.5 then
            attesa = 0
            exports.aurea_ui:Prompt(true, 'Camera di Commercio', 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuCameraCommercio()
            end
        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Agenzia delle Entrate
-- ---------------------------------------------------------------------------
function menuAgenziaEntrate()
    local pos = AUREA.Callback.Attendi('fisco:posizione')
    if not pos then return end

    local voci = {}

    if pos.totaleTributi > 0 then
        voci[#voci + 1] = {
            id = 'paga_tutti', icona = '💳',
            titolo = 'Versa tutti i tributi',
            descrizione = ('%d posizioni aperte'):format(#pos.tributi),
            valore = U.Euro(pos.totaleTributi),
        }
        for _, t in ipairs(pos.tributi) do
            voci[#voci + 1] = {
                id = 'trib:' .. t.id,
                icona = t.stato == 'cartella' and '📮' or '🧾',
                titolo = ('%s — %s'):format(t.tipo:upper(), t.periodo),
                descrizione = ('Scadenza %s%s'):format(t.scadenzaIT,
                    t.mora > 0 and (' · mora ' .. U.Euro(t.mora)) or ''),
                valore = U.Euro(t.dovuto),
            }
        end
    else
        voci[#voci + 1] = { id = 'nulla', icona = '✅', titolo = 'Posizione regolare', descrizione = 'Nessun tributo da versare.', disattivata = true }
    end

    for _, f in ipairs(pos.fatture) do
        voci[#voci + 1] = {
            id = 'fatt:' .. f.id, icona = '📄',
            titolo = ('Fattura %s — %s'):format(f.numero, f.ragione_sociale or 'privato'),
            descrizione = ('%s · imponibile %s + IVA %d%%'):format(f.descrizione, U.Euro(f.imponibile), f.aliquota),
            valore = U.Euro(f.totale),
        }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Agenzia delle Entrate',
        sottotitolo = ('Cassetto fiscale · CF %s'):format(pos.cf),
        voci = voci,
    })
    if not scelta or scelta == 'nulla' then return end

    local ok, messaggio
    if scelta == 'paga_tutti' then
        ok, messaggio = AUREA.Callback.Attendi('fisco:paga', 'tutti')
    elseif scelta:sub(1, 5) == 'trib:' then
        ok, messaggio = AUREA.Callback.Attendi('fisco:paga', scelta:sub(6))
    elseif scelta:sub(1, 5) == 'fatt:' then
        ok, messaggio = AUREA.Callback.Attendi('fisco:pagaFattura', tonumber(scelta:sub(6)))
    end

    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        titolo = ok and 'Versamento eseguito' or 'Versamento rifiutato',
        testo = messaggio, durata = 9000,
    })
end

-- ---------------------------------------------------------------------------
--  Camera di Commercio
-- ---------------------------------------------------------------------------
function menuCameraCommercio()
    local imprese = AUREA.Callback.Attendi('fisco:mieImprese') or {}

    local voci = {
        { id = 'apri', icona = '🏢', titolo = 'Apri una partita IVA', descrizione = 'Costituisci una nuova impresa.' },
    }

    for _, i in ipairs(imprese) do
        voci[#voci + 1] = {
            id = 'imp:' .. i.id,
            icona = i.eTitolare == 1 and '👑' or '👤',
            titolo = i.ragione_sociale,
            descrizione = ('P.IVA %s · %s · %s'):format(i.piva, i.formaEtichetta, i.regimeEtichetta),
            valore = i.eTitolare == 1 and ('cassa ' .. U.Euro(i.cassa)) or (i.mansione or 'dipendente'),
        }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Camera di Commercio',
        sottotitolo = 'Registro delle imprese',
        voci = voci,
    })
    if not scelta then return end

    if scelta == 'apri' then return apriImpresa() end
    if scelta:sub(1, 4) == 'imp:' then
        local id = tonumber(scelta:sub(5))
        for _, i in ipairs(imprese) do
            if i.id == id then return gestisciImpresa(i) end
        end
    end
end

function apriImpresa()
    local formeVoci = {}
    for id, f in pairs(FISCO.Forme) do
        formeVoci[#formeVoci + 1] = {
            id = id, icona = '🏛', titolo = f.etichetta,
            descrizione = ('Fino a %d dipendenti · capitale minimo %s'):format(f.dipendenti, U.Euro(f.capitaleMinimo)),
            valore = ('diritti %s'):format(U.Euro(f.costo)),
            ordine = f.costo,
        }
    end
    table.sort(formeVoci, function(a, b) return a.ordine < b.ordine end)

    local forma = exports.aurea_ui:Menu({
        titolo = 'Forma societaria',
        sottotitolo = 'Determina responsabilità, capacità e costi',
        voci = formeVoci,
    })
    if not forma then return end

    local settoriVoci = {}
    for _, s in ipairs(FISCO.Settori) do
        settoriVoci[#settoriVoci + 1] = {
            id = s.id, icona = '🧭', titolo = s.etichetta,
            descrizione = ('IVA sulle vendite: %d%%'):format(s.ivaVendita),
        }
    end

    local settore = exports.aurea_ui:Menu({
        titolo = 'Settore di attività',
        sottotitolo = 'Codice ATECO semplificato',
        voci = settoriVoci,
    })
    if not settore then return end

    local regime = exports.aurea_ui:Menu({
        titolo = 'Regime fiscale',
        sottotitolo = 'Puoi cambiarlo in seguito solo superando i limiti',
        voci = {
            { id = 'forfettario', icona = '📉', titolo = FISCO.Regimi.forfettario.etichetta, descrizione = FISCO.Regimi.forfettario.descrizione },
            { id = 'ordinario',   icona = '📊', titolo = FISCO.Regimi.ordinario.etichetta,   descrizione = FISCO.Regimi.ordinario.descrizione },
        },
    })
    if not regime then return end

    local valori = exports.aurea_ui:Dialogo('Dati dell\'impresa', {
        { etichetta = 'Ragione sociale', tipo = 'text', segnaposto = 'Es. Trattoria da Nonna Rosa', obbligatorio = true },
        { etichetta = 'Sede (indirizzo)', tipo = 'text', segnaposto = 'Es. Vespucci Blvd 44' },
    })
    if not valori then return end

    local impresa, errore = AUREA.Callback.Attendi('fisco:apriImpresa', {
        forma = forma, settore = settore, regime = regime,
        ragioneSociale = valori[1], sede = valori[2],
    })

    if not impresa then
        return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Costituzione rifiutata', testo = errore, durata = 10000 })
    end

    exports.aurea_ui:Notifica({
        tipo = 'successo', icona = '🏢', durata = 14000,
        titolo = ('%s costituita'):format(impresa.ragione),
        testo = ('P.IVA %s · IBAN aziendale %s. Trovi la visura nell\'inventario.'):format(impresa.piva, impresa.iban),
    })
end

function gestisciImpresa(impresa)
    local titolare = impresa.eTitolare == 1

    local voci = {
        { id = 'fattura', icona = '🧾', titolo = 'Emetti fattura', descrizione = 'Serve il codice fiscale del cliente.' },
        { id = 'organico', icona = '👥', titolo = 'Organico',
          descrizione = ('%d dipendenti su %d posti'):format(#(impresa.dipendenti or {}), impresa.dipendenti_max) },
    }

    if titolare then
        voci[#voci + 1] = { id = 'assumi', icona = '➕', titolo = 'Assumi un dipendente', descrizione = 'Contratto con stipendio periodico.' }
        voci[#voci + 1] = { id = 'ricapitalizza', icona = '💰', titolo = 'Versa in cassa', descrizione = 'Trasferisci denaro dal tuo conto alla cassa.' }
        voci[#voci + 1] = { id = 'preleva', icona = '💸', titolo = 'Preleva utili', descrizione = 'Trasferisci dalla cassa al tuo conto.' }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = impresa.ragione_sociale,
        sottotitolo = ('P.IVA %s · cassa %s · IVA a debito %s'):format(
            impresa.piva, U.Euro(impresa.cassa), U.Euro(impresa.iva_a_debito)),
        voci = voci,
    })
    if not scelta then return end

    if scelta == 'fattura' then
        local valori = exports.aurea_ui:Dialogo('Nuova fattura', {
            { etichetta = 'Codice fiscale del cliente', tipo = 'text', segnaposto = 'RSSMRA80A01H501U', obbligatorio = true },
            { etichetta = 'Descrizione della prestazione', tipo = 'text', segnaposto = 'Es. Riparazione impianto frenante', obbligatorio = true },
            { etichetta = 'Imponibile in euro', tipo = 'text', segnaposto = '250.00', obbligatorio = true },
        })
        if not valori then return end

        local ok, messaggio = AUREA.Callback.Attendi('fisco:emettiFattura', impresa.id, valori[1], valori[2], valori[3])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            titolo = ok and 'Fattura emessa' or 'Emissione rifiutata',
            testo = messaggio, durata = 9000,
        })

    elseif scelta == 'assumi' then
        local valori = exports.aurea_ui:Dialogo('Assunzione', {
            { etichetta = 'Codice fiscale del dipendente', tipo = 'text', obbligatorio = true },
            { etichetta = 'Mansione', tipo = 'text', segnaposto = 'Es. cameriere' },
            { etichetta = 'Stipendio per ciclo di paga (euro)', tipo = 'text', segnaposto = '180.00', obbligatorio = true },
        })
        if not valori then return end

        local ok, messaggio = AUREA.Callback.Attendi('fisco:assumi', impresa.id, valori[1], valori[2], valori[3])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            titolo = ok and 'Assunzione registrata' or 'Assunzione rifiutata',
            testo = messaggio, durata = 9000,
        })

    elseif scelta == 'organico' then
        local voci2 = {}
        for _, d in ipairs(impresa.dipendenti or {}) do
            voci2[#voci2 + 1] = {
                id = d.citizenid, icona = '👤',
                titolo = ('%s %s'):format(d.nome, d.cognome),
                descrizione = d.mansione,
                valore = U.Euro(d.stipendio),
            }
        end
        if #voci2 == 0 then
            voci2[1] = { id = 'vuoto', icona = '—', titolo = 'Nessun dipendente', disattivata = true }
        end
        exports.aurea_ui:Menu({ titolo = 'Organico', sottotitolo = impresa.ragione_sociale, voci = voci2 })

    elseif scelta == 'ricapitalizza' or scelta == 'preleva' then
        local valori = exports.aurea_ui:Dialogo(
            scelta == 'ricapitalizza' and 'Versamento in cassa' or 'Prelievo di utili',
            { { etichetta = 'Importo in euro', tipo = 'text', segnaposto = '500.00', obbligatorio = true } })
        if not valori then return end

        local ok, messaggio = AUREA.Callback.Attendi('fisco:movimentoCassa', impresa.id, scelta, valori[1])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            titolo = ok and 'Movimento eseguito' or 'Movimento rifiutato',
            testo = messaggio, durata = 8000,
        })
    end
end
