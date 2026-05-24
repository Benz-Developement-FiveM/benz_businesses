fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbox_all_businesses'
author 'OpenAI'
description 'Modern Qbox business system with tablet UI, DJ booths, deliveries, employees, and accounts'
version '5.2.8'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'item_images/*.png'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'ox_target',
    'xsound',
    'Renewed-Banking'
}
