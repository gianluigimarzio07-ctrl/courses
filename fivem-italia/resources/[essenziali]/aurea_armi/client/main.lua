--[[
    AUREA · Armi (client)
]]

local U = AUREA.Util
local armiOrdinanza = {}

-- ---------------------------------------------------------------------------
--  Blip
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, a in ipairs(ARM.Armerie) do
        local b = AddBlipForCoord(a.coord.x, a.coord.y, a.coord.z)
        SetBlipSprite(b, 110) SetBlipColour(b, 1) SetBlipScale(b, 0.65)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(a.nome) EndTextCommandSetBlipName(b)
    end

    local u = AddBlipForCoord(ARM.Ufficio.coord.x, ARM.Ufficio.coord.y, ARM.Ufficio.coord.z)
    SetBlipSprite(u, 419) SetBlipColour(u, 3) SetBlipScale(u, 0.7)
    SetBlipAsShortRange(u, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentString(ARM.Ufficio.nome) EndTextCommandSetBlipName(u)
end)

-- ---------------------------------------------------------------------------
--  Interazioni
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())
        local trovato = false

        for _, a in ipairs(ARM.Armerie) do
            if #(coord - a.coord) < 2.2 then
                trovato = true attesa = 0
                exports.aurea_ui:Prompt(true, a.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    menuArmeria()
                end
                break
            end
        end

        if not trovato and #(coord - ARM.Ufficio.coord) < 2.2 then
            trovato = true attesa = 0
            exports.aurea_ui:Prompt(true, ARM.Ufficio.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuUfficio()
            end
        end

        if not trovato and AUREA.PG then
            for _, armadio in ipairs(ARM.Armadi) do
                if armadio.lavoro == AUREA.PG.lavoro.nome and #(coord - armadio.coord) < 2.2 then
                    trovato = true attesa = 0
                    exports.aurea_ui:Prompt(true, armadio.nome, 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        menuOrdinanza()
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
--  Ufficio Armi
-- ---------------------------------------------------------------------------
function menuUfficio()
    CreateThread(function()
        local mie = AUREA.Callback.Attendi('arm:mieArmi') or { armi = {} }

        local voci = {}

        if mie.titolo then
            voci[#voci + 1] = {
                id = 'titolo', icona = '📜', titolo = mie.titolo.etichetta,
                descrizione = ('Valido fino al %s · %s'):format(
                    mie.titolo.scadenza,
                    mie.titolo.consentePorto and 'consente il porto in luogo pubblico' or 'non consente il porto in luogo pubblico'),
                disattivata = true,
            }
        else
            for id, t in pairs(ARM.Titoli) do
                if not t.soloLavori then
                    voci[#voci + 1] = {
                        id = 'richiedi:' .. id, icona = '📜', titolo = t.etichetta,
                        descrizione = t.descrizione, valore = U.Euro(t.costo),
                    }
                end
            end
        end

        -- Denunce di detenzione ancora da presentare
        for _, a in ipairs(mie.armi) do
            if a.clandestina == 0 and a.denunciata == 0 and a.scadenzaDenuncia then
                voci[#voci + 1] = {
                    id = 'denuncia:' .. a.id, icona = '⚠',
                    titolo = ('Denuncia di detenzione — %s'):format(a.nome),
                    descrizione = ('Matricola %s · entro il %s'):format(a.matricola, a.scadenzaDenuncia),
                }
            end
        end

        if #voci == 0 then
            voci[1] = { id = 'v', icona = '✅', titolo = 'Posizione regolare', disattivata = true }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ARM.Ufficio.nome,
            sottotitolo = 'Rilascio dei titoli e denunce di detenzione',
            voci = voci,
        })
        if not scelta or type(scelta) ~= 'string' then return end

        if scelta:sub(1, 9) == 'richiedi:' then
            local ok, messaggio = AUREA.Callback.Attendi('arm:richiediTitolo', scelta:sub(10))
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '📜', titolo = ok and 'Titolo rilasciato' or 'Rilascio negato',
                testo = messaggio, durata = 12000,
            })

        elseif scelta:sub(1, 9) == 'denuncia:' then
            local ok, messaggio = AUREA.Callback.Attendi('arm:denuncia', tonumber(scelta:sub(10)))
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '📋', titolo = ok and 'Denuncia presentata' or 'Denuncia rifiutata',
                testo = messaggio, durata = 9000,
            })
        end
    end)
end

-- ---------------------------------------------------------------------------
--  Armeria
-- ---------------------------------------------------------------------------
function menuArmeria()
    CreateThread(function()
        local catalogo = AUREA.Callback.Attendi('arm:catalogo')
        if not catalogo then return end

        if not catalogo.titolo then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🚫', durata = 12000,
                titolo = 'Nessun titolo valido',
                testo = 'Senza porto d\'armi non si vende nulla. Rivolgiti all\'Ufficio Armi della Questura.',
            })
        end

        local voci = {}
        for _, a in ipairs(catalogo.armi) do
            voci[#voci + 1] = {
                id = 'arma:' .. a.arma, icona = '🔫',
                titolo = a.nome,
                descrizione = ('Categoria %s%s'):format(a.categoria,
                    a.capienza and (' · caricatore da %d'):format(a.capienza) or ''),
                valore = U.Euro(a.prezzo),
            }
        end

        voci[#voci + 1] = { id = 'muniz', icona = '📦', titolo = 'Munizioni',
            descrizione = ('%s a cartuccia, %s per la caccia'):format(
                U.Euro(catalogo.prezzoCartuccia), U.Euro(catalogo.prezzoCartucciaCaccia)) }

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Armeria',
            sottotitolo = ('%s · pagamento tracciato, solo bonifico'):format(catalogo.titolo),
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'muniz' then
            local tipo = exports.aurea_ui:Menu({
                titolo = 'Munizioni',
                voci = {
                    { id = 'comune', icona = '📦', titolo = 'Cartucce comuni', valore = U.Euro(catalogo.prezzoCartuccia) },
                    { id = 'caccia', icona = '📦', titolo = 'Cartucce da caccia', valore = U.Euro(catalogo.prezzoCartucciaCaccia) },
                },
            })
            if not tipo then return end

            local valori = exports.aurea_ui:Dialogo('Quante cartucce?', {
                { etichetta = ('Quantità (max %d)'):format(ARM.Regole.massimoAcquistoMunizioni),
                  tipo = 'number', valore = 50, min = 1, max = ARM.Regole.massimoAcquistoMunizioni },
            })
            if not valori then return end

            local ok, messaggio = AUREA.Callback.Attendi('arm:munizioni', tipo, valori[1])
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '📦', titolo = ok and 'Munizioni acquistate' or 'Acquisto rifiutato',
                testo = messaggio, durata = 9000,
            })
        end

        local ok, messaggio = AUREA.Callback.Attendi('arm:acquista', scelta:sub(6))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🔫', titolo = ok and 'Arma acquistata' or 'Vendita rifiutata',
            testo = messaggio, durata = 13000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Armeria di reparto
-- ---------------------------------------------------------------------------
function menuOrdinanza()
    CreateThread(function()
        local voci = {}
        for _, a in ipairs(ARM.Catalogo) do
            if a.categoria == 'ordinanza' then
                voci[#voci + 1] = {
                    id = a.arma, icona = '🚔', titolo = a.nome,
                    descrizione = a.gradoMinimo and 'Riservata ai gradi superiori.' or 'In dotazione ordinaria.',
                }
            end
        end

        voci[#voci + 1] = { id = '__riconsegna', icona = '📥', titolo = 'Riconsegna tutto',
            descrizione = 'Svuota la dotazione che hai addosso.' }

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Armeria di reparto',
            sottotitolo = 'La dotazione va riconsegnata a fine turno',
            voci = voci,
        })
        if not scelta then return end

        if scelta == '__riconsegna' then
            TriggerEvent('arm:svuotaOrdinanza')
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '📥', titolo = 'Dotazione riconsegnata' })
        end

        local ok, messaggio = AUREA.Callback.Attendi('arm:ordinanza', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🚔', titolo = ok and 'Dotazione prelevata' or 'Prelievo negato',
            testo = messaggio, durata = 9000,
        })
    end)
end

RegisterNetEvent('arm:consegna', function(nomeArma, munizioni)
    local ped = PlayerPedId()
    GiveWeaponToPed(ped, GetHashKey(nomeArma), munizioni or 0, false, false)
    armiOrdinanza[nomeArma] = true
end)

RegisterNetEvent('arm:svuotaOrdinanza', function()
    local ped = PlayerPedId()
    for nomeArma in pairs(armiOrdinanza) do
        RemoveWeaponFromPed(ped, GetHashKey(nomeArma))
    end
    armiOrdinanza = {}
end)
AddEventHandler('arm:svuotaOrdinanza', function() end)

RegisterNetEvent('arm:rimuovi', function(nomeArma)
    RemoveWeaponFromPed(PlayerPedId(), GetHashKey(nomeArma))
end)

-- ---------------------------------------------------------------------------
--  Registro personale
-- ---------------------------------------------------------------------------
RegisterNetEvent('arm:apriRegistro', function()
    CreateThread(function()
        local mie = AUREA.Callback.Attendi('arm:mieArmi') or { armi = {} }

        local voci = {}
        if mie.titolo then
            voci[#voci + 1] = {
                id = 't', icona = '📜', titolo = mie.titolo.etichetta,
                descrizione = ('Scadenza %s'):format(mie.titolo.scadenza),
                valore = mie.titolo.consentePorto and 'porto consentito' or 'solo trasporto',
                disattivata = true,
            }
        else
            voci[#voci + 1] = { id = 't', icona = '🚫', titolo = 'Nessun porto d\'armi',
                descrizione = 'Portare un\'arma senza titolo è reato.', disattivata = true }
        end

        for _, a in ipairs(mie.armi) do
            local stato = a.sequestrata == 1 and 'SEQUESTRATA'
                or a.clandestina == 1 and 'senza matricola'
                or a.denunciata == 1 and 'regolare'
                or 'da denunciare'

            voci[#voci + 1] = {
                id = a.id,
                icona = a.clandestina == 1 and '🚫' or (a.denunciata == 1 and '✅' or '⚠'),
                titolo = a.nome,
                descrizione = ('Matricola %s · categoria %s'):format(a.matricola, a.categoria),
                valore = stato, disattivata = true,
            }
        end

        exports.aurea_ui:Menu({
            titolo = 'Le tue armi',
            sottotitolo = 'Registro nazionale delle armi',
            voci = voci,
        })
    end)
end)

-- ---------------------------------------------------------------------------
--  Controllo da parte delle forze dell'ordine
-- ---------------------------------------------------------------------------
RegisterNetEvent('arm:apriControllo', function()
    CreateThread(function()
        local bersaglio = giocatoreVicino(3.5)
        if not bersaglio then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati al soggetto.' })
        end

        local esito, errore = AUREA.Callback.Attendi('arm:controlla', bersaglio)
        if not esito then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Controllo non riuscito', testo = errore })
        end

        local voci = {
            { id = 'x', icona = '🪪', titolo = esito.nome,
              descrizione = ('CF %s'):format(esito.cf),
              valore = esito.titolo or 'nessun titolo', disattivata = true },
        }

        if #esito.armi == 0 then
            voci[#voci + 1] = { id = 'y', icona = '✅', titolo = 'Nessuna arma intestata', disattivata = true }
        end

        for _, a in ipairs(esito.armi) do
            voci[#voci + 1] = {
                id = a.matricola,
                icona = a.clandestina == 1 and '🚫' or '🔫',
                titolo = a.nome,
                descrizione = ('Matricola %s · %s'):format(a.matricola,
                    a.clandestina == 1 and 'MATRICOLA ABRASA' or (a.denunciata == 1 and 'denunciata' or 'non denunciata')),
                valore = 'sequestra',
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Controllo armi',
            sottotitolo = esito.consentePorto and 'Il titolo consente il porto' or 'Il titolo NON consente il porto in luogo pubblico',
            voci = voci,
        })
        if not scelta or scelta == 'x' or scelta == 'y' then return end

        local ok, messaggio = AUREA.Callback.Attendi('arm:sequestra', scelta, bersaglio)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '📥', titolo = ok and 'Sequestro eseguito' or 'Sequestro rifiutato',
            testo = messaggio, durata = 10000,
        })
    end)
end)

function giocatoreVicino(raggio)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    for _, altro in ipairs(GetActivePlayers()) do
        local altroPed = GetPlayerPed(altro)
        if altroPed ~= ped and #(coord - GetEntityCoords(altroPed)) < raggio then
            return GetPlayerServerId(altro)
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Uso dell'arma dall'inventario
-- ---------------------------------------------------------------------------
RegisterNetEvent('arm:impugna', function(metadata)
    if not metadata or not metadata.arma then return end

    local ped = PlayerPedId()
    local hash = GetHashKey(metadata.arma)

    if HasPedGotWeapon(ped, hash, false) then
        RemoveWeaponFromPed(ped, hash)
        exports.aurea_ui:Notifica({ tipo = 'info', icona = '🔫', titolo = 'Arma riposta' })
    else
        GiveWeaponToPed(ped, hash, metadata.munizioni or 0, false, true)
        exports.aurea_ui:Notifica({
            tipo = 'avviso', icona = '🔫', titolo = metadata.nomeArma or 'Arma impugnata',
            testo = ('Matricola %s'):format(metadata.matricola or 'n.d.'),
        })
    end
end)

-- ---------------------------------------------------------------------------
--  Fuori dal poligono, sparare è un fatto rilevante
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()

        if IsPedArmed(ped, 4) then
            local coord = GetEntityCoords(ped)
            local inPoligono = false
            for _, p in ipairs(ARM.Poligoni) do
                if #(coord - p.coord) < p.raggio then inPoligono = true break end
            end
            LocalPlayer.state:set('inPoligono', inPoligono, false)
        end
    end
end)
