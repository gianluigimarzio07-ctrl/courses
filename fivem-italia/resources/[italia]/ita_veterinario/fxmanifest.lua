fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'ita_veterinario'
author      'AUREA · Italia Roleplay'
description 'Visite, vaccinazioni con scadenza e accertamento di maltrattamento di animali (art. 544-ter c.p.)'
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
    'aurea_animali',
    'ita_giustizia',
    'ita_fisco',
}
