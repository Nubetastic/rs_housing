local AMBUSH_RESOURCE = 'Nt_Ambient_Ambush'
local AMBUSH_RANGE = 100
local registered = false

local function AddPropertyAmbushCoords()
    if registered or GetResourceState(AMBUSH_RESOURCE) ~= 'started' then
        return
    end

    local addedCount = 0

    for propertyId, property in pairs(Config.Properties or {}) do
        local coords = property.Locations and property.Locations.MenuActions

        if coords then
            local added = exports[AMBUSH_RESOURCE]:addCoords(coords, AMBUSH_RANGE)

            if added then
                addedCount = addedCount + 1
            elseif Config.Debug then
                print(('[rs_housing] Ambush coordinates were not added for property %s.'):format(propertyId))
            end
        elseif Config.Debug then
            print(('[rs_housing] Property %s has no MenuActions coordinates.'):format(propertyId))
        end
    end

    registered = true

    if Config.Debug then
        print(('[rs_housing] Added %d property locations to %s.'):format(addedCount, AMBUSH_RESOURCE))
    end
end

CreateThread(function()
    AddPropertyAmbushCoords()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == AMBUSH_RESOURCE then
        registered = false
        AddPropertyAmbushCoords()
    end
end)
