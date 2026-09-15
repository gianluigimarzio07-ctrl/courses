fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_immobiliare'
author      'AUREA · Italia Roleplay'
description 'Vetrina fra privati, visite accompagnate, proposte con caparra, provvigione di mediazione'
version     '1.0.0'

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
    'aurea_target',
    'aurea_case',
    'aurea_azienda',
    'ita_fisco',
    'ita_notaio',
}
