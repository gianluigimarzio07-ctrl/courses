--[[
    AUREA · Musica (server)

    Il server tiene l'elenco degli stereo accesi e da quando suonano, così
    chi entra nel raggio si sincronizza sul punto giusto del brano.
]]

local U = AUREA.Util
local stereo = {}       -- [id] = { proprietario, coord, url, nome, volume, dalle, tipo }
local contatore = 0

local function inOraSilenzio()
    local ora = tonumber(os.date('%H'))
    local d, a = MUS.Regole.oraSilenzio[1], MUS.Regole.oraSilenzio[2]
    if d <= a then return ora >= d and ora < a end
    return ora >= d or ora < a
end

AUREA.Callback.Registra('mus:accendi', function(src, rispondi, dati)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local url = tostring(dati and dati.url or '')
    if not MUS.DominioAmmesso(url) then
        return rispondi(false, 'Quel collegamento non è ammesso. Usa uno dei domini consentiti.')
    end

    local tipo = dati.tipo == 'autoradio' and 'autoradio' or 'boombox'
    if tipo == 'boombox' then
        local inventario = exports.aurea_inventory:Inventario(g.citizenid)
        if not inventario:Ha(MUS.Sorgenti.boombox.item, 1) then
            return rispondi(false, 'Non hai uno stereo portatile.')
        end
    end

    -- Uno stereo per persona
    for id, s in pairs(stereo) do
        if s.proprietario == g.citizenid then stereo[id] = nil TriggerClientEvent('mus:spegni', -1, id) end
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    contatore = contatore + 1
    local id = contatore

    stereo[id] = {
        id = id, proprietario = g.citizenid, nome = g:NomeCompleto(),
        coord = { x = coord.x, y = coord.y, z = coord.z },
        url = url, tipo = tipo,
        volume = math.floor(U.Clamp(tonumber(dati.volume) or MUS.Regole.volumePredefinito,
            0, MUS.Regole.volumeMassimo)),
        dalle = os.time(),
        rete = dati.rete,
    }

    TriggerClientEvent('mus:accendi', -1, stereo[id], 0)

    -- Volume alto di notte: i vicini chiamano
    if stereo[id].volume >= MUS.Regole.volumeMolesto and inOraSilenzio()
       and math.random(100) <= MUS.Regole.probabilitaSegnalazione then
        TriggerEvent('aurea:112:allerta', MUS.Regole.reato,
            { x = coord.x, y = coord.y, z = coord.z },
            'Segnalata musica ad alto volume in orario notturno.',
            'segnalazione dei residenti')
    end

    rispondi(true, id)
end)

AUREA.Callback.Registra('mus:spegni', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    local s = stereo[id]
    if not g or not s then return rispondi(false, 'Nessuno stereo acceso.') end

    -- Lo spegne il proprietario, o chi ha il potere di farlo tacere
    local puo = s.proprietario == g.citizenid
        or (g.lavoro.servizio and AUREA.EForzaOrdine(g.lavoro.nome))
        or AUREA.HaGruppo(src, 'moderatore')

    if not puo then return rispondi(false, 'Non è il tuo.') end

    stereo[id] = nil
    TriggerClientEvent('mus:spegni', -1, id)
    rispondi(true, 'Spento.')
end)

AUREA.Callback.Registra('mus:volume', function(src, rispondi, id, volume)
    local g = AUREA.GetPlayer(src)
    local s = stereo[id]
    if not g or not s or s.proprietario ~= g.citizenid then return rispondi(false) end

    s.volume = math.floor(U.Clamp(tonumber(volume) or 0, 0, MUS.Regole.volumeMassimo))
    TriggerClientEvent('mus:volume', -1, id, s.volume)
    rispondi(true, ('Volume al %d%%.'):format(s.volume))
end)

--- Chi entra in partita si sincronizza su quello che sta già suonando.
AUREA.Callback.Registra('mus:attivi', function(src, rispondi)
    local out = {}
    for id, s in pairs(stereo) do
        out[#out + 1] = {
            id = id, coord = s.coord, url = s.url, volume = s.volume,
            tipo = s.tipo, rete = s.rete,
            -- Da quanti secondi suona: il client salta avanti di tanto
            trascorsi = os.time() - s.dalle,
        }
    end
    rispondi(out)
end)

AddEventHandler('playerDropped', function()
    local g = AUREA.GetPlayer(source)
    if not g then return end
    for id, s in pairs(stereo) do
        if s.proprietario == g.citizenid then
            stereo[id] = nil
            TriggerClientEvent('mus:spegni', -1, id)
        end
    end
end)
