ObjectBuilderUtils = {}

function ObjectBuilderUtils.round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

function ObjectBuilderUtils.isVec3(data)
    return type(data) == 'table'
        and type(data.x) == 'number'
        and type(data.y) == 'number'
        and type(data.z) == 'number'
end

function ObjectBuilderUtils.toVec3Array(vec)
    return {
        ObjectBuilderUtils.round(vec.x, 4),
        ObjectBuilderUtils.round(vec.y, 4),
        ObjectBuilderUtils.round(vec.z, 4)
    }
end

function ObjectBuilderUtils.safeString(value, maxLen)
    if type(value) ~= 'string' then
        return nil
    end

    if #value > (maxLen or 64) then
        return nil
    end

    return value
end
