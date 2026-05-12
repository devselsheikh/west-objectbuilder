ObjectBuilderValidators = {}

local loadedCatalog = nil

local function loadCatalogFile(path)
    local chunk = LoadResourceFile(GetCurrentResourceName(), path)
    if not chunk then return {} end
    local fn = load(chunk, ('@@%s'):format(path), 't', {})
    if not fn then return {} end
    local ok, list = pcall(fn)
    if not ok or type(list) ~= 'table' then return {} end
    return list
end

function ObjectBuilderValidators.getCatalog()
    if loadedCatalog then return loadedCatalog end

    local allowed = {}
    local core = loadCatalogFile('data/catalog/core.lua')
    local extended = loadCatalogFile('data/catalog/extended.lua')
    local blacklist = loadCatalogFile('data/catalog/blacklist.lua')

    for i = 1, #core do allowed[core[i]] = true end
    if Config.Catalog.allowExtended then
        for i = 1, #extended do allowed[extended[i]] = true end
    end
    for i = 1, #blacklist do allowed[blacklist[i]] = nil end

    for modelName, enabled in pairs(Config.AllowedModels) do
        if enabled then allowed[modelName] = true end
    end

    loadedCatalog = allowed
    return loadedCatalog
end

function ObjectBuilderValidators.isModelAllowed(model)
    if Config.Catalog.allowUnsafeCatalog then
        return type(model) == 'string'
    end
    return ObjectBuilderValidators.getCatalog()[model] == true
end

function ObjectBuilderValidators.isObjectPayload(payload)
    return ObjectBuilderSchema.isObjectPayload(payload)
end
