fx_version 'cerulean'
game 'gta5'

name 'Object Builder'
author 'West'
description 'Lightweight production-safe in-game object placement tool'
version '1.0.0'

lua54 'yes'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
