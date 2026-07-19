local RSGCore = exports['rsg-core']:GetCoreObject()

local CONFIG_FILE = 'config.lua'
local BACKUP_FILE = 'config.lua.property-values-backup'

local function SendResult(source, success, message)
    if source == 0 then
        print(('[rs_housing] %s'):format(message))
        return
    end

    TriggerClientEvent('rs_housing:client:propertyValuesUpdateResult', source, success, message)
end

local function GetAllPropertyConfigs()
    local properties = {}

    for propertyId, property in pairs(Config.Properties or {}) do
        properties[tostring(propertyId)] = property
    end

    for propertyId, property in pairs(Config.DisabledProperties or {}) do
        properties[tostring(propertyId)] = property
    end

    return properties
end

local function CalculateValues(property)
    local overrides = Config.PropertiesOverrides
    local dollars = property.purchaseMethods and property.purchaseMethods.dollars
    local buyPrice = dollars and tonumber(dollars.cost)

    if not buyPrice then
        return nil, 'missing a dollar purchase price'
    end

    local storageValues = overrides.additionalStorageWeight
    local additionalWeight = storageValues and tonumber(storageValues[1])
    local priceStep = storageValues and tonumber(storageValues[2])

    if not additionalWeight or not priceStep or priceStep <= 0 then
        return nil, 'has an invalid additionalStorageWeight setting'
    end

    local tax = math.floor(buyPrice * overrides.taxAmount)
    local sellPrice = math.floor(buyPrice * overrides.sellPrice)
    local storageSteps = math.floor(buyPrice / priceStep)

    return {
        tax = tax,
        sellPrice = sellPrice,
        ledgerLimit = overrides.ledgerLimit,
        storageWeight = overrides.defaultStorageWeight + (storageSteps * additionalWeight)
    }
end

local function ValidateOverrides()
    local overrides = Config.PropertiesOverrides

    if not overrides or not overrides.enable then
        return false, 'Config.PropertiesOverrides.enable must be true.'
    end

    local numericFields = {
        'taxAmount',
        'sellPrice',
        'ledgerLimit',
        'defaultStorageWeight'
    }

    for _, field in ipairs(numericFields) do
        if type(overrides[field]) ~= 'number' or overrides[field] < 0 then
            return false, ('Config.PropertiesOverrides.%s must be a non-negative number.'):format(field)
        end
    end

    return true
end

local function RewriteConfig(source, valuesByProperty)
    local newline = source:find('\r\n', 1, true) and '\r\n' or '\n'
    local normalized = source:gsub('\r\n', '\n')
    local output = {}
    local inProperties = false
    local currentPropertyId = nil
    local updatedProperties = 0

    for line in (normalized .. '\n'):gmatch('(.-)\n') do
        do
        if not inProperties and line:match('^Config%.Properties%s*=%s*{%s*$') then
            inProperties = true
            output[#output + 1] = line
            goto continue
        end

        if inProperties and line:match('^}%s*$') then
            inProperties = false
            currentPropertyId = nil
            output[#output + 1] = line
            goto continue
        end

        if inProperties then
            local propertyId = line:match("^%s*%['(%d+)'%]%s*=%s*{%s*$")
            if propertyId then
                currentPropertyId = propertyId
                if valuesByProperty[propertyId] then
                    updatedProperties = updatedProperties + 1
                end
            end
        end

        local values = currentPropertyId and valuesByProperty[currentPropertyId]

        if values then
            local indent = line:match('^(%s*)sell%s*=')
            if indent then
                output[#output + 1] = ('%ssell = { receive = %d },'):format(indent, values.sellPrice)
                goto continue
            end

            indent = line:match('^(%s*)tax%s*=')
            if indent then
                output[#output + 1] = ('%stax = %d,'):format(indent, values.tax)
                goto continue
            end

            indent = line:match('^(%s*)ledgerLimit%s*=')
            if indent then
                output[#output + 1] = ('%sledgerLimit = %d,'):format(indent, values.ledgerLimit)
                goto continue
            end

            indent = line:match('^(%s*)defaultStorageWeight%s*=')
            if indent then
                output[#output + 1] = ('%sdefaultStorageWeight = %d,'):format(indent, values.storageWeight)
                goto continue
            end
        end

        output[#output + 1] = line
        end

        ::continue::
    end

    return table.concat(output, newline), updatedProperties
end

RSGCore.Commands.Add(
    'UpdatePropertyValues',
    'Permanently update property values using Config.PropertiesOverrides',
    {},
    false,
    function(source)
        local valid, validationError = ValidateOverrides()
        if not valid then
            SendResult(source, false, validationError)
            return
        end

        local resourceName = GetCurrentResourceName()
        local configSource = LoadResourceFile(resourceName, CONFIG_FILE)
        if not configSource then
            SendResult(source, false, 'Unable to read config.lua.')
            return
        end

        local valuesByProperty = {}
        local skipped = {}

        for propertyId, property in pairs(GetAllPropertyConfigs()) do
            local values, calculationError = CalculateValues(property)
            if values then
                valuesByProperty[propertyId] = values
            else
                skipped[#skipped + 1] = ('%s (%s)'):format(propertyId, calculationError)
            end
        end

        local updatedSource, updatedCount = RewriteConfig(configSource, valuesByProperty)
        if updatedCount == 0 then
            SendResult(source, false, 'No property definitions were updated; config.lua was not changed.')
            return
        end

        if not LoadResourceFile(resourceName, BACKUP_FILE) then
            SaveResourceFile(resourceName, BACKUP_FILE, configSource, #configSource)
        end

        SaveResourceFile(resourceName, CONFIG_FILE, updatedSource, #updatedSource)

        local savedSource = LoadResourceFile(resourceName, CONFIG_FILE)
        if savedSource ~= updatedSource then
            SendResult(source, false, 'The updated config.lua could not be verified. The backup was preserved.')
            return
        end

        local message = ('Updated %d properties and saved a backup as %s. Comment out both updater files in fxmanifest.lua, then restart rs_housing.'):format(updatedCount, BACKUP_FILE)

        if #skipped > 0 then
            message = message .. (' Skipped: %s.'):format(table.concat(skipped, ', '))
        end

        SendResult(source, true, message)
    end,
    'admin'
)
