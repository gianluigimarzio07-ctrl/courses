--[[
    AUREA · Previdenza sociale (client)

    Uno sportello e un menu. I numeri arrivano già calcolati dal server:
    qui non si somma niente e non si decide niente, si disegna.
]]

local function apriSportello()
    CreateThread(function()
        local p = AUREA.Callback.Attendi('pre:posizione')
        if not p then return end

        local voci = {}

        voci[#voci + 1] = {
            id = 'x', disattivata = true, icona = '📅',
            titolo = ('%d settimane contribuite'):format(p.settimane),
            descrizione = p.spiegazione,
        }
        voci[#voci + 1] = {
            id = 'x2', disattivata = true, icona = '📈',
            titolo = ('Montante: %s'):format(AUREA.Util.Euro(p.montante)),
            descrizione = ('Rateo stimato %s ogni erogazione. Ultimo imponibile %s.')
                :format(AUREA.Util.Euro(p.rateoStimato), AUREA.Util.Euro(p.ultimoImponibile)),
        }

        for _, pr in ipairs(p.prestazioni or {}) do
            voci[#voci + 1] = {
                id = 'x3', disattivata = true, icona = '🏛',
                titolo = ('In pagamento: %s'):format(pr.tipo),
                descrizione = pr.tipo == 'pensione'
                    and ('%s a rateo, a tempo indeterminato.'):format(AUREA.Util.Euro(pr.importo_rateo))
                    or ('%s a rateo · ratei residui %d'):format(AUREA.Util.Euro(pr.importo_rateo), pr.ratei_residui),
            }
        end

        if not p.pensionato then
            voci[#voci + 1] = {
                id = 'pensione', icona = '🧓', titolo = 'Chiedi la pensione',
                descrizione = p.requisito == 'non_maturato'
                    and 'Non hai ancora il requisito contributivo.'
                    or (p.requisito == 'anticipata'
                        and 'Pensione anticipata, con riduzione dell\'assegno.'
                        or 'Hai maturato il diritto alla pensione di vecchiaia.'),
                disattivata = p.requisito == 'non_maturato',
            }
        end

        voci[#voci + 1] = {
            id = 'malattia', icona = '🤒', titolo = 'Metti in pagamento la malattia',
            descrizione = 'Serve un certificato di malattia del medico. Lavorare mentre la percepisci è indebita percezione.',
        }
        voci[#voci + 1] = {
            id = 'naspi', icona = '📄', titolo = 'Chiedi la NASpI',
            descrizione = 'Disoccupazione per chi ha versato contributi. Diversa dal sussidio del Centro per l\'Impiego.',
        }
        voci[#voci + 1] = {
            id = 'durc', icona = p.durc and '✅' or '⛔',
            titolo = 'Ritira il DURC',
            descrizione = p.durc and 'La tua posizione contributiva è regolare.'
                or ('Irregolare: %s'):format(table.concat(p.motiviDurc or {}, '; ')),
        }

        local scelta = exports.aurea_ui:Menu({
            titolo = PRE.Sede.nome,
            sottotitolo = 'Posizione assicurativa e prestazioni',
            voci = voci,
        })
        if not scelta then return end

        local ok, messaggio

        if scelta == 'pensione' then
            local conferma = exports.aurea_ui:Menu({
                titolo = 'Domanda di pensione',
                sottotitolo = 'Il rapporto di lavoro cessa. Riprendere a lavorare sospende l\'assegno.',
                voci = {
                    { id = 'si', icona = '✔', titolo = 'Confermo, mi ritiro' },
                    { id = 'no', icona = '✖', titolo = 'Ci penso' },
                },
            })
            if conferma ~= 'si' then return end
            ok, messaggio = AUREA.Callback.Attendi('pre:pensione')

        elseif scelta == 'malattia' then
            ok, messaggio = AUREA.Callback.Attendi('pre:malattia')

        elseif scelta == 'naspi' then
            ok, messaggio = AUREA.Callback.Attendi('pre:naspi')

        elseif scelta == 'durc' then
            ok, messaggio = AUREA.Callback.Attendi('pre:durc')
        else
            return
        end

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏛',
            titolo = 'INPS', testo = tostring(messaggio), durata = 15000,
        })
    end)
end

RegisterCommand('inps', apriSportello, false)

-- ---------------------------------------------------------------------------
--  Sede e punto di interazione
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:client:caricato', function()
    local blip = AddBlipForCoord(PRE.Sede.coord)
    SetBlipSprite(blip, PRE.Sede.blip.sprite)
    SetBlipColour(blip, PRE.Sede.blip.colore)
    SetBlipScale(blip, PRE.Sede.blip.scala)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(PRE.Sede.nome)
    EndTextCommandSetBlipName(blip)

    exports.aurea_target:AggiungiZona('previdenza_sportello', PRE.Sede.coord, PRE.Sede.raggio, {
        { etichetta = 'Sportello INPS', icona = '🏛', azione = apriSportello },
    })
end)
