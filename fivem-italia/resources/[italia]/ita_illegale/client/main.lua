--[[
    AUREA · Mercato nero (client)
]]

local mercato = nil

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(4000)
        mercato = AUREA.Callback.Attendi('ill:mercatoDove')
    end)
end)

-- ---------------------------------------------------------------------------
--  Il banco
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1200

        if mercato then
            local coord = GetEntityCoords(PlayerPedId())
            local pos = vector3(mercato.x, mercato.y, mercato.z)

            if #(coord - pos) < 3.0 then
                attesa = 0
                exports.aurea_ui:Prompt(true, ILL.MercatoNero.nome, 'G')
                if IsControlJustReleased(0, 47) then
                    exports.aurea_ui:Prompt(false)
                    menuMercato()
                end
            end
        end

        Wait(attesa)
    end
end)

function menuMercato()
    CreateThread(function()
        local catalogo, errore = AUREA.Callback.Attendi('ill:mercatoCatalogo')
        if not catalogo then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Chiuso', testo = errore })
        end

        local sezione = exports.aurea_ui:Menu({
            titolo = ILL.MercatoNero.nome,
            sottotitolo = ('Hai %d banconote non tracciate · qui non si accettano bonifici'):format(catalogo.banconote),
            voci = {
                { id = 'oggetti', icona = '📦', titolo = 'Attrezzatura',
                  descrizione = ('%d articoli'):format(#catalogo.oggetti) },
                { id = 'armi', icona = '🔫', titolo = 'Armi senza matricola',
                  descrizione = 'Nessun registro, nessuna domanda.' },
            },
        })
        if not sezione then return end

        local voci = {}
        if sezione == 'oggetti' then
            for _, o in ipairs(catalogo.oggetti) do
                voci[#voci + 1] = {
                    id = o.item, icona = '📦', titolo = o.etichetta,
                    descrizione = o.descrizione,
                    valore = ('%d banconote'):format(o.banconote),
                }
            end
        else
            for _, a in ipairs(catalogo.armi) do
                local nome = a.arma:gsub('^WEAPON_', ''):lower():gsub('^%l', string.upper)
                voci[#voci + 1] = {
                    id = a.arma, icona = '🔫', titolo = nome,
                    descrizione = 'Matricola abrasa: detenerla è reato in sé.',
                    valore = ('%d banconote'):format(a.banconote),
                }
            end
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = sezione == 'oggetti' and 'Attrezzatura' or 'Armi',
            sottotitolo = 'Pagamento in contanti non tracciati',
            voci = voci,
        })
        if not scelta then return end

        local quantita = 1
        if sezione == 'oggetti' then
            local valori = exports.aurea_ui:Dialogo('Quantità', {
                { etichetta = 'Quante unità?', tipo = 'number', valore = 1, min = 1, max = 50 },
            })
            if not valori then return end
            quantita = valori[1]
        end

        local ok, messaggio = AUREA.Callback.Attendi('ill:mercatoAcquista',
            sezione == 'oggetti' and 'oggetto' or 'arma', scelta, quantita)

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🕶', titolo = ok and 'Affare concluso' or 'Affare saltato',
            testo = messaggio, durata = 10000,
        })
    end)
end
