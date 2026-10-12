return function(ASTRAL)
    local Scheduler = { Owner = nil, Priority = 0 }
    function Scheduler:Request(owner, priority)
        priority = priority or 0
        if self.Owner and priority < self.Priority then return false end
        self.Owner, self.Priority = owner, priority
        return true
    end
    function Scheduler:Release(owner)
        if self.Owner == owner then self.Owner, self.Priority = nil, 0 end
    end
    function Scheduler:Status() return self.Owner or "IDLE" end
    ASTRAL.Scheduler = Scheduler
    return Scheduler
end
