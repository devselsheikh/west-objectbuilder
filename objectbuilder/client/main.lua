local uiOpen = false
local currentMap = Config.DefaultMapName
local mapObjects = {}

local function closeUi()
    uiOpen = false
    ObjectBuilderEditor.closePreview()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    TriggerServerEvent('objectbuilder:server:sessionEnded')
    SendNUIMessage({ type = 'close' })
end

CreateThread(function()
    while true do
        if uiOpen and IsControlJustPressed(0, 322) then
            closeUi()
            Wait(150)
        else
            Wait(uiOpen and 0 or 500)
        end
    end
end)

RegisterNetEvent('objectbuilder:client:sessionAccepted', function(mapName)
    currentMap = mapName
end)

RegisterNetEvent('objectbuilder:client:mapStateUpdated', function(mapName, objects)
    currentMap = mapName
    mapObjects = objects or {}
    SendNUIMessage({ type = 'mapState', map = currentMap, objects = mapObjects })
end)


RegisterNetEvent('objectbuilder:client:mapExportReady', function(payload)
    SendNUIMessage({ type = 'export', payload = payload })
end)

RegisterNUICallback('close', function(_, cb) closeUi() cb({ ok = true }) end)

RegisterNUICallback('loadMap', function(data, cb)
    if ObjectBuilderSchema.isSafeName(data.map, 64) then
        currentMap = data.map
        TriggerServerEvent('objectbuilder:server:sessionStarted', currentMap)
    end
    cb({ ok = true })
end)

RegisterNUICallback('toggleEditor', function(data, cb)
    if data.enabled then
        ObjectBuilderEditor.openPreview()
    else
        ObjectBuilderEditor.closePreview()
    end
    cb({ ok = true })
end)

RegisterNUICallback('setModel', function(data, cb)
    if type(data.model) == 'string' then ObjectBuilderEditor.openPreview(data.model) end
    cb({ ok = true })
end)

RegisterNUICallback('selectObject', function(data, cb)
    ObjectBuilderSelection.setSingle(data.id)
    for i = 1, #mapObjects do
        if mapObjects[i].id == data.id then
            SendNUIMessage({ type = 'inspector', object = mapObjects[i] })
            break
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('duplicateObject', function(_, cb)
    local selected = ObjectBuilderSelection.getAll()[1]
    for i = 1, #mapObjects do
        if mapObjects[i].id == selected then
            local obj = mapObjects[i]
            TriggerServerEvent('objectbuilder:server:objectPlaced', {
                id = ('obj_%s'):format(GetGameTimer()),
                model = obj.model,
                coords = { x = obj.coords.x + 0.3, y = obj.coords.y + 0.3, z = obj.coords.z },
                rotation = obj.rotation,
                frozen = obj.frozen
            })
            break
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('updateTransform', function(data, cb)
    local selected = ObjectBuilderSelection.getAll()[1]
    TriggerServerEvent('objectbuilder:server:objectUpdated', {
        id = selected,
        model = data.model or 'prop_barrier_work05',
        coords = data.coords,
        rotation = data.rotation,
        frozen = true
    })
    cb({ ok = true })
end)

RegisterNUICallback('exportMap', function(_, cb) TriggerServerEvent('objectbuilder:server:mapExportRequested') cb({ ok = true }) end)

RegisterCommand('objectbuilder', function()
    uiOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'open', models = Config.AllowedModels, map = currentMap })
    TriggerServerEvent('objectbuilder:server:sessionStarted', currentMap)
end, false)
