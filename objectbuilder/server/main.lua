local resourceName = GetCurrentResourceName()
local objectMaps, activeObjects = {}, {}

local function ensureMapFolder()
    SaveResourceFile(resourceName, ('%s/.keep'):format(Config.MapFolder), '', -1)
end

local function hasAce(src, ace) return IsPlayerAceAllowed(src, ace) end
local function mapPath(name) return ('%s/%s.json'):format(Config.MapFolder, name) end

local function saveMap(name)
    SaveResourceFile(resourceName, mapPath(name), json.encode({ name = name, version = '1.1', objects = objectMaps[name] or {} }), -1)
end

local function loadMap(name)
    local raw = LoadResourceFile(resourceName, mapPath(name))
    if not raw then objectMaps[name] = {} return true end
    local parsed = json.decode(raw)
    if type(parsed) ~= 'table' or type(parsed.objects) ~= 'table' then return false end
    objectMaps[name] = parsed.objects
    return true
end

local function cleanupEntity(id)
    local entity = activeObjects[id]
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
    activeObjects[id] = nil
end

local function spawnEntity(object)
    cleanupEntity(object.id)
    local hash = joaat(object.model)
    local entity = CreateObjectNoOffset(hash, object.coords.x, object.coords.y, object.coords.z, true, true, false)
    SetEntityRotation(entity, object.rotation.x, object.rotation.y, object.rotation.z, 2, true)
    FreezeEntityPosition(entity, object.frozen == true)
    SetEntityAsMissionEntity(entity, true, false)
    activeObjects[object.id] = entity
end

local function validateAndSanitize(src, payload)
    if not ObjectBuilderValidators.isObjectPayload(payload) then return nil end
    if not ObjectBuilderValidators.isModelAllowed(payload.model) then return nil end
    local coords = vector3(payload.coords.x, payload.coords.y, payload.coords.z)
    local ped = GetPlayerPed(src)
    if ped == 0 or #(coords - GetEntityCoords(ped)) > Config.Validation.maxDistanceFromPlayer then return nil end
    return {
        id = ObjectBuilderUtils.safeString(payload.id, 80) or ('obj_%s'):format(math.random(100000, 999999)),
        model = payload.model,
        coords = payload.coords,
        rotation = payload.rotation,
        frozen = payload.frozen == true,
        zone = payload.zone,
        tags = type(payload.tags) == 'table' and payload.tags or {},
        meta = type(payload.meta) == 'table' and payload.meta or {}
    }
end

local function pushMapState(src, map)
    TriggerClientEvent('objectbuilder:client:mapStateUpdated', src, map, objectMaps[map] or {})
end

RegisterNetEvent('objectbuilder:server:sessionStarted', function(map)
    local src = source
    if GetInvokingResource() then return end
    if not hasAce(src, Config.AceUse) or not ObjectBuilderSchema.isSafeName(map, 64) then return end
    if not loadMap(map) then return end
    ObjectBuilderSession.start(src, map)
    pushMapState(src, map)
    TriggerClientEvent('objectbuilder:client:sessionAccepted', src, map)
end)

RegisterNetEvent('objectbuilder:server:sessionEnded', function()
    local src = source
    ObjectBuilderSession.stop(src)
end)

RegisterNetEvent('objectbuilder:server:objectPlaced', function(payload)
    local src = source
    local session = ObjectBuilderSession.get(src)
    if not session or ObjectBuilderSession.isLocked(src) then return end
    if not ObjectBuilderSession.recordAction(src, Config.RateLimit.placementsPerMinute, Config.RateLimit.abuseLockSeconds) then return end
    local obj = validateAndSanitize(src, payload)
    if not obj then return end

    local map = session.map
    objectMaps[map] = objectMaps[map] or {}
    if #objectMaps[map] >= Config.RateLimit.maxObjectsPerMap then return end

    objectMaps[map][#objectMaps[map] + 1] = obj
    spawnEntity(obj)
    ObjectBuilderHistory.pushUndo(map, { type = 'objectPlaced', object = obj }, 100)
    saveMap(map)
    pushMapState(src, map)
end)

RegisterNetEvent('objectbuilder:server:objectUpdated', function(payload)
    local src = source
    local session = ObjectBuilderSession.get(src)
    if not session then return end
    local obj = validateAndSanitize(src, payload)
    if not obj then return end
    local map = objectMaps[session.map] or {}

    for i = 1, #map do
        if map[i].id == obj.id then
            local old = map[i]
            map[i] = obj
            spawnEntity(obj)
            ObjectBuilderHistory.pushUndo(session.map, { type = 'objectUpdated', before = old, after = obj }, 100)
            saveMap(session.map)
            pushMapState(src, session.map)
            return
        end
    end
end)


RegisterNetEvent('objectbuilder:server:mapExportRequested', function()
    local src = source
    local session = ObjectBuilderSession.get(src)
    if not session or not hasAce(src, Config.AceAdmin) then return end
    local payload = json.encode({ name = session.map, version = '1.1', objects = objectMaps[session.map] or {} }, { indent = true })
    TriggerClientEvent('objectbuilder:client:mapExportReady', src, payload)
end)

AddEventHandler('playerDropped', function() ObjectBuilderSession.stop(source) end)
AddEventHandler('onResourceStart', function(res) if res == resourceName then ensureMapFolder() loadMap(Config.DefaultMapName) end end)
AddEventHandler('onResourceStop', function(res) if res ~= resourceName then return end for id, _ in pairs(activeObjects) do cleanupEntity(id) end end)
