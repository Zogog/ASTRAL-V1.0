-- ASTRAL dev.5.1 shared house-furniture discovery.
-- Discovers the local player's own house slots with the read-only
-- HousingAPI/GetFurnitureWithinHouse remote. No house teleport is required.
return function(ASTRAL)
    local Game = assert(ASTRAL.Game, "GameAPI must load before FurnitureAPI")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ClientData = require(ReplicatedStorage:WaitForChild("Fsys")).load("ClientData")

    local Furniture = {
        Version = "0.1.3-dev.6.2",
        MaxAutoSlot = 20,
        Slots = {},
        Scanned = {},
        DiscoveredSlots = {},
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

    function Furniture:CandidateSlots()
        local slots, seen = {}, {}

        -- Explicit configuration always wins when the user knows the slot.
        addUnique(slots, seen, ASTRAL.Config and ASTRAL.Config.HouseSlot)

        -- Keep support for known ClientData layouts when the game exposes one.
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

        -- GetFurnitureWithinHouse only exposes the local player's house slots.
        -- Probe a bounded range lazily; Find/FindMatching stops as soon as a
        -- matching owned furniture item is found.
        for slot = 1, self.MaxAutoSlot do
            addUnique(slots, seen, slot)
        end
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
        end
        print(string.format("[ASTRAL FURNITURE] discovered house slot %d (%d furniture records)", slot, #records))
        return snapshot
    end

    function Furniture:Find(ids, forceRefresh)
        -- ids is an ordered preference list. Search by furniture priority
        -- across discovered house slots, rather than letting an early slot's
        -- fallback beat a preferred item in a later slot.
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

        local function bestKnown()
            for _, id in ipairs(ordered) do
                for _, slot in ipairs(self.DiscoveredSlots) do
                    local snapshot = self.Slots[slot]
                    local record = snapshot and snapshot.byId[id]
                    if record then return record, rank[id] end
                end
            end
            return nil
        end

        local best, bestRank = bestKnown()
        if bestRank == 1 then
            print(string.format("[ASTRAL FURNITURE] matched %s in house slot %d -> %s", best.id, best.slot, best.unique))
            return best
        end

        -- Keep any fallback already found, but continue probing until the
        -- highest-priority requested furniture is found or all candidates
        -- have been checked.
        for _, slot in ipairs(self:CandidateSlots()) do
            if not self.Scanned[slot] then
                self:ScanSlot(slot, false)
                local candidate, candidateRank = bestKnown()
                if candidate and (not bestRank or candidateRank < bestRank) then
                    best, bestRank = candidate, candidateRank
                end
                if bestRank == 1 then break end
            end
        end

        if best then
            print(string.format("[ASTRAL FURNITURE] matched %s in house slot %d -> %s", best.id, best.slot, best.unique))
            return best
        end

        -- A house slot can transiently return unavailable while housing data is
        -- still settling. Do not let that first miss poison the cache for the
        -- whole ASTRAL session: retry previously unavailable candidate slots
        -- once when an exact requested item was not found.
        local retried = 0
        for _, slot in ipairs(self:CandidateSlots()) do
            if self.Scanned[slot] and not self.Slots[slot] then
                retried += 1
                self:ScanSlot(slot, true)
                local candidate, candidateRank = bestKnown()
                if candidate and (not bestRank or candidateRank < bestRank) then
                    best, bestRank = candidate, candidateRank
                end
                if bestRank == 1 then break end
            end
        end

        if best then
            print(string.format("[ASTRAL FURNITURE] matched %s in house slot %d -> %s after unavailable-slot retry", best.id, best.slot, best.unique))
            return best
        end

        local visible = {}
        for _, slot in ipairs(self.DiscoveredSlots) do
            local snapshot = self.Slots[slot]
            if snapshot then
                for _, record in ipairs(snapshot.records) do
                    local id = normalise(record.id)
                    if id:find("bed", 1, true) or id:find("crib", 1, true) then
                        table.insert(visible, string.format("%s@%d", record.id, slot))
                    end
                end
            end
        end
        print(string.format(
            "[ASTRAL FURNITURE] exact lookup failed after retrying %d unavailable slot(s); discovered slots=[%s]; bed/crib ids=[%s]",
            retried,
            table.concat(self.DiscoveredSlots, ","),
            table.concat(visible, ",")
        ))

        return nil, "Required furniture not found: " .. table.concat(ids, ", ")
    end

    function Furniture:GetMatches(ids)
        local rank = {}
        for _, id in ipairs(ids or {}) do
            local key = normalise(id)
            if key ~= "" and not rank[key] then rank[key] = #rank + 1 end
        end

        -- Preserve duplicate owned furniture instances. Find() intentionally
        -- returns one preferred record, while interaction retries need distinct
        -- uniques so a rejected/busy instance does not get retried repeatedly.
        local matches, seen = {}, {}
        for _, slot in ipairs(self.DiscoveredSlots) do
            local snapshot = self.Slots[slot]
            if snapshot then
                for _, record in ipairs(snapshot.records) do
                    local id = normalise(record.id)
                    if rank[id] and not seen[record.unique] then
                        seen[record.unique] = true
                        table.insert(matches, {
                            record = record,
                            rank = rank[id],
                        })
                    end
                end
            end
        end

        table.sort(matches, function(a, b)
            if a.rank ~= b.rank then return a.rank < b.rank end
            if a.record.slot ~= b.record.slot then return a.record.slot < b.record.slot end
            return tostring(a.record.unique) < tostring(b.record.unique)
        end)

        local records = {}
        for _, entry in ipairs(matches) do table.insert(records, entry.record) end
        return records
    end

    function Furniture:FindMatching(predicate, description, forceRefresh)
        if type(predicate) ~= "function" then return nil, "Predicate required" end
        for _, slot in ipairs(self:CandidateSlots()) do
            local snapshot = self:ScanSlot(slot, forceRefresh == true)
            if snapshot then
                local matches = {}
                for _, record in ipairs(snapshot.records) do
                    local ok, matched = pcall(predicate, record)
                    if ok and matched then table.insert(matches, record) end
                end
                table.sort(matches, function(a, b) return normalise(a.id) < normalise(b.id) end)
                if matches[1] then
                    local record = matches[1]
                    print(string.format("[ASTRAL FURNITURE] matched %s in house slot %d -> %s", record.id, slot, record.unique))
                    return record
                end
            end
        end
        return nil, "Required furniture not found: " .. tostring(description or "custom match")
    end

    function Furniture:Refresh()
        self.Slots = {}
        self.Scanned = {}
        self.DiscoveredSlots = {}
    end

    ASTRAL.Furniture = Furniture
    return Furniture
end
