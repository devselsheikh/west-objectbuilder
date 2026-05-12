local state = {
    open = false,
    editing = false,
    selectedModel = 'prop_barrier_work05',
    previewEntity = nil,
    currentMap = Config.DefaultMapName,
    selectedAxis = 'all',
    snap = true,
    frozen = true,
    mapObjects = {},
    selectedObjectId = nil
}

local function notify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

local function cleanupPreview()
    if state.previewEntity and DoesEntityExist(state.previewEntity) then DeleteEntity(state.previewEntity) end
    state.previewEntity = nil
end

local function requestModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function createPreview()
    cleanupPreview()
    local coords = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 2.0, 0.0)
    local hash = requestModel(state.selectedModel)
    if not hash then notify('Invalid model selected') return end
    state.previewEntity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(state.previewEntity, false, false)
    SetEntityAlpha(state.previewEntity, 180, false)
    FreezeEntityPosition(state.previewEntity, true)
end

local function getTransformStep(kind)
    if state.snap then return kind == 'move' and Config.Validation.snapMove or Config.Validation.snapRotate end
    return kind == 'move' and Config.Validation.precisionMove or Config.Validation.precisionRotate
end

local function applyMove(dx, dy, dz)
    if not state.previewEntity then return end
    local c = GetEntityCoords(state.previewEntity)
    local step = getTransformStep('move')
    local nx, ny, nz = c.x + (dx * step), c.y + (dy * step), c.z + (dz * step)
    if state.selectedAxis == 'x' then ny, nz = c.y, c.z end
    if state.selectedAxis == 'y' then nx, nz = c.x, c.z end
    if state.selectedAxis == 'z' then nx, ny = c.x, c.y end
    SetEntityCoordsNoOffset(state.previewEntity, nx, ny, nz, false, false, false)
end

local function applyRotate(direction)
    if not state.previewEntity then return end
    local rot = GetEntityRotation(state.previewEntity, 2)
    SetEntityRotation(state.previewEntity, rot.x, rot.y, rot.z + (direction * getTransformStep('rotate')), 2, true)
end

local function getSelectedObject()
    if not state.selectedObjectId then return nil end
    for i = 1, #state.mapObjects do
        if state.mapObjects[i].id == state.selectedObjectId then return state.mapObjects[i] end
    end
    return nil
end

local function placeObject()
    if not state.previewEntity then return end
    local coords = GetEntityCoords(state.previewEntity)
    local rot = GetEntityRotation(state.previewEntity, 2)
    TriggerServerEvent('objectbuilder:server:objectPlaced', state.currentMap, {
        id = ('obj_%s'):format(GetGameTimer()),
        model = state.selectedModel,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        rotation = { x = rot.x, y = rot.y, z = rot.z },
        frozen = state.frozen,
        metadata = { placedBy = GetPlayerServerId(PlayerId()) }
    })
end

local function closeUi()
    state.open, state.editing = false, false
    cleanupPreview()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'close' })
end

CreateThread(function()
    while true do
        if state.editing and state.previewEntity then
            Wait(0)
            if IsControlJustPressed(0, 172) then applyMove(0, 1, 0) end
            if IsControlJustPressed(0, 173) then applyMove(0, -1, 0) end
            if IsControlJustPressed(0, 174) then applyMove(-1, 0, 0) end
            if IsControlJustPressed(0, 175) then applyMove(1, 0, 0) end
            if IsControlJustPressed(0, 10) then applyMove(0, 0, 1) end
            if IsControlJustPressed(0, 11) then applyMove(0, 0, -1) end
            if IsControlJustPressed(0, 44) then applyRotate(-1) end
            if IsControlJustPressed(0, 38) then applyRotate(1) end
            if IsControlJustPressed(0, 191) then placeObject() end
        else
            Wait(300)
        end
    end
end)

CreateThread(function()
    while true do
        if state.open then
            Wait(0)
            if IsControlJustPressed(0, 322) then closeUi() end
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('objectbuilder:client:mapStateUpdated', function(mapName, mapObjects)
    state.currentMap = mapName
    state.mapObjects = mapObjects or {}
    SendNUIMessage({ type = 'mapState', objects = state.mapObjects, map = state.currentMap })
end)

RegisterNetEvent('objectbuilder:client:mapExported', function(payload)
    SendNUIMessage({ type = 'export', payload = payload })
end)

RegisterNUICallback('close', function(_, cb) closeUi() cb({ ok = true }) end)

RegisterNUICallback('toggleEditor', function(data, cb)
    state.editing = data.enabled == true
    if state.editing then createPreview() else cleanupPreview() end
    cb({ ok = true })
end)

RegisterNUICallback('setModel', function(data, cb)
    if type(data.model) == 'string' then
        state.selectedModel = data.model
        if state.editing then createPreview() end
    end
    cb({ ok = true })
end)

RegisterNUICallback('setSnap', function(data, cb) state.snap = data.enabled == true cb({ ok = true }) end)

RegisterNUICallback('setAxis', function(data, cb)
    if data.axis == 'x' or data.axis == 'y' or data.axis == 'z' or data.axis == 'all' then state.selectedAxis = data.axis end
    cb({ ok = true })
end)

RegisterNUICallback('selectObject', function(data, cb)
    state.selectedObjectId = data.id
    local object = getSelectedObject()
    SendNUIMessage({ type = 'inspector', object = object })
    cb({ ok = true })
end)

RegisterNUICallback('deleteObject', function(data, cb)
    TriggerServerEvent('objectbuilder:server:objectDeleted', state.currentMap, data.id)
    cb({ ok = true })
end)

RegisterNUICallback('duplicateObject', function(_, cb)
    local object = getSelectedObject()
    if object then
        TriggerServerEvent('objectbuilder:server:objectPlaced', state.currentMap, {
            id = ('obj_%s'):format(GetGameTimer()),
            model = object.model,
            coords = { x = object.coords.x + 0.5, y = object.coords.y + 0.5, z = object.coords.z },
            rotation = object.rotation,
            frozen = object.frozen,
            metadata = object.metadata
        })
    end
    cb({ ok = true })
end)

RegisterNUICallback('freezeObject', function(data, cb)
    local object = getSelectedObject()
    if object then
        object.frozen = data.frozen == true
        TriggerServerEvent('objectbuilder:server:objectUpdated', state.currentMap, object)
    end
    cb({ ok = true })
end)

RegisterNUICallback('updateTransform', function(data, cb)
    local object = getSelectedObject()
    if object and ObjectBuilderUtils.isVec3(data.coords) and ObjectBuilderUtils.isVec3(data.rotation) then
        object.coords, object.rotation = data.coords, data.rotation
        TriggerServerEvent('objectbuilder:server:objectUpdated', state.currentMap, object)
    end
    cb({ ok = true })
end)

RegisterNUICallback('exportMap', function(_, cb) TriggerServerEvent('objectbuilder:server:mapExported', state.currentMap) cb({ ok = true }) end)
RegisterNUICallback('importMap', function(data, cb) TriggerServerEvent('objectbuilder:server:mapImported', state.currentMap, data.payload) cb({ ok = true }) end)
RegisterNUICallback('loadMap', function(data, cb) if type(data.map) == 'string' then TriggerServerEvent('objectbuilder:server:mapLoaded', data.map) end cb({ ok = true }) end)

AddEventHandler('onResourceStart', function(resName) if resName == GetCurrentResourceName() then closeUi() end end)
AddEventHandler('onResourceStop', function(resName) if resName == GetCurrentResourceName() then closeUi() end end)

RegisterCommand('objectbuilder', function()
    state.open = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'open', models = Config.AllowedModels, map = state.currentMap })
    TriggerServerEvent('objectbuilder:server:mapLoaded', state.currentMap)
end, false)
