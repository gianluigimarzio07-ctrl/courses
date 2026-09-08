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

-- ---------------------------------------------------------------------------
--  App del telefono
-- ---------------------------------------------------------------------------
-- Il telefono è un registro: chi vuole un'app la descrive e basta. Restava
-- però un tranello, l'ordine di avvio — se una risorsa parte prima di
-- aurea_telefono l'export non esiste ancora e l'app si perde in silenzio,
-- senza un errore che lo dica.
--
-- AureaApp lo toglie di mezzo: consegna subito se il telefono c'è, e si
-- ripresenta ogni volta che il telefono (ri)parte. Così l'ordine degli
-- ensure non conta e un /restart aurea_telefono non svuota la home.
--
--     AureaApp({ id = 'cripto', nome = 'Exchange', icona = '🪙',
--                schermata = function(g) ... end })
--
-- Le variabili globali sono per risorsa, quindi ogni risorsa ha il suo
-- elenco: non c'è modo di pestarsi i piedi a vicenda.
if IsDuplicityVersion() then
    local mie, consegnate = {}, 0

    -- Riprende da dove si era fermata: se il telefono non c'è ancora, il
    -- pcall fallisce, si esce e si riproverà. Nessuna app viene consegnata
    -- due volte, così il registro non stampa "sostituita" senza motivo.
    local function consegna()
        for i = consegnate + 1, #mie do
            if not pcall(function() exports.aurea_telefono:RegistraApp(mie[i]) end) then return end
            consegnate = i
        end
    end

    --- Registra un'app del telefono per conto di questa risorsa.
    function AureaApp(descrizione)
        mie[#mie + 1] = descrizione
        consegna()
    end

    AddEventHandler('onResourceStart', function(risorsa)
        if risorsa == 'aurea_telefono' then
            consegnate = 0      -- il registro riparte vuoto: si riconsegna tutto
            consegna()
        end
    end)
end
