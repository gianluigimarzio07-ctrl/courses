fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_112'
author      'AUREA · Italia Roleplay'
description 'Numero Unico Emergenze 112: triage, smistamento agli enti, gestione interventi'
version     '1.0.0'

shared_scripts {
    '@aurea_core/bridge/aurea.lua',
    'config.lua',
}
client_scripts { 'client/main.lua', 'client/rilevatori.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'aurea_core',
    'aurea_ui',
    'ita_codicestrada',
}
