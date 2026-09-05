fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_concessionaria'
author      'AUREA · Italia Roleplay'
description 'Concessionaria: listino con IVA e oneri, prova su strada, passaggio di proprietà fra privati'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

dependencies {
    'aurea_core',
    'aurea_ui',
    'aurea_target',
    'ita_veicoli',
    'ita_fisco',
}
