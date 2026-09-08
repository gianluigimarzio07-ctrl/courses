--[[
    AUREA · Telefono — registro delle app (server)

    Il cuore del telefono unico. Non contiene nessuna app: contiene il
    posto dove le app stanno e il modo in cui parlano con la NUI.

    IL CONTRATTO

    Un'app è una tabella con quattro cose che contano:

        id          identificatore, univoco
        schermata   fun(giocatore, argomenti) -> tabella schermata
        azione      fun(giocatore, idAzione, dati) -> ok, messaggio, ricarica
        condizione  fun(giocatore) -> boolean   (facoltativa: chi la vede)

    La schermata è DATI, non markup. Il telefono ne rende cinque forme:

        lista     un elenco di righe
        saldo     una cifra grande più un elenco (estratto conto)
        tessera   un documento (identità digitale)
        testo     un corpo lungo (un articolo, un regolamento)
        griglia   riquadri grandi (i numeri di emergenza)

    Nessuna app tocca l'HTML. È la ragione per cui aggiungerne una costa
    venti righe di Lua invece di un file NUI.

    PERCHÉ TUTTO SUL SERVER

    Una schermata si costruisce qui e arriva già fatta. Il client non
    interroga il database, non calcola saldi e non decide cosa può vedere:
    riceve una lista di righe da disegnare. Se qualcuno si modifica il
    client vede quello che il server gli ha mandato, che è esattamente
    quello che aveva il diritto di vedere.
]]

local U = AUREA.Util

Registro = { app = {} }

-- ---------------------------------------------------------------------------
--  Registrazione
-- ---------------------------------------------------------------------------

--- Aggiunge un'app al telefono.
---@param dati table { id, nome, icona, colore, ordine, condizione, badge, schermata, azione }
function Registro.Aggiungi(dati)
    -- Da quale risorsa arriva: serve per toglierla se quella si ferma.
    -- GetInvokingResource risponde solo quando la chiamata passa da un
    -- export, quindi le app interne restano senza e non vengono toccate.
    if type(dati) == 'table' and not dati.risorsa then
        dati.risorsa = GetInvokingResource() or nil
    end

    if type(dati) ~= 'table' or type(dati.id) ~= 'string' then
        return print('[aurea_telefono] RegistraApp: serve almeno un id.')
    end
    if type(dati.schermata) ~= 'function' then
        return print(('[aurea_telefono] RegistraApp("%s"): manca la funzione schermata.'):format(dati.id))
    end

    if Registro.app[dati.id] then
        print(('[aurea_telefono] RegistraApp("%s"): sostituita quella già presente.'):format(dati.id))
    end

    dati.nome = dati.nome or dati.id
    dati.icona = dati.icona or '▪'
    dati.colore = dati.colore or TEL.Colori.impostazioni
    dati.ordine = tonumber(dati.ordine) or 100

    Registro.app[dati.id] = dati
end

exports('RegistraApp', Registro.Aggiungi)

--- Toglie un'app: serve a chi la registra e poi si spegne.
function Registro.Rimuovi(id)
    Registro.app[id] = nil
end

exports('RimuoviApp', Registro.Rimuovi)

--- Se una risorsa che ha registrato app si ferma, le sue app se ne vanno
--- con lei. Senza questo, il telefono mostrerebbe icone che aprono errori.
AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then return end
    for id, app in pairs(Registro.app) do
        if app.risorsa == risorsa then Registro.app[id] = nil end
    end
end)

-- ---------------------------------------------------------------------------
--  Elenco per la home
-- ---------------------------------------------------------------------------
local function ammessa(app, g)
    if not app.condizione then return true end
    local ok, risultato = pcall(app.condizione, g)
    return ok and risultato ~= false
end

local function badgeDi(app, g)
    if not app.badge then return 0 end
    local ok, valore = pcall(app.badge, g)
    if not ok then return 0 end
    return math.max(0, math.floor(tonumber(valore) or 0))
end

function Registro.Home(g)
    local out = {}

    for _, app in pairs(Registro.app) do
        if ammessa(app, g) then
            out[#out + 1] = {
                id = app.id, nome = app.nome, icona = app.icona,
                colore = app.colore, ordine = app.ordine,
                badge = badgeDi(app, g),
            }
        end
    end

    table.sort(out, function(a, b)
        if a.ordine ~= b.ordine then return a.ordine < b.ordine end
        return a.nome < b.nome
    end)

    return out
end

-- ---------------------------------------------------------------------------
--  Apertura del telefono
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tel:apertura', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local impostazioni = g:Get('telefono') or {}

    rispondi({
        pg = {
            nome = g:NomeCompleto(),
            numero = g.telefono,
            citizenid = g.citizenid,
        },
        app = Registro.Home(g),
        aspetto = {
            operatore = TEL.Aspetto.operatore,
            tema = impostazioni.tema or TEL.Aspetto.temaPredefinito,
            sfondo = TEL.GetSfondo(impostazioni.sfondo or TEL.Aspetto.sfondoPredefinito).css,
        },
    })
end)

-- ---------------------------------------------------------------------------
--  Apertura di una app
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tel:schermata', function(src, rispondi, richiesta)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    richiesta = type(richiesta) == 'table' and richiesta or {}
    local app = Registro.app[richiesta.app]

    if not app then return rispondi({ tipo = 'testo', titolo = 'App non disponibile',
        corpo = 'Questa applicazione non è installata su questo server.' }) end

    if not ammessa(app, g) then
        return rispondi({ tipo = 'testo', titolo = app.nome,
            corpo = 'Non hai accesso a questa applicazione.' })
    end

    local ok, schermata = pcall(app.schermata, g, richiesta.argomenti)

    if not ok then
        print(('[aurea_telefono] app "%s" ha sollevato un errore: %s'):format(app.id, tostring(schermata)))
        return rispondi({ tipo = 'testo', titolo = app.nome,
            corpo = 'L\'applicazione ha restituito un errore. È stato scritto nel registro del server.' })
    end

    if type(schermata) ~= 'table' then
        return rispondi({ tipo = 'testo', titolo = app.nome, corpo = 'Nessun contenuto.' })
    end

    schermata.app = app.id
    schermata.titolo = schermata.titolo or app.nome
    schermata.icona = schermata.icona or app.icona
    rispondi(schermata)
end)

-- ---------------------------------------------------------------------------
--  Azione dentro una app
--
--  Ogni riga o pulsante può portare un'azione. Arriva qui, viene girata a
--  chi ha registrato l'app, e la risposta dice se ricaricare la schermata.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tel:azione', function(src, rispondi, richiesta)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({ ok = false }) end

    richiesta = type(richiesta) == 'table' and richiesta or {}
    local app = Registro.app[richiesta.app]

    if not app or not app.azione then
        return rispondi({ ok = false, messaggio = 'Azione non prevista.' })
    end
    if not ammessa(app, g) then
        return rispondi({ ok = false, messaggio = 'Non hai accesso a questa applicazione.' })
    end

    local ok, r1, r2, r3 = pcall(app.azione, g, richiesta.azione, richiesta.dati)

    if not ok then
        print(('[aurea_telefono] azione "%s" di "%s": %s')
            :format(tostring(richiesta.azione), app.id, tostring(r1)))
        return rispondi({ ok = false, messaggio = 'L\'operazione non è riuscita.' })
    end

    -- Un'app può rispondere in due modi: booleano più messaggio, oppure
    -- una tabella completa. Si accettano tutti e due.
    if type(r1) == 'table' then return rispondi(r1) end

    rispondi({ ok = r1 == true, messaggio = r2, ricarica = r3 ~= false })
end)

-- ---------------------------------------------------------------------------
--  Le pastiglie, senza aprire il telefono
-- ---------------------------------------------------------------------------
function Registro.Badge(g)
    local out = {}
    for id, app in pairs(Registro.app) do
        if app.badge and ammessa(app, g) then
            local n = badgeDi(app, g)
            if n > 0 then out[id] = n end
        end
    end
    return out
end

AUREA.Callback.Registra('tel:badge', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end
    rispondi(Registro.Badge(g))
end)

--- Le altre risorse possono far comparire una notifica sul telefono.
AddEventHandler('aurea:telefono:notifica', function(citizenid, dati)
    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if not g then return end
    TriggerClientEvent('tel:notifica', g.source, dati)
end)

exports('Notifica', function(citizenid, dati)
    TriggerEvent('aurea:telefono:notifica', citizenid, dati)
end)

-- ---------------------------------------------------------------------------
--  Impostazioni del telefono
-- ---------------------------------------------------------------------------
function Registro.Impostazioni(g)
    return g:Get('telefono') or {}
end

function Registro.SalvaImpostazione(g, chiave, valore)
    local i = Registro.Impostazioni(g)
    i[chiave] = valore
    g:Set('telefono', i, false)
end
