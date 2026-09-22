fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_capitaneria'
author      'AUREA · Italia Roleplay'
description 'Capitaneria di Porto: ordinanze sullo specchio acqueo, ricerca e soccorso a settori, controlli e fermo amministrativo'
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
    'ita_codicestrada',
    'ita_nautica',
}
