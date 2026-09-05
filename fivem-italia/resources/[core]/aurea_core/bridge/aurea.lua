--[[
    AUREA · Ponte verso il framework

    In FiveM le variabili globali NON attraversano il confine fra risorse:
    ogni risorsa ha il suo stato Lua. Senza questo file, una risorsa che
    scrive AUREA.GetPlayer(src) troverebbe semplicemente nil.

    Il ponte risolve la cosa nell'unico modo che regge: aurea_core espone
    la propria tabella AUREA con un export, e qui la si aggancia. Fra due
    risorse Lua il valore passa per riferimento, quindi arrivano anche i
    metodi dell'oggetto Giocatore e la tabella dei giocatori connessi resta
    quella vera, non una copia.

    Ogni risorsa che usa il framework deve caricarlo per PRIMO fra i suoi
    shared_scripts:

        shared_scripts {
            '@aurea_core/bridge/aurea.lua',
            'config.lua',
        }

    Vale sia lato client sia lato server: l'export si risolve nel contesto
    in cui gira.
]]

local nucleo = 'aurea_core'

local ok, tabella = pcall(function()
    return exports[nucleo]:Aurea()
end)

if not ok or type(tabella) ~= 'table' then
    error(("[%s] aurea_core non risponde. Deve partire PRIMA di questa risorsa: "
        .. "controlla l'ordine degli 'ensure' in server.cfg e il blocco dependencies del manifest.")
        :format(GetCurrentResourceName()), 0)
end

--- La tabella del framework, condivisa con aurea_core.
--- Ci si può anche scrivere: quello che una risorsa aggiunge lo vedono tutte
--- (è così che aurea_hud pubblica AUREA.LimiteVelocita).
AUREA = tabella
