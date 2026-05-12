ObjectBuilderEditor = {}

local state = {
    enabled = false,
    previewEntity = nil,
    model = 'prop_barrier_work05',
    snap = true,
    axis = 'all'
}

local function cleanup()
    if state.previewEntity and DoesEntityExist(state.previewEntity) then DeleteEntity(state.previewEntity) end
    state.previewEntity = nil
end

function ObjectBuilderEditor.openPreview(model)
    cleanup()
    state.model = model or state.model
    local hash = joaat(state.model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(hash) then return false end
    local coords = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 2.0, 0.0)
    state.previewEntity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(state.previewEntity, false, false)
    SetEntityAlpha(state.previewEntity, 170, false)
    FreezeEntityPosition(state.previewEntity, true)
    state.enabled = true
    return true
end

function ObjectBuilderEditor.closePreview()
    state.enabled = false
    cleanup()
end

function ObjectBuilderEditor.getPreviewPayload()
    if not state.previewEntity then return nil end
    local coords = GetEntityCoords(state.previewEntity)
    local rot = GetEntityRotation(state.previewEntity, 2)
    return {
        id = ('obj_%s'):format(GetGameTimer()),
        model = state.model,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        rotation = { x = rot.x, y = rot.y, z = rot.z },
        frozen = true
    }
end
