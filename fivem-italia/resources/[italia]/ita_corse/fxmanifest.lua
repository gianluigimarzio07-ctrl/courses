fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_corse'
author      'AUREA · Italia Roleplay'
description 'Competizioni di velocità non autorizzate: quote, checkpoint validati dal server, art. 9-ter CdS e confisca'
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
    'ita_codicestrada',
    'ita_veicoli',
    'ita_112',
}
