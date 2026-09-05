fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'aurea_banca'
author      'AUREA · Italia Roleplay'
description 'Conti correnti con IBAN, bonifici, ATM, mutui e finanziamenti'
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
    'ita_codicestrada',
    'ita_fisco',
}
