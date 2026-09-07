fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'es_extended'
author      'AUREA · Italia Roleplay'
description 'Ponte ESX: espone l oggetto ESX completo costruito sopra il framework AUREA'
version     '1.0.0'

--[[
    ATTENZIONE

    Questa risorsa si chiama es_extended di proposito: exports['es_extended']
    cerca proprio questo nome. Non puoi avere anche il vero es_extended
    installato — sono la stessa risorsa e FiveM ne carica una sola.

    Se invece vuoi usare il vero es_extended come framework, cancella questa
    cartella e usa [esx]/aurea_esx, che fa il percorso inverso.
    Vedi docs/ESX.md.
]]

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
    'shared/comune.lua',
}

client_scripts {
    'client/oggetto.lua',
    'client/gioco.lua',
    'client/menu.lua',
    'client/eventi.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/xplayer.lua',
    'server/oggetto.lua',
    'server/eventi.lua',
    'server/migrazione.lua',
}

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_inventory',
    'aurea_armi',
}
