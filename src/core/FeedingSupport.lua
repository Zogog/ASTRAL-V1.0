-- Shared Hungry / Thirsty execution pipeline.
-- Extracted from the verified dev.4.1 Feeding handler so each ailment can be loaded independently.
return function(ASTRAL)
    local Game = assert(ASTRAL.Game)
    local Support = {
        Version = "0.1.1-dev.5-modular",
        PurchaseCooldown = 60,
        LastPurchase = {},
    }

    function Support:Log(message)
        local text = "Feeding: " .. tostring(message)
        if ASTRAL.State then
            pcall(function() ASTRAL.State:Log(text) end)
        end
        print("[ASTRAL FEEDING] " .. tostring(message))
    end

    function Support:WaitUntilClear(kind, petUnique, context, seconds)
        local deadline = os.clock() + seconds
        while os.clock() < deadline do
            if context:IsCancelled() then return false, "Cancelled" end
            if Game:GetCurrentPetUnique() ~= petUnique then return false, "Equipped pet changed" end
            if not Game:PetHasAilment(kind) then return true end
            task.wait(0.25)
        end
        return not Game:PetHasAilment(kind), "Timed out"
    end

    function Support:Attempt(kind, petUnique, context, label, callback, timeout)
        if context:IsCancelled() then return false, "Cancelled" end
        self:Log(kind .. ": trying " .. label)
        local ok, result, reason = pcall(callback)
        if not ok then return false, tostring(result) end
        if result == false then
            self:Log(kind .. ": " .. label .. " skipped/failed: " .. tostring(reason or "Unavailable"))
            return false, tostring(reason or "Action unavailable")
        end
        local done, why = self:WaitUntilClear(kind, petUnique, context, timeout)
        if done then
            self:Log(kind .. ": completed via " .. label)
        else
            self:Log(kind .. ": " .. label .. " did not complete: " .. tostring(why))
        end
        return done, why
    end

    function Support:Run(kind, context)
        local petUnique = Game:GetCurrentPetUnique()
        if not petUnique then return false, "No equipped pet" end
        if not Game:PetHasAilment(kind) then return true end

        local done = self:Attempt(kind, petUnique, context, "house bowl", function()
            return Game:TryUseNeedBowl(kind, petUnique)
        end, 9)
        if done then return true end
        if context:IsCancelled() then return false, "Cancelled" end
        if Game:GetCurrentPetUnique() ~= petUnique then return false, "Pet changed" end

        local owned = Game:FindCompatibleConsumable(kind)
        if owned then
            done = self:Attempt(kind, petUnique, context, "owned consumable", function()
                return Game:UsePetConsumable(petUnique, owned)
            end, 12)
            if done then return true end
            return false, "Owned consumable did not clear need"
        end

        if self.LastPurchase[kind] and os.clock() - self.LastPurchase[kind] < self.PurchaseCooldown then
            return false, "Purchase cooldown"
        end
        self.LastPurchase[kind] = os.clock()
        local bought, why = Game:BuyConsumable(kind)
        if not bought then return false, "Purchase failed: " .. tostring(why) end
        self:Log(kind .. ": purchased one fallback item")

        local item
        local inventoryDeadline = os.clock() + 6
        while os.clock() < inventoryDeadline do
            if context:IsCancelled() then return false, "Cancelled" end
            item = Game:FindCompatibleConsumable(kind)
            if item then break end
            task.wait(0.25)
        end
        if not item then return false, "Purchased item not replicated" end
        return self:Attempt(kind, petUnique, context, "purchased consumable", function()
            return Game:UsePetConsumable(petUnique, item)
        end, 12)
    end

    ASTRAL.FeedingSupport = Support
    return Support
end
