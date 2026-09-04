--[[
    AUREA · Zone a Traffico Limitato (client)

    Il varco legge la targa quando il veicolo entra nel poligono. L'esito
    (autorizzato o sanzionabile) lo decide il server: qui si mostra solo
    l'indicatore e si segnala il transito.
]]

local zonaCorrente = nil
local ultimoTransito = {}     -- [idZona] = timestamp

-- ---------------------------------------------------------------------------
--  Disegno dei confini ZTL sulla minimappa
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, z in ipairs(CDS.ZTL) do
        -- centroide per il blip
        local sx, sy = 0.0, 0.0
        for _, p in ipairs(z.poligono) do sx = sx + p.x sy = sy + p.y end
        local cx, cy = sx / #z.poligono, sy / #z.poligono

        local blip = AddBlipForCoord(cx, cy, 30.0)
        SetBlipSprite(blip, 419)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(z.nome)
        EndTextCommandSetBlipName(blip)

        -- Area evidenziata: raggio approssimato dal poligono
        local raggio = 0.0
        for _, p in ipairs(z.poligono) do
            local d = #(vector2(cx, cy) - p)
            if d > raggio then raggio = d end
        end
        local area = AddBlipForRadius(cx, cy, 30.0, raggio)
        SetBlipColour(area, 1)
        SetBlipAlpha(area, 60)
    end
end)

-- ---------------------------------------------------------------------------
--  Rilevamento ingresso/uscita
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1200
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped then
            attesa = 500
            local coord = GetEntityCoords(veicolo)
            local punto = vector2(coord.x, coord.y)
            local ora = GetClockHours()

            local dentro = nil
            for _, z in ipairs(CDS.ZTL) do
                if CDS.DentroPoligono(punto, z.poligono) then dentro = z break end
            end

            if dentro and (not zonaCorrente or zonaCorrente.id ~= dentro.id) then
                zonaCorrente = dentro
                local attiva = CDS.InFascia(dentro.fasce, ora)
                    and (not dentro.giorni or true)   -- il giorno lo valida il server

                -- limite di velocità di zona per il cruscotto
                LocalPlayer.state:set('limiteImposto', {
                    valore = dentro.limiteVelocita, nota = dentro.nome,
                }, false)

                TriggerEvent('aurea:hud:ztl', {
                    dentro = true, nome = dentro.nome, attiva = attiva, autorizzato = false,
                })

                -- Un solo transito registrato per zona ogni 5 minuti
                if (GetGameTimer() - (ultimoTransito[dentro.id] or 0)) > 300000 then
                    ultimoTransito[dentro.id] = GetGameTimer()
                    TriggerServerEvent('cds:ztlTransito', {
                        zona = dentro.id,
                        nome = dentro.nome,
                        targa = GetVehicleNumberPlateText(veicolo),
                        netId = VehToNet(veicolo),
                        ora = ora,
                        coord = { x = coord.x, y = coord.y, z = coord.z },
                    })
                end

            elseif not dentro and zonaCorrente then
                zonaCorrente = nil
                LocalPlayer.state:set('limiteImposto', nil, false)
                TriggerEvent('aurea:hud:ztl', { dentro = false })
            end

        elseif zonaCorrente then
            zonaCorrente = nil
            LocalPlayer.state:set('limiteImposto', nil, false)
            TriggerEvent('aurea:hud:ztl', { dentro = false })
        end

        Wait(attesa)
    end
end)

--- Il server conferma se il veicolo ha un permesso valido per la zona.
RegisterNetEvent('cds:ztlEsito', function(esito)
    TriggerEvent('aurea:hud:ztl', {
        dentro = true,
        nome = esito.nome,
        attiva = esito.attiva,
        autorizzato = esito.autorizzato,
    })

    if esito.autorizzato then
        exports.aurea_ui:Notifica({
            tipo = 'successo', titolo = esito.nome,
            testo = ('Permesso %s valido fino al %s.'):format(esito.tipo or 'residente', esito.scadenza or ''),
            durata = 5000, icona = '🅿',
        })
    elseif esito.attiva then
        exports.aurea_ui:Notifica({
            tipo = 'errore', titolo = 'Varco ZTL attivo',
            testo = 'Targa rilevata senza permesso. Il verbale arriverà per posta.',
            durata = 7000, icona = '📷',
        })
    end
end)
