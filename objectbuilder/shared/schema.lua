ObjectBuilderSchema = {}

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

function ObjectBuilderSchema.isVec3(value)
    return type(value) == 'table'
        and isFiniteNumber(value.x)
        and isFiniteNumber(value.y)
        and isFiniteNumber(value.z)
end

function ObjectBuilderSchema.isSafeName(value, maxLen)
    return type(value) == 'string' and #value > 0 and #value <= (maxLen or 64)
end

function ObjectBuilderSchema.isObjectPayload(payload)
    return type(payload) == 'table'
        and ObjectBuilderSchema.isSafeName(payload.model, 120)
        and ObjectBuilderSchema.isVec3(payload.coords)
        and ObjectBuilderSchema.isVec3(payload.rotation)
end

function ObjectBuilderSchema.isImportPayload(payload, maxBytes)
    return type(payload) == 'string' and #payload > 2 and #payload <= maxBytes
end
