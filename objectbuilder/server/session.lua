ObjectBuilderSession = {}

local sessions = {}

function ObjectBuilderSession.start(src, mapName)
    sessions[src] = {
        source = src,
        map = mapName,
        startedAt = os.time(),
        lastActionAt = os.time(),
        windowStart = os.time(),
        actionCount = 0,
        strikes = 0,
        lockUntil = 0
    }
    return sessions[src]
end

function ObjectBuilderSession.get(src)
    return sessions[src]
end

function ObjectBuilderSession.stop(src)
    sessions[src] = nil
end

function ObjectBuilderSession.isLocked(src)
    local session = sessions[src]
    if not session then return false end
    if session.lockUntil > os.time() then return true end
    session.lockUntil = 0
    return false
end

function ObjectBuilderSession.recordAction(src, maxPerMinute, lockSeconds)
    local session = sessions[src]
    if not session then return false end

    local now = os.time()
    session.lastActionAt = now

    if now - session.windowStart >= 60 then
        session.windowStart = now
        session.actionCount = 0
    end

    session.actionCount = session.actionCount + 1
    if session.actionCount <= maxPerMinute then
        return true
    end

    session.strikes = session.strikes + 1
    if session.strikes >= 3 then
        session.lockUntil = now + lockSeconds
    end

    return false
end
