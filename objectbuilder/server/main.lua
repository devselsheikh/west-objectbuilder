local resourceName = GetCurrentResourceName()
local objectMaps = {}
local activeObjects = {}
local playerRates = {}
local lockedPlayers = {}
local pendingDelete = {}

local function ensureMapFolder()
    local testName = ('%s/.keep'):format(Config.MapFolder)
    SaveResourceFile(resourceName, testName, '', -1)
end

local function hasAce(src, ace)
    return IsPlayerAceAllowed(src, ace)
end

local function now() return os.time() end

local function isLocked(src)
    local info = lockedPlayers[src]
    if not info then return false end
    if now() > info.unlockAt then lockedPlayers[src] = nil return false end
    return true
end

local function lockPlayer(src, reason)
    lockedPlayers[src] = { unlockAt = now() + Config.RateLimit.abuseLockSeconds, reason = reason }
end

local function checkAndCountRate(src)
    local current = now()
    local rate = playerRates[src]
    if not rate or current - rate.windowStart >= 60 then
        rate = { windowStart = current, count = 0, strikes = 0 }
        playerRates[src] = rate
    end
    rate.count = rate.count + 1
    if rate.count > Config.RateLimit.placementsPerMinute then
        rate.strikes = rate.strikes + 1
        if rate.strikes >= 3 then lockPlayer(src, 'spam') end
        return false
    end
    return true
end

local function isCoordinateValid(vec)
    if not ObjectBuilderUtils.isVec3(vec) then return false end
    return vec.x >= Config.Validation.minCoordinate and vec.x <= Config.Validation.maxCoordinate
        and vec.y >= Config.Validation.minCoordinate and vec.y <= Config.Validation.maxCoordinate
        and vec.z >= Config.Validation.minCoordinate and vec.z <= Config.Validation.maxCoordinate
end

local function isDistanceValid(src, coords)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(coords - GetEntityCoords(ped)) <= Config.Validation.maxDistanceFromPlayer
end

local function isModelAllowed(model)
    return type(model) == 'string' and Config.AllowedModels[model] == true
end

local function mapPath(name)
    return ('%s/%s.json'):format(Config.MapFolder, name)
end

local function saveMap(name)
    SaveResourceFile(resourceName, mapPath(name), json.encode({ name = name, objects = objectMaps[name] or {} }), -1)
end

local function loadMap(name)
    local raw = LoadResourceFile(resourceName, mapPath(name))
    if not raw then objectMaps[name] = {} return true end
    if #raw > Config.RateLimit.maxPayloadBytes then return false end
    local data = json.decode(raw)
    if type(data) ~= 'table' or type(data.objects) ~= 'table' then return false end
    objectMaps[name] = data.objects
    return true
end

local function cleanupObject(id)
    local entity = activeObjects[id]
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
    activeObjects[id] = nil
end

local function spawnObject(object)
    cleanupObject(object.id)
    local modelHash = joaat(object.model)
    local entity = CreateObjectNoOffset(modelHash, object.coords.x, object.coords.y, object.coords.z, true, true, false)
    SetEntityRotation(entity, object.rotation.x, object.rotation.y, object.rotation.z, 2, true)
    FreezeEntityPosition(entity, object.frozen == true)
    SetEntityAsMissionEntity(entity, true, false)
    activeObjects[object.id] = entity
end

local function sanitizeObject(src, payload)
    if type(payload) ~= 'table' then return nil end
    if not isModelAllowed(payload.model) then return nil end
    if not isCoordinateValid(payload.coords) or not isCoordinateValid(payload.rotation) then return nil end
    local coordsVec = vector3(payload.coords.x, payload.coords.y, payload.coords.z)
    if not isDistanceValid(src, coordsVec) then return nil end
    return {
        id = ObjectBuilderUtils.safeString(payload.id, 80) or ('obj_%s'):format(math.random(100000, 999999)),
        model = payload.model,
        coords = { x = payload.coords.x, y = payload.coords.y, z = payload.coords.z },
        rotation = { x = payload.rotation.x, y = payload.rotation.y, z = payload.rotation.z },
        frozen = payload.frozen == true,
        metadata = type(payload.metadata) == 'table' and payload.metadata or {}
    }
end

local function sendMapState(src, mapName)
    TriggerClientEvent('objectbuilder:client:mapStateUpdated', src, mapName, objectMaps[mapName] or {})
end

RegisterNetEvent('objectbuilder:server:mapLoaded', function(mapName)
    local src = source
    if GetInvokingResource() then return end
    if not hasAce(src, Config.AceUse) or type(mapName) ~= 'string' then return end

    if not loadMap(mapName) then return end
    local map = objectMaps[mapName]
    for i = 1, #map do
        local object = map[i]
        if isModelAllowed(object.model) and isCoordinateValid(object.coords) and isCoordinateValid(object.rotation) then
            spawnObject(object)
        end
    end
    sendMapState(src, mapName)
end)

RegisterNetEvent('objectbuilder:server:objectPlaced', function(mapName, payload)
    local src = source
    if GetInvokingResource() then return end
    if not hasAce(src, Config.AceUse) or isLocked(src) then return end
    if not checkAndCountRate(src) or type(mapName) ~= 'string' then return end

    objectMaps[mapName] = objectMaps[mapName] or {}
    if #objectMaps[mapName] >= Config.RateLimit.maxObjectsPerMap then return end

    local object = sanitizeObject(src, payload)
    if not object then return end

    objectMaps[mapName][#objectMaps[mapName] + 1] = object
    spawnObject(object)
    saveMap(mapName)
    sendMapState(src, mapName)
end)

RegisterNetEvent('objectbuilder:server:objectDeleted', function(mapName, objectId)
    local src = source
    if GetInvokingResource() then return end
    if not hasAce(src, Config.AceUse) or type(mapName) ~= 'string' or type(objectId) ~= 'string' then return end

    local map = objectMaps[mapName]
    if type(map) ~= 'table' then return end
    for i = #map, 1, -1 do
        if map[i].id == objectId then
            map[i] = map[#map]
            map[#map] = nil
            pendingDelete[#pendingDelete + 1] = objectId
            saveMap(mapName)
            sendMapState(src, mapName)
            return
        end
    end
end)

RegisterNetEvent('objectbuilder:server:objectUpdated', function(mapName, payload)
    local src = source
    if GetInvokingResource() then return end
    if not hasAce(src, Config.AceUse) or type(mapName) ~= 'string' then return end
    local object = sanitizeObject(src, payload)
    if not object then return end

    local map = objectMaps[mapName]
    if type(map) ~= 'table' then return end
    for i = 1, #map do
        if map[i].id == object.id then
            map[i] = object
            spawnObject(object)
            saveMap(mapName)
            sendMapState(src, mapName)
            return
        end
    end
end)

RegisterNetEvent('objectbuilder:server:mapImported', function(mapName, payload)
    local src = source
    if GetInvokingResource() then return end
    if not hasAce(src, Config.AceAdmin) then return end
    if type(payload) ~= 'string' or #payload > Config.RateLimit.maxPayloadBytes then return end

    local decoded = json.decode(payload)
    if type(decoded) ~= 'table' or type(decoded.objects) ~= 'table' then return end

    local rebuilt, count = {}, 0
    for i = 1, #decoded.objects do
        local sanitized = sanitizeObject(src, decoded.objects[i])
        if sanitized then
            count = count + 1
            rebuilt[count] = sanitized
            if count >= Config.RateLimit.maxObjectsPerMap then break end
        end
    end

    objectMaps[mapName] = rebuilt
    for id, _ in pairs(activeObjects) do cleanupObject(id) end
    for i = 1, #rebuilt do spawnObject(rebuilt[i]) end
    saveMap(mapName)
    sendMapState(src, mapName)
end)

RegisterNetEvent('objectbuilder:server:mapExported', function(mapName)
    local src = source
    if GetInvokingResource() then return end
    if not hasAce(src, Config.AceAdmin) then return end
    local map = objectMaps[mapName] or {}
    TriggerClientEvent('objectbuilder:client:mapExported', src, json.encode({ name = mapName, objects = map }, { indent = true }))
end)

CreateThread(function()
    while true do
        if #pendingDelete > 0 then
            cleanupObject(table.remove(pendingDelete, 1))
            Wait(75)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerRates[src], lockedPlayers[src] = nil, nil
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= resourceName then return end
    ensureMapFolder()
    if not loadMap(Config.DefaultMapName) then objectMaps[Config.DefaultMapName] = {} end
    local map = objectMaps[Config.DefaultMapName]
    for i = 1, #map do
        local object = map[i]
        if isModelAllowed(object.model) and isCoordinateValid(object.coords) and isCoordinateValid(object.rotation) then
            spawnObject(object)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= resourceName then return end
    for id, _ in pairs(activeObjects) do cleanupObject(id) end
end)
