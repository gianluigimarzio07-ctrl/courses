fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_sindacato'
author      'AUREA · Italia Roleplay'
description 'Vertenze per mestiere, adesioni che contano davvero, sciopero che costa a entrambe le parti, arretrati da accordo'
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
    'aurea_azienda',
}
