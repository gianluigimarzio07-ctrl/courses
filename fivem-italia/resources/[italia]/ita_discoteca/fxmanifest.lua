fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_discoteca'
author      'AUREA · Italia Roleplay'
description 'Locali notturni: licenza art. 68 TULPS, permesso SIAE, addetti ai servizi di controllo, capienza, DASPO alla porta'
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
    'ita_fisco',
    'ita_questura',
    'ita_prefettura',
    'ita_siae',
}
