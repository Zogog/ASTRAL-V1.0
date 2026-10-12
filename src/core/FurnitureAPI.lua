-- ASTRAL dev.6.9.1 preferred Autofarm house discovery.
-- Scan owned house slots, score them by useful ailment furniture, then keep
-- furniture selection inside the best-covered house whenever possible.
return function(ASTRAL)
    local Game = assert(ASTRAL.Game, "GameAPI must load before FurnitureAPI")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ClientData = require(ReplicatedStorage:WaitForChild("Fsys")).load("ClientData")

    local Furniture = {
        Version = "0.2.0-dev.6.9.1-preferred-house",
        MaxAutoSlot = 20,
        Slots = {},
        Scanned = {},
        DiscoveredSlots = {},
        PreferredSlot = nil,
        PreferredCoverage = 0,
        PreferredCapabilities = {},
        HomeSelected = false,
    }

    local function normalise(value)
        return string.lower(tostring(value or ""))
    end

    local function validSlot(value)
        local slot = tonumber(value)
        if slot and slot >= 1 and slot % 1 == 0 then return slot end
        return nil
    end

    local function addUnique(list, seen, value)
        local slot = validSlot(value)
        if slot and not seen[slot] then
            seen[slot] = true
            table.insert(list, slot)
        end
    end

    local function hasAny(id, needles)
        for _, needle in ipairs(needles) do
            if id:find(needle, 1, true) then return true end
        end
        return false
    end

    function Furniture:Capabilities(record)
        local id = normalise(record and record.id)
        local caps = {}
        if id == "" then return caps end

        if hasAny(id, {"bed", "crib"}) then caps.sleepy = true end
        if hasAny(id, {"shower", "bathtub", "bath_tub"}) then caps.dirty = true end
        if id:find("toilet", 1, true) then caps.toilet = true end

        local bowlLike = id:find("bowl", 1, true)
            or id:find("feeder", 1, true)
            or id:find("feeding", 1, true)
        if bowlLike and (id:find("food", 1, true) or id:find("feed", 1, true)) then
            caps.hungry = true
        end
        if bowlLike and (id:find("water", 1, true) or id:find("drink", 1, true)) then
            caps.thirsty = true
        end

        -- Historically observed Adopt Me ids. Keep these explicit even though
        -- the fuzzy rules above also recognise them.
        if id == "petfoodbowl" or id == "pet_food_bowl" then caps.hungry = true end
        if id == "petwaterbowl" or id == "pet_water_bowl" then caps.thirsty = true end
        return caps
    end

    function Furniture:CandidateSlots()
        local slots, seen = {}, {}
        addUnique(slots, seen, ASTRAL.Config and ASTRAL.Config.HouseSlot)
        for _, key in ipairs({ "house_interior", "house", "housing", "house_slots" }) do
            local ok, value = pcall(function() return ClientData.get(key) end)
            if ok and type(value) == "table" then
                for _, field in ipairs({
                    "active_house_slot", "active_house_id", "house_id", "houseId",
                }) do
                    addUnique(slots, seen, value[field])
                end
            end
        end
        for slot = 1, self.MaxAutoSlot do addUnique(slots, seen, slot) end
        return slots
    end

    function Furniture:ScanSlot(slot, force)
        slot = validSlot(slot)
        if not slot then return nil, "Invalid house slot" end
        if self.Scanned[slot] and not force then
            return self.Slots[slot], self.Slots[slot] and nil or "Previously unavailable"
        end

        self.Scanned[slot] = true
        local remote = Game:GetRemote("HousingAPI/GetFurnitureWithinHouse")
        if not remote then return nil, "Furniture lookup remote missing" end

        local ok, result = pcall(function() return remote:InvokeServer(slot) end)
        if not ok or type(result) ~= "table" then
            self.Slots[slot] = nil
            return nil, "House slot unavailable"
        end

        local records, byId = {}, {}
        for _, wrapper in pairs(result) do
            local data = type(wrapper) == "table" and (wrapper.data or wrapper) or nil
            if type(data) == "table" and type(data.unique) == "string" then
                local record = {
                    slot = slot,
                    id = tostring(data.id or ""),
                    unique = data.unique,
                    data = data,
                }
                table.insert(records, record)
                local id = normalise(record.id)
                if id ~= "" and not byId[id] then byId[id] = record end
            end
        end

        if #records == 0 then
            self.Slots[slot] = nil
            return nil, "No furniture records"
        end

        local snapshot = { slot = slot, records = records, byId = byId }
        self.Slots[slot] = snapshot
        if not table.find(self.DiscoveredSlots, slot) then
            table.insert(self.DiscoveredSlots, slot)
            table.sort(self.DiscoveredSlots)
        end

        local bowlIds = {}
        for _, record in ipairs(records) do
            local id = normalise(record.id)
            if id:find("bowl", 1, true) or id:find("feeder", 1, true)
                or id:find("feeding", 1, true) then
                table.insert(bowlIds, record.id)
            end
        end

        print(string.format(
            "[ASTRAL FURNITURE] discovered house slot %d (%d furniture records)%s",
            slot, #records,
            #bowlIds > 0 and (" | bowl-like=[" .. table.concat(bowlIds, ",") .. "]") or ""
        ))
        return snapshot
    end

    function Furniture:ScoreSlot(slot)
        local snapshot = self.Slots[slot]
        if not snapshot then return 0, {}, 0 end
        local caps, useful = {}, 0
        for _, record in ipairs(snapshot.records) do
            local recordCaps = self:Capabilities(record)
            local any = false
            for cap in pairs(recordCaps) do
                caps[cap] = true
                any = true
            end
            if any then useful += 1 end
        end
        local coverage = 0
        for _, cap in ipairs({"sleepy", "dirty", "toilet", "hungry", "thirsty"}) do
            if caps[cap] then coverage += 1 end
        end
        return coverage, caps, useful
    end

    function Furniture:SelectPreferredHome(force)
        if self.HomeSelected and self.PreferredSlot and not force then
            return self.PreferredSlot
        end

        -- Scan the complete bounded owned-slot range once. Slot availability is
        -- asynchronous, so retry unavailable slots once after the first pass.
        for _, slot in ipairs(self:CandidateSlots()) do self:ScanSlot(slot, force == true) end
        task.wait(0.35)
        for _, slot in ipairs(self:CandidateSlots()) do
            if self.Scanned[slot] and not self.Slots[slot] then self:ScanSlot(slot, true) end
        end

        local configured = validSlot(ASTRAL.Config and ASTRAL.Config.HouseSlot)
        local bestSlot, bestCoverage, bestUseful, bestCaps = nil, -1, -1, {}

        for _, slot in ipairs(self.DiscoveredSlots) do
            local coverage, caps, useful = self:ScoreSlot(slot)
            local capNames = {}
            for _, cap in ipairs({"sleepy", "dirty", "toilet", "hungry", "thirsty"}) do
                if caps[cap] then table.insert(capNames, cap) end
            end
            print(string.format(
                "[ASTRAL FURNITURE] house slot %d ailment coverage %d/5 [%s] (%d useful furniture)",
                slot, coverage, table.concat(capNames, ","), useful
            ))

            local wins = configured and slot == configured
                or (not configured and (
                    coverage > bestCoverage
                    or (coverage == bestCoverage and useful > bestUseful)
                    or (coverage == bestCoverage and useful == bestUseful
                        and (not bestSlot or slot < bestSlot))
                ))
            if wins then
                bestSlot, bestCoverage, bestUseful, bestCaps = slot, coverage, useful, caps
            end
        end

        self.PreferredSlot = bestSlot
        self.PreferredCoverage = math.max(0, bestCoverage)
        self.PreferredCapabilities = bestCaps
        self.HomeSelected = bestSlot ~= nil

        if bestSlot then
            local names = {}
            for _, cap in ipairs({"sleepy", "dirty", "toilet", "hungry", "thirsty"}) do
                if bestCaps[cap] then table.insert(names, cap) end
            end
            print(string.format(
                "[ASTRAL FURNITURE] preferred Autofarm house = slot %d | coverage %d/5 [%s]",
                bestSlot, self.PreferredCoverage, table.concat(names, ",")
            ))
        end
        return bestSlot
    end

    function Furniture:OrderedDiscoveredSlots()
        self:SelectPreferredHome(false)
        local out = {}
        if self.PreferredSlot and self.Slots[self.PreferredSlot] then
            table.insert(out, self.PreferredSlot)
        end
        for _, slot in ipairs(self.DiscoveredSlots) do
            if slot ~= self.PreferredSlot and self.Slots[slot] then table.insert(out, slot) end
        end
        return out
    end

    function Furniture:Find(ids, forceRefresh)
        local ordered, rank = {}, {}
        for _, id in ipairs(ids or {}) do
            local key = normalise(id)
            if key ~= "" and not rank[key] then
                table.insert(ordered, key)
                rank[key] = #ordered
            end
        end
        if #ordered == 0 then return nil, "No furniture ids requested" end
        if forceRefresh == true then self:Refresh() end
        self:SelectPreferredHome(false)

        -- Stay inside the preferred house first. Only cross-house fallback if
        -- that house genuinely lacks every requested candidate.
        for _, slot in ipairs(self:OrderedDiscoveredSlots()) do
            local snapshot = self.Slots[slot]
            if snapshot then
                for _, id in ipairs(ordered) do
                    local record = snapshot.byId[id]
                    if record then
                        print(string.format(
                            "[ASTRAL FURNITURE] matched %s in %s house slot %d -> %s",
                            record.id,
                            slot == self.PreferredSlot and "preferred" or "fallback",
                            slot, record.unique
                        ))
                        return record, rank[id]
                    end
                end
            end
        end

        return nil, "Required furniture not found: " .. table.concat(ids, ", ")
    end

    function Furniture:GetMatches(ids, preferredOnly)
        local rank, nextRank = {}, 0
        for _, id in ipairs(ids or {}) do
            local key = normalise(id)
            if key ~= "" and not rank[key] then
                nextRank += 1
                rank[key] = nextRank
            end
        end
        self:SelectPreferredHome(false)

        local matches, seen = {}, {}
        for _, slot in ipairs(self:OrderedDiscoveredSlots()) do
            if not preferredOnly or slot == self.PreferredSlot then
                local snapshot = self.Slots[slot]
                if snapshot then
                    for _, record in ipairs(snapshot.records) do
                        local id = normalise(record.id)
                        if rank[id] and not seen[record.unique] then
                            seen[record.unique] = true
                            table.insert(matches, {
                                record = record,
                                rank = rank[id],
                                preferred = slot == self.PreferredSlot,
                            })
                        end
                    end
                end
            end
        end
        table.sort(matches, function(a, b)
            if a.preferred ~= b.preferred then return a.preferred end
            if a.rank ~= b.rank then return a.rank < b.rank end
            return tostring(a.record.unique) < tostring(b.record.unique)
        end)
        local records = {}
        for _, entry in ipairs(matches) do table.insert(records, entry.record) end
        return records
    end

    function Furniture:FindMatching(predicate, description, forceRefresh)
        if type(predicate) ~= "function" then return nil, "Predicate required" end
        if forceRefresh == true then self:Refresh() end
        self:SelectPreferredHome(false)

        for _, slot in ipairs(self:OrderedDiscoveredSlots()) do
            local snapshot = self.Slots[slot]
            if snapshot then
                local matches = {}
                for _, record in ipairs(snapshot.records) do
                    local ok, matched = pcall(predicate, record)
                    if ok and matched then table.insert(matches, record) end
                end
                table.sort(matches, function(a, b) return normalise(a.id) < normalise(b.id) end)
                if matches[1] then
                    local record = matches[1]
                    print(string.format(
                        "[ASTRAL FURNITURE] matched %s in %s house slot %d -> %s",
                        record.id,
                        slot == self.PreferredSlot and "preferred" or "fallback",
                        slot, record.unique
                    ))
                    return record
                end
            end
        end
        return nil, "Required furniture not found: " .. tostring(description or "custom match")
    end

    function Furniture:FindNeedBowl(kind)
        self:SelectPreferredHome(false)
        local wanted = kind == "hungry" and "hungry"
            or kind == "thirsty" and "thirsty" or nil
        if not wanted then return nil, "Unknown feeding need" end

        for _, slot in ipairs(self:OrderedDiscoveredSlots()) do
            local snapshot = self.Slots[slot]
            if snapshot then
                local candidates = {}
                for _, record in ipairs(snapshot.records) do
                    if self:Capabilities(record)[wanted] then table.insert(candidates, record) end
                end
                table.sort(candidates, function(a, b)
                    local ai, bi = normalise(a.id), normalise(b.id)
                    local exactA = ai == (kind == "hungry" and "petfoodbowl" or "petwaterbowl")
                        or ai == (kind == "hungry" and "pet_food_bowl" or "pet_water_bowl")
                    local exactB = bi == (kind == "hungry" and "petfoodbowl" or "petwaterbowl")
                        or bi == (kind == "hungry" and "pet_food_bowl" or "pet_water_bowl")
                    if exactA ~= exactB then return exactA end
                    return ai < bi
                end)
                if candidates[1] then
                    local record = candidates[1]
                    print(string.format(
                        "[ASTRAL FURNITURE] %s bowl candidate %s in %s house slot %d -> %s",
                        kind, record.id,
                        slot == self.PreferredSlot and "preferred" or "fallback",
                        slot, record.unique
                    ))
                    return record
                end
            end
        end
        return nil, "No compatible owned " .. tostring(kind) .. " bowl discovered"
    end

    function Furniture:GetHomeStatus()
        self:SelectPreferredHome(false)
        return {
            slot = self.PreferredSlot,
            coverage = self.PreferredCoverage,
            capabilities = self.PreferredCapabilities,
        }
    end

    function Furniture:Refresh()
        self.Slots = {}
        self.Scanned = {}
        self.DiscoveredSlots = {}
        self.PreferredSlot = nil
        self.PreferredCoverage = 0
        self.PreferredCapabilities = {}
        self.HomeSelected = false
    end

    ASTRAL.Furniture = Furniture
    return Furniture
end
