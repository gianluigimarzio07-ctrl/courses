fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_veicoli'
author      'AUREA · Italia Roleplay'
description 'Immatricolazione, bollo auto, RCA, revisione, sequestro e demolizione'
version     '1.0.0'

shared_scripts { 'config.lua' }
client_scripts { 'client/main.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/scadenze.lua',
}

dependencies { 'aurea_core', 'aurea_ui' }
