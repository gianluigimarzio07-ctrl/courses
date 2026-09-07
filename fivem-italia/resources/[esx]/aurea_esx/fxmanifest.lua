fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_esx'
author      'AUREA · Italia Roleplay'
description 'Ponte inverso: AUREA gira sopra il vero es_extended'
version     '1.0.0'

--[[
    Si usa SOLO se hai installato il vero es_extended.
    In quel caso [esx]/es_extended (il ponte opposto) va cancellato:
    sono alternative. Vedi docs/ESX.md.
]]

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}

client_scripts { 'client/main.lua' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_inventory',
}
