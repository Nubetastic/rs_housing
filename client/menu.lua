local MenuData = {}
local RSGCore = exports['rsg-core']:GetCoreObject()

TriggerEvent("rsg-menubase:getData", function(call)
    MenuData = call
end)

local LocationType    = nil
local CurrentProperty = nil

function OpenMenuManagement(propertyId)

    local PlayerData = GetPlayerData()

    if LocationType then
        return
    end

    MenuData.CloseAll()

    if CurrentProperty == nil then
        CurrentProperty = propertyId
    end

    PlayerData.IsInMenu = true

    local property = PlayerData.Properties[CurrentProperty]

    TaskStandStill(PlayerPedId(), -1)

    local options = {}

    for _, option in pairs(Config.ManagementMenu) do

        -- Saltamos MENU_LEDGER porque lo controlaremos manualmente
        if option.Type ~= "MENU_LEDGER" and option.Enabled then

            local label = Locales[option.Type]
            local description = Locales[option.Type .. "_DESCRIPTION"]

            if option.Type == 'MENU_SELL' then
                label = string.format(Locales['MENU_SELL_WITH_PRICE'], property.sell.receive)
                description = string.format(Locales['MENU_SELL_DESCRIPTION_DOLLARS'], property.sell.receive)
            end

            table.insert(options, {
                label = label,
                value = option.Type,
                desc  = description
            })
        end
    end

    if Config.TaxRepoSystem.Enabled then
        table.insert(options, {
            label = Locales['MENU_LEDGER'],
            value = "MENU_LEDGER",
            desc  = Locales['MENU_LEDGER_DESCRIPTION']
        })
    end

    table.insert(options, {
        label = Locales['MENU_FURNITURE'],
        value = "MENU_FURNITURE",
        desc  = Locales['MENU_FURNITURE_DESCRIPTION']
    })

    table.insert(options, {
        label = Locales['MENU_EXIT'],
        value = "backup",
        desc  = ""
    })

    MenuData.Open('default', GetCurrentResourceName(), 'main',

    {
        title    = string.format(Locales['MENU_PROPERTY_TITLE'], CurrentProperty),
        subtext  = "",
        align    = "right",
        elements = options,
    },

    function(data, menu)
        if (data.current == "backup") then
            return
        end

        if (data.current.value == "backup") then
            MenuData.CloseAll()
            TaskStandStill(PlayerPedId(), 1)

            PlayerData.IsInMenu = false

            CurrentProperty = nil
            return

        elseif (data.current.value == "MENU_WARDROBE_LOCATION") then

            if HasPermissionByName(CurrentProperty, 'set_wardrobe', PlayerData.CitizenId) == 0 then
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INSUFFICIENT_PERMISSIONS'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
                return
            end

            MenuData.CloseAll()
            LocationType = string.upper(data.current.value)
            TaskStandStill(PlayerPedId(), 1)

        elseif (data.current.value == "MENU_STORAGE_LOCATION") then

            if HasPermissionByName(CurrentProperty, 'set_storage', PlayerData.CitizenId) == 0 then
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INSUFFICIENT_PERMISSIONS'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
                return
            end

            MenuData.CloseAll()
            LocationType = string.upper(data.current.value)
            TaskStandStill(PlayerPedId(), 1)

        elseif (data.current.value == "MENU_LEDGER") then

            OpenMenuLedger()

        elseif (data.current.value == "MENU_LEDGER_HOME") then

            OpenMenuLedgerHome()

        elseif (data.current.value == "MENU_SET_KEYHOLDERS") then

            if HasPermissionByName(CurrentProperty, 'keyholders', PlayerData.CitizenId) == 0 then
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INSUFFICIENT_PERMISSIONS'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
                return
            end

            OpenMenuKeyholders()

        elseif (data.current.value == "MENU_TRANSFER") then

            if property.citizenid ~= PlayerData.CitizenId then
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INSUFFICIENT_PERMISSIONS'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
                return
            end

            local input = lib.inputDialog(Locales['MENU_TRANSFER_TITLE'], {
                {
                    type     = 'number',
                    label    = Locales['MENU_TRANSFER_DESCRIPTION'],
                    required = true,
                    min      = 1,
                }
            })

            if input and input[1] then

                local inputId = tonumber(input[1])

                if inputId == GetPlayerServerId(PlayerId()) then
                    lib.notify({
                        title       = Locales['HOUSING_NOTI'],
                        description = Locales['CANNOT_TRANSFER_TO_SAME_PERSON'],
                        type        = 'error',
                        duration    = 3000,
                        position    = 'top'
                    })
                    return
                end

                local nearestPlayers = GetNearestPlayers(3.0)
                local foundPlayer    = false

                for _, targetPlayer in pairs(nearestPlayers) do
                    if inputId == GetPlayerServerId(targetPlayer) then
                        foundPlayer = true
                    end
                end

                if foundPlayer then

                    TriggerServerEvent("rs_housing:server:transferOwnedProperty", CurrentProperty, inputId)

                    TaskStandStill(PlayerPedId(), 1)

                    PlayerData.IsInMenu = false

                    CurrentProperty = nil
                    MenuData.CloseAll()

                else
                    lib.notify({
                        title       = Locales['HOUSING_NOTI'],
                        description = Locales['PLAYER_NOT_FOUND'],
                        type        = 'error',
                        duration    = 3000,
                        position    = 'top'
                    })
                end

            else
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INVALID_INPUT'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
            end

        elseif (data.current.value == "MENU_SELL") then

            if property.citizenid ~= PlayerData.CitizenId then
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INSUFFICIENT_PERMISSIONS'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
                return
            end

            OpenMenuSellProperty()

        elseif (data.current.value == "MENU_FURNITURE") then

            if HasPermissionByName(CurrentProperty, 'place_furniture', PlayerData.CitizenId) == 0 then
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INSUFFICIENT_PERMISSIONS'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
                return
            end

            MenuData.CloseAll()
            TriggerEvent('rs_furniture:open', CurrentProperty)

        end

    end,

    function(data, menu)
        TaskStandStill(PlayerPedId(), 1)
        PlayerData.IsInMenu = false
        CurrentProperty = nil
        MenuData.CloseAll()
    end)

end

function OpenMenuSellProperty()
    MenuData.CloseAll()

    local PlayerData = GetPlayerData()

    local options  = {
        {
            label = Locales['MENU_SELL_ACCEPT'], 
            value = "accept", 
            desc  = Locales['MENU_SELL_ACCEPT_DESCRIPTION'],
        },
        {
            label = Locales['MENU_BACK'],
            value = "backup", 
            desc  = "",
        },
    }

    MenuData.Open('default', GetCurrentResourceName(), 'menu_sell',

    {
        title    = string.format(Locales['MENU_PROPERTY_TITLE'], CurrentProperty),
        subtext  = "",
        align    = "right",
        elements = options,
    },

    function(data, menu)

        if (data.current.value == "backup") then
            OpenMenuManagement()

        elseif (data.current.value == "accept") then

            TriggerServerEvent("rs_housing:server:sell", CurrentProperty)

            TaskStandStill(PlayerPedId(), 1)
            PlayerData.IsInMenu = false

            CurrentProperty = nil
            MenuData.CloseAll()
        end

    end,

    function(data, menu)
        OpenMenuManagement()
    end)

end

function OpenMenuKeyholders() 
    MenuData.CloseAll()

    local options  = {
        {
            label = Locales['MENU_KEYHOLDERS_LIST'], 
            value = "list", 
            desc  = "",
        },
        {
            label = Locales['MENU_KEYHOLDERS_ADD_NEW'], 
            value = "add", 
            desc  = "",
        },
        {
            label = Locales['MENU_BACK'],
            value = "backup", 
            desc  = "",
        },
    }

    MenuData.Open('default', GetCurrentResourceName(), 'menu_keyholders_main',

    {
        title    = string.format(Locales['MENU_PROPERTY_TITLE'], CurrentProperty),
        subtext  = "",
        align    = "right",
        elements = options,
    },

    function(data, menu)

        if (data.current.value == "backup") then
            OpenMenuManagement()

        elseif (data.current.value == "list") then
            OpenMenuKeyholdersList()

        elseif (data.current.value == "add") then

            local input = lib.inputDialog(Locales['MENU_KEYHOLDERS_ADD_NEW_TITLE'], {
                {
                    type     = 'number',
                    label    = Locales['MENU_KEYHOLDERS_ADD_NEW_DESCRIPTION'],
                    required = true,
                    min      = 1,
                }
            })

            if input and input[1] then

                local inputId = tonumber(input[1])

                local PlayerData = GetPlayerData()
                local property   = PlayerData.Properties[CurrentProperty]

                if property.keyholders == nil then
                    property.keyholders = {}
                end

                local length = 0
                for _ in pairs(property.keyholders) do
                    length = length + 1
                end

                if length < Config.MaxHouseKeyHolders then
                    TriggerServerEvent("rs_housing:server:addPropertyKeyholder", CurrentProperty, inputId)
                else
                    lib.notify({
                      title       = Locales['HOUSING_NOTI'],
                      description = Locales['MENU_KEYHOLDERS_REACHED_MAX'],
                      type        = 'error',
                      duration    = 3000,
                      position    = 'top'
                    })
                end

            else
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INVALID_INPUT'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
            end

        end

    end,

    function(data, menu)
        OpenMenuManagement()
    end)

end

function OpenMenuKeyholdersList()
    MenuData.CloseAll()

    local PlayerData = GetPlayerData()
    local property   = PlayerData.Properties[CurrentProperty]
    
    local elements   = {}

    local length = 0
    if property.keyholders then
        for _ in pairs(property.keyholders) do
            length = length + 1
        end
    end

    if length > 0 then

        local count = 0

        for _, keyholder in pairs(property.keyholders) do
            count = count + 1
            
            table.insert(elements, { 
                label      = count .. ". " .. keyholder.username,
                citizenid  = keyholder.citizenid,
                username   = keyholder.username,
                value      = _,
                desc       = string.format(Locales['MENU_KEYHOLDERS_MANAGE'], keyholder.username)
            })

        end

    end

    table.insert(elements, { label = Locales['MENU_BACK'], value = "backup", desc = "" })

    MenuData.Open('default', GetCurrentResourceName(), 'menu_keyholders_list',

    {
        title    = string.format(Locales['MENU_PROPERTY_TITLE'], CurrentProperty),
        subtext  = "",
        align    = "right",
        elements = elements,
    },

    function(data, menu)
            
        if (data.current.value == "backup") then
            menu.close()
            OpenMenuKeyholders()
        else
            menu.close()
            OpenSelectedPlayerCatalog(data.current.citizenid, data.current.username)
        end

    end,

    function(data, menu)
        OpenMenuKeyholders()
    end)

end

function OpenSelectedPlayerCatalog(citizenid, username)

    local elements = {
        {
            label = Locales['MENU_KEYHOLDERS_PERMISSIONS_TITLE'],
            value = "permissions",
            desc  = "",
        },
        {
            label = Locales['MENU_KEYHOLDERS_REMOVE_TITLE'],
            value = "remove",
            desc  = "",
        },
        {
            label = Locales['MENU_BACK'],
            value = "back",
            desc  = ""
        },
    }

    MenuData.Open('default', GetCurrentResourceName() .. "_user_management", 'menuapi',
    {
        title    = username,
        subtext  = "",
        align    = "right",
        elements = elements,
        lastmenu = "MEMBERS"
    },

    function(data, menu)
        if (data.current == "backup" or data.current.value == "back") then
            menu.close()
            OpenMenuKeyholdersList()
        end

        if (data.current.value == 'permissions') then
            menu.close()
            OpenSelectedPlayerPermissions(citizenid, username)
        end

        if (data.current.value == "remove") then
            menu.close()

            TriggerServerEvent("rs_housing:server:removePropertyKeyholder", CurrentProperty, citizenid, username)

            Wait(1000)
            OpenMenuKeyholders()
        end

    end,
    function(data, menu)
        OpenMenuKeyholdersList()
        menu.close()
    end)

end

local function GetPermissionDescription(value)
    if tonumber(value) == 1 then
        return  Locales['YES']
    else
        return Locales['NO']
    end
end

local function GetLabel(localeKey)
    return Locales[localeKey] or localeKey
end

function OpenSelectedPlayerPermissions(citizenid, username)

    local propertyId = CurrentProperty

    local elements = {
        { 
            label = GetLabel("ledger_deposit"),
            value = "ledger_deposit",
            desc  = GetPermissionDescription(HasPermissionByName(propertyId, "ledger_deposit", citizenid))
        },
        { 
            label = GetLabel("ledgerhome_deposit"),
            value = "ledgerhome_deposit",
            desc  = GetPermissionDescription(HasPermissionByName(propertyId, "ledgerhome_deposit", citizenid))
        },
        { 
            label = GetLabel("ledgerhome_withdraw"),
            value = "ledgerhome_withdraw",
            desc  = GetPermissionDescription(HasPermissionByName(propertyId, "ledgerhome_withdraw", citizenid))
        },
        { 
            label = GetLabel("keyholders_management"),
            value = "keyholders",
            desc  = GetPermissionDescription(HasPermissionByName(propertyId, "keyholders", citizenid))
        },
        { 
            label = GetLabel("set_wardrobe"),
            value = "set_wardrobe",
            desc  = GetPermissionDescription(HasPermissionByName(propertyId, "set_wardrobe", citizenid))
        },
        { 
            label = GetLabel("set_storage"),
            value = "set_storage",
            desc  = GetPermissionDescription(HasPermissionByName(propertyId, "set_storage", citizenid))
        },
        { 
            label = GetLabel("storage_access"),
            value = "storage_access",
            desc  = GetPermissionDescription(HasPermissionByName(propertyId, "storage_access", citizenid))
        },
        { 
            label = GetLabel("place_furniture"),
            value = "place_furniture",
            desc  = GetPermissionDescription(HasPermissionByName(propertyId, "place_furniture", citizenid))
        },
        {
            label = Locales["MENU_BACK"],
            value = "back",
            desc  = ""
        },
    }

    MenuData.Open('default', GetCurrentResourceName() .. "_user_perms_management", 'menuapi',
    {
        title    = username,
        subtext  = "",
        align    = "right",
        elements = elements,
        lastmenu = "MEMBERS"
    },

    function(data, menu)
        if data.current == "backup" or (type(data.current) == "table" and data.current.value == "back") then
            MenuData.CloseAll()
            Wait(100)
            OpenSelectedPlayerCatalog(citizenid, username)
            return
        end

        TriggerServerEvent("rs_housing:server:onMembersPermissionUpdate", propertyId, citizenid, data.current.value)
        Wait(300)
        OpenSelectedPlayerPermissions(citizenid, username)
    end,

    function(data, menu)
        MenuData.CloseAll()
        Wait(100)
        OpenSelectedPlayerCatalog(citizenid, username)
    end)
end

function OpenMenuLedger()
    MenuData.CloseAll()

    local PlayerData = GetPlayerData()
    local property   = PlayerData.Properties[CurrentProperty]
    local taxInfo = ""

    if Config.TaxRepoSystem.Enabled then
        if Config.TaxRepoSystem.Monthly then
            taxInfo = string.format(
                "\n%s\n%s %s %s %02d:%02d",
                Locales['LEDGER_TAX_SYSTEM'],
                Locales['LEDGER_TAX_MONTHLY_LABEL'],
                Config.TaxRepoSystem.Day,
                Locales['LEDGER_TAX_AT'],
                Config.TaxRepoSystem.Hour,
                Config.TaxRepoSystem.Minute
            )
        end
        if Config.TaxRepoSystem.Weekly then
            local days = table.concat(Config.TaxRepoSystem.WeekDays, ", ")
            taxInfo = string.format(
                "\n%s\n%s %s %s %02d:%02d",
                Locales['LEDGER_TAX_SYSTEM'],
                Locales['LEDGER_TAX_WEEKLY_LABEL'],
                days,
                Locales['LEDGER_TAX_AT'],
                Config.TaxRepoSystem.Hour,
                Config.TaxRepoSystem.Minute
            )
        end
    end

    local options  = {
        {
            label = Locales['MENU_LEDGER_DEPOSIT_TITLE'], 
            value = "deposit", 
            desc  = taxInfo,
        },
        {
            label = Locales['MENU_BACK'],
            value = "backup", 
            desc  = "",
        },
    }

    MenuData.Open('default', GetCurrentResourceName(), 'menu_ledger_main',

    {
        title    = string.format(Locales['MENU_PROPERTY_TITLE'], CurrentProperty),
        subtext  = string.format(Locales['MENU_LEDGER_SUB_DESCRIPTION'], property.ledger),
        align    = "right",
        elements = options,
    },

    function(data, menu)

        if (data.current.value == "backup") then
            OpenMenuManagement()

        elseif (data.current.value == "deposit") then
            
            if HasPermissionByName(CurrentProperty, 'ledger_' .. data.current.value, PlayerData.CitizenId) == 0 then
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INSUFFICIENT_PERMISSIONS'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
                return
            end

            local actionType = string.upper(data.current.value)

            local input = lib.inputDialog(Locales['INPUT_' .. actionType .. '_TITLE'], {
                {
                    type     = 'number',
                    label    = Locales['INPUT_' .. actionType .. '_DESCRIPTION'],
                    required = true,
                    min      = 1,
                }
            })

            if input and input[1] then

                local numberInput = tonumber(input[1])

                if numberInput and numberInput > 0 then
                    TriggerServerEvent("rs_housing:server:updateAccountLedgerById", CurrentProperty, actionType, numberInput)
                    OpenMenuManagement()
                else
                    lib.notify({
                        title       = Locales['HOUSING_NOTI'],
                        description = Locales['INVALID_QUANTITY'],
                        type        = 'error',
                        duration    = 3000,
                        position    = 'top'
                    })
                end

            else
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INVALID_QUANTITY'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
            end

        end

    end,

    function(data, menu)
        OpenMenuManagement() 
    end)

end

function OpenMenuLedgerHome()
    MenuData.CloseAll()

    local PlayerData = GetPlayerData()
    local property   = PlayerData.Properties[CurrentProperty]

    local balance = property.ledgerhome 

    local options  = {
        {
            label = Locales['MENU_LEDGER_DEPOSIT_TITLE'], 
            value = "deposit", 
            desc  = Locales['MENU_LEDGER_DEPOSIT_DESCRIPTION'],
        },
        {
            label = Locales['MENU_LEDGER_WITHDRAW_TITLE'],
            value = "withdraw", 
            desc  = Locales['MENU_LEDGER_WITHDRAW_DESCRIPTION'],
        },
        {
            label = Locales['MENU_BACK'],
            value = "backup", 
            desc  = "",
        },
    }

    MenuData.Open('default', GetCurrentResourceName(), 'menu_ledger_home',

    {
        title    = string.format(Locales['MENU_PROPERTY_TITLE'], CurrentProperty),
        subtext  = Locales['BALANCE'].. ": " .. balance .. "$",
        align    = "right",
        elements = options,
    },

    function(data, menu)

        if (data.current.value == "backup") then
            OpenMenuManagement()

        elseif (data.current.value == "deposit") then
            
            -- PERMISO NUEVO
            if HasPermissionByName(CurrentProperty, 'ledgerhome_deposit', PlayerData.CitizenId) == 0 then
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INSUFFICIENT_PERMISSIONS'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
                return
            end

            local input = lib.inputDialog(Locales['INPUT_DEPOSIT_TITLE'], {
                {
                    type     = 'number',
                    label    = Locales['INPUT_DEPOSIT_DESCRIPTION'],
                    required = true,
                    min      = 1,
                }
            })

            if input and input[1] then
                TriggerServerEvent("rs_housing:server:updateAccountLedgerHomeById", CurrentProperty, "DEPOSIT", tonumber(input[1]))
                OpenMenuManagement()
            end

        elseif (data.current.value == "withdraw") then

            if HasPermissionByName(CurrentProperty, 'ledgerhome_withdraw', PlayerData.CitizenId) == 0 then
                lib.notify({
                    title       = Locales['HOUSING_NOTI'],
                    description = Locales['INSUFFICIENT_PERMISSIONS'],
                    type        = 'error',
                    duration    = 3000,
                    position    = 'top'
                })
                return
            end

            local input = lib.inputDialog(Locales['INPUT_WITHDRAW_TITLE'], {
                {
                    type     = 'number',
                    label    = Locales['INPUT_WITHDRAW_DESCRIPTION'],
                    required = true,
                    min      = 1,
                }
            })

            if input and input[1] then
                TriggerServerEvent("rs_housing:server:updateAccountLedgerHomeById", CurrentProperty, "WITHDRAW", tonumber(input[1]))
                OpenMenuManagement()
            end
        end

    end,

    function(data, menu)
        OpenMenuManagement() 
    end)

end

-- Housing NUI ---------------------------------------------------------------
-- The legacy menu functions above are retained for compatibility with any
-- external calls. These definitions replace the property-facing flows with
-- the same NUI shell used by the decoration menu.

local HousingView = nil
local HousingSelectedKeyholder = nil
local HousingTaxDueDates = {}
local HousingTransferPlayers = {}
local RequestNearbyHousingPlayers

local function NotifyHousingError(message)
    lib.notify({
        title = Locales['HOUSING_NOTI'],
        description = message,
        type = 'error',
        duration = 3000,
        position = 'top'
    })
end

local function ShowHousingNui(payload)
    payload.action = 'housing'
    payload.show = true
    HousingView = payload.view
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage(payload)
end

local function CloseHousingNui(resetProperty)
    HousingView = nil
    HousingSelectedKeyholder = nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close', show = false })

    if resetProperty then
        local PlayerData = GetPlayerData()
        PlayerData.IsInMenu = false
        CurrentProperty = nil
        TaskStandStill(PlayerPedId(), 1)
    end
end

local function NextTaxDueDate(propertyId)
    if not Config.TaxRepoSystem or not Config.TaxRepoSystem.Enabled then
        return 'Taxes disabled'
    end

    local cached = HousingTaxDueDates[propertyId]
    local now = GetGameTimer()
    if cached and cached.value and (now - cached.receivedAt) < 60000 then
        return cached.value
    end

    if not cached or not cached.pending then
        HousingTaxDueDates[propertyId] = {
            value = cached and cached.value or nil,
            receivedAt = cached and cached.receivedAt or 0,
            pending = true
        }
        TriggerServerEvent('rs_housing:server:requestTaxDueDate', propertyId)
    end

    return cached and cached.value or 'Loading...'
end

local function OpenHousingLedger()
    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    if not property then return end

    local price = property.purchaseMethods
        and property.purchaseMethods.dollars
        and tonumber(property.purchaseMethods.dollars.cost) or 0
    local tax = tonumber(property.tax) or 0
    local taxFunds = tonumber(property.ledger) or 0
    local normalFunds = tonumber(property.ledgerhome) or 0
    local taxRate = price > 0 and ((tax / price) * 100) or 0
    local fundedPeriods = tax > 0 and math.floor(taxFunds / tax) or 0
    local fundedUnit = 'periods'
    if Config.TaxRepoSystem and Config.TaxRepoSystem.Monthly then
        fundedUnit = fundedPeriods == 1 and 'month' or 'months'
    elseif Config.TaxRepoSystem and Config.TaxRepoSystem.Weekly then
        fundedUnit = fundedPeriods == 1 and 'week' or 'weeks'
    end
    local taxAtRisk = Config.TaxRepoSystem
        and Config.TaxRepoSystem.Enabled
        and tax > 0
        and taxFunds < tax

    ShowHousingNui({
        view = 'ledger',
        title = 'Money Ledger',
        subtitle = ('House #%s'):format(CurrentProperty),
        property = {
            house = tostring(CurrentProperty),
            taxAmount = tax,
            taxRate = ('%.2f%%'):format(taxRate),
            taxDueDate = NextTaxDueDate(CurrentProperty),
            taxFunds = taxFunds,
            taxAtRisk = taxAtRisk,
            taxFunded = ('%d %s'):format(fundedPeriods, fundedUnit),
            normalFunds = normalFunds,
            taxEnabled = Config.TaxRepoSystem ~= nil and Config.TaxRepoSystem.Enabled == true
        },
        labels = {
            house = 'House #',
            taxAmount = 'Tax Amount',
            taxRate = 'Tax Rate',
            taxDueDate = 'Tax Due Date',
            taxFunds = 'Tax Funds',
            taxFunded = 'Tax Funded For',
            normalFunds = 'Ledger Balance',
            deposit = Locales['MENU_LEDGER_DEPOSIT_TITLE'],
            withdraw = Locales['MENU_LEDGER_WITHDRAW_TITLE'],
            payTax = 'Pay Tax'
        }
    })
end

local function GetCurrentPlayerCash()
    local corePlayerData = RSGCore.Functions.GetPlayerData()
    return corePlayerData and corePlayerData.money and tonumber(corePlayerData.money.cash) or 0
end

local function OpenHousingNormalTransaction(actionType)
    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    if not property then return end

    ShowHousingNui({
        view = 'ledger_transaction',
        title = actionType == 'DEPOSIT' and 'Deposit Funds' or 'Withdraw Funds',
        subtitle = ('House #%s · Money Ledger'):format(CurrentProperty),
        transaction = {
            action = actionType,
            currentAmount = tonumber(property.ledgerhome) or 0,
            playerFunds = GetCurrentPlayerCash(),
            maximum = actionType == 'DEPOSIT'
                and GetCurrentPlayerCash()
                or (tonumber(property.ledgerhome) or 0)
        },
        labels = {
            currentAmount = 'Current Amount',
            playerFunds = 'Player Cash',
            amount = 'Amount',
            submit = actionType == 'DEPOSIT' and 'Deposit' or 'Withdraw'
        }
    })
end

local function OpenHousingTaxPayment()
    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    if not property then return end

    local price = property.purchaseMethods
        and property.purchaseMethods.dollars
        and tonumber(property.purchaseMethods.dollars.cost) or 0
    local tax = tonumber(property.tax) or 0
    local taxFunds = tonumber(property.ledger) or 0
    local taxRate = price > 0 and ((tax / price) * 100) or 0

    ShowHousingNui({
        view = 'tax_payment',
        title = 'Pay Property Tax',
        subtitle = ('House #%s · Payments increase by one tax period'):format(CurrentProperty),
        taxPayment = {
            taxAmount = tax,
            taxRate = ('%.2f%%'):format(taxRate),
            taxDueDate = NextTaxDueDate(CurrentProperty),
            currentFunds = taxFunds,
            playerFunds = GetCurrentPlayerCash()
        },
        labels = {
            taxAmount = 'Tax Amount',
            taxRate = 'Tax Rate',
            taxDueDate = 'Tax Due Date',
            currentFunds = 'Current Tax Funds',
            playerFunds = 'Player Cash',
            amount = 'Tax Payment',
            submit = 'Deposit Tax'
        }
    })
end

local function OpenHousingTransfer(nearbyPlayers)
    HousingTransferPlayers = nearbyPlayers or {}
    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    if not property then return end

    ShowHousingNui({
        view = 'transfer',
        title = 'Transfer Property',
        subtitle = ('House #%s · Select a player currently on the property'):format(CurrentProperty),
        transfer = {
            range = tonumber(property.actionsRange) or 15.0,
            players = HousingTransferPlayers,
            loading = nearbyPlayers == nil
        },
        labels = {
            nearbyPlayers = 'Players On Property',
            amount = 'Player Server ID',
            submit = 'Transfer Property'
        }
    })

    if nearbyPlayers == nil then
        RequestNearbyHousingPlayers()
    end
end

RequestNearbyHousingPlayers = function()
    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    if not property then return end

    local serverIds = {}
    local range = tonumber(property.actionsRange) or 15.0
    local center = property.Locations and property.Locations.MenuActions
    if not center then return end

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            local coords = GetEntityCoords(ped)
            local distance = #(coords - vector3(center.x, center.y, center.z))
            if distance <= range then
                serverIds[#serverIds + 1] = GetPlayerServerId(player)
            end
        end
    end

    TriggerServerEvent('rs_housing:server:requestNearbyPropertyPlayers', CurrentProperty, serverIds)
end

local function OpenHousingKeyholders(nearbyPlayers)
    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    if not property then return end

    local keyholders = {}
    local existing = {}
    for citizenid, keyholder in pairs(property.keyholders or {}) do
        existing[citizenid] = true
        keyholders[#keyholders + 1] = {
            name = keyholder.username or citizenid,
            id = citizenid,
            citizenid = citizenid
        }
    end
    table.sort(keyholders, function(a, b) return a.name:lower() < b.name:lower() end)

    local nonKeyholders = {}
    for _, player in ipairs(nearbyPlayers or {}) do
        if player.citizenid ~= PlayerData.CitizenId and not existing[player.citizenid] then
            nonKeyholders[#nonKeyholders + 1] = player
        end
    end
    table.sort(nonKeyholders, function(a, b) return a.name:lower() < b.name:lower() end)

    ShowHousingNui({
        view = 'keyholders',
        title = 'Property Keyholders',
        subtitle = ('House #%s · Players within %.1f meters'):format(
            CurrentProperty,
            tonumber(property.actionsRange) or 15.0
        ),
        keyholders = keyholders,
        nonKeyholders = nonKeyholders,
        maxKeyholders = Config.MaxHouseKeyHolders
    })
end

local function RefreshHousingKeyholders()
    OpenHousingKeyholders({})
    RequestNearbyHousingPlayers()
end

local PermissionOptions = {
    { key = 'ledger_deposit', locale = 'ledger_deposit' },
    { key = 'ledgerhome_deposit', locale = 'ledgerhome_deposit' },
    { key = 'ledgerhome_withdraw', locale = 'ledgerhome_withdraw' },
    { key = 'keyholders', locale = 'keyholders_management' },
    { key = 'set_wardrobe', locale = 'set_wardrobe' },
    { key = 'set_storage', locale = 'set_storage' },
    { key = 'storage_access', locale = 'storage_access' },
    { key = 'place_furniture', locale = 'place_furniture' }
}

local function OpenHousingPermissions(citizenid, username)
    HousingSelectedKeyholder = { citizenid = citizenid, username = username }
    local items = {}
    for _, permission in ipairs(PermissionOptions) do
        items[#items + 1] = {
            value = permission.key,
            label = Locales[permission.locale] or permission.locale,
            description = GetPermissionDescription(
                HasPermissionByName(CurrentProperty, permission.key, citizenid)
            )
        }
    end

    ShowHousingNui({
        view = 'permissions',
        title = username,
        subtitle = 'Select a permission to toggle it',
        items = items
    })
end

function OpenMenuManagement(propertyId)
    local PlayerData = GetPlayerData()
    if CurrentProperty == nil then CurrentProperty = propertyId end
    if not CurrentProperty then return end

    local property = PlayerData.Properties[CurrentProperty]
    if not property then return end

    MenuData.CloseAll()
    PlayerData.IsInMenu = true
    TaskStandStill(PlayerPedId(), -1)

    local items = {}
    for _, option in pairs(Config.ManagementMenu) do
        if option.Enabled then
            local label = Locales[option.Type]
            local description = Locales[option.Type .. '_DESCRIPTION'] or ''
            if option.Type == 'MENU_SELL' then
                label = string.format(Locales['MENU_SELL_WITH_PRICE'], property.sell.receive)
                description = string.format(Locales['MENU_SELL_DESCRIPTION_DOLLARS'], property.sell.receive)
            end
            items[#items + 1] = { value = option.Type, label = label, description = description }
        end
    end

    items[#items + 1] = {
        value = 'MENU_FURNITURE',
        label = Locales['MENU_FURNITURE'],
        description = Locales['MENU_FURNITURE_DESCRIPTION'] or ''
    }
    items[#items + 1] = {
        value = 'MENU_EXIT',
        label = Locales['MENU_EXIT'],
        description = ''
    }

    ShowHousingNui({
        view = 'management',
        title = ('House #%s'):format(CurrentProperty),
        subtitle = 'Property Management',
        items = items
    })
end

-- Preserve the public function names used elsewhere in the resource.
function OpenMenuKeyholders()
    RefreshHousingKeyholders()
end

function OpenMenuLedgerHome()
    OpenHousingLedger()
end

RegisterNetEvent('rs_housing:client:nearbyPropertyPlayers', function(propertyId, players)
    if HousingView == 'keyholders' and tostring(propertyId) == tostring(CurrentProperty) then
        OpenHousingKeyholders(players)
    elseif HousingView == 'transfer' and tostring(propertyId) == tostring(CurrentProperty) then
        OpenHousingTransfer(players)
    end
end)

RegisterNetEvent('rs_housing:client:taxDueDate', function(propertyId, dueDate)
    HousingTaxDueDates[propertyId] = {
        value = dueDate or 'Not scheduled',
        receivedAt = GetGameTimer(),
        pending = false
    }

    if tostring(propertyId) == tostring(CurrentProperty) then
        if HousingView == 'ledger' then
            OpenHousingLedger()
        elseif HousingView == 'tax_payment' then
            OpenHousingTaxPayment()
        end
    end
end)

RegisterNetEvent('rs_housing:client:sellInformation', function(propertyId, saleInformation)
    if tostring(propertyId) ~= tostring(CurrentProperty) then return end

    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    if not property or property.citizenid ~= PlayerData.CitizenId then return end

    saleInformation = saleInformation or {}
    ShowHousingNui({
        view = 'sell_confirm',
        title = 'Sell House',
        subtitle = '',
        sale = {
            house = tostring(CurrentProperty),
            price = tonumber(property.sell.receive) or 0,
            ledger = tonumber(saleInformation.ledger) or 0,
            taxLedger = tonumber(saleInformation.taxLedger) or 0,
            refundAccount = saleInformation.refundAccount or 'bank',
            refundAccountName = saleInformation.refundAccountName or saleInformation.refundAccount or 'bank',
            inventoryHasItems = saleInformation.inventoryHasItems
        },
        labels = {
            house = 'House #',
            price = 'Sell Price',
            ledger = 'Money in Ledger',
            taxLedger = 'Unused Tax Money',
            inventory = 'House Inventory',
            inventoryHasItems = 'Has Items',
            inventoryEmpty = 'Empty',
            inventoryUnknown = 'Unable to Check',
            refundNote = 'Ledger funds will be deposited into your %s account.',
            taxRefundNote = 'Unused tax money will be deposited into your %s account.',
            inventoryWarning = 'Inventory will not be transferred when the house is sold.'
        },
        items = {
            { value = 'confirm_sell', label = Locales['MENU_SELL_ACCEPT'], description = Locales['MENU_SELL_ACCEPT_DESCRIPTION'] },
            { value = 'cancel_sell', label = Locales['MENU_BACK'], description = '' }
        }
    })
end)

RegisterNetEvent('rs_housing:client:updateProperty', function(propertyId, actionType)
    if tostring(propertyId) ~= tostring(CurrentProperty) then return end

    if HousingView == 'ledger' and (actionType == 'LEDGER' or actionType == 'LEDGERHOME') then
        SetTimeout(100, OpenHousingLedger)
    elseif HousingView == 'keyholders'
        and (actionType == 'ADDED_KEYHOLDER' or actionType == 'REMOVED_KEYHOLDER') then
        SetTimeout(100, RefreshHousingKeyholders)
    elseif HousingView == 'permissions' and actionType == 'UPDATE_KEYHOLDER_PERMISSION'
        and HousingSelectedKeyholder then
        local selected = HousingSelectedKeyholder
        SetTimeout(100, function()
            OpenHousingPermissions(selected.citizenid, selected.username)
        end)
    end
end)

RegisterNUICallback('housingSelect', function(data, cb)
    cb('ok')
    local value = data and data.value
    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    if not value or not property then return end

    if HousingView == 'permissions' and HousingSelectedKeyholder then
        TriggerServerEvent(
            'rs_housing:server:onMembersPermissionUpdate',
            CurrentProperty,
            HousingSelectedKeyholder.citizenid,
            value
        )
        return
    end

    if HousingView == 'sell_confirm' then
        if value == 'confirm_sell' then
            TriggerServerEvent('rs_housing:server:sell', CurrentProperty)
            CloseHousingNui(true)
        else
            OpenMenuManagement(CurrentProperty)
        end
        return
    end

    if value == 'MENU_EXIT' then
        CloseHousingNui(true)
    elseif value == 'MENU_WARDROBE_LOCATION' or value == 'MENU_STORAGE_LOCATION' then
        local permission = value == 'MENU_WARDROBE_LOCATION' and 'set_wardrobe' or 'set_storage'
        if HasPermissionByName(CurrentProperty, permission, PlayerData.CitizenId) == 0 then
            NotifyHousingError(Locales['INSUFFICIENT_PERMISSIONS'])
            return
        end
        CloseHousingNui(false)
        LocationType = value
        TaskStandStill(PlayerPedId(), 1)
    elseif value == 'MENU_LEDGER_HOME' then
        OpenHousingLedger()
    elseif value == 'MENU_SET_KEYHOLDERS' then
        if HasPermissionByName(CurrentProperty, 'keyholders', PlayerData.CitizenId) == 0 then
            NotifyHousingError(Locales['INSUFFICIENT_PERMISSIONS'])
            return
        end
        RefreshHousingKeyholders()
    elseif value == 'MENU_TRANSFER' then
        if property.citizenid ~= PlayerData.CitizenId then
            NotifyHousingError(Locales['INSUFFICIENT_PERMISSIONS'])
            return
        end
        OpenHousingTransfer()
    elseif value == 'MENU_SELL' then
        if property.citizenid ~= PlayerData.CitizenId then
            NotifyHousingError(Locales['INSUFFICIENT_PERMISSIONS'])
            return
        end
        TriggerServerEvent('rs_housing:server:requestSellInformation', CurrentProperty)
    elseif value == 'MENU_FURNITURE' then
        if HasPermissionByName(CurrentProperty, 'place_furniture', PlayerData.CitizenId) == 0 then
            NotifyHousingError(Locales['INSUFFICIENT_PERMISSIONS'])
            return
        end
        local propertyId = CurrentProperty
        CloseHousingNui(true)
        TriggerEvent('rs_furniture:open', propertyId)
    end
end)

RegisterNUICallback('housingLedgerAction', function(data, cb)
    cb('ok')
    local action = data and data.action
    if HousingView ~= 'ledger'
        or (action ~= 'DEPOSIT' and action ~= 'WITHDRAW' and action ~= 'PAY_TAX') then return end

    if action == 'PAY_TAX'
        and (not Config.TaxRepoSystem or Config.TaxRepoSystem.Enabled ~= true) then return end

    local PlayerData = GetPlayerData()
    local permission = action == 'DEPOSIT' and 'ledgerhome_deposit'
        or action == 'WITHDRAW' and 'ledgerhome_withdraw'
        or 'ledger_deposit'
    if HasPermissionByName(CurrentProperty, permission, PlayerData.CitizenId) == 0 then
        NotifyHousingError(Locales['INSUFFICIENT_PERMISSIONS'])
        return
    end

    if action == 'PAY_TAX' then
        OpenHousingTaxPayment()
    else
        OpenHousingNormalTransaction(action)
    end
end)

RegisterNUICallback('housingSubmitLedgerTransaction', function(data, cb)
    cb('ok')
    if HousingView ~= 'ledger_transaction' or not data then return end

    local action = data.action
    local amount = tonumber(data.amount)
    if (action ~= 'DEPOSIT' and action ~= 'WITHDRAW') or not amount or amount <= 0 then
        NotifyHousingError(Locales['INVALID_QUANTITY'])
        return
    end

    local PlayerData = GetPlayerData()
    local permission = action == 'DEPOSIT' and 'ledgerhome_deposit' or 'ledgerhome_withdraw'
    if HasPermissionByName(CurrentProperty, permission, PlayerData.CitizenId) == 0 then
        NotifyHousingError(Locales['INSUFFICIENT_PERMISSIONS'])
        return
    end

    TriggerServerEvent('rs_housing:server:updateAccountLedgerHomeById', CurrentProperty, action, amount)
    OpenHousingLedger()
end)

RegisterNUICallback('housingSubmitTaxPayment', function(data, cb)
    cb('ok')
    if HousingView ~= 'tax_payment' or not data then return end

    local amount = tonumber(data.amount)
    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    local tax = property and tonumber(property.tax) or 0

    if not amount or amount <= 0 or tax <= 0 or amount % tax ~= 0 then
        NotifyHousingError(Locales['INVALID_QUANTITY'])
        return
    end
    if HasPermissionByName(CurrentProperty, 'ledger_deposit', PlayerData.CitizenId) == 0 then
        NotifyHousingError(Locales['INSUFFICIENT_PERMISSIONS'])
        return
    end

    TriggerServerEvent('rs_housing:server:updateAccountLedgerById', CurrentProperty, 'DEPOSIT', amount)
    OpenHousingLedger()
end)

RegisterNUICallback('housingSubmitTransfer', function(data, cb)
    cb('ok')
    if HousingView ~= 'transfer' or not data then return end

    local targetId = tonumber(data.serverId)
    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    if not property or property.citizenid ~= PlayerData.CitizenId then
        NotifyHousingError(Locales['INSUFFICIENT_PERMISSIONS'])
        return
    end
    if not targetId or targetId < 1 then
        NotifyHousingError(Locales['INVALID_INPUT'])
        return
    end
    if targetId == GetPlayerServerId(PlayerId()) then
        NotifyHousingError(Locales['CANNOT_TRANSFER_TO_SAME_PERSON'])
        return
    end

    local listedPlayer = false
    for _, nearbyPlayer in ipairs(HousingTransferPlayers) do
        if targetId == tonumber(nearbyPlayer.serverId) then
            listedPlayer = true
            break
        end
    end

    if not listedPlayer then
        NotifyHousingError(Locales['PLAYER_NOT_FOUND'])
        return
    end

    local targetStillPresent = false
    local center = property.Locations and property.Locations.MenuActions
    local range = tonumber(property.actionsRange) or 15.0
    if center then
        for _, targetPlayer in ipairs(GetActivePlayers()) do
            if targetId == GetPlayerServerId(targetPlayer) then
                local coords = GetEntityCoords(GetPlayerPed(targetPlayer))
                targetStillPresent = #(coords - vector3(center.x, center.y, center.z)) <= range
                break
            end
        end
    end

    if not targetStillPresent then
        NotifyHousingError(Locales['PLAYER_NOT_FOUND'])
        return
    end

    TriggerServerEvent('rs_housing:server:transferOwnedProperty', CurrentProperty, targetId)
    CloseHousingNui(true)
end)

RegisterNUICallback('housingKeyholderAction', function(data, cb)
    cb('ok')
    if HousingView ~= 'keyholders' or not data then return end

    local PlayerData = GetPlayerData()
    local property = PlayerData.Properties[CurrentProperty]
    if not property then return end

    if data.action == 'add' then
        local count = 0
        for _ in pairs(property.keyholders or {}) do count = count + 1 end
        if count >= Config.MaxHouseKeyHolders then
            NotifyHousingError(Locales['MENU_KEYHOLDERS_REACHED_MAX'])
            return
        end
        TriggerServerEvent('rs_housing:server:addPropertyKeyholder', CurrentProperty, tonumber(data.serverId))
    elseif data.action == 'remove' then
        TriggerServerEvent(
            'rs_housing:server:removePropertyKeyholder',
            CurrentProperty,
            data.citizenid,
            data.name
        )
    elseif data.action == 'permissions' then
        OpenHousingPermissions(data.citizenid, data.name)
    end
end)

RegisterNUICallback('housingBack', function(_, cb)
    cb('ok')
    if HousingView == 'management' then
        CloseHousingNui(true)
    elseif HousingView == 'permissions' then
        RefreshHousingKeyholders()
    elseif HousingView == 'ledger_transaction' or HousingView == 'tax_payment' then
        OpenHousingLedger()
    elseif HousingView == 'transfer' then
        OpenMenuManagement(CurrentProperty)
    else
        OpenMenuManagement(CurrentProperty)
    end
end)

RegisterNUICallback('housingClose', function(_, cb)
    cb('ok')
    CloseHousingNui(true)
end)

Citizen.CreateThread(function()
    while true do
        
        Wait(0)

        local sleep = true

        if LocationType then
    
            sleep = false

            DrawTxt(Locales['SET_' .. LocationType], 0.50, 0.85, 0.7, 0.5, true, 255, 255, 255, 255, true)

            if IsControlJustReleased(0, 0x760A9C6F) then

                local PlayerData     = GetPlayerData()
                local property       = PlayerData.Properties[CurrentProperty]
                local coords         = GetEntityCoords(PlayerPedId())
                local coordsDist     = vector3(coords.x, coords.y, coords.z)
                local propertyCoords = vector3(property.Locations.PrimaryEntrance.x, property.Locations.PrimaryEntrance.y, property.Locations.PrimaryEntrance.z)
                local distance       = #(coordsDist - propertyCoords)

                if distance <= tonumber(property.actionsRange) then

                    TriggerServerEvent("rs_housing:server:setPropertyLocationByType", CurrentProperty, LocationType, coords)

                    PlayerData.IsInMenu = false
                    LocationType        = nil
                    CurrentProperty     = nil

                    lib.notify({
                        title       = Locales['HOUSING_NOTI'],
                        description = Locales['LOCATION_SET'],
                        type        = 'error',
                        duration    = 3000,
                        position    = 'top'
                    })

                else
                    lib.notify({
                        title       = Locales['HOUSING_NOTI'],
                        description = Locales['TOO_FAR'],
                        type        = 'error',
                        duration    = 3000,
                        position    = 'top'
                    })
                end

            end

        end

        if sleep then
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1)

        local PlayerData = GetPlayerData()

        if PlayerData.IsInMenu then

            DisableControlAction(0, 0xCC1075A7, true) -- MWUP
            DisableControlAction(0, 0xFD0F0C2C, true) -- MWDOWN

        else
            Wait(1000)
        end
    end
end)
