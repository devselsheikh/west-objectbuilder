ObjectBuilderSelection = {}

local selectedIds = {}

function ObjectBuilderSelection.clear()
    selectedIds = {}
end

function ObjectBuilderSelection.setSingle(id)
    selectedIds = {}
    if id then selectedIds[1] = id end
end

function ObjectBuilderSelection.getAll()
    return selectedIds
end
