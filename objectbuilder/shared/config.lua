Config = {}

Config.AceUse = 'objectbuilder.use'
Config.AceAdmin = 'objectbuilder.admin'

Config.AllowedModels = {
    prop_barrier_work05 = true,
    prop_cone_float_1 = true,
    prop_tool_box_04 = true,
    prop_generator_01a = true,
    prop_roadcone02a = true
}

Config.RateLimit = {
    placementsPerMinute = 40,
    maxObjectsPerMap = 500,
    abuseLockSeconds = 300,
    maxPayloadBytes = 65536
}

Config.Validation = {
    maxDistanceFromPlayer = 40.0,
    minCoordinate = -20000.0,
    maxCoordinate = 20000.0,
    snapMove = 0.25,
    snapRotate = 5.0,
    precisionMove = 0.05,
    precisionRotate = 1.0
}

Config.DefaultMapName = 'default'
Config.MapFolder = 'maps'
