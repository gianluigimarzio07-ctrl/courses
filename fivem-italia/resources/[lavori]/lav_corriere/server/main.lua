--[[
    AUREA · Corriere (server)
]]

local U = AUREA.Util
local giri = {}     -- [src] = { pacchi = { {immobile, indirizzo, coord, destinatario} }, indice }

AUREA.Callback.Registra('cor:carica', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if g.lavoro.nome ~= COR.Lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Devi essere in servizio.')
    end
    if giri[src] then return rispondi(false, 'Hai già un giro in corso.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - COR.Deposito.coord) > 40.0 then
        return rispondi(false, 'Si carica in deposito.')
    end

    -- Gli indirizzi sono immobili veri, con i loro intestatari
    local righe = MySQL.query.await([[
        SELECT i.nome, i.indirizzo, i.ingresso,
               COALESCE(i.inquilino, i.proprietario) AS soggetto,
               p.nome AS pnome, p.cognome AS pcognome
        FROM immobili i
        LEFT JOIN personaggi p ON p.citizenid = COALESCE(i.inquilino, i.proprietario)
        WHERE i.ingresso IS NOT NULL
        ORDER BY RAND() LIMIT ?
    ]], { COR.Consegne.perGiro }) or {}

    if #righe == 0 then return rispondi(false, 'Nessun indirizzo disponibile in questo momento.') end

    local pacchi = {}
    for _, r in ipairs(righe) do
        local ok, coord = pcall(json.decode, r.ingresso)
        if ok and coord and coord.x then
            pacchi[#pacchi + 1] = {
                indirizzo = r.indirizzo,
                nome = r.nome,
                coord = { x = coord.x, y = coord.y, z = coord.z },
                destinatario = r.soggetto,
                nomeDestinatario = r.pnome and ('%s %s'):format(r.pnome, r.pcognome) or nil,
            }
        end
    end

    if #pacchi == 0 then return rispondi(false, 'Gli indirizzi disponibili non hanno un ingresso valido.') end

    giri[src] = { pacchi = pacchi, indice = 1, avviato = os.time(), consegnati = 0 }

    -- Chi è in partita e riceve un pacco viene avvisato
    for _, p in ipairs(pacchi) do
        if p.destinatario then
            local d = AUREA.GetPlayerByCitizenId(p.destinatario)
            if d then
                TriggerClientEvent('aurea:ui:notifica', d.source, {
                    tipo = 'info', icona = '📦', durata = 13000,
                    titolo = 'Consegna in arrivo',
                    testo = ('Un corriere sta portando un pacco a %s. Se lo ritiri di persona fai prima.')
                        :format(p.indirizzo),
                })
            end
        end
    end

    rispondi(true, { pacchi = pacchi, paga = COR.Consegne.pagaBase,
                     mezzi = COR.Deposito.mezzi, modello = COR.Deposito.modello })
end)

AUREA.Callback.Registra('cor:consegna', function(src, rispondi, diretta)
    local g = AUREA.GetPlayer(src)
    local giro = giri[src]
    if not g or not giro then return rispondi(false, 'Nessun giro in corso.') end

    local p = giro.pacchi[giro.indice]
    if not p then return rispondi(false, 'Giro concluso.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - vector3(p.coord.x, p.coord.y, p.coord.z)) > COR.Consegne.distanzaPorta + 3.0 then
        return rispondi(false, 'Non sei all\'indirizzo.')
    end

    -- Consegna a mano al destinatario: deve essere davvero lì
    local aMano = false
    if diretta and p.destinatario then
        local d = AUREA.GetPlayerByCitizenId(p.destinatario)
        if d and #(coord - GetEntityCoords(GetPlayerPed(d.source))) < 5.0 then
            aMano = true
            TriggerClientEvent('aurea:ui:notifica', d.source, {
                tipo = 'successo', icona = '📦', durata = 11000,
                titolo = 'Pacco consegnato',
                testo = ('%s te l\'ha consegnato a mano.'):format(g:NomeCompleto()),
            })
        end
    end

    local paga = COR.Consegne.pagaBase
    if aMano then paga = math.floor(paga * (1 + COR.Consegne.bonusRitiroDiretto)) end

    g:Aggiungi('contanti', paga, 'consegna a domicilio')

    giro.indice = giro.indice + 1
    giro.consegnati = giro.consegnati + 1

    local finito = giro.indice > #giro.pacchi
    if finito then giri[src] = nil end

    rispondi(true, {
        finito = finito, paga = paga, aMano = aMano,
        consegnati = giro.consegnati, totale = #giro.pacchi,
        prossimo = not finito and giro.pacchi[giro.indice] or nil,
    })
end)

AddEventHandler('playerDropped', function() giri[source] = nil end)
