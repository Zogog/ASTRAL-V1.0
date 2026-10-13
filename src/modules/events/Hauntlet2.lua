-- ASTRAL Hauntlet 2 v0.6.0
-- Integrated from the live-proven standalone v0.5 runner.
-- Proven paths retained: try_pick_door, physical follow, Nexus payload routing,
-- Gold/Ghost potion confirmation and persistent attach across runs.
return function(ASTRAL)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local player = Players.LocalPlayer

    local Hauntlet = {
        Id = "hauntlet_2",
        Name = "Hauntlet 2",
        Page = "Events",
        Description = "Persistent Hauntlet runner: doors, movement, Nexus routing and conservative survival items.",
        Version = "0.6.0-dev.6.12.2-integrated",
        Implemented = true,
        Enabled = false,
        Busy = false,
        Attached = false,
        CurrentRoom = 0,
        Health = "?/?,temp=?",
        CurrentAction = "Off",
        LastError = nil,
        RunsAttached = 0,
        DoorsPicked = 0,
        NexusPicked = 0,
    }

    local function log(...)
        local out = {}
        for i = 1, select("#", ...) do out[i] = tostring(select(i, ...)) end
        local message = table.concat(out, " ")
        print("[ASTRAL HAUNTLET] " .. message)
        if ASTRAL.State then pcall(function() ASTRAL.State:Log("Hauntlet: " .. message) end) end
    end

    local function getClient()
        if type(getloadedmodules) ~= "function" then return nil end
        local ok, modules = pcall(getloadedmodules)
        if not ok or type(modules) ~= "table" then return nil end
        for _, module in ipairs(modules) do
            if typeof(module) == "Instance"
                and module:IsA("ModuleScript")
                and module.Name == "HauntletMinigameClient"
                and module:GetFullName():find("Halloween2026", 1, true) then
                local required, result = pcall(require, module)
                if required and type(result) == "table" then return result end
            end
        end
        return nil
    end

    local function getRunner(run)
        if type(run) ~= "table" or type(run.runners) ~= "table" then return nil end
        if type(run.runners[player.Name]) == "table" then return run.runners[player.Name] end
        local modelName = run.player_model and run.player_model.Name
        if modelName and type(run.runners[modelName]) == "table" then return run.runners[modelName] end
        local only, count
        count = 0
        for _, value in pairs(run.runners) do
            if type(value) == "table" and value.health ~= nil then
                only, count = value, count + 1
            end
        end
        return count == 1 and only or nil
    end

    local function healthString(runner)
        if not runner then return "?/?,temp=?" end
        return tostring(runner.health) .. "/" .. tostring(runner.max_health)
            .. ",temp=" .. tostring(runner.temp_health or 0)
    end

    local function inventoryCount(run, kind)
        return type(run and run.inventory) == "table"
            and (tonumber(run.inventory[kind]) or 0) or 0
    end

    local function inventoryString(run)
        local kinds = {"cell_phone","ghost_potion","key","gold_key","gold_potion","rainbow_wand","red_potion"}
        local out = {}
        for _, kind in ipairs(kinds) do
            out[#out + 1] = kind .. "=" .. tostring(inventoryCount(run, kind))
        end
        return table.concat(out, ",")
    end

    -- Live Halloween2026 HauntletDoorDB observations. Scores deliberately keep
    -- locked/damaging/item-loss doors behind ordinary known-safe choices.
    local DOORS = {
        wooden      = {score=90},
        bouncy      = {score=110},
        rotten      = {score=120},
        shadow      = {score=150},
        nightmare   = {score=180},
        copycat     = {score=140},
        electric    = {score=230},
        webbed      = {score=240},
        locked      = {score=190, grey=1},
        security    = {score=230, grey=2},
        gold_locked = {score=260, gold=1},
    }

    local NEXUS_AREA_SCORE = {
        carnival=10, copycat=20, hallway=25, spider=30,
        laboratory=40, mechanical=50, nightmare=60,
    }

    local nexusSnapshot
    local messageRemote = ReplicatedStorage:FindFirstChild("API")
        and ReplicatedStorage.API:FindFirstChild("MinigameAPI/MessageClient")
    if messageRemote and messageRemote:IsA("RemoteEvent") then
        ASTRAL.Runtime:Connect(messageRemote.OnClientEvent, function(minigameId, message, roomData)
            if not Hauntlet.Enabled or message ~= "started_room"
                or type(roomData) ~= "table" or roomData.kind ~= "nexus"
                or type(roomData.doors) ~= "table" then return end
            local choices = {}
            for index, doorData in ipairs(roomData.doors) do
                if type(doorData) == "table" then
                    choices[#choices + 1] = {
                        index=index, kind="unknown",
                        area_kind=tostring(doorData.area_kind or "unknown"),
                        door=nil,
                    }
                end
            end
            nexusSnapshot = {
                minigame_id=tostring(minigameId),
                choices=choices,
                captured_at=os.clock(),
            }
            local names = {}
            for _, c in ipairs(choices) do names[#names+1] = c.index .. ":" .. c.area_kind end
            log("NEXUS PAYLOAD", table.concat(names, " | "))
        end)
    else
        log("Nexus capture unavailable - MessageClient remote not found")
    end

    local function currentChoices(run)
        local room = run and run.current_room
        local folder = room and room:FindFirstChild("Doors")
        if not folder then return {} end
        local raw = folder:GetChildren()
        table.sort(raw, function(a,b)
            local ai, bi = tonumber(a.Name), tonumber(b.Name)
            if ai and bi then return ai < bi end
            if ai then return true elseif bi then return false end
            return tostring(a.Name) < tostring(b.Name)
        end)
        local choices = {}
        for ordinal, door in ipairs(raw) do
            choices[#choices+1] = {
                index=tonumber(door.Name) or ordinal,
                kind=tostring(door:GetAttribute("kind") or "unknown"),
                area_kind=tostring(door:GetAttribute("area_kind") or "unknown"),
                door=door,
            }
        end
        return choices
    end

    local function legal(run, runner, choice)
        local p = DOORS[choice.kind]
        if not p then return false, "unknown" end
        if p.grey and inventoryCount(run,"key") < p.grey then return false, "grey key" end
        if p.gold and inventoryCount(run,"gold_key") < p.gold then return false, "gold key" end
        if choice.kind == "electric" then
            local hp = runner and tonumber(runner.health)
            local temp = runner and tonumber(runner.temp_health) or 0
            if hp and hp + temp <= 1 then return false, "final heart" end
        end
        return true
    end

    local function chooseDoor(run)
        local runner, candidates, summary = getRunner(run), {}, {}
        for _, choice in ipairs(currentChoices(run)) do
            local ok, reason = legal(run, runner, choice)
            local p = DOORS[choice.kind]
            local score = p and p.score or 9999
            summary[#summary+1] = string.format("%d:%s[%s]", choice.index, choice.kind,
                ok and ("score="..score) or ("BLOCKED:"..tostring(reason)))
            if ok then choice.score=score; candidates[#candidates+1]=choice end
        end
        table.sort(candidates, function(a,b)
            if a.score ~= b.score then return a.score < b.score end
            local pref={[2]=1,[1]=2,[3]=3}
            return (pref[a.index] or 9) < (pref[b.index] or 9)
        end)
        return candidates[1], table.concat(summary," | ")
    end

    local function chooseNexus(choices)
        local ranked, summary = {}, {}
        for _, choice in ipairs(choices) do
            choice.score = NEXUS_AREA_SCORE[choice.area_kind] or 999
            ranked[#ranked+1] = choice
            summary[#summary+1] = string.format("%d:%s[score=%d]",choice.index,choice.area_kind,choice.score)
        end
        table.sort(ranked,function(a,b)
            return a.score == b.score and a.index < b.index or a.score < b.score
        end)
        return ranked[1], table.concat(summary," | ")
    end

    local function isNexus(choices)
        if #choices ~= 2 then return false end
        for _, c in ipairs(choices) do
            if c.kind ~= "unknown" or c.area_kind == "unknown" then return false end
        end
        return true
    end

    local itemAutoDisabled, itemAttempted, itemEffectConfirmed, itemLastConfirmedAt, itemRetryAfter
    local function resetRunState()
        itemAutoDisabled=false
        itemAttempted={}
        itemEffectConfirmed={}
        itemLastConfirmedAt={}
        itemRetryAfter={}
    end
    resetRunState()

    local function useItemOnce(run, kind, roomIndex)
        if itemAutoDisabled or not Hauntlet.Enabled or not run.is_participating then return false end
        local nowClock=os.clock()
        if itemRetryAfter[kind] and nowClock < itemRetryAfter[kind] then return false end
        if itemLastConfirmedAt[kind] and nowClock-itemLastConfirmedAt[kind] < 2.5 then return false end
        local key=tostring(roomIndex)..":"..kind
        if itemAttempted[key] or inventoryCount(run,kind)<1 then return false end
        itemAttempted[key]=true
        if type(run.message_server)~="function" then
            itemAutoDisabled=true; log("ITEM DISABLED - message_server unavailable"); return false
        end
        local before=inventoryCount(run,kind)
        local runner=getRunner(run)
        local beforeHealth=runner and tonumber(runner.health)
        local beforeMax=runner and tonumber(runner.max_health)
        local beforeTemp=runner and tonumber(runner.temp_health) or 0
        log("ITEM TRY",kind,"room="..roomIndex,"hp="..healthString(runner))
        local ok,err=pcall(function() return run:message_server("try_use_item",kind) end)
        if not ok then itemAutoDisabled=true; log("ITEM ERROR",kind,tostring(err)); return false end
        local started=os.clock()
        while Hauntlet.Enabled and run.is_participating and os.clock()-started<1.5 do
            local after=inventoryCount(run,kind)
            local now=getRunner(run)
            local hp=now and tonumber(now.health)
            local maxHp=now and tonumber(now.max_health)
            local temp=now and tonumber(now.temp_health) or 0
            local effect=(kind=="gold_potion" and beforeMax and maxHp and maxHp>beforeMax)
                or (kind=="red_potion" and beforeHealth and hp and hp>beforeHealth)
                or (kind=="ghost_potion" and temp>beforeTemp)
            if after<before or effect then
                itemEffectConfirmed[kind]=true
                itemLastConfirmedAt[kind]=os.clock()
                itemRetryAfter[kind]=nil
                log("ITEM CONFIRMED",kind,"count="..before.."->"..after,"hp="..healthString(now))
                return true
            end
            task.wait(0.05)
        end
        itemRetryAfter[kind]=os.clock()+2.5
        log("ITEM UNCONFIRMED",kind,"per-item backoff")
        return false
    end

    local function survival(run,roomIndex)
        local runner=getRunner(run)
        if not runner then return end
        -- Gold max-health increase and Ghost temporary-health increase are live-proven.
        if inventoryCount(run,"gold_potion")>0 and not itemEffectConfirmed.gold_potion then
            useItemOnce(run,"gold_potion",roomIndex)
        end
        runner=getRunner(run)
        local hp=runner and tonumber(runner.health)
        local maxHp=runner and tonumber(runner.max_health)
        if hp and maxHp and inventoryCount(run,"red_potion")>0
            and hp<maxHp and (hp<=1 or maxHp-hp>=2) then
            -- Red uses the recovered normal try_use_item path; effect confirmation
            -- remains conservative because this branch is not yet live-proven.
            useItemOnce(run,"red_potion",roomIndex)
        end
        runner=getRunner(run)
        hp=runner and tonumber(runner.health)
        local temp=runner and tonumber(runner.temp_health) or 0
        if hp and hp<=2 and temp<1 and inventoryCount(run,"ghost_potion")>0 then
            useItemOnce(run,"ghost_potion",roomIndex)
        end
    end

    local function followDoor(choice)
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local door=choice and choice.door
        if not root or not door or not door.Parent then return false,"root/door unavailable" end
        local ok,pivot=pcall(function()
            if door:IsA("Model") then return door:GetPivot() end
            if door:IsA("BasePart") then return door.CFrame end
            local part=door:FindFirstChildWhichIsA("BasePart",true)
            return part and part.CFrame
        end)
        if not ok or typeof(pivot)~="CFrame" then return false,"pivot unavailable" end
        local target=pivot+Vector3.new(0,3,0)
        local moved,err=pcall(function()
            character:PivotTo(target)
            root.AssemblyLinearVelocity=Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
        end)
        return moved, moved and string.format("%.1f,%.1f,%.1f",target.X,target.Y,target.Z) or tostring(err)
    end

    local function sendChoice(run,index)
        if type(run.message_server)~="function" then return false,"message_server unavailable" end
        run.selected_door_index=index
        local ok,result=pcall(function() return run:message_server("try_pick_door",index) end)
        if not ok then run.selected_door_index=nil; return false,tostring(result) end
        return true,result
    end

    local function waitOutcome(run,roomBefore,index)
        local started,confirmed=os.clock(),false
        while Hauntlet.Enabled and os.clock()-started<8 do
            if not run.is_participating then return true,"run ended" end
            local now=tonumber(run.current_room_index) or 0
            if now~=roomBefore then return true,"advanced to room "..now end
            if run.confirmed_selected_door_index==index and not confirmed then
                confirmed=true; log("SERVER CONFIRMED","room="..roomBefore,"door="..index)
            end
            task.wait(0.05)
        end
        return false, confirmed and "confirmed but did not advance" or "not server-confirmed"
    end

    local lastHandledRoom, stoppedForError

    local function detach(message)
        if Hauntlet.Attached then
            log(message or "RUN ENDED / DETACHED")
        end
        Hauntlet.Attached=false
        Hauntlet.Busy=false
        Hauntlet.CurrentRoom=0
        Hauntlet.Health="?/?,temp=?"
        lastHandledRoom=nil
        stoppedForError=false
        nexusSnapshot=nil
        ASTRAL.Scheduler:Release("hauntlet_2")
        if Hauntlet.Enabled then Hauntlet.CurrentAction="Armed - waiting for Hauntlet run" end
    end

    function Hauntlet:SetEnabled(enabled)
        self.Enabled=enabled==true
        if self.Enabled then
            self.CurrentAction="Armed - waiting for Hauntlet run"
            self.LastError=nil
            log("enabled - persistent runner armed")
            log("Nexus preference: Bounce House > Copycat > Spider Den > Security > Power Station > Nightmare")
        else
            detach("disabled")
            self.CurrentAction="Off"
            log("disabled")
        end
        return true
    end

    function Hauntlet:GetStatus()
        return {
            enabled=self.Enabled, implemented=true, busy=self.Busy,
            message=self.CurrentAction, attached=self.Attached,
            room=self.CurrentRoom, health=self.Health,
            runs=self.RunsAttached, doors=self.DoorsPicked, nexus=self.NexusPicked,
            error=self.LastError,
        }
    end

    task.spawn(function()
        while not ASTRAL.Runtime.Destroyed do
            if not Hauntlet.Enabled then
                task.wait(0.25)
                continue
            end

            local client=getClient()
            local run=client and client.instanced_minigame
            if run and run.is_participating then
                if not Hauntlet.Attached then
                    Hauntlet.Attached=true
                    Hauntlet.RunsAttached+=1
                    lastHandledRoom=nil
                    stoppedForError=false
                    resetRunState()
                    log("ATTACHED",tostring(run.minigame_id or "?"))
                end

                ASTRAL.Scheduler:Request("hauntlet_2",100)
                Hauntlet.Busy=true
                local roomIndex=tonumber(run.current_room_index) or 0
                Hauntlet.CurrentRoom=roomIndex
                Hauntlet.Health=healthString(getRunner(run))
                Hauntlet.CurrentAction=stoppedForError
                    and ("Run halted safely at room "..roomIndex)
                    or ("Running room "..roomIndex.." | "..Hauntlet.Health)

                if not stoppedForError then
                    local choices=currentChoices(run)
                    if #choices==0 and nexusSnapshot
                        and nexusSnapshot.minigame_id==tostring(run.minigame_id)
                        and os.clock()-nexusSnapshot.captured_at<35 then
                        choices=nexusSnapshot.choices
                    end

                    if roomIndex>=1 and #choices>0
                        and run.selected_door_index==nil
                        and run.confirmed_selected_door_index==nil
                        and lastHandledRoom~=roomIndex then

                        lastHandledRoom=roomIndex
                        local nexus=isNexus(choices)
                        log(nexus and "NEXUS" or "ROOM",roomIndex,"hp="..Hauntlet.Health)
                        log("INVENTORY",inventoryString(run))
                        if not nexus then survival(run,roomIndex) end

                        local choice,summary
                        if nexus then choice,summary=chooseNexus(choices)
                        else choice,summary=chooseDoor(run) end
                        log(nexus and "NEXUS CHOICES" or "CHOICES",summary)

                        if not choice then
                            stoppedForError=true
                            Hauntlet.LastError="No legal known door at room "..roomIndex
                            log("CURRENT RUN HALTED -",Hauntlet.LastError)
                        else
                            local label=nexus and choice.area_kind or choice.kind
                            log(nexus and "NEXUS PICK" or "PICK",choice.index..":"..label,"score="..choice.score)
                            if not nexus then
                                local moved,result=followDoor(choice)
                                log(moved and "FOLLOW" or "FOLLOW SKIP",result)
                            end
                            task.wait(0.05)
                            local sent,result=sendChoice(run,choice.index)
                            if not sent then
                                stoppedForError=true
                                Hauntlet.LastError="try_pick_door failed: "..tostring(result)
                                log("CURRENT RUN HALTED -",Hauntlet.LastError)
                            else
                                Hauntlet.DoorsPicked+=1
                                if nexus then Hauntlet.NexusPicked+=1 end
                                local progressed,outcome=waitOutcome(run,roomIndex,choice.index)
                                log(nexus and "NEXUS RESULT" or "RESULT",outcome)
                                if progressed and nexus then nexusSnapshot=nil end
                                if not progressed then
                                    stoppedForError=true
                                    Hauntlet.LastError=outcome
                                    log("CURRENT RUN HALTED - no retry sent")
                                end
                            end
                        end
                    elseif roomIndex>=10 and #choices==0 and lastHandledRoom~=roomIndex then
                        lastHandledRoom=roomIndex
                        log("SPECIAL ROOM WAIT","room="..roomIndex,"no selectable doors exposed yet")
                    end
                end
            elseif Hauntlet.Attached then
                detach("RUN ENDED / DETACHED")
            else
                Hauntlet.Busy=false
                Hauntlet.CurrentAction="Armed - waiting for Hauntlet run"
                ASTRAL.Scheduler:Release("hauntlet_2")
            end
            task.wait(0.05)
        end
        detach("runtime destroyed")
    end)

    ASTRAL.Modules:Register(Hauntlet)
    return Hauntlet
end
