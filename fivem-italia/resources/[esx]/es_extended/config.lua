--[[
    ESX su AUREA — configurazione del ponte

    PERCHÉ QUESTA RISORSA SI CHIAMA es_extended

    Non è un capriccio. Gli script ESX si agganciano al framework in due modi:

        ESX = exports['es_extended']:getSharedObject()
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

    Il secondo funziona da qualunque risorsa, il primo no: cerca proprio una
    risorsa di nome es_extended. Per far girare gli script esistenti senza
    toccarli, questa deve chiamarsi così.

    Conseguenza diretta, e va detta chiara: NON puoi avere anche il vero
    es_extended installato. Sono la stessa risorsa. Se vuoi usare quello
    vero, cancella questa cartella e usa aurea_esx, che fa il lavoro
    inverso — vedi docs/ESX.md.

    CHE COSA FA

    Espone l'oggetto ESX completo (server e client) costruito sopra AUREA.
    Un xPlayer non è una copia dei dati: è una facciata sull'oggetto
    Giocatore vero. xPlayer.addMoney(500) chiama Giocatore:Aggiungi, che
    logga, notifica ed emette gli eventi come sempre. Non esistono due
    portafogli che si devono sincronizzare, ne esiste uno solo visto da due
    angolazioni.

    IL PUNTO DELICATO: I SOLDI

    ESX ragiona in euro come numero (può essere decimale). AUREA ragiona in
    centesimi interi, di proposito: sui float i centesimi si perdono, e su
    diecimila transazioni la differenza si vede nel bilancio dello Stato.

    Il ponte converte a ogni passaggio e arrotonda al centesimo più vicino,
    mai per difetto. Un ESX.addMoney(0.005) diventa 1 centesimo, non zero.
    In lettura restituisce euro con due decimali.
]]

ESXC = {}

-- ---------------------------------------------------------------------------
--  Conti
--
--  ESX ha tre conti standard. AUREA ne ha due più un oggetto.
-- ---------------------------------------------------------------------------
ESXC.Conti = {
    -- conto ESX -> conto AUREA
    money       = 'contanti',
    bank        = 'banca',
    -- black_money non è un conto in AUREA: è l'oggetto 'contanti_sporchi',
    -- perché il denaro sporco deve stare in tasca, potersi perdere in una
    -- perquisizione e passare di mano fisicamente. Restano una cosa sola.
    black_money = false,
}

ESXC.Nero = {
    oggetto = 'contanti_sporchi',
    -- Quanto vale una unità, in centesimi. È il taglio di ita_illegale.
    valoreUnita = 10000,
    -- Poiché il nero è a banconote intere, addAccountMoney('black_money', 150)
    -- non può dare una banconota e mezza: arrotonda per difetto e il resto
    -- non si crea. Lo diciamo nel log invece di far sparire soldi in
    -- silenzio.
    avvisaArrotondamento = true,
}

-- ---------------------------------------------------------------------------
--  Gruppi staff
--
--  ESX: user, mod, admin, superadmin. AUREA ha sei livelli.
-- ---------------------------------------------------------------------------
ESXC.Gruppi = {
    -- AUREA -> ESX
    aurea = {
        utente     = 'user',
        supporto   = 'mod',
        moderatore = 'mod',
        admin      = 'admin',
        gestore    = 'superadmin',
        fondatore  = 'superadmin',
    },
    -- ESX -> AUREA (per ESX.RegisterCommand e i controlli di gruppo)
    esx = {
        user       = 'utente',
        mod        = 'moderatore',
        admin      = 'admin',
        superadmin = 'gestore',
    },
}

-- ---------------------------------------------------------------------------
--  Inventario
-- ---------------------------------------------------------------------------
ESXC.Inventario = {
    -- ESX legacy pesa in grammi come AUREA: nessuna conversione.
    -- Se usi script tarati sui pesi vecchi di ESX (dove 1 = 1 kg), metti 0.001.
    fattorePeso = 1.0,

    -- ESX chiama 'count' quello che AUREA chiama 'quantita', e si aspetta
    -- che ogni item del catalogo compaia nell'inventario anche a zero:
    -- parecchi script ciclano su getInventory() e leggono item.count.
    includiAZero = false,
}

-- ---------------------------------------------------------------------------
--  Notifiche
--
--  ESX ha tre tipi di notifica. Si mappano sulla UI di AUREA.
-- ---------------------------------------------------------------------------
ESXC.Notifiche = {
    durata = 6000,
    icona = 'ℹ',
    -- ShowAdvancedNotification ha titolo, sottotitolo e icona: si rende
    -- come una notifica AUREA con titolo composto.
    avanzataDurata = 9000,
}

-- ---------------------------------------------------------------------------
--  Menu ESX
--
--  Molti script usano ESX.UI.Menu.Open('default', ...). Si rendono con il
--  menu di aurea_ui. I due tipi standard sono 'default' e 'dialog'.
-- ---------------------------------------------------------------------------
ESXC.Menu = {
    -- Il menu di AUREA è bloccante, quello di ESX è a callback. Il ponte
    -- lancia il menu in un thread e richiama submit/cancel: il chiamante
    -- non se ne accorge.
    tipiSupportati = { 'default', 'dialog' },
}

-- ---------------------------------------------------------------------------
--  Compatibilità
-- ---------------------------------------------------------------------------
ESXC.Compat = {
    -- Alcuni script vecchi leggono ESX.PlayerData.job.grade_label e simili:
    -- il ponte compila sempre entrambe le forme (grade_name, grade_label,
    -- grade_salary, label).
    campiGradoCompleti = true,

    -- ESX.CreatePickup non esiste in AUREA: gli oggetti a terra li gestisce
    -- aurea_inventory con le sue regole. Se true, i pickup diventano
    -- mucchi AUREA; se false, la chiamata non fa niente e lo dice a console.
    pickupComeMucchi = true,

    -- Stampa a console ogni chiamata a un pezzo di API non implementato.
    -- Tienilo acceso quando provi uno script ESX nuovo: ti dice esattamente
    -- cosa gli manca invece di farlo fallire in silenzio.
    avvisaNonImplementato = true,
}

-- ---------------------------------------------------------------------------
--  Utilità di conversione
--
--  Un solo posto in cui si passa da centesimi a euro e viceversa, così se
--  la regola cambia cambia qui.
-- ---------------------------------------------------------------------------

--- Centesimi interi -> euro con due decimali (quello che ESX si aspetta).
function ESXC.AEuro(centesimi)
    return math.floor((tonumber(centesimi) or 0)) / 100
end

--- Euro (anche decimali) -> centesimi interi, arrotondando al più vicino.
--- Mai per difetto: 0,005 € deve valere 1 centesimo, non 0.
function ESXC.ACentesimi(euro)
    local n = tonumber(euro) or 0
    return math.floor(n * 100 + (n >= 0 and 0.5 or -0.5))
end

--- Il conto AUREA corrispondente a un conto ESX, o nil se è il nero.
function ESXC.ContoAurea(nome)
    local c = ESXC.Conti[nome]
    if c == false then return nil end
    return c
end

function ESXC.GruppoESX(gruppoAurea)
    return ESXC.Gruppi.aurea[gruppoAurea] or 'user'
end

function ESXC.GruppoAurea(gruppoESX)
    return ESXC.Gruppi.esx[gruppoESX] or 'utente'
end
