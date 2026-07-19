local MenuData = {}

TriggerEvent("rsg-menubase:getData", function(call)
    MenuData = call
end)

local globalpropname   = nil
local globalpropconfig = nil
local inmenu           = false
local placefurniture   = false
local placedobject     = false
local objectxyz        = nil
local x, y, z         = 0, 0, 0
local h                = 0
local actionQueue      = nil
local actionSpeed      = 0.01
local menuOpen         = false
local int              = 0.5
local furnitem
local furnitemcost
local furniname
local thefurniitem
local xx, yy, zz, hh
local furniturex       = {}
local furniitems       = {}
local spawnedfurniture = {}
local hidePlacementText = false
local created           = false
local decorationOpen    = false
local decorationView    = nil
local decorationEntries = {}
local decorationCategory = nil
local selectedSellFurniture = nil
local browsePreview     = false
local cameraDragActive  = false
local cameraDragControl = nil
local cameraDragGrace   = 0
local decorationPreviewRequest = 0
local DECORATION_PREVIEW_DISTANCE = tonumber(Config.DecorationPreviewDistance) or 3.0
local DECORATION_PREVIEW_DELAY = tonumber(Config.DecorationPreviewSpawnDelay) or 250
local DECORATION_PREVIEW_CLEANUP_RADIUS = tonumber(Config.DecorationPreviewCleanupRadius) or 10.0

local function drawtext(str, dx, dy, w, h2, shadow, r, g, b, a, centre)
    local s = CreateVarString(10, "LITERAL_STRING", str, Citizen.ResultAsLong())
    SetTextScale(w, h2)
    SetTextColor(math.floor(r), math.floor(g), math.floor(b), math.floor(a))
    SetTextCentre(centre)
    if shadow then SetTextDropshadow(1, 0, 0, 0, 255) end
    Citizen.InvokeNative(0xADA9255D, 10)
    DisplayText(s, dx, dy)
end

local function GetGameplayCameraForwardVector()
    local rotation = GetGameplayCamRot(2)
    local heading = math.rad(rotation.z)

    return vector3(-math.sin(heading), math.cos(heading), 0.0)
end

local function DistanceToProperty(propconfig)
    local center = propconfig.Locations.MenuActions
    local pos    = GetEntityCoords(PlayerPedId())
    return GetDistanceBetweenCoords(pos.x, pos.y, pos.z, center.x, center.y, center.z, true)
end

local function IsInRange()
    if not globalpropconfig then return false end
    return DistanceToProperty(globalpropconfig) <= globalpropconfig.actionsRange
end

RegisterNUICallback("menuAction", function(data, cb)
    actionQueue = data.action
    actionSpeed = tonumber(data.speed) or 0.5
    cb("ok")
end)

local function OpenFurnitureMenu()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        action = 'placement',
        show = true,
        lang = {
            title          = Locales['TITLE'],
            speed          = Locales['SPEED'],
            positionGroup  = Locales['POSITIONGROUP'],
            elevationGroup = Locales['ELEVATIONGROUP'],
            rotationGroup  = Locales['ROTATIONGROUP'],
            forward        = Locales['FORWARD'],
            backward       = Locales['BACKWARD'],
            left           = Locales['LEFT'],
            right          = Locales['RIGHT'],
            up             = Locales['UP'],
            down           = Locales['DOWN'],
            rotPlus        = Locales['ROTPLUS'],
            rotMinus       = Locales['ROTMINUS'],
            confirm        = Locales['CONFIRM'],
            cancel         = Locales['CANCEL'],
        }
    })
    menuOpen = true
end

local function CloseFurnitureMenu()
    cameraDragActive = false
    cameraDragControl = nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close', show = false })
    menuOpen = false
end

local function DeleteDecorationPreview()
    decorationPreviewRequest = decorationPreviewRequest + 1
    browsePreview = false

    if objectxyz and DoesEntityExist(objectxyz) then
        DeleteObject(objectxyz)
    end

    objectxyz = nil
end

local function NormalizeModelHash(model)
    model = tonumber(model)
    if not model then return nil end
    return model < 0 and model + 4294967296 or model
end

local function CleanupOrphanedDecorationPreviews(keepModel)
    local configuredModels = {}
    local keepHash = NormalizeModelHash(keepModel)

    for _, furnitureItems in pairs(Config.furniture or {}) do
        for _, furniture in pairs(furnitureItems) do
            local model = NormalizeModelHash(furniture.hash)
            if model then configuredModels[model] = true end
        end
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, entity in ipairs(GetGamePool('CObject')) do
        if entity ~= objectxyz and DoesEntityExist(entity) then
            local model = NormalizeModelHash(GetEntityModel(entity))

            if model ~= keepHash and configuredModels[model]
                and GetEntityAlpha(entity) < 255 then
                local coords = GetEntityCoords(entity)
                local distance = GetDistanceBetweenCoords(
                    playerCoords.x, playerCoords.y, playerCoords.z,
                    coords.x, coords.y, coords.z,
                    true
                )

                if distance <= DECORATION_PREVIEW_CLEANUP_RADIUS then
                    SetEntityAsMissionEntity(entity, true)
                    DeleteObject(entity)
                end
            end
        end
    end
end

local function CloseDecorationMenu(clearPreview)
    cameraDragActive = false
    cameraDragControl = nil
    decorationOpen = false
    decorationView = nil
    decorationEntries = {}
    selectedSellFurniture = nil

    if clearPreview then
        DeleteDecorationPreview()
    end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close', show = false })
end

local function ExitDecorationMenu()
    CloseDecorationMenu(true)
    inmenu = false

    local PlayerData = GetPlayerData()
    PlayerData.IsInMenu = false

    FreezeEntityPosition(PlayerPedId(), false)
    ClearPedTasks(PlayerPedId())
    MenuData.CloseAll()
end

local function SetDecorationView(view, title, subtitle, entries)
    decorationOpen = true
    decorationView = view
    decorationEntries = entries or {}
    selectedSellFurniture = nil

    local items = {}
    for index, entry in ipairs(decorationEntries) do
        items[index] = {
            label = entry.label or '',
            description = entry.description or ''
        }
    end

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        action = 'decoration',
        show = true,
        title = title,
        subtitle = subtitle or '',
        items = items,
        emptyText = 'No furniture available.'
    })
end

local function SpawnDecorationPreview(entry)
    DeleteDecorationPreview()

    if not entry or not entry.data or not entry.data.hash then return end

    local model = entry.data.hash
    local requestId = decorationPreviewRequest

    Wait(DECORATION_PREVIEW_DELAY)

    if requestId ~= decorationPreviewRequest
        or not decorationOpen or decorationView ~= 'buy_items' then
        return
    end

    CleanupOrphanedDecorationPreviews(model)

    if not HasModelLoaded(model) then
        RequestModel(model)
    end

    local waited = 0
    while not HasModelLoaded(model) and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end

    if requestId ~= decorationPreviewRequest
        or not decorationOpen or decorationView ~= 'buy_items' then
        return
    end

    if not HasModelLoaded(model) then
        lib.notify({
            title = Locales['HOUSING_NOTI'],
            description = Locales['FURNITURE_NOT_FOUND'],
            type = 'error',
            duration = 3000,
            position = 'top'
        })
        return
    end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local forward = GetGameplayCameraForwardVector()

    objectxyz = CreateObject(
        model,
        pos.x + forward.x * DECORATION_PREVIEW_DISTANCE,
        pos.y + forward.y * DECORATION_PREVIEW_DISTANCE,
        pos.z,
        false, false, false
    )

    if not objectxyz or objectxyz == 0 then return end

    PlaceObjectOnGroundProperly(objectxyz)
    SetEntityAsMissionEntity(objectxyz, true)
    SetEntityCollision(objectxyz, false, false)
    FreezeEntityPosition(objectxyz, true)
    SetEntityAlpha(objectxyz, 153)
    SetEntityHeading(objectxyz, GetEntityHeading(ped))
    browsePreview = true
end

function OpenDecorationMain()
    DeleteDecorationPreview()
    decorationCategory = nil

    SetDecorationView('main', 'Decoration Menu',
        ('Property %s'):format(globalpropname or '?'), {
            { kind = 'buy', label = 'Buy Furniture', description = 'Browse furniture categories.' },
            { kind = 'sell', label = 'Sell Furniture', description = 'Select placed furniture to sell.' },
            { kind = 'exit', label = 'Exit', description = 'Close the decoration menu.' }
        })
end

function OpenDecorationCategories()
    DeleteDecorationPreview()
    decorationCategory = nil

    local categories = {}
    for category in pairs(Config.furniture) do
        categories[#categories + 1] = category
    end
    table.sort(categories)

    local entries = {}
    for _, category in ipairs(categories) do
        entries[#entries + 1] = {
            kind = 'category',
            label = category,
            category = category
        }
    end

    SetDecorationView('categories', 'Buy Furniture', 'Select a category', entries)
end

function OpenDecorationItems(category)
    decorationCategory = category

    local sorted = {}
    for name, data in pairs(Config.furniture[category] or {}) do
        sorted[#sorted + 1] = { name = name, data = data }
    end
    table.sort(sorted, function(a, b) return a.name < b.name end)

    local entries = {}
    for _, entry in ipairs(sorted) do
        entries[#entries + 1] = {
            kind = 'buy_item',
            label = entry.name,
            description = ('$%s'):format(entry.data.cost or 0),
            name = entry.name,
            data = entry.data
        }
    end

    SetDecorationView('buy_items', category, 'Walk around to preview furniture', entries)
end

function OpenDecorationSell()
    DeleteDecorationPreview()

    local entries = {}
    for _, furniture in ipairs(furniturex) do
        local sellPrice = math.floor((furniture.price or 0) * Config.furnituresellrate)
        entries[#entries + 1] = {
            kind = 'sell_item',
            label = furniture.name or '?',
            description = ('$%s'):format(sellPrice),
            data = furniture
        }
    end

    SetDecorationView('sell_items', 'Sell Furniture',
        'The selected object is marked with a red ring', entries)
end

RegisterNUICallback('decorationNavigate', function(data, cb)
    local entry = decorationEntries[tonumber(data.index)]

    selectedSellFurniture = nil
    if decorationView == 'buy_items' then
        SpawnDecorationPreview(entry)
    elseif decorationView == 'sell_items' and entry then
        selectedSellFurniture = entry.data
    end

    cb('ok')
end)

RegisterNUICallback("cameraDragStart", function(data, cb)
    if (menuOpen or decorationOpen) and not cameraDragActive then
        cameraDragActive = true
        cameraDragControl = data.button == 'right' and 0xF84FA74F or 0x07CE1E61
        cameraDragGrace = GetGameTimer() + 250
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(true)
    end

    cb("ok")
end)

RegisterNUICallback('decorationSelect', function(data, cb)
    local entry = decorationEntries[tonumber(data.index)]
    if not entry then cb('ok') return end

    if entry.kind == 'buy' then
        OpenDecorationCategories()
    elseif entry.kind == 'sell' then
        OpenDecorationSell()
    elseif entry.kind == 'exit' then
        ExitDecorationMenu()
    elseif entry.kind == 'category' then
        OpenDecorationItems(entry.category)
    elseif entry.kind == 'sell_item' then
        TriggerServerEvent('rs_furniture:server:sell', globalpropname, tostring(entry.data.id))
        OpenDecorationMain()
    elseif entry.kind == 'buy_item' then
        if not objectxyz or not DoesEntityExist(objectxyz) then
            SpawnDecorationPreview(entry)
        end

        if objectxyz and DoesEntityExist(objectxyz) then
            furnitem = entry.data.hash
            furnitemcost = entry.data.cost
            furniname = entry.name
            browsePreview = false
            decorationOpen = false
            decorationView = 'placement'
            selectedSellFurniture = nil
            placefurniture = true
            placedobject = true
            created = true
            hidePlacementText = true

            local coords = GetEntityCoords(objectxyz)
            x, y, z = coords.x, coords.y, coords.z
            h = GetEntityHeading(objectxyz)

            OpenFurnitureMenu()
        end
    end

    cb('ok')
end)

RegisterNUICallback('decorationBack', function(_, cb)
    if decorationView == 'categories' then
        OpenDecorationMain()
    elseif decorationView == 'buy_items' then
        OpenDecorationCategories()
    elseif decorationView == 'sell_items' then
        OpenDecorationMain()
    else
        ExitDecorationMenu()
    end

    cb('ok')
end)

RegisterNUICallback('decorationClose', function(_, cb)
    ExitDecorationMenu()
    cb('ok')
end)

Citizen.CreateThread(function()
    while true do
        local sleep = 500

        if decorationOpen then
            sleep = 0

            if not IsInRange() then
                ExitDecorationMenu()
                lib.notify({
                    title = Locales['HOUSING_NOTI'],
                    description = Locales['FURNITURE_TOO_FAR'],
                    type = 'error',
                    duration = 3000,
                    position = 'top'
                })
            elseif selectedSellFurniture then
                local furniture = selectedSellFurniture
                Citizen.InvokeNative(
                    0x2A32FAA57B937173,
                    0x94FDAE17,
                    furniture.x, furniture.y, furniture.z,
                    0, 0, 0, 0, 0, 0,
                    Config.Checkpoints.size,
                    Config.Checkpoints.size,
                    Config.Checkpoints.height,
                    255, 0, 0, 180,
                    0, 0, 2,
                    Config.Checkpoints.rotate,
                    0, 0, 0
                )
            end
        end

        Wait(sleep)
    end
end)

local function CancelFurniturePlacement()
    placefurniture = false
    placedobject = false
    created = false
    hidePlacementText = false
    actionQueue = nil

    if objectxyz and DoesEntityExist(objectxyz) then
        DeleteObject(objectxyz)
    end
    objectxyz = nil

    CloseFurnitureMenu()

    if not Config.furnitureitems and decorationCategory and IsInRange() then
        inmenu = true
        OpenDecorationItems(decorationCategory)
        return
    end

    inmenu = false
    local PlayerData = GetPlayerData()
    PlayerData.IsInMenu = false
end

Citizen.CreateThread(function()
    while true do
        if decorationOpen and decorationView == 'buy_items'
            and browsePreview and objectxyz and DoesEntityExist(objectxyz) then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local forward = GetGameplayCameraForwardVector()

            SetEntityCoordsNoOffset(
                objectxyz,
                pos.x + forward.x * DECORATION_PREVIEW_DISTANCE,
                pos.y + forward.y * DECORATION_PREVIEW_DISTANCE,
                pos.z,
                false, false, false
            )
            SetEntityHeading(objectxyz, GetEntityHeading(ped))
            PlaceObjectOnGroundProperly(objectxyz)
            Wait(100)
        else
            Wait(500)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if menuOpen or decorationOpen then
            drawtext(Locales['CAMERA'],
                0.50, 0.05, 0.3, 0.3, true, 0, 255, 0, 255, true)
            local cameraButtonPressed = IsControlPressed(0, 0x07CE1E61)
                or IsControlPressed(0, 0xF84FA74F)

            if not cameraButtonPressed and not cameraDragActive then
                DisableControlAction(0, 0xA987235F, true)
                DisableControlAction(0, 0xD2047988, true)
            end

            if cameraDragActive and GetGameTimer() > cameraDragGrace
                and not IsControlPressed(0, cameraDragControl) then
                cameraDragActive = false
                cameraDragControl = nil
                SetNuiFocus(true, true)
                SetNuiFocusKeepInput(true)
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local sleep = true

        if placefurniture then
            sleep = false

            DisableControlAction(0, Config.keysPlace.Create,  true)
            DisableControlAction(0, Config.keysPlace.Confirm, true)
            DisableControlAction(0, Config.keysPlace.Cancel,  true)

            if not IsInRange() then

                if placedobject and menuOpen then
                    CancelFurniturePlacement()
                    lib.notify({
                        title = Locales['HOUSING_NOTI'],
                        description = Locales['FURNITURE_TOO_FAR'],
                        type = 'error',
                        duration = 3000,
                        position = 'top'
                    })
                else
                    if not created and not hidePlacementText then
                        drawtext(Locales['FURNITURE_TOO_FAR'],
                            0.15, 0.10, 0.1, 0.3, true, 255, 80, 80, 255, true)

                        drawtext(Locales['FOURTOCANCEL'],
                            0.15, 0.13, 0.3, 0.3, true, 255, 255, 255, 255, true)
                    end

                    if IsDisabledControlJustPressed(0, Config.keysPlace.Cancel) then
                        CancelFurniturePlacement()
                    end
                end

            else

                if not created and not hidePlacementText then
                    drawtext(Locales['GITEMPLACE'],
                        0.15, 0.10, 0.1, 0.3, true, 255, 255, 255, 255, true)

                    drawtext(Locales['FOURTOCANCEL'],
                        0.15, 0.13, 0.3, 0.3, true, 255, 255, 255, 255, true)

                    drawtext(Locales['USEDMENU'],
                        0.15, 0.16, 0.3, 0.3, true, 255, 255, 255, 255, true)
                end

                if not HasModelLoaded(furnitem) then
                    RequestModel(furnitem)
                end

                while not HasModelLoaded(furnitem) do
                    Citizen.Wait(1)
                end

                if IsDisabledControlJustPressed(0, Config.keysPlace.Create) then
                    if not placedobject then

                        local myPed   = PlayerPedId()
                        local pos     = GetEntityCoords(myPed, true)
                        local forward = GetEntityForwardVector(myPed)

                        objectxyz = CreateObject(
                            furnitem,
                            pos.x + forward.x * 2.5,
                            pos.y + forward.y * 2.5,
                            pos.z,
                            true, true, false
                        )

                        PlaceObjectOnGroundProperly(objectxyz)
                        SetEntityAsMissionEntity(objectxyz, true)
                        FreezeEntityPosition(objectxyz, true)
                        SetEntityAlpha(objectxyz, 153)

                        placedobject = true
                        created      = true

                        local p = GetEntityCoords(objectxyz, true)

                        x, y, z = p.x, p.y, p.z
                        h       = GetEntityHeading(objectxyz)

                        OpenFurnitureMenu()
                    end
                end

                if placedobject and menuOpen and actionQueue ~= nil then
                    local sp = actionSpeed * int

                    if actionQueue == "x_plus"    then x = x + sp end
                    if actionQueue == "x_minus"   then x = x - sp end
                    if actionQueue == "y_plus"    then y = y + sp end
                    if actionQueue == "y_minus"   then y = y - sp end
                    if actionQueue == "z_plus"    then z = z + sp end
                    if actionQueue == "z_minus"   then z = z - sp end
                    if actionQueue == "rot_plus"  then h = h + (actionSpeed * 5.0) end
                    if actionQueue == "rot_minus" then h = h - (actionSpeed * 5.0) end

                    if actionQueue == "confirm" then
                        xx, yy, zz, hh = x, y, z, h

                        placefurniture = false
                        placedobject   = false
                        created        = false
                        hidePlacementText = false

                        DeleteObject(objectxyz)
                        objectxyz = nil

                        CloseFurnitureMenu()

                        if not Config.furnitureitems then
                            TriggerServerEvent('rs_furniture:server:buy',
                                globalpropname, furnitem, furniname, furnitemcost,
                                xx, yy, zz, hh)

                            inmenu = false
                            local PlayerData = GetPlayerData()
                            PlayerData.IsInMenu = false
                            FreezeEntityPosition(PlayerPedId(), false)
                            ClearPedTasks(PlayerPedId())
                        else
                            Citizen.Wait(500)
                            confirmmenu_furniture(
                                "confirmfurniturebuy",
                                "buyfurnimenu2"
                            )
                        end
                    end

                    if actionQueue == "cancel" then
                        CancelFurniturePlacement()
                    end

                    if objectxyz then
                        SetEntityCoords(objectxyz, x, y, z)
                        SetEntityHeading(objectxyz, h)
                    end

                    actionQueue = nil
                end

                if IsDisabledControlJustPressed(0, Config.keysPlace.Cancel) then
                    CancelFurniturePlacement()
                end
            end
        end

        if sleep then
            Citizen.Wait(500)
        end
    end
end)

local function SpawnFurniture(propname, furniture)
    if spawnedfurniture[propname] then
        for _, ent in ipairs(spawnedfurniture[propname]) do
            if DoesEntityExist(ent) then DeleteObject(ent) end
        end
    end
    spawnedfurniture[propname] = {}

    for _, v in ipairs(furniture) do
        local hash = v.furnitem
        if not HasModelLoaded(hash) then RequestModel(hash) end
        local waited = 0
        while not HasModelLoaded(hash) and waited < 3000 do
            Citizen.Wait(100)
            waited = waited + 100
        end
        if HasModelLoaded(hash) then
            local obj = CreateObjectNoOffset(hash, v.x, v.y, v.z, false, true, false)
            SetEntityAsMissionEntity(obj, true)
            FreezeEntityPosition(obj, true)
            SetEntityHeading(obj, v.h)
            table.insert(spawnedfurniture[propname], obj)
        end
    end
end

local function DespawnFurniture(propname)
    if spawnedfurniture[propname] then
        for _, ent in ipairs(spawnedfurniture[propname]) do
            if DoesEntityExist(ent) then DeleteObject(ent) end
        end
        spawnedfurniture[propname] = nil
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3000)
        local pos = GetEntityCoords(PlayerPedId())

        for propname, propdata in pairs(Config.Properties) do
            local center = propdata.Locations.MenuActions
            local dist   = GetDistanceBetweenCoords(
                pos.x, pos.y, pos.z,
                center.x, center.y, center.z,
                true
            )
            local renderRange = (propdata.actionsRange) + 20.0

            if dist <= renderRange then
                if not spawnedfurniture[propname] then
                    TriggerServerEvent('rs_furniture:server:load', propname)
                end
            else
                if spawnedfurniture[propname] then
                    DespawnFurniture(propname)
                end
            end
        end
    end
end)

RegisterNetEvent('rs_furniture:client:receive')
AddEventHandler('rs_furniture:client:receive', function(propname, furniture)
    if globalpropname == propname then
        furniturex = furniture

        if decorationOpen and decorationView == 'sell_items' then
            OpenDecorationSell()
        end
    end
    SpawnFurniture(propname, furniture)
end)

RegisterNetEvent('rs_furniture:client:useitem')
AddEventHandler('rs_furniture:client:useitem', function(itemname)
    TriggerServerEvent('rs_furniture:server:useitem', itemname)
end)

RegisterNetEvent('rs_furniture:client:tryplaceitem')
AddEventHandler('rs_furniture:client:tryplaceitem', function(furnidata)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local foundProp    = nil
    local foundConfig  = nil

    for propname, propconfig in pairs(Config.Properties) do
        local center = propconfig.Locations.MenuActions
        local dist   = GetDistanceBetweenCoords(
            playerCoords.x, playerCoords.y, playerCoords.z,
            center.x, center.y, center.z,
            true
        )
        if dist <= propconfig.actionsRange then
            foundProp   = propname
            foundConfig = propconfig
            break
        end
    end

    if not foundProp then
        lib.notify({
            title       = Locales['HOUSING_NOTI'],
            description = Locales['FURNITURE_TOO_FAR'],
            type        = 'error',
            duration    = 3000,
            position    = 'top'
        })
        return
    end

    globalpropname   = foundProp
    globalpropconfig = foundConfig

    TriggerServerEvent('rs_furniture:server:checkauth', foundProp, furnidata)
end)

RegisterNetEvent('rs_furniture:client:startplace')
AddEventHandler('rs_furniture:client:startplace', function(propname, furnidata)

    if not IsInRange() then
        lib.notify({
            title       = Locales['HOUSING_NOTI'],
            description = Locales['FURNITURE_TOO_FAR'],
            type        = 'error',
            duration    = 3000,
            position    = 'top'
        })
        return
    end

    thefurniitem = furnidata.item
    furnitem     = furnidata.hash
    furniname    = furnidata.label

    placefurniture   = true
    inmenu           = false
    hidePlacementText = true

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)

    if not HasModelLoaded(furnitem) then
        RequestModel(furnitem)

        while not HasModelLoaded(furnitem) do
            Wait(0)
        end
    end

    objectxyz = CreateObject(
        furnitem,
        pos.x + fwd.x * 2.0,
        pos.y + fwd.y * 2.0,
        pos.z,
        true, true, false
    )

    PlaceObjectOnGroundProperly(objectxyz)
    SetEntityAsMissionEntity(objectxyz, true)
    FreezeEntityPosition(objectxyz, true)
    SetEntityAlpha(objectxyz, 153)

    placedobject = true

    local p = GetEntityCoords(objectxyz)

    x, y, z = p.x, p.y, p.z
    h       = GetEntityHeading(objectxyz)

    OpenFurnitureMenu()

    FreezeEntityPosition(PlayerPedId(), false)
    ClearPedTasks(PlayerPedId())
end)

AddEventHandler('rs_furniture:open', function(propname)
    local propconfig = Config.Properties[propname]
    if not propconfig then
        print('[rs_furniture] Propiedad desconocida: ' .. tostring(propname))
        return
    end

    globalpropname   = propname
    globalpropconfig = propconfig
    furniturex = {}

    TriggerServerEvent('rs_furniture:server:load', propname)

    inmenu = true

    MenuData.CloseAll()
    FreezeEntityPosition(PlayerPedId(), false)
    ClearPedTasks(PlayerPedId())

    if not Config.furnitureitems then
        OpenDecorationMain()
        return
    end

    FreezeEntityPosition(PlayerPedId(), true)
    TaskStandStill(PlayerPedId(), -1)
    furnimenu()
end)

function BackToManagement()
    inmenu = false
    local PlayerData = GetPlayerData()
    PlayerData.IsInMenu = false
    FreezeEntityPosition(PlayerPedId(), false)
    ClearPedTasks(PlayerPedId())
    MenuData.CloseAll()
    OpenMenuManagement(globalpropname)
end

function confirmmenu_furniture(mtype, lastmenux)
    MenuData.CloseAll()

    local elements = {
        { label = Locales['YESPLACE'], value = "yes", desc = "" },
        { label = Locales['NOPLACE'],  value = "no",  desc = "" },
    }

    MenuData.Open("default", GetCurrentResourceName(), "menuapi",
        {
            title    = Locales['CONFIRM'],
            subtext  = "",
            align    = "top-right",
            elements = elements,
            lastmenu = lastmenux,
        },
        function(data, menu)
            if data.current.value == "yes" then
                if mtype == "confirmfurniturebuy" then
                    if not Config.furnitureitems then
                        -- Sin items: compra con dinero
                        TriggerServerEvent('rs_furniture:server:buy',
                            globalpropname, furnitem, furniname, furnitemcost,
                            xx, yy, zz, hh)
                    else
                        -- Con items: coloca gastando el item, coste = 0
                        TriggerServerEvent('rs_furniture:server:place',
                            globalpropname, furnitem, furniname, 0,
                            xx, yy, zz, hh, thefurniitem)
                    end
                    inmenu = false
                    local PlayerData = GetPlayerData()
                    PlayerData.IsInMenu = false
                    FreezeEntityPosition(PlayerPedId(), false)
                    ClearPedTasks(PlayerPedId())
                    MenuData.CloseAll()
                end
            end

            if data.current.value == "no" then
                placefurniture = false
                placedobject   = false
                if objectxyz then DeleteObject(objectxyz) objectxyz = nil end
                inmenu = false
                local PlayerData = GetPlayerData()
                PlayerData.IsInMenu = false
                FreezeEntityPosition(PlayerPedId(), false)
                ClearPedTasks(PlayerPedId())
                MenuData.CloseAll()
            end
        end,
        function(data, menu) menu.close() end
    )
end

function furnimenu()
    MenuData.CloseAll()

    if not Config.furnitureitems then
        FreezeEntityPosition(PlayerPedId(), false)
        ClearPedTasks(PlayerPedId())
        OpenDecorationMain()
        return
    end

    local elements = {}
    local sellPercent = math.floor((Config.sellPercentage or 0.6) * 100)

    if not Config.furnitureitems then
        table.insert(elements, {
            label = Locales['MENU_FURNITURE_BUY'],
            value = "buyfurni",
            desc  = ""
        })
        table.insert(elements, {
            label = Locales['MENU_FURNITURE_SELL'],
            value = "sellfurni",
            desc  = Locales['MENU_FURNITURE_SELL_DESC'] .. " " .. sellPercent .. "%" .. " " .. Locales['MENU_FURNITURE_SELL_DESC_2']
        })
    else
        table.insert(elements, {
            label = Locales['MENU_FURNITURE_REMOVE'],
            value = "removefurni",
            desc  = ""
        })
    end

    table.insert(elements, {
        label = Locales['MENU_BACK'],
        value = "backup",
        desc  = ""
    })

    MenuData.Open("default", GetCurrentResourceName(), "menuapi", {
        title   = Locales['MENU_FURNITURE'],
        subtext = Locales['MENU_FURNITURE_SUBTEXT_PROP'] .. " " .. globalpropname .. " | " .. Locales['MENU_FURNITURE_SUBTEXT_RANGE'] .. " " .. globalpropconfig.actionsRange .. "m",
        align   = "right",
        elements = elements,
    },
    function(data, menu)
        if data.current.value == "backup"      then BackToManagement() return end
        if data.current.value == "buyfurni"    then buyfurnimenu()     return end
        if data.current.value == "sellfurni"   then sellfurnimenu()    return end
        if data.current.value == "removefurni" then removefurnimenu()  return end
    end,
    function(data, menu)
        BackToManagement()
    end)
end

function buyfurnimenu()
    MenuData.CloseAll()
    local elements = {}
    for k, v in pairs(Config.furniture) do
        table.insert(elements, { label = k, value = v, desc = "" })
    end
    table.insert(elements, { label = Locales['MENU_BACK'], value = "backup", desc = "" })

    MenuData.Open("default", GetCurrentResourceName(), "menuapi",
        {
            title    = Locales['MENU_FURNITURE'],
            subtext  = "",
            align    = "right",
            elements = elements,
        },
        function(data, menu)
            if data.current == "backup" or data.current.value == "backup" then
                furnimenu() return
            end
            buyfurnimenu2(data.current.value)
        end,
        function(data, menu)
            furnimenu()
        end
    )
end

function buyfurnimenu2(furnigroup)
    MenuData.CloseAll()

    local elements = {}

    for k, v in pairs(furnigroup) do
        table.insert(elements, {
            label = k .. " - $" .. v.cost,
            value = v,
            namee = k,
            desc  = "",
        })
    end

    table.insert(elements, {
        label = Locales['MENU_BACK'],
        value = "backup",
        desc  = ""
    })

    MenuData.Open("default", GetCurrentResourceName(), "menuapi",
    {
        title    = Locales['MENU_FURNITURE'],
        subtext  = "",
        align    = "right",
        elements = elements,
    },
    function(data, menu)

        if data.current == "backup"
        or data.current.value == "backup" then
            buyfurnimenu()
            return
        end

        furnitem       = data.current.value.hash
        furnitemcost   = data.current.value.cost
        furniname      = data.current.namee

        placefurniture   = true
        hidePlacementText = false

        inmenu = false

        local PlayerData = GetPlayerData()
        PlayerData.IsInMenu = false

        MenuData.CloseAll()

        FreezeEntityPosition(PlayerPedId(), false)
        ClearPedTasks(PlayerPedId())

    end,
    function(data, menu)
        buyfurnimenu()
    end)
end

function sellfurnimenu()
    MenuData.CloseAll()
    local elements = {}
    if next(furniturex) ~= nil then
        for _, v in ipairs(furniturex) do
            local sellprice = math.floor((v.price or 0) * Config.furnituresellrate)
            table.insert(elements, {
                label = (v.name or "?") .. " - $" .. sellprice,
                value = v,
                desc  = "",
            })
        end
    end
    table.insert(elements, { label = Locales['MENU_BACK'], value = "backup", desc = "" })

    MenuData.Open("default", GetCurrentResourceName(), "menuapi",
        {
            title    = Locales['MENU_FURNITURE'],
            subtext  = "",
            align    = "right",
            elements = elements,
        },
        function(data, menu)
            if data.current == "backup" or data.current.value == "backup" then
                furnimenu() return
            end
            TriggerServerEvent('rs_furniture:server:sell',
                globalpropname, tostring(data.current.value.id))
            inmenu = false
            local PlayerData = GetPlayerData()
            PlayerData.IsInMenu = false
            FreezeEntityPosition(PlayerPedId(), false)
            ClearPedTasks(PlayerPedId())
            MenuData.CloseAll()
        end,
        function(data, menu)
            furnimenu()
        end
    )
end

function removefurnimenu()
    MenuData.CloseAll()
    local elements = {}
    if next(furniturex) ~= nil then
        for _, v in ipairs(furniturex) do
            table.insert(elements, {
                label = v.name or "?",
                value = v,
                desc  = "",
            })
        end
    end
    table.insert(elements, { label = Locales['MENU_BACK'], value = "backup", desc = "" })

    MenuData.Open("default", GetCurrentResourceName(), "menuapi",
        {
            title    = Locales['MENU_FURNITURE'],
            subtext  = "",
            align    = "right",
            elements = elements,
        },
        function(data, menu)
            if data.current == "backup" or data.current.value == "backup" then
                furnimenu() return
            end
            TriggerServerEvent('rs_furniture:server:remove',
                globalpropname, tostring(data.current.value.id))
            inmenu = false
            local PlayerData = GetPlayerData()
            PlayerData.IsInMenu = false
            FreezeEntityPosition(PlayerPedId(), false)
            ClearPedTasks(PlayerPedId())
            MenuData.CloseAll()
        end,
        function(data, menu)
            furnimenu()
        end
    )
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CloseDecorationMenu(true)
        CloseFurnitureMenu()

        for propname, entities in pairs(spawnedfurniture) do
            for _, ent in ipairs(entities) do
                if DoesEntityExist(ent) then DeleteObject(ent) end
            end
        end
    end
end)
