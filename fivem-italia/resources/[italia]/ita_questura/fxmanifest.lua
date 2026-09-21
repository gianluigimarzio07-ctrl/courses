fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_questura'
author      'AUREA · Italia Roleplay'
description 'Licenze di polizia: passaporto, porto d\'armi, licenza di pubblico spettacolo, DASPO'
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
    'aurea_armi',
    'ita_giustizia',
    'ita_fisco',
    'ita_tabaccheria',
}
