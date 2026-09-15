--[[
    AUREA · Studio notarile (client)

    Il notaio predispone, le parti firmano. Il client non calcola niente:
    il riepilogo con imposte e onorario arriva già scritto dal server, ed
    è lo stesso testo che vedono tutte e tre le persone.
]]

local attesa = nil      -- proposta in corso a mio carico

RegisterNetEvent('not:proposta', function(p)
    attesa = p
    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '📜', durata = 25000,
        titolo = ('Atto da firmare — sei il %s'):format(p.ruolo),
        testo = ('%s\n\nApri /firma per accettare o ritirarti.'):format(p.testo),
    })
end)

RegisterCommand('firma', function()
    CreateThread(function()
        if not attesa then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '📜', titolo = 'Nessun atto',
                testo = 'Non c\'è nessun atto che ti riguardi in questo momento.' })
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ('Atto — sei il %s'):format(attesa.ruolo),
            sottotitolo = 'Leggi prima di firmare: dopo non si torna indietro',
            voci = {
                { id = 'testo', disattivata = true, icona = '📄',
                  titolo = 'Condizioni', descrizione = attesa.testo },
                { id = 'si', icona = '✔', titolo = 'Firmo' },
                { id = 'no', icona = '✖', titolo = 'Mi ritiro' },
            },
        })
        if not scelta or scelta == 'testo' then return end

        local ok, messaggio = AUREA.Callback.Attendi('not:firma', attesa.notaio, scelta == 'si')
        attesa = nil
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📜',
            titolo = 'Studio notarile', testo = tostring(messaggio), durata = 20000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Il banco del notaio
-- ---------------------------------------------------------------------------
local function scegliPersona(titolo)
    local vicini = {}
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)

    for _, p in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(p)
        if altro ~= ped and #(coord - GetEntityCoords(altro)) <= NOT.Studio.distanzaParti + 1.0 then
            vicini[#vicini + 1] = {
                id = tostring(GetPlayerServerId(p)), icona = '👤',
                titolo = ('ID %d'):format(GetPlayerServerId(p)),
            }
        end
    end

    if #vicini == 0 then
        exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📜', titolo = titolo,
            testo = 'Non c\'è nessuno abbastanza vicino al banco.' })
        return nil
    end
    return exports.aurea_ui:Menu({ titolo = titolo, sottotitolo = 'Chi è davanti a te', voci = vicini })
end

local function rogito()
    CreateThread(function()
        local venditore = scegliPersona('Chi vende')
        if not venditore then return end
        local compratore = scegliPersona('Chi compra')
        if not compratore then return end

        -- Gli immobili disponibili li chiede il venditore, non il notaio:
        -- il notaio non sa cosa possiedi finché non glielo dici.
        local elenco = AUREA.Callback.Attendi('not:vendibiliDi', tonumber(venditore)) or {}
        local voci = {}
        for _, i in ipairs(elenco) do
            voci[#voci + 1] = {
                id = tostring(i.id), icona = '🏠', titolo = i.nome,
                descrizione = ('%s · %s · valore di listino %s%s'):format(
                    i.tipo, i.indirizzo, AUREA.Util.Euro(i.prezzo),
                    i.perProcura and ' · PER PROCURA' or ''),
                disattivata = i.inquilino ~= nil,
            }
        end
        if #voci == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🏠',
                titolo = 'Nessun immobile', testo = 'La parte venditrice non ha immobili di cui disporre.' })
        end

        local immobile = exports.aurea_ui:Menu({
            titolo = 'Oggetto dell\'atto', sottotitolo = 'Immobile da trasferire', voci = voci })
        if not immobile then return end

        local r = exports.aurea_ui:Dialogo('Prezzo convenuto', {
            { etichetta = 'Prezzo in euro', tipo = 'number', min = 1, obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('not:preparaRogito',
            tonumber(venditore), tonumber(compratore), tonumber(immobile), tonumber(r[1]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📜',
            titolo = 'Studio notarile', testo = tostring(messaggio), durata = 22000,
        })
    end)
end

local function procura()
    CreateThread(function()
        local delegato = scegliPersona('A chi dai la procura')
        if not delegato then return end

        local elenco = AUREA.Callback.Attendi('not:vendibili') or {}
        local voci = {}
        for _, i in ipairs(elenco) do
            if not i.perProcura then
                voci[#voci + 1] = { id = tostring(i.id), icona = '🏠', titolo = i.nome,
                    descrizione = ('%s · %s'):format(i.tipo, i.indirizzo) }
            end
        end
        if #voci == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🏠',
                titolo = 'Nessun immobile', testo = 'Non possiedi immobili su cui dare procura.' })
        end

        local immobile = exports.aurea_ui:Menu({
            titolo = 'Procura a vendere',
            sottotitolo = 'Chi la riceve può vendere e incassare al posto tuo',
            voci = voci })
        if not immobile then return end

        local ok, messaggio = AUREA.Callback.Attendi('not:procura', tonumber(delegato), tonumber(immobile))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📜',
            titolo = 'Studio notarile', testo = tostring(messaggio), durata = 18000,
        })
    end)
end

local function banco()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = NOT.Studio.nome,
            sottotitolo = 'Atti pubblici e autentiche',
            voci = {
                { id = 'rogito', icona = '📜', titolo = 'Ricevi un atto di compravendita',
                  descrizione = 'Le due parti devono essere davanti al banco.' },
                { id = 'procura', icona = '✍', titolo = 'Autentica una procura a vendere',
                  descrizione = ('Vale %d minuti. Si revoca sempre.'):format(NOT.Procura.durataMinuti) },
                { id = 'repertorio', icona = '📚', titolo = 'Repertorio degli atti' },
            },
        })
        if scelta == 'rogito' then return rogito() end
        if scelta == 'procura' then return procura() end
        if scelta ~= 'repertorio' then return end

        local righe = AUREA.Callback.Attendi('not:repertorio') or {}
        local voci = {}
        for _, a in ipairs(righe) do
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '📜',
                titolo = ('%s — %s'):format(a.immobile or 'immobile', AUREA.Util.Euro(a.prezzo)),
                descrizione = ('%s → %s · imposte %s · onorario %s%s\n%s'):format(
                    a.venditore or '?', a.compratore or '?',
                    AUREA.Util.Euro(a.imposte), AUREA.Util.Euro(a.onorario),
                    a.prima_casa == 1 and ' · prima casa' or '', a.quando) }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '📚', titolo = 'Repertorio vuoto' }
        end
        exports.aurea_ui:Menu({ titolo = 'Repertorio', sottotitolo = 'Ultimi atti ricevuti', voci = voci })
    end)
end

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(NOT.Studio.coord)
    SetBlipSprite(b, NOT.Studio.blip.sprite)
    SetBlipColour(b, NOT.Studio.blip.colore)
    SetBlipScale(b, NOT.Studio.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(NOT.Studio.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('notaio_banco', NOT.Studio.coord, NOT.Studio.raggio, {
        { etichetta = 'Banco del notaio', icona = '📜', lavoro = NOT.Lavoro, azione = banco },
    })
end)

RegisterCommand('notaio', banco, false)
