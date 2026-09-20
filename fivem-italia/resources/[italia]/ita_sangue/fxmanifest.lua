fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_sangue'
author      'AUREA · Italia Roleplay'
description 'Centro trasfusionale: gruppi sanguigni, donazioni, scorte condivise, trasfusioni compatibili'
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
    'aurea_inventory',
    'aurea_azienda',
    'ita_fisco',
}
