fx_version 'cerulean'
game 'gta5'

name 'Object Builder'
author 'West'
description 'Lightweight production-safe in-game object placement tool'
version '1.1.0'

lua54 'yes'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

shared_scripts {
    'shared/config.lua',
    'shared/utils.lua',
    'shared/schema.lua'
}

client_scripts {
    'client/selection.lua',
    'client/editor.lua',
    'client/main.lua'
}

server_scripts {
    'server/validators.lua',
    'server/session.lua',
    'server/history.lua',
    'server/main.lua'
}
