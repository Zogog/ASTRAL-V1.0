-- ASTRAL dev.4: shared Hungry / Thirsty ailment handlers.
return function(ASTRAL)
    local Game = assert(ASTRAL.Game)
    local PURCHASE_COOLDOWN = 60
    local lastPurchase = {}

    local function log(message)
        if ASTRAL.State then ASTRAL.State:Log("Feeding: " .. message) end
        print("[ASTRAL FEEDING] " .. message)
    end

    local function waitUntilClear(kind, petUnique, context, seconds)
        local deadline = os.clock() + seconds
        while os.clock() < deadline do
            if context:IsCancelled() then return false, "Cancelled" end
            if Game:GetCurrentPetUnique() ~= petUnique then
                return false, "Equipped pet changed"
            end
            if not Game:PetHasAilment(kind) then return true end
            task.wait(0.25)
        end
        return not Game:PetHasAilment(kind), "Timed out"
    end

    local function attempt(kind, petUnique, context, label, callback, timeout)
        if context:IsCancelled() then return false, "Cancelled" end
        log(kind .. ": trying " .. label)
        local ok, result, reason = pcall(callback)
        if not ok then return false, tostring(result) end
        if result == false then
            log(kind .. ": " .. label .. " skipped/failed: " .. tostring(reason or "Unavailable"))
            return false, tostring(reason or "Action unavailable")
        end
        local done, why = waitUntilClear(kind, petUnique, context, timeout)
        if done then
            log(kind .. ": completed via " .. label)
        else
            log(kind .. ": " .. label .. " did not complete: " .. tostring(why))
        end
        return done, why
    end

    local function makeHandler(kind, priority)
        local handler = {
            Id = kind,
            Name = kind == "hungry" and "Hungry" or "Thirsty",
            Version = "0.1.0-dev.4",
            Priority = priority,
        }
        function handler:CanRun()
            return Game:GetCurrentPetUnique() ~= nil
        end
        function handler:Run(_, context)
            local petUnique = Game:GetCurrentPetUnique()
            if not petUnique then return false, "No equipped pet" end
            if not Game:PetHasAilment(kind) then return true end

            local done = attempt(kind, petUnique, context, "house bowl", function()
                return Game:TryUseNeedBowl(kind, petUnique)
            end, 9)
            if done then return true end
            if context:IsCancelled() then return false, "Cancelled" end
            if Game:GetCurrentPetUnique() ~= petUnique then return false, "Pet changed" end

            local owned = Game:FindCompatibleConsumable(kind)
            if owned then
                done = attempt(kind, petUnique, context, "owned consumable", function()
                    return Game:UsePetConsumable(petUnique, owned)
                end, 12)
                if done then return true end
                -- Do not waste Bucks purchasing another item when the same
                -- consumption pipeline failed for an already-owned item.
                return false, "Owned consumable did not clear need"
            end

            if lastPurchase[kind] and os.clock() - lastPurchase[kind] < PURCHASE_COOLDOWN then
                return false, "Purchase cooldown"
            end
            lastPurchase[kind] = os.clock()
            local bought, why = Game:BuyConsumable(kind)
            if not bought then return false, "Purchase failed: " .. tostring(why) end
            log(kind .. ": purchased one fallback item")

            local item
            local inventoryDeadline = os.clock() + 6
            while os.clock() < inventoryDeadline do
                if context:IsCancelled() then return false, "Cancelled" end
                item = Game:FindCompatibleConsumable(kind)
                if item then break end
                task.wait(0.25)
            end
            if not item then return false, "Purchased item not replicated" end
            done, why = attempt(kind, petUnique, context, "purchased consumable", function()
                return Game:UsePetConsumable(petUnique, item)
            end, 12)
            return done, why
        end
        return handler
    end

    local hungry = makeHandler("hungry", 60)
    local thirsty = makeHandler("thirsty", 59)
    ASTRAL.Ailments:Register(hungry)
    ASTRAL.Ailments:Register(thirsty)
    return { Hungry = hungry, Thirsty = thirsty }
end
