--[[
    AUREA · Traffico di rifiuti (client)

    I siti contaminati compaiono sulla mappa solo quando il cumulo è
    abbastanza grosso da vedersi. Prima esistono e non si vedono, che è
    esattamente il punto di scaricare di notte in mezzo al niente.
]]

local visibili = {}
local blip = {}

RegisterNetEvent('rif:siti', function(elenco)
    for _, b in pairs(blip) do RemoveBlip(b) end
    blip, visibili = {}, {}

    for _, s in ipairs(elenco or {}) do
        local def = RIF.GetSito(s.id)
        if def then
            visibili[s.id] = s.contaminazione
            local b = AddBlipForCoord(def.coord)
            SetBlipSprite(b, 318)
            SetBlipColour(b, s.contaminazione >= 50 and 1 or 47)
            SetBlipScale(b, 0.7)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('Abbandono di rifiuti — %s'):format(def.nome))
            EndTextCommandSetBlipName(b)
            blip[s.id] = b
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Il sito
-- ---------------------------------------------------------------------------
local function sopralluogo(sito)
    CreateThread(function()
        local s = AUREA.Callback.Attendi('rif:sopralluogo')
        if not s then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '♻',
                titolo = 'Niente', testo = 'Qui non c\'è nessun accumulo.' })
        end

        local voci = {
            { id = 'x', disattivata = true, icona = '♻',
              titolo = ('%d kg accumulati'):format(s.chili),
              descrizione = ('Contaminazione %d%% · bonifica stimata %s')
                  :format(s.contaminazione, AUREA.Util.Euro(s.costoBonifica)) },
        }

        for _, a in ipairs(s.autori or {}) do
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '🚛',
                titolo = a.nome or 'ignoto',
                descrizione = ('%d kg scaricati qui'):format(math.floor(tonumber(a.chili) or 0)) }
        end

        if s.chili > 0 then
            voci[#voci + 1] = { id = 'bonifica', icona = '🧹',
                titolo = ('Bonifica un lotto (%d kg)'):format(RIF.Bonifica.chiliPerLotto),
                descrizione = ('%s di compenso, li paga l\'erario.')
                    :format(AUREA.Util.Euro(RIF.Bonifica.compensoPerLotto)) }
        end
        voci[#voci + 1] = { id = 'scarica', icona = '🚛', titolo = 'Scarica quello che hai in carico',
            descrizione = 'Art. 256 D.Lgs. 152/2006. Il registro non tornerà più.' }

        local scelta = exports.aurea_ui:Menu({
            titolo = sito.nome,
            sottotitolo = s.ammesso and 'Sopralluogo' or 'Un posto fuori mano',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        local durata = scelta == 'bonifica' and RIF.Bonifica.secondiPerLotto or RIF.Discarica.secondiScarico
        if not exports.aurea_ui:Progresso({
            etichetta = scelta == 'bonifica' and 'Rimozione dei rifiuti' or 'Scarico',
            durata = durata * 1000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi(
            scelta == 'bonifica' and 'rif:bonifica' or 'rif:scarica')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '♻',
            titolo = 'Rifiuti', testo = tostring(messaggio), durata = 18000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  L'impianto
-- ---------------------------------------------------------------------------
local function impianto()
    CreateThread(function()
        local ok, messaggio = AUREA.Callback.Attendi('rif:smaltisci')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '♻',
            titolo = 'Impianto', testo = tostring(messaggio), durata = 18000,
        })
    end)
end

RegisterCommand('registrorifiuti', function()
    CreateThread(function()
        local r = AUREA.Callback.Attendi('rif:registro')
        if not r then return end

        local voci = {
            { id = 'x', disattivata = true, icona = '📦',
              titolo = ('In carico: %d kg'):format(r.inCarico),
              descrizione = ('Smaltirli all\'impianto costa %s.')
                  :format(AUREA.Util.Euro(r.inCarico * RIF.Impianto.costoAlChilo)) },
            { id = 'x', disattivata = true, icona = '🏭',
              titolo = ('Prodotti %d kg · smaltiti %d kg'):format(r.prodotti, r.smaltiti),
              descrizione = r.buco > 0
                  and ('%d kg non tracciati: un controllo del registro li trova.'):format(r.buco)
                  or 'Il registro torna.' },
        }
        for _, f in ipairs(r.formulari or {}) do
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '📄',
                titolo = ('Formulario n. %d — %d kg'):format(f.id, f.chili),
                descrizione = ('%s · %s · %s'):format(f.codice or 'CER',
                    AUREA.Util.Euro(f.costo), f.quando or '') }
        end

        exports.aurea_ui:Menu({
            titolo = 'Registro di carico e scarico',
            sottotitolo = 'Rifiuti speciali',
            voci = voci,
        })
    end)
end, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(RIF.Impianto.coord)
    SetBlipSprite(b, RIF.Impianto.blip.sprite)
    SetBlipColour(b, RIF.Impianto.blip.colore)
    SetBlipScale(b, RIF.Impianto.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(RIF.Impianto.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('rif_impianto', RIF.Impianto.coord, RIF.Impianto.raggio, {
        { etichetta = 'Conferisci con formulario', icona = '♻', azione = impianto },
    })

    for _, s in ipairs(RIF.Siti) do
        exports.aurea_target:AggiungiZona('rif_sito_' .. s.id, s.coord, 8.0, {
            { etichetta = 'Terreno', icona = '♻', azione = function() sopralluogo(s) end },
        })
    end
end)
