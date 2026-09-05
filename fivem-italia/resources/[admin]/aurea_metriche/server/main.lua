--[[
    AUREA · Metriche (server)
]]

local U = AUREA.Util
local storico = {}      -- campioni recenti

local function campiona()
    local giocatori = 0
    for _ in pairs(AUREA.Giocatori) do giocatori = giocatori + 1 end

    local massa = MySQL.scalar.await('SELECT SUM(contanti) + SUM(banca) FROM personaggi') or 0
    local erario = MySQL.scalar.await('SELECT valore FROM economia_stato WHERE chiave = ?',
        { 'erario_saldo' })

    local c = {
        momento = os.time(),
        giocatori = giocatori,
        massa = math.floor(tonumber(massa) or 0),
        erario = math.floor(tonumber(erario) or 0),
    }

    storico[#storico + 1] = c
    while #storico > MET.Regole.campioniStorici do table.remove(storico, 1) end

    return c
end

--- Il confronto con un'ora fa dice se il denaro sta crescendo troppo.
local function tendenza()
    if #storico < 5 then return nil end

    local ultimo = storico[#storico]
    local passato = storico[math.max(1, #storico - 4)]

    local delta = ultimo.massa - passato.massa
    local minuti = math.max(1, (ultimo.momento - passato.momento) / 60)

    return {
        deltaMassa = delta,
        alOra = math.floor(delta * (60 / minuti)),
        giocatoriMedi = math.floor((ultimo.giocatori + passato.giocatori) / 2),
    }
end

CreateThread(function()
    Wait(30000)
    campiona()
    while true do
        Wait(MET.Regole.minutiCampionamento * 60000)
        local c = campiona()
        local t = tendenza()

        -- Allarmi, quando serve
        if c.massa > MET.Regole.soglie.massaMonetaria then
            AUREA.Log('economia', 'allarme', nil,
                ('Massa monetaria oltre soglia: %s'):format(U.Euro(c.massa)))
        end
        if t and t.alOra > 0 and c.massa > 0 then
            local crescita = t.alOra / math.max(1, c.massa) * 100
            if crescita > 5 then
                AUREA.Log('economia', 'avviso', nil,
                    ('Il denaro cresce del %.1f%% l\'ora: controlla le fonti di reddito.'):format(crescita))
            end
        end
    end
end)

AUREA.Callback.Registra('met:pannello', function(src, rispondi)
    if not AUREA.HaGruppo(src, MET.Regole.gruppoLettura) then return rispondi(nil) end

    local giocatori = 0
    local perLavoro, inServizio = {}, 0
    for _, g in pairs(AUREA.Giocatori) do
        giocatori = giocatori + 1
        perLavoro[g.lavoro.nome] = (perLavoro[g.lavoro.nome] or 0) + 1
        if g.lavoro.servizio then inServizio = inServizio + 1 end
    end

    local lavori = {}
    for nome, quanti in pairs(perLavoro) do
        lavori[#lavori + 1] = { nome = AUREA.EtichettaLavoro(nome, 0), quanti = quanti }
    end
    table.sort(lavori, function(a, b) return a.quanti > b.quanti end)

    local ultimo = storico[#storico] or campiona()

    rispondi({
        giocatori = giocatori,
        inServizio = inServizio,
        lavori = lavori,
        massa = ultimo.massa,
        erario = ultimo.erario,
        tendenza = tendenza(),
        veicoli = MySQL.scalar.await('SELECT COUNT(*) FROM veicoli') or 0,
        immobili = MySQL.scalar.await('SELECT COUNT(*) FROM immobili WHERE proprietario IS NOT NULL') or 0,
        imprese = MySQL.scalar.await('SELECT COUNT(*) FROM imprese WHERE attiva = 1') or 0,
        campioni = #storico,
        soglie = MET.Regole.soglie,
    })
end)

--- L'andamento, per capire se una cosa sta peggiorando o migliorando.
AUREA.Callback.Registra('met:storico', function(src, rispondi)
    if not AUREA.HaGruppo(src, MET.Regole.gruppoLettura) then return rispondi({}) end

    local out = {}
    for _, c in ipairs(storico) do
        out[#out + 1] = {
            ora = os.date('%H:%M', c.momento),
            giocatori = c.giocatori,
            massa = c.massa,
            erario = c.erario,
        }
    end
    rispondi(out)
end)

exports('Campione', function() return storico[#storico] end)
