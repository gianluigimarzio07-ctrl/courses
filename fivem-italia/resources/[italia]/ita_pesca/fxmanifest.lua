fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_pesca'
author      'AUREA · Italia Roleplay'
description 'Pesca professionale: licenza, quote condivise, mercato ittico a prezzo variabile, vendita in nero e controlli'
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
    'ita_nautica',
    'ita_fisco',
    'ita_famiglie',
}
