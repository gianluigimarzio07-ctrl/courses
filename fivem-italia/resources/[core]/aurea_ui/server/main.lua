--[[
    AUREA · UI server
    Inoltro di notifiche verso singoli giocatori, gruppi, enti o tutti.
]]

--- Notifica a un singolo giocatore.
local function Notifica(src, dati)
    TriggerClientEvent('aurea:ui:notifica', src, dati)
end

--- Notifica a tutti i giocatori con un dato lavoro (opzionalmente in servizio).
local function NotificaLavoro(lavoro, dati, soloInServizio)
    for _, g in ipairs(exports.aurea_core:GetGiocatoriPerLavoro(lavoro, soloInServizio)) do
        TriggerClientEvent('aurea:ui:notifica', g.source, dati)
    end
end

--- Notifica a un ente di emergenza (carabinieri, polizia, 118, vigili_fuoco...).
local function NotificaEnte(ente, dati, soloInServizio)
    for _, g in ipairs(exports.aurea_core:GetGiocatoriPerEnte(ente, soloInServizio)) do
        TriggerClientEvent('aurea:ui:notifica', g.source, dati)
    end
end

--- Notifica a tutti.
local function NotificaTutti(dati)
    TriggerClientEvent('aurea:ui:notifica', -1, dati)
end

exports('Notifica', Notifica)
exports('NotificaLavoro', NotificaLavoro)
exports('NotificaEnte', NotificaEnte)
exports('NotificaTutti', NotificaTutti)

RegisterNetEvent('aurea:ui:notificaTutti', function(dati)
    -- evento interno: accettato solo se originato dal server (source == 0)
    if source ~= 0 then return end
    NotificaTutti(dati)
end)
