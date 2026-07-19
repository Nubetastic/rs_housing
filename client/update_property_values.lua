RegisterNetEvent('rs_housing:client:propertyValuesUpdateResult', function(success, message)
    lib.notify({
        title = 'Property Value Updater',
        description = message,
        type = success and 'success' or 'error',
        duration = success and 8000 or 6000,
        position = 'top'
    })
end)
