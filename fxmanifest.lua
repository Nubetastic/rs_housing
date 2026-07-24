fx_version "adamant"
games {"rdr3"}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

version '1.0.0'

ui_page {
	'html/ui.html'
}

files {
	'html/ui.html',
}

shared_scripts {
    'config.lua', 
    'locales.lua'
}
client_scripts { 
    '@ox_lib/init.lua',
    'doorhashes.lua',
    'client/admin_disabled_properties.lua',
    'client/clientfurniture.lua',
    'client/clientshop.lua',
    'client/doorlocks.lua',
    'client/functions.lua',
    'client/main.lua',
    'client/menu.lua',

    -- One-time property value updater. Comment this line out after running UpdatePropertyValues.
    --'client/update_property_values.lua'
    --'client/doorInfo.lua',
}
server_scripts { 
    'server/versionchecker.lua',
    'server/admin_disabled_properties.lua',
    'server/ambush.lua',
    'server/serverfurniture.lua',
    'server/servershop.lua',
    'server/server_doorlocks.lua',
    'server/server_keyholders.lua',
    'server/server_main.lua',

    -- One-time property value updater. Comment this line out after running UpdatePropertyValues.
    --'server/update_property_values.lua'
}

lua54 'yes'
