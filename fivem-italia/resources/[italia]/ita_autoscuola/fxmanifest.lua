fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_autoscuola'
author      'AUREA · Italia Roleplay'
description 'Autoscuola: quiz sul Codice della Strada ed esame di guida su percorso, con bocciatura'
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
    'ita_codicestrada',
    'ita_fisco',
}
