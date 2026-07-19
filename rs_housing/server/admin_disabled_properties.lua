local RSGCore = exports['rsg-core']:GetCoreObject()

RSGCore.Commands.Add(
    'disabledproperties',
    'Toggle disabled property blips on the map',
    {},
    false,
    function(source)
        if source == 0 then return end
        TriggerClientEvent('rs_housing:client:toggleDisabledPropertyBlips', source)
    end,
    'admin'
)
