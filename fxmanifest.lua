--[[ FX Information ]] --
fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'
version '1.0.0'

files {
	'config/config.js',
	'config/config.lua',
	'locales/**',
	'web/**'
}

shared_scripts {
	'@vrp/lib/Utils.lua',
	'@ox_lib/init.lua',
	'setup.lua',
	'locales/*.lua',
}
server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua'
}

client_scripts {
	'client/*.lua'
}


ui_page 'web/index.html'