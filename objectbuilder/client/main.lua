local state = {
    open = false,
    editing = false,
    selectedModel = 'prop_barrier_work05',
    previewEntity = nil,
    currentMap = Config.DefaultMapName,
    selectedAxis = 'all',
    snap = true,
    frozen = true
}

local function notify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

local function requestModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasModelLoaded(hash) and hash or nil
end

local function cleanupPreview()
    if state.previewEntity and DoesEntityExist(state.previewEntity) then
        DeleteEntity(state.previewEntity)
    end
    state.previewEntity = nil
end

local function createPreview()
    cleanupPreview()
    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
    local hash = requestModel(state.selectedModel)
    if not hash then
        notify('Invalid model')
        return
    end

    local entity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(entity, false, false)
    SetEntityAlpha(entity, 180, false)
    FreezeEntityPosition(entity, true)
    state.previewEntity = entity
end

local function getTransformStep(kind)
    if state.snap then
        return kind == 'move' and Config.Validation.snapMove or Config.Validation.snapRotate
    end
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

local function applyRotate(rz)
    if not state.previewEntity then return end
    local rot = GetEntityRotation(state.previewEntity, 2)
    local step = getTransformStep('rotate')
    SetEntityRotation(state.previewEntity, rot.x, rot.y, rot.z + (rz * step), 2, true)
end

local function placeObject()
    if not state.previewEntity then return end
    local coords = GetEntityCoords(state.previewEntity)
    local rot = GetEntityRotation(state.previewEntity, 2)
    local payload = {
        id = ('obj_%s'):format(GetGameTimer()),
        model = state.selectedModel,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        rotation = { x = rot.x, y = rot.y, z = rot.z },
        frozen = state.frozen,
        metadata = { placedBy = GetPlayerServerId(PlayerId()) }
    }

    TriggerServerEvent('objectbuilder:server:place', state.currentMap, payload)
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
            Wait(500)
        end
    end
end)

RegisterNetEvent('objectbuilder:client:placed', function()
    notify('Object saved successfully')
end)

RegisterNetEvent('objectbuilder:client:exported', function(payload)
    SendNUIMessage({ type = 'export', payload = payload })
end)

RegisterNUICallback('toggleEditor', function(data, cb)
    state.editing = data.enabled == true
    if state.editing then
        createPreview()
    else
        cleanupPreview()
    end
    cb({ ok = true })
end)

RegisterNUICallback('setModel', function(data, cb)
    if type(data.model) == 'string' then
        state.selectedModel = data.model
        if state.editing then createPreview() end
    end
    cb({ ok = true })
end)

RegisterNUICallback('setSnap', function(data, cb)
    state.snap = data.enabled == true
    cb({ ok = true })
end)

RegisterNUICallback('setAxis', function(data, cb)
    if data.axis == 'x' or data.axis == 'y' or data.axis == 'z' or data.axis == 'all' then
        state.selectedAxis = data.axis
    end
    cb({ ok = true })
end)

RegisterNUICallback('deleteObject', function(data, cb)
    TriggerServerEvent('objectbuilder:server:delete', state.currentMap, data.id)
    cb({ ok = true })
end)

RegisterNUICallback('exportMap', function(_, cb)
    TriggerServerEvent('objectbuilder:server:export', state.currentMap)
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    state.open = false
    state.editing = false
    cleanupPreview()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
    cb({ ok = true })
end)

AddEventHandler('onResourceStart', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    state.open = false
    state.editing = false
    cleanupPreview()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    state.open = false
    state.editing = false
    cleanupPreview()
    SetNuiFocus(false, false)
end)

RegisterCommand('objectbuilder', function()
    state.open = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'open',
        models = Config.AllowedModels,
        map = state.currentMap
    })
end, false)
