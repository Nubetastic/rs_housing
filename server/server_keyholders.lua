local RSGCore = exports['rsg-core']:GetCoreObject()

local function notiKeySuccess(source, title, message)
    TriggerClientEvent('ox_lib:notify', source, {
        title       = title,
        description = message,
        type        = 'success',
        duration    = 4000,
        position    = 'top'
    })
end

local function notiKeyError(source, title, message)
    TriggerClientEvent('ox_lib:notify', source, {
        title       = title,
        description = message,
        type        = 'error',
        duration    = 3000,
        position    = 'top'
    })
end

local function GetTableLength(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

local function GetPlayerData(source)
  local _source = source
  local xPlayer = RSGCore.Functions.GetPlayer(_source)

  if not xPlayer then return nil end

  return {
    citizenid  = xPlayer.PlayerData.citizenid,
    money      = xPlayer.PlayerData.money['cash'],
    job        = xPlayer.PlayerData.job.name,
    firstname  = xPlayer.PlayerData.charinfo.firstname,
    lastname   = xPlayer.PlayerData.charinfo.lastname,
    group      = xPlayer.PlayerData.group,
    steamName  = GetPlayerName(_source),
  }
end

local function CanManageKeyholders(property, source)
    local player = GetPlayerData(source)
    if not player then return false end
    if property.citizenid == player.citizenid then return true end

    local keyholder = property.keyholders[player.citizenid]
    return keyholder
        and keyholder.permissions
        and tonumber(keyholder.permissions.keyholders) == 1
end

local function IsPlayerAtProperty(property, source)
    local center = property.Locations and property.Locations.MenuActions
    local ped = GetPlayerPed(source)
    if not center or not ped or ped <= 0 then return false end

    local coords = GetEntityCoords(ped)
    local range = tonumber(property.actionsRange) or 15.0
    return #(coords - vector3(center.x, center.y, center.z)) <= range
end

local AllowedKeyholderPermissions = {
    ledger_deposit = true,
    ledgerhome_deposit = true,
    ledgerhome_withdraw = true,
    keyholders = true,
    set_wardrobe = true,
    set_storage = true,
    storage_access = true,
    place_furniture = true
}

RegisterServerEvent('rs_housing:server:requestNearbyPropertyPlayers')
AddEventHandler('rs_housing:server:requestNearbyPropertyPlayers', function(propertyId, serverIds)
    local _source = source
    local Properties = GetProperties()
    local property = Properties[propertyId]

    if not property or type(serverIds) ~= 'table' then return end

    if not CanManageKeyholders(property, _source) or not IsPlayerAtProperty(property, _source) then return end

    local players = {}
    local seen = {}
    for _, playerId in ipairs(serverIds) do
        playerId = tonumber(playerId)
        if playerId and playerId ~= _source and not seen[playerId] then
            seen[playerId] = true
            local player = GetPlayerData(playerId)
            if player and IsPlayerAtProperty(property, playerId) then
                players[#players + 1] = {
                    name = player.firstname .. ' ' .. player.lastname,
                    serverId = playerId,
                    citizenid = player.citizenid
                }
            end
        end
    end

    TriggerClientEvent('rs_housing:client:nearbyPropertyPlayers', _source, propertyId, players)
end)

RegisterServerEvent("rs_housing:server:addPropertyKeyholder")
AddEventHandler("rs_housing:server:addPropertyKeyholder", function(propertyId, playerId)

    local _source  = source
    local _tsource = tonumber(playerId)

    local Properties = GetProperties()

    if not Properties[propertyId] or not _tsource then return end

    local property = Properties[propertyId]
    if not CanManageKeyholders(property, _source)
        or not IsPlayerAtProperty(property, _source)
        or not IsPlayerAtProperty(property, _tsource) then
        notiKeyError(_source, Locales['HOUSING_NOTI'], Locales['PLAYER_NOT_VALID'])
        return
    end

    if GetPlayerName(_tsource) == nil then
        notiKeyError(_source, Locales['HOUSING_NOTI'], Locales['PLAYER_NOT_VALID'])
        return
    end

    if _tsource == _source then
      notiKeyError(_source, Locales['HOUSING_NOTI'], Locales['MENU_KEYHOLDERS_ADD_NEW_TO_SELF'])
      return
    end

    local PlayerData = GetPlayerData(_tsource)

    if not PlayerData then
        notiKeyError(_source, Locales['HOUSING_NOTI'], Locales['PLAYER_NOT_VALID'])
        return
    end

    local citizenid = PlayerData.citizenid

    if property.keyholders[citizenid] then
        notiKeyError(_source, Locales['HOUSING_NOTI'], Locales['MENU_KEYHOLDERS_ALREADY_EXISTS'])
        return
    end


    if GetTableLength(property.keyholders) >= Config.MaxHouseKeyHolders then
        notiKeyError(_source, Locales['HOUSING_NOTI'], Locales['MENU_KEYHOLDERS_REACHED_MAX'])
        return
    end

    local username = PlayerData.firstname .. " " .. PlayerData.lastname

    property.keyholders[citizenid] = {
        username  = username,
        citizenid = citizenid,
        permissions = {
            ledger_deposit      = 0,
            ledgerhome_deposit  = 0,
            ledgerhome_withdraw = 0,
            keyholders          = 0,
            set_wardrobe        = 0,
            set_storage         = 0,
            storage_access      = 0,
            place_furniture     = 0,
        }
    }

    exports.oxmysql:execute(
        'UPDATE properties SET keyholders = ? WHERE name = ?',
        {
            json.encode(property.keyholders),
            propertyId
        }
    )
    
    notiKeySuccess(_source, Locales['HOUSING_NOTI'], string.format(Locales['MENU_KEYHOLDERS_ADDED'], username))

    if not property.hasTeleportationEntrance then
        TriggerEvent("rs_housing:server:updateDoorlockInformation", propertyId, 'REGISTER_KEYHOLDER', { citizenid, username })
    end

    TriggerClientEvent("rs_housing:client:updateProperty", -1, propertyId, 'ADDED_KEYHOLDER', { citizenid, username })

end)

RegisterServerEvent("rs_housing:server:removePropertyKeyholder")
AddEventHandler("rs_housing:server:removePropertyKeyholder", function(propertyId, citizenid, username)

  local _source = source

  local Properties = GetProperties()

  if not Properties[propertyId] then return end

  if not CanManageKeyholders(Properties[propertyId], _source)
      or not IsPlayerAtProperty(Properties[propertyId], _source) then
    notiKeyError(_source, Locales['HOUSING_NOTI'], Locales['INSUFFICIENT_PERMISSIONS'])
    return
  end

  if not Properties[propertyId].keyholders[citizenid] then
    notiKeyError(_source, Locales['HOUSING_NOTI'], Locales['MENU_KEYHOLDERS_DOES_NOT_EXISTS'])
    return
  end

  local property = Properties[propertyId]
   
  notiKeyError(_source, Locales['HOUSING_NOTI'], string.format(Locales['MENU_KEYHOLDERS_REMOVED'], username))

  if not property.hasTeleportationEntrance then
    TriggerEvent("rs_housing:server:updateDoorlockInformation", propertyId, 'UNREGISTER_KEYHOLDER', { citizenid })
  end

  Properties[propertyId].keyholders[citizenid] = nil

  exports.oxmysql:execute(
    'UPDATE properties SET keyholders = ? WHERE name = ?',
    {
      json.encode(Properties[propertyId].keyholders),
      propertyId
    }
  )

  TriggerClientEvent("rs_housing:client:updateProperty", -1, propertyId, 'REMOVED_KEYHOLDER', { citizenid })

end)

RegisterServerEvent('rs_housing:server:onMembersPermissionUpdate')
AddEventHandler('rs_housing:server:onMembersPermissionUpdate', function(propertyId, citizenid, permission)

  local _source = source

  local Properties = GetProperties()

  if Properties[propertyId] == nil or not AllowedKeyholderPermissions[permission] then return end

  if not CanManageKeyholders(Properties[propertyId], _source)
      or not IsPlayerAtProperty(Properties[propertyId], _source) then
    notiKeyError(_source, Locales['HOUSING_NOTI'], Locales['INSUFFICIENT_PERMISSIONS'])
    return
  end

  local Property = Properties[propertyId]

  if Property.keyholders[citizenid] == nil then return end

  local KeyholderData = Property.keyholders[citizenid]

  KeyholderData.permissions[permission] =
  KeyholderData.permissions[permission] == 0 and 1 or 0

  local newValue = KeyholderData.permissions[permission]

  exports.oxmysql:execute(
    'UPDATE properties SET keyholders = ? WHERE name = ?',
    {
      json.encode(Property.keyholders),
      propertyId
    }
  )

  TriggerClientEvent("rs_housing:client:updateProperty", -1, propertyId, 'UPDATE_KEYHOLDER_PERMISSION', 
    {
      citizenid, 
      permission, 
      newValue
    }
  )
end)

