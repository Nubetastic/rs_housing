local TARGET_OPTION_NAME = 'rs_housing:doorInfo'

local function PrintDoorInfo(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        print('[rs_housing] Door Info: unable to read the selected object.')
        return
    end

    local coords = GetEntityCoords(entity)
    local yaw = GetEntityHeading(entity)
    local modelHash = GetEntityModel(entity)

    print(('^3[rs_housing] Door Info^7\n' ..
        'entity = %s\n' ..
        'modelHash = %s\n' ..
        'objCoords = vector3(%.6f, %.6f, %.6f),\n' ..
        'objYaw = %.6f,')
        :format(entity, modelHash, coords.x, coords.y, coords.z, yaw))
end

CreateThread(function()
    if GetResourceState('ox_target') ~= 'started' then
        print('^1[rs_housing] Door Info requires ox_target to be started.^7')
        return
    end

    exports.ox_target:addGlobalObject({
        {
            name = TARGET_OPTION_NAME,
            icon = 'fa-solid fa-door-open',
            label = 'Print Door Info',
            distance = 2.0,
            onSelect = function(data)
                PrintDoorInfo(data.entity)
            end
        }
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if GetResourceState('ox_target') ~= 'started' then return end

    exports.ox_target:removeGlobalObject(TARGET_OPTION_NAME)
end)
