RegisterNetEvent("rs_housing:client:closeNUI")
AddEventHandler("rs_housing:client:closeNUI", function()
	SendNUIMessage({ action = 'closeUI' })
end)

SetCurrentBackgroundImageUrl = function(cb)
    SendNUIMessage({ action = "updateCurrentSelectedType", backgroundImageUrl = cb})
end

CloseNUIProperly = function()
	SendNUIMessage({ action = 'closeUI' })

	GetPlayerData().DisplayingUI = false
end

EnableNUI = function(state)
	SetNuiFocus(false, false)

	GetPlayerData().DisplayingUI = state

	SendNUIMessage({ type = "enable",  enable = state })
end

RegisterNUICallback('closeNUI', function()
	EnableNUI(false)
end)

RegisterNetEvent('rs_housing:ShowAdvancedNotification', function(title, subTitle, dict, icon, duration, color)
    exports['rs_housing']:ShowAdvancedNotification(title, subTitle, dict, icon, duration, color)
end)