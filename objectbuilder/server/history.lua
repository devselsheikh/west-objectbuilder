ObjectBuilderHistory = {}

local history = {}

local function pushStack(stack, value, max)
    stack[#stack + 1] = value
    if #stack > max then table.remove(stack, 1) end
end

function ObjectBuilderHistory.initMap(mapName)
    history[mapName] = history[mapName] or { undo = {}, redo = {} }
end

function ObjectBuilderHistory.pushUndo(mapName, op, max)
    ObjectBuilderHistory.initMap(mapName)
    local entry = history[mapName]
    pushStack(entry.undo, op, max)
    entry.redo = {}
end

function ObjectBuilderHistory.popUndo(mapName)
    ObjectBuilderHistory.initMap(mapName)
    local entry = history[mapName]
    local op = entry.undo[#entry.undo]
    entry.undo[#entry.undo] = nil
    return op
end

function ObjectBuilderHistory.pushRedo(mapName, op, max)
    ObjectBuilderHistory.initMap(mapName)
    pushStack(history[mapName].redo, op, max)
end

function ObjectBuilderHistory.popRedo(mapName)
    ObjectBuilderHistory.initMap(mapName)
    local entry = history[mapName]
    local op = entry.redo[#entry.redo]
    entry.redo[#entry.redo] = nil
    return op
end
