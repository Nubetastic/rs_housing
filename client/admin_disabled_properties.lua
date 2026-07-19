local disabledPropertyBlips = {}

local function RemoveDisabledPropertyBlips()
    for _, blip in pairs(disabledPropertyBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    disabledPropertyBlips = {}
end

local function CreateDisabledPropertyBlips()
    for propertyId, property in pairs(Config.DisabledProperties or {}) do
        local coords = property.Locations and property.Locations.PrimaryEntrance

        if coords then
            local blip = N_0x554d9d53f696d002(1664425300, coords)
            SetBlipSprite(blip, Config.PropertyBlips.OnSale.Sprite, 1)
            SetBlipScale(blip, 0.2)
            Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey('BLIP_MODIFIER_MP_COLOR_2'))
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, ('Disabled Property (#%s)'):format(propertyId))
            disabledPropertyBlips[propertyId] = blip
        end
    end
end

RegisterNetEvent('rs_housing:client:toggleDisabledPropertyBlips', function()
    if next(disabledPropertyBlips) then
        RemoveDisabledPropertyBlips()
        lib.notify({
            title = 'Disabled Properties',
            description = 'Disabled property blips hidden.',
            type = 'inform'
        })
        return
    end

    CreateDisabledPropertyBlips()

    local count = 0
    for _ in pairs(disabledPropertyBlips) do
        count = count + 1
    end

    lib.notify({
        title = 'Disabled Properties',
        description = count > 0
            and ('Showing %s disabled properties.'):format(count)
            or 'There are no disabled properties.',
        type = count > 0 and 'success' or 'inform'
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RemoveDisabledPropertyBlips()
end)
