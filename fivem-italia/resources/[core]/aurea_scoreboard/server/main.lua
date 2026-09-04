--[[
    AUREA · Elenco dei collegati (server)

    Non si espone mai il nome del personaggio di chi non è un ente pubblico:
    sapere chi c'è in partita è un'informazione fuori personaggio, e usarla
    per riconoscere qualcuno in gioco è metagaming. Si mostra il numero di
    sessione e, per gli enti, il servizio attivo.
]]

local ENTI = {
    { lavoro = 'carabinieri',     etichetta = 'Carabinieri',        icona = '🎖' },
    { lavoro = 'polizia',         etichetta = 'Polizia di Stato',   icona = '👮' },
    { lavoro = 'guardia_finanza', etichetta = 'Guardia di Finanza', icona = '💼' },
    { lavoro = '118',             etichetta = 'Emergenza 118',      icona = '🚑' },
    { lavoro = 'vigili_fuoco',    etichetta = 'Vigili del Fuoco',   icona = '🚒' },
    { lavoro = 'meccanico',       etichetta = 'Officine',           icona = '🔧' },
    { lavoro = 'tassista',        etichetta = 'Taxi',               icona = '🚕' },
    { lavoro = 'avvocato',        etichetta = 'Studi legali',       icona = '⚖' },
    { lavoro = 'giornalista',     etichetta = 'Redazione',          icona = '📰' },
}

AUREA.Callback.Registra('score:elenco', function(src, rispondi)
    local richiedente = AUREA.GetPlayer(src)
    local eStaff = AUREA.HaGruppo(src, 'moderatore')

    local giocatori = {}
    local perEnte = {}

    for altroSrc, g in pairs(AUREA.Giocatori) do
        giocatori[#giocatori + 1] = {
            id = altroSrc,
            -- Il nome del personaggio lo vede solo lo staff
            nome = eStaff and g:NomeCompleto() or nil,
            proprio = altroSrc == src,
        }

        local l = AUREA.GetLavoro(g.lavoro.nome)
        if l.servizio and g.lavoro.servizio then
            perEnte[g.lavoro.nome] = (perEnte[g.lavoro.nome] or 0) + 1
        end
    end

    table.sort(giocatori, function(a, b) return a.id < b.id end)

    local enti = {}
    for _, e in ipairs(ENTI) do
        enti[#enti + 1] = {
            etichetta = e.etichetta, icona = e.icona,
            inServizio = perEnte[e.lavoro] or 0,
        }
    end

    rispondi({
        giocatori = giocatori,
        enti = enti,
        collegati = #giocatori,
        massimo = GetConvarInt('sv_maxclients', 64),
        eStaff = eStaff,
        tuoId = src,
    })
end)
