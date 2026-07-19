# Adding Bank Money to an Offline Player

Another server-side resource can add money to a player's bank account while the player is offline by loading the character through RSG Core, adding the money, and explicitly saving the offline player.

Use the character's `citizenid`, not their temporary server ID.

```lua
local RSGCore = exports['rsg-core']:GetCoreObject()

local function AddMoneyToBank(citizenid, amount, reason)
    amount = tonumber(amount)

    if not citizenid or not amount or amount <= 0 then
        return false, 'invalid arguments'
    end

    -- Check for a live player first so their current in-memory data is used.
    local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    local isOffline = false

    if not Player then
        Player = RSGCore.Functions.GetOfflinePlayerByCitizenId(citizenid)
        isOffline = true
    end

    if not Player then
        return false, 'player not found'
    end

    local success = Player.Functions.AddMoney(
        'bank',
        amount,
        reason or 'external-bank-transfer'
    )

    if not success then
        return false, 'unable to add bank money'
    end

    -- AddMoney updates only the loaded object for an offline character.
    -- Save it explicitly to persist the new balance in the database.
    if isOffline then
        Player.Functions.Save()
    end

    return true
end
```

## Example

```lua
local success, errorMessage = AddMoneyToBank(
    targetCitizenId,
    250.00,
    'property-sale'
)

if not success then
    print(('Bank transfer failed: %s'):format(errorMessage))
end
```

The essential offline-only sequence is:

```lua
local Player = RSGCore.Functions.GetOfflinePlayerByCitizenId(citizenid)

if Player and Player.Functions.AddMoney('bank', amount, reason) then
    Player.Functions.Save()
end
```

This resource currently uses `bank` as its configured bank money type. `Player.Functions.Save()` is required for an offline player because `AddMoney()` does not automatically write an offline player's changed balance back to the `players.money` database field.
