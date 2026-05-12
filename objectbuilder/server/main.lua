local resourceName = GetCurrentResourceName()
local objectMaps = {}
local activeObjects = {}
local playerRates = {}
local lockedPlayers = {}
local pendingDelete = {}

local function ensureMapFolder()
    local folder = Config.MapFolder
    local testName = ('%s/.keep'):format(folder)
    SaveResourceFile(resourceName, testName, '', -1)
end

local function hasAce(src, ace)
    return IsPlayerAceAllowed(src, ace)
end

local function now()
    return os.time()
end

local function isLocked(src)
    local info = lockedPlayers[src]
    if not info then return false end
    if now() > info.unlockAt then
        lockedPlayers[src] = nil
        return false
    end
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
        if rate.strikes >= 3 then
            lockPlayer(src, 'spam')
        end
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
    local pcoords = GetEntityCoords(ped)
    local distance = #(coords - pcoords)
    return distance <= Config.Validation.maxDistanceFromPlayer
end

local function isModelAllowed(model)
    local modelName = type(model) == 'number' and tostring(model) or model
    if type(modelName) ~= 'string' then return false end
    return Config.AllowedModels[modelName] == true
end

local function mapPath(name)
    return ('%s/%s.json'):format(Config.MapFolder, name)
end

local function saveMap(name)
    local payload = json.encode({ name = name, objects = objectMaps[name] or {} })
    SaveResourceFile(resourceName, mapPath(name), payload, -1)
end

local function loadMap(name)
    local raw = LoadResourceFile(resourceName, mapPath(name))
    if not raw then
        objectMaps[name] = {}
        return true
    end

    if #raw > Config.RateLimit.maxPayloadBytes then
        return false
    end

    local data = json.decode(raw)
    if type(data) ~= 'table' or type(data.objects) ~= 'table' then
        return false
    end

    objectMaps[name] = data.objects
    return true
end

local function spawnObject(object)
    local modelHash = type(object.model) == 'string' and joaat(object.model) or object.model
    local entity = CreateObjectNoOffset(modelHash, object.coords.x, object.coords.y, object.coords.z, true, true, false)
    SetEntityRotation(entity, object.rotation.x, object.rotation.y, object.rotation.z, 2, true)
    FreezeEntityPosition(entity, object.frozen == true)
    SetEntityAsMissionEntity(entity, true, false)
    activeObjects[object.id] = entity
end

local function cleanupObject(id)
    local entity = activeObjects[id]
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
    activeObjects[id] = nil
end

local function validatePlacement(src, payload)
    if type(payload) ~= 'table' then return false end
    if not isModelAllowed(payload.model) then return false end
    if not isCoordinateValid(payload.coords) or not isCoordinateValid(payload.rotation) then return false end
    if not isDistanceValid(src, vector3(payload.coords.x, payload.coords.y, payload.coords.z)) then return false end
    return true
end

RegisterNetEvent('objectbuilder:server:place', function(mapName, payload)
    local src = source
    if not hasAce(src, Config.AceUse) or isLocked(src) then return end
    if not checkAndCountRate(src) then return end
    if type(mapName) ~= 'string' or #mapName > 64 then return end
    if not validatePlacement(src, payload) then return end

    objectMaps[mapName] = objectMaps[mapName] or {}
    if #objectMaps[mapName] >= Config.RateLimit.maxObjectsPerMap then return end

    local object = {
        id = payload.id,
        model = payload.model,
        coords = payload.coords,
        rotation = payload.rotation,
        frozen = payload.frozen == true,
        metadata = payload.metadata or {}
    }

    table.insert(objectMaps[mapName], object)
    spawnObject(object)
    saveMap(mapName)

    TriggerClientEvent('objectbuilder:client:placed', src, object)
end)

RegisterNetEvent('objectbuilder:server:delete', function(mapName, objectId)
    local src = source
    if not hasAce(src, Config.AceUse) or isLocked(src) then return end

    local map = objectMaps[mapName]
    if type(map) ~= 'table' then return end

    for i = #map, 1, -1 do
        if map[i].id == objectId then
            table.remove(map, i)
            pendingDelete[#pendingDelete + 1] = objectId
            saveMap(mapName)
            break
        end
    end
end)

CreateThread(function()
    while true do
        Wait(250)
        if #pendingDelete > 0 then
            local id = table.remove(pendingDelete, 1)
            cleanupObject(id)
        else
            Wait(1000)
        end
    end
end)

RegisterNetEvent('objectbuilder:server:loadMap', function(mapName)
    local src = source
    if not hasAce(src, Config.AceUse) then return end
    if type(mapName) ~= 'string' or #mapName > 64 then return end

    if not loadMap(mapName) then return end

    for _, object in ipairs(objectMaps[mapName]) do
        if isModelAllowed(object.model) and isCoordinateValid(object.coords) and isCoordinateValid(object.rotation) then
            spawnObject(object)
        end
    end
end)

RegisterNetEvent('objectbuilder:server:export', function(mapName)
    local src = source
    if not hasAce(src, Config.AceAdmin) then return end

    local map = objectMaps[mapName] or {}
    local payload = json.encode({ name = mapName, objects = map }, { indent = true })
    if #payload > Config.RateLimit.maxPayloadBytes then return end
    TriggerClientEvent('objectbuilder:client:exported', src, payload)
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerRates[src] = nil
    lockedPlayers[src] = nil
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= resourceName then return end
    ensureMapFolder()
    loadMap(Config.DefaultMapName)
    for _, object in ipairs(objectMaps[Config.DefaultMapName]) do
        if isModelAllowed(object.model) and isCoordinateValid(object.coords) and isCoordinateValid(object.rotation) then
            spawnObject(object)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= resourceName then return end
    for id, _ in pairs(activeObjects) do
        cleanupObject(id)
    end
end)
