fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_usura'
author      'AUREA · Italia Roleplay'
description 'Prestiti fra privati, tasso soglia, morosità, denuncia per usura ex art. 644 c.p.'
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
    'ita_giustizia',
    'ita_famiglie',
    'ita_fisco',
}
