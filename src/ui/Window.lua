return function(ASTRAL)
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")

    local player = Players.LocalPlayer

    local UI = {
        Version = "0.4.0-dev.6.9-egg-manager",
        Pages = {},
        Nav = {},
        ModuleCards = {},
        Refreshers = {},
    }

    ASTRAL.UI = UI

    local function new(className, props)
        local object = Instance.new(className)
        for key, value in pairs(props or {}) do
            object[key] = value
        end
        return object
    end

    local function corner(parent, pixels)
        new("UICorner", {
            CornerRadius = UDim.new(0, pixels or 10),
            Parent = parent,
        })
    end

    local function stroke(parent, transparency)
        new("UIStroke", {
            Color = Color3.fromRGB(54, 63, 84),
            Transparency = transparency or 0,
            Thickness = 1,
            Parent = parent,
        })
    end

    local C = {
        bg = Color3.fromRGB(11, 14, 22),
        panel = Color3.fromRGB(18, 22, 33),
        panel2 = Color3.fromRGB(24, 29, 43),
        accent = Color3.fromRGB(124, 92, 255),
        text = Color3.fromRGB(239, 241, 248),
        sub = Color3.fromRGB(153, 163, 184),
        green = Color3.fromRGB(83, 210, 139),
        amber = Color3.fromRGB(245, 184, 73),
    }

    local root = new("ScreenGui", {
        Name = "ASTRAL_1_DEV",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    UI.Root = root

    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    pcall(function()
        root.Parent = parent
    end)

    if not root.Parent then
        root.Parent = player:WaitForChild("PlayerGui")
    end

    -- Keep the dev.1 window dimensions: user confirmed this size is good.
    local shell = new("Frame", {
        Name = "Shell",
        Size = UDim2.fromOffset(920, 590),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0,
        Parent = root,
    })

    UI.Shell = shell
    corner(shell, 14)
    stroke(shell, 0.15)

    local scale = new("UIScale", {
        Scale = 1,
        Parent = shell,
    })

    local top = new("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        Parent = shell,
    })
    corner(top, 14)

    new("Frame", {
        Position = UDim2.new(0, 0, 1, -14),
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        Parent = top,
    })

    new("TextLabel", {
        Text = "ASTRAL",
        Position = UDim2.fromOffset(18, 0),
        Size = UDim2.new(0, 260, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = top,
    })

    new("TextLabel", {
        Text = ASTRAL.Version,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -92, 0.5, 0),
        Size = UDim2.fromOffset(130, 28),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = C.sub,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = top,
    })

    local minimise = new("TextButton", {
        Text = "-",
        Position = UDim2.new(1, -72, 0, 13),
        Size = UDim2.fromOffset(26, 30),
        BackgroundTransparency = 1,
        TextColor3 = C.sub,
        TextSize = 18,
        Parent = top,
    })

    local close = new("TextButton", {
        Text = "x",
        Position = UDim2.new(1, -40, 0, 13),
        Size = UDim2.fromOffset(26, 30),
        BackgroundTransparency = 1,
        TextColor3 = C.sub,
        TextSize = 18,
        Parent = top,
    })

    local side = new("Frame", {
        Position = UDim2.fromOffset(0, 58),
        Size = UDim2.new(0, 178, 1, -86),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        Parent = shell,
    })

    new("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = side,
    })

    new("UIPadding", {
        PaddingTop = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        Parent = side,
    })

    local content = new("Frame", {
        Position = UDim2.fromOffset(178, 58),
        Size = UDim2.new(1, -178, 1, -86),
        BackgroundTransparency = 1,
        Parent = shell,
    })

    local status = new("Frame", {
        Position = UDim2.new(0, 0, 1, -28),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        Parent = shell,
    })

    UI.StatusLabel = new("TextLabel", {
        Text = "BOOTING",
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(0.5, -14, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = C.green,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = status,
    })

    new("TextLabel", {
        Text = "ASTRAL MODULAR",
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.new(0.5, -14, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextColor3 = C.sub,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = status,
    })

    local pages = {
        "Dashboard",
        "Autofarm",
        "Pets",
        "Eggs",
        "Pet Pens",
        "Neon Factory",
        "Events",
        "Inventory",
        "Diagnostics",
        "Settings",
    }

    function UI:ShowPage(name)
        ASTRAL.State.CurrentPage = name

        for pageName, page in pairs(self.Pages) do
            page.Visible = pageName == name
        end

        for pageName, button in pairs(self.Nav) do
            button.BackgroundColor3 = pageName == name and C.panel2 or C.panel
            button.TextColor3 = pageName == name and C.text or C.sub
        end
    end

    for index, name in ipairs(pages) do
        local button = new("TextButton", {
            Text = name,
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = C.panel,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = index,
            Parent = side,
        })
        corner(button, 8)

        new("UIPadding", {
            PaddingLeft = UDim.new(0, 12),
            Parent = button,
        })

        UI.Nav[name] = button
        ASTRAL.Runtime:Connect(button.MouseButton1Click, function()
            UI:ShowPage(name)
        end)

        local page = new("ScrollingFrame", {
            Name = name,
            Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            Parent = content,
        })

        new("UIPadding", {
            PaddingTop = UDim.new(0, 20),
            PaddingBottom = UDim.new(0, 20),
            PaddingLeft = UDim.new(0, 22),
            PaddingRight = UDim.new(0, 22),
            Parent = page,
        })

        new("UIListLayout", {
            Padding = UDim.new(0, 12),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = page,
        })

        UI.Pages[name] = page
    end

    function UI:Heading(page, title, subtitle)
        local holder = new("Frame", {
            Size = UDim2.new(1, 0, 0, 62),
            BackgroundTransparency = 1,
            Parent = self.Pages[page],
        })

        new("TextLabel", {
            Text = title,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 23,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = holder,
        })

        new("TextLabel", {
            Text = subtitle or "",
            Position = UDim2.fromOffset(0, 32),
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = holder,
        })
    end

    function UI:Card(page, title, body, badge)
        local frame = new("Frame", {
            Size = UDim2.new(1, 0, 0, 86),
            BackgroundColor3 = C.panel,
            BorderSizePixel = 0,
            Parent = self.Pages[page],
        })
        corner(frame, 10)
        stroke(frame, 0.55)

        new("TextLabel", {
            Text = title,
            Position = UDim2.fromOffset(14, 11),
            Size = UDim2.new(1, -150, 0, 24),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = frame,
        })

        local bodyLabel = new("TextLabel", {
            Name = "Body",
            Text = body or "",
            Position = UDim2.fromOffset(14, 39),
            Size = UDim2.new(1, -28, 0, 34),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextWrapped = true,
            TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = frame,
        })

        if badge then
            local badgeLabel = new("TextLabel", {
                Name = "Badge",
                Text = badge,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 11),
                Size = UDim2.fromOffset(112, 24),
                BackgroundColor3 = C.panel2,
                BorderSizePixel = 0,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = C.amber,
                Parent = frame,
            })
            corner(badgeLabel, 7)
        end

        return {
            Frame = frame,
            Body = bodyLabel,
        }
    end

    function UI:ModuleCard(page, module)
        local card = self:Card(
            page,
            module.Name,
            module.Description,
            module.Implemented and "AVAILABLE" or "NOT IMPLEMENTED"
        )

        if not module.Implemented then
            return card
        end

        card.Body.Size = UDim2.new(1, -150, 0, 34)

        local toggle = new("TextButton", {
            Name = "Toggle",
            Text = "OFF",
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -12, 1, -12),
            Size = UDim2.fromOffset(92, 28),
            BackgroundColor3 = C.panel2,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            TextSize = 11,
            TextColor3 = C.sub,
            Parent = card.Frame,
        })
        corner(toggle, 7)

        self.ModuleCards[module.Id] = {
            Module = module,
            Toggle = toggle,
            Body = card.Body,
        }

        ASTRAL.Runtime:Connect(toggle.MouseButton1Click, function()
            local ok, reason = ASTRAL.Modules:SetEnabled(
                module.Id,
                not module.Enabled
            )

            if not ok then
                warn("[ASTRAL UI] Could not toggle", module.Id, reason)
            end

            -- Some executor-created callback threads cannot touch GUI
            -- Instances directly. Heartbeat will refresh on the next safe UI
            -- frame, so an immediate refresh is best-effort only.
            pcall(function()
                UI:Refresh()
            end)
        end)

        return card
    end

    UI:Heading(
        "Dashboard",
        "Dashboard",
        "ASTRAL 1.0 modular rebuild - first verified automation migration."
    )

    local runtimeCard = UI:Card(
        "Dashboard",
        "Runtime",
        "Initialising...",
        "MODULAR"
    )
    UI.RuntimeBody = runtimeCard.Body

    UI:Card(
        "Dashboard",
        "Migration policy",
        "v0.8.3b remains frozen. Known-good features will be migrated one module at a time.",
        "SAFE BASELINE"
    )

    local descriptions = {
        Autofarm = "Pet and baby needs, ailment exclusions and task scheduling.",
        Pets = "Pet queue, friendship and potion progression.",
        Eggs = "Egg purchasing, hatch targets and priorities.",
        ["Pet Pens"] = "Pet assignment, XP/Bucks claiming and automatic replacement.",
        ["Neon Factory"] = "Plan and execute Normal -> Neon -> Mega progression.",
        Events = "Seasonal event plugins such as Halloween 2026.",
        Inventory = "Inventory metadata, collection goals, purchases and lures.",
    }

    for page, description in pairs(descriptions) do
        UI:Heading(page, page, description)
    end

    for _, id in ipairs(ASTRAL.Modules.Order) do
        local module = ASTRAL.Modules:Get(id)
        if UI.Pages[module.Page] then
            UI:ModuleCard(module.Page, module)
        end
    end

    -- Pet Queue v2 management surface. Queue policy remains in PetQueue.lua;
    -- this panel only displays snapshots and invokes its public operations.
    local petQueue = ASTRAL.Modules:Get("pet_queue")
    if petQueue and UI.Pages.Pets then
        local manager = new("Frame", {
            Name = "PetQueueV2",
            Size = UDim2.new(1, 0, 0, 350),
            BackgroundColor3 = C.panel,
            BorderSizePixel = 0,
            Parent = UI.Pages.Pets,
        })
        corner(manager, 10)
        stroke(manager, 0.55)

        new("TextLabel", {
            Text = "Pet Queue v2",
            Position = UDim2.fromOffset(14, 10),
            Size = UDim2.new(1, -28, 0, 22),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = manager,
        })

        local currentLabel = new("TextLabel", {
            Text = "Current: scanning...",
            Position = UDim2.fromOffset(14, 36),
            Size = UDim2.new(1, -28, 0, 34),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = manager,
        })

        local function smallButton(textValue, x, width)
            local button = new("TextButton", {
                Text = textValue,
                Position = UDim2.fromOffset(x, 72),
                Size = UDim2.fromOffset(width, 27),
                BackgroundColor3 = C.panel2,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                TextColor3 = C.sub,
                Parent = manager,
            })
            corner(button, 7)
            return button
        end

        local growAllButton = smallButton("GROW ALL", 14, 92)
        local manualButton = smallButton("MANUAL", 112, 92)

        local inventoryLabel = new("TextLabel", {
            Text = "",
            Position = UDim2.fromOffset(216, 72),
            Size = UDim2.new(1, -230, 0, 27),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = manager,
        })

        local function listPanel(title, xScale)
            local titleLabel = new("TextLabel", {
                Text = title,
                Position = UDim2.new(xScale, xScale == 0 and 14 or 7, 0, 108),
                Size = UDim2.new(0.5, -21, 0, 20),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamSemibold,
                TextSize = 11,
                TextColor3 = C.text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = manager,
            })

            local list = new("ScrollingFrame", {
                Position = UDim2.new(xScale, xScale == 0 and 14 or 7, 0, 130),
                Size = UDim2.new(0.5, -21, 0, 146),
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = C.accent,
                BackgroundColor3 = C.bg,
                BorderSizePixel = 0,
                Parent = manager,
            })
            corner(list, 7)
            new("UIPadding", {
                PaddingTop = UDim.new(0, 5),
                PaddingBottom = UDim.new(0, 5),
                PaddingLeft = UDim.new(0, 5),
                PaddingRight = UDim.new(0, 5),
                Parent = list,
            })
            new("UIListLayout", {
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = list,
            })
            return list
        end

        local queueList = listPanel("ACTIVE QUEUE", 0)
        local eligibleList = listPanel("ELIGIBLE PETS", 0.5)

        local selectedQueued
        local selectedEligible
        local queueSignature = ""
        local eligibleSignature = ""

        local function petText(pet, index)
            local prefix = index and (tostring(index) .. ". ") or ""
            local stage = pet.age ~= nil and ("Age " .. tostring(pet.age)) or "Age ?"
            local progress = ""
            if pet.targetXP and pet.targetXP > 0 then
                progress = string.format("  %.0f%%", math.clamp((pet.xp or 0) / pet.targetXP * 100, 0, 100))
            end
            return prefix .. tostring(pet.name or pet.kind or "Pet") .. "  |  " .. stage .. progress
        end

        local function clearRows(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
        end

        local function row(parent, pet, index, selectedGetter, selectedSetter)
            local button = new("TextButton", {
                Text = petText(pet, index),
                Size = UDim2.new(1, -2, 0, 26),
                BackgroundColor3 = selectedGetter() == pet.unique and C.panel2 or C.bg,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextColor3 = selectedGetter() == pet.unique and C.text or C.sub,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = parent,
            })
            corner(button, 5)
            new("UIPadding", {
                PaddingLeft = UDim.new(0, 7),
                Parent = button,
            })
            ASTRAL.Runtime:Connect(button.MouseButton1Click, function()
                selectedSetter(pet.unique)
                queueSignature = ""
                eligibleSignature = ""
            end)
        end

        local addButton = smallButton("ADD >", 14, 72)
        addButton.Position = UDim2.fromOffset(14, 286)
        local removeButton = smallButton("< REMOVE", 92, 82)
        removeButton.Position = UDim2.fromOffset(92, 286)
        local upButton = smallButton("UP", 184, 58)
        upButton.Position = UDim2.fromOffset(184, 286)
        local downButton = smallButton("DOWN", 248, 58)
        downButton.Position = UDim2.fromOffset(248, 286)
        local clearButton = smallButton("CLEAR", 316, 68)
        clearButton.Position = UDim2.fromOffset(316, 286)

        local helpLabel = new("TextLabel", {
            Text = "Grow All finishes the most-developed eligible pets first. Manual follows your ordered list after the current pet finishes.",
            Position = UDim2.fromOffset(14, 319),
            Size = UDim2.new(1, -28, 0, 22),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextWrapped = true,
            TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = manager,
        })

        ASTRAL.Runtime:Connect(growAllButton.MouseButton1Click, function()
            petQueue:SetMode("grow_all")
        end)
        ASTRAL.Runtime:Connect(manualButton.MouseButton1Click, function()
            petQueue:SetMode("manual")
        end)
        ASTRAL.Runtime:Connect(addButton.MouseButton1Click, function()
            if selectedEligible then
                local ok, reason = petQueue:AddPet(selectedEligible)
                if not ok then warn("[ASTRAL UI] Pet Queue add:", reason) end
                selectedEligible = nil
                queueSignature, eligibleSignature = "", ""
            end
        end)
        ASTRAL.Runtime:Connect(removeButton.MouseButton1Click, function()
            if selectedQueued then
                local ok, reason = petQueue:RemovePet(selectedQueued)
                if not ok then warn("[ASTRAL UI] Pet Queue remove:", reason) end
                selectedQueued = nil
                queueSignature, eligibleSignature = "", ""
            end
        end)
        ASTRAL.Runtime:Connect(upButton.MouseButton1Click, function()
            if selectedQueued then
                local ok, reason = petQueue:MovePet(selectedQueued, -1)
                if not ok then warn("[ASTRAL UI] Pet Queue move:", reason) end
                queueSignature = ""
            end
        end)
        ASTRAL.Runtime:Connect(downButton.MouseButton1Click, function()
            if selectedQueued then
                local ok, reason = petQueue:MovePet(selectedQueued, 1)
                if not ok then warn("[ASTRAL UI] Pet Queue move:", reason) end
                queueSignature = ""
            end
        end)
        ASTRAL.Runtime:Connect(clearButton.MouseButton1Click, function()
            petQueue:ClearManual()
            selectedQueued = nil
            queueSignature, eligibleSignature = "", ""
        end)

        function UI:RefreshPetQueue()
            local now = os.clock()
            if self._PetQueueRefreshAt and now < self._PetQueueRefreshAt then
                return
            end
            self._PetQueueRefreshAt = now + 0.35

            local statusInfo = petQueue:GetStatus()
            local current = statusInfo.current
            if current then
                local progress = ""
                if current.targetXP and current.targetXP > 0 and current.age ~= nil and current.age < 6 then
                    progress = string.format(
                        " | stage %.0f%% (%s/%s XP)",
                        math.clamp((current.xp or 0) / current.targetXP * 100, 0, 100),
                        tostring(current.xp or 0),
                        tostring(current.targetXP)
                    )
                end
                currentLabel.Text = string.format(
                    "Current: %s | Age %s%s%s",
                    tostring(current.name),
                    tostring(current.age or "?"),
                    current.isFullGrown and " | Full Grown" or "",
                    progress
                )
            else
                currentLabel.Text = "Current: no equipped pet detected"
            end

            growAllButton.TextColor3 = petQueue.Mode == "grow_all" and C.green or C.sub
            manualButton.TextColor3 = petQueue.Mode == "manual" and C.green or C.sub

            local stats = statusInfo.inventory or {}
            inventoryLabel.Text = string.format(
                "%d growable | %d full grown | %d eggs | %d pen",
                stats.growable or 0,
                stats.fullGrown or 0,
                stats.eggs or 0,
                stats.penAssigned or 0
            )

            local queued = petQueue:GetQueue()
            local qParts = {petQueue.Mode, tostring(selectedQueued)}
            for i, pet in ipairs(queued) do
                table.insert(qParts, tostring(i) .. ":" .. tostring(pet.unique) .. ":" .. tostring(pet.age) .. ":" .. tostring(pet.xp))
            end
            local qSig = table.concat(qParts, "|")
            if qSig ~= queueSignature then
                queueSignature = qSig
                clearRows(queueList)
                for i, pet in ipairs(queued) do
                    row(queueList, pet, i,
                        function() return selectedQueued end,
                        function(unique) selectedQueued = unique end)
                end
            end

            local eligible = petQueue:GetEligiblePets()
            local eParts = {tostring(selectedEligible)}
            for _, pet in ipairs(eligible) do
                table.insert(eParts, tostring(pet.unique) .. ":" .. tostring(pet.age) .. ":" .. tostring(pet.xp))
            end
            local eSig = table.concat(eParts, "|")
            if eSig ~= eligibleSignature then
                eligibleSignature = eSig
                clearRows(eligibleList)
                for _, pet in ipairs(eligible) do
                    row(eligibleList, pet, nil,
                        function() return selectedEligible end,
                        function(unique) selectedEligible = unique end)
                end
            end

            local manual = petQueue.Mode == "manual"
            addButton.TextColor3 = manual and selectedEligible and C.green or C.sub
            removeButton.TextColor3 = manual and selectedQueued and C.amber or C.sub
            upButton.TextColor3 = manual and selectedQueued and C.text or C.sub
            downButton.TextColor3 = manual and selectedQueued and C.text or C.sub
            clearButton.TextColor3 = manual and #petQueue.ManualOrder > 0 and C.amber or C.sub
        end
    end

    -- Egg Manager v1 dashboard. Like the other detailed panels, it consumes
    -- cache-only getters so UI refresh never reaches into ClientData/Fsys.
    local eggManager = ASTRAL.Modules:Get("eggs")
    if eggManager and UI.Pages.Eggs then
        local eggPanel = new("Frame", {
            Name = "EggManagerV1",
            Size = UDim2.new(1, 0, 0, 328),
            BackgroundColor3 = C.panel,
            BorderSizePixel = 0,
            Parent = UI.Pages.Eggs,
        })
        corner(eggPanel, 10)
        stroke(eggPanel, 0.55)

        new("TextLabel", {
            Text = "Egg Manager v1  |  HATCH ALL",
            Position = UDim2.fromOffset(14, 10),
            Size = UDim2.new(1, -28, 0, 22),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = eggPanel,
        })

        local eggStatus = new("TextLabel", {
            Text = "Egg Manager off",
            Position = UDim2.fromOffset(14, 36),
            Size = UDim2.new(1, -28, 0, 20),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = eggPanel,
        })

        local currentEgg = new("TextLabel", {
            Text = "Current: none",
            Position = UDim2.fromOffset(14, 62),
            Size = UDim2.new(1, -28, 0, 38),
            BackgroundColor3 = C.bg,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamSemibold,
            TextSize = 11,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = eggPanel,
        })
        corner(currentEgg, 7)
        new("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            Parent = currentEgg,
        })

        new("TextLabel", {
            Text = "OWNED EGGS",
            Position = UDim2.fromOffset(14, 108),
            Size = UDim2.new(0.5, -20, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = eggPanel,
        })

        new("TextLabel", {
            Text = "RECENT HATCHES",
            Position = UDim2.new(0.5, 7, 0, 108),
            Size = UDim2.new(0.5, -21, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = eggPanel,
        })

        local kindLabels = {}
        local historyLabels = {}
        for i = 1, 6 do
            kindLabels[i] = new("TextLabel", {
                Text = i == 1 and "Waiting for inventory scan..." or "",
                Position = UDim2.fromOffset(14, 128 + (i - 1) * 28),
                Size = UDim2.new(0.5, -21, 0, 24),
                BackgroundColor3 = C.bg,
                BackgroundTransparency = 0.2,
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextColor3 = C.sub,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = eggPanel,
            })
            corner(kindLabels[i], 5)
            new("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
                Parent = kindLabels[i],
            })
        end

        for i = 1, 6 do
            historyLabels[i] = new("TextLabel", {
                Text = i == 1 and "No hatches this session" or "",
                Position = UDim2.new(0.5, 7, 0, 128 + (i - 1) * 28),
                Size = UDim2.new(0.5, -21, 0, 24),
                BackgroundColor3 = C.bg,
                BackgroundTransparency = 0.2,
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextColor3 = C.sub,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = eggPanel,
            })
            corner(historyLabels[i], 5)
            new("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
                Parent = historyLabels[i],
            })
        end

        function UI:RefreshEggManager()
            local now = os.clock()
            if self._EggRefreshAt and now < self._EggRefreshAt then return end
            self._EggRefreshAt = now + 0.35

            local info = eggManager:GetStatus()
            local kinds = eggManager:GetEggKinds()
            local history = eggManager:GetHistory()

            eggStatus.Text = string.format(
                "%s  |  %d owned  |  %d hatched this session  |  %s",
                info.enabled and "ACTIVE" or "OFF",
                info.totalEggs or 0,
                info.sessionHatched or 0,
                tostring(info.message or "")
            )
            eggStatus.TextColor3 = info.enabled and C.green or C.sub

            if info.current then
                local progressText = ""
                if info.current.targetXP and info.current.targetXP > 0 then
                    progressText = string.format(
                        "  |  %.0f%% (%s/%s XP)",
                        math.clamp((info.current.xp or 0) / info.current.targetXP * 100, 0, 100),
                        tostring(info.current.xp or 0),
                        tostring(info.current.targetXP)
                    )
                end
                currentEgg.Text = "Current:  " .. tostring(info.current.name or info.current.kind or "Egg") .. progressText
            else
                currentEgg.Text = "Current:  none"
            end

            for i = 1, 6 do
                local entry = kinds[i]
                kindLabels[i].Text = entry
                    and string.format("%s   x%d", tostring(entry.name or entry.kind or "Egg"), entry.count or 0)
                    or ""
            end
            if #kinds == 0 then kindLabels[1].Text = "No eligible owned eggs" end

            for i = 1, 6 do
                local entry = history[i]
                historyLabels[i].Text = entry
                    and (tostring(entry.eggName or entry.eggKind or "Egg")
                        .. "  ->  " .. tostring(entry.petName or entry.petKind or "Pet"))
                    or ""
            end
            if #history == 0 then historyLabels[1].Text = "No hatches this session" end
        end
    end

    -- Pet Pens v2 dashboard. All values come from PetPens.lua's cached
    -- plain-Lua snapshots; this UI never calls ClientData/Fsys itself.
    local petPens = ASTRAL.Modules:Get("pet_pens")
    if petPens and UI.Pages["Pet Pens"] then
        local pensPanel = new("Frame", {
            Name = "PetPensV2",
            Size = UDim2.new(1, 0, 0, 382),
            BackgroundColor3 = C.panel,
            BorderSizePixel = 0,
            Parent = UI.Pages["Pet Pens"],
        })
        corner(pensPanel, 10)
        stroke(pensPanel, 0.55)

        new("TextLabel", {
            Text = "Pet Pens v2",
            Position = UDim2.fromOffset(14, 10),
            Size = UDim2.new(0.5, -14, 0, 22),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
            TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = pensPanel,
        })

        local pensStatus = new("TextLabel", {
            Text = "Waiting for first cycle...",
            Position = UDim2.fromOffset(14, 34),
            Size = UDim2.new(1, -128, 0, 32),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = pensPanel,
        })

        local claimButton = new("TextButton", {
            Text = "CLAIM NOW",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -14, 0, 16),
            Size = UDim2.fromOffset(100, 30),
            BackgroundColor3 = C.panel2,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            TextColor3 = C.sub,
            Parent = pensPanel,
        })
        corner(claimButton, 7)

        local slotRefs = {}
        for index = 1, 4 do
            local y = 76 + (index - 1) * 72
            local frame = new("Frame", {
                Name = "PenSlot" .. tostring(index),
                Position = UDim2.fromOffset(14, y),
                Size = UDim2.new(1, -28, 0, 62),
                BackgroundColor3 = C.bg,
                BorderSizePixel = 0,
                Parent = pensPanel,
            })
            corner(frame, 7)

            local title = new("TextLabel", {
                Text = "PEN " .. tostring(index) .. "  |  Empty",
                Position = UDim2.fromOffset(10, 6),
                Size = UDim2.new(1, -20, 0, 20),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamSemibold,
                TextSize = 11,
                TextColor3 = C.text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })

            local detail = new("TextLabel", {
                Text = "Waiting for assignment data",
                Position = UDim2.fromOffset(10, 28),
                Size = UDim2.new(1, -20, 0, 27),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextColor3 = C.sub,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                Parent = frame,
            })

            slotRefs[index] = {Title = title, Detail = detail}
        end

        local function duration(seconds)
            if seconds == nil then return "measuring..." end
            seconds = math.max(0, math.floor(seconds + 0.5))
            local hours = math.floor(seconds / 3600)
            local minutes = math.floor((seconds % 3600) / 60)
            if hours > 0 then
                return string.format("%dh %02dm", hours, minutes)
            end
            if minutes > 0 then
                return string.format("%dm", minutes)
            end
            return "<1m"
        end

        ASTRAL.Runtime:Connect(claimButton.MouseButton1Click, function()
            local ok, reason = petPens:RequestCycle()
            if not ok then
                warn("[ASTRAL UI] Pet Pens claim:", reason)
            end
        end)

        function UI:RefreshPetPens()
            local now = os.clock()
            if self._PetPensRefreshAt and now < self._PetPensRefreshAt then
                return
            end
            self._PetPensRefreshAt = now + 0.35

            local statusInfo = petPens:GetStatus()
            local slots = petPens:GetSlots()

            local cycleText = statusInfo.enabled
                and ("Next claim: " .. duration(statusInfo.nextCycleIn))
                or "Auto management off"
            pensStatus.Text = string.format(
                "%d/%d occupied  |  %s\n%s",
                statusInfo.occupied or 0,
                statusInfo.capacity or 4,
                cycleText,
                tostring(statusInfo.summary or statusInfo.message or "")
            )

            claimButton.TextColor3 = statusInfo.enabled
                and not statusInfo.busy and C.green or C.sub
            claimButton.Text = statusInfo.busy and "WORKING..." or "CLAIM NOW"

            for index = 1, 4 do
                local refs = slotRefs[index]
                local slot = slots[index]
                if slot then
                    local stage = slot.isFullGrown
                        and "Full Grown"
                        or ("Age " .. tostring(slot.age or "?"))
                    local stageProgress = ""
                    if slot.targetXP and slot.targetXP > 0 and not slot.isFullGrown then
                        stageProgress = string.format(
                            " | %.0f%% (%s/%s XP)",
                            math.clamp((slot.xp or 0) / slot.targetXP * 100, 0, 100),
                            tostring(slot.xp or 0),
                            tostring(slot.targetXP)
                        )
                    end

                    refs.Title.Text = string.format(
                        "PEN %d  |  %s  |  %s%s",
                        index,
                        tostring(slot.name or "Pet"),
                        stage,
                        stageProgress
                    )

                    if slot.isFullGrown then
                        refs.Detail.Text = "Ready for automatic replacement on the next cycle"
                        refs.Detail.TextColor3 = C.green
                    else
                        local ratePrefix = slot.rateMeasured and "" or "~"
                        local rateSuffix = slot.rateMeasured and " measured" or " baseline"
                        refs.Detail.Text = string.format(
                            "%s XP remaining  |  %s%s XP/hr%s  |  Est. Full Grown: %s",
                            tostring(slot.remainingXP or "?"),
                            ratePrefix,
                            tostring(slot.xpPerHour or "?"),
                            rateSuffix,
                            duration(slot.etaSeconds)
                        )
                        refs.Detail.TextColor3 = C.sub
                    end
                else
                    refs.Title.Text = "PEN " .. tostring(index) .. "  |  Empty"
                    refs.Detail.Text = "ASTRAL will fill this slot with an eligible growable pet."
                    refs.Detail.TextColor3 = C.sub
                end
            end
        end
    end

    UI:Heading(
        "Diagnostics",
        "Diagnostics",
        "Runtime visibility for development and long unattended sessions."
    )

    local diagnosticsCard = UI:Card(
        "Diagnostics",
        "System status",
        "",
        "LIVE"
    )

    local diagnosticsText = new("TextLabel", {
        Text = "",
        Position = UDim2.fromOffset(14, 38),
        Size = UDim2.new(1, -28, 0, 38),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = C.sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = diagnosticsCard.Frame,
    })

    UI:Card(
        "Diagnostics",
        "Activity log",
        "Detailed copy/export tools will be added after the modular foundation is stable.",
        "DEV"
    )

    UI:Heading(
        "Settings",
        "Settings",
        "Foundation UI and runtime preferences."
    )

    UI:Card(
        "Settings",
        "Responsive interface",
        "The dev.1 window size is retained; viewport scaling remains available for smaller screens.",
        "ENABLED"
    )

    UI:Card(
        "Settings",
        "Gameplay automation",
        "Only the verified Play ailment is migrated in dev.3. All other gameplay modules remain disabled.",
        "DISABLED"
    )

    function UI:Refresh()
        local implemented, total = ASTRAL.Modules:Counts()

        if self.RuntimeBody then
            self.RuntimeBody.Text = string.format(
                "%s | Scheduler: %s | Modules: %d/%d | Uptime: %s",
                ASTRAL.State.Runtime,
                ASTRAL.Scheduler:Status(),
                implemented,
                total,
                ASTRAL.State:Uptime()
            )
        end

        diagnosticsText.Text = string.format(
            "Runtime: %-12s Scheduler: %s\nModules: %d/%d implemented  Remote files: %d failed  Uptime: %s",
            ASTRAL.State.Runtime,
            ASTRAL.Scheduler:Status(),
            implemented,
            total,
            (function()
                local n = 0
                for _ in pairs(ASTRAL.Boot.Failed or {}) do
                    n += 1
                end
                return n
            end)(),
            ASTRAL.State:Uptime()
        )

        for id, refs in pairs(self.ModuleCards) do
            local module = refs.Module
            local statusInfo = module.GetStatus and module:GetStatus() or nil

            refs.Toggle.Text = module.Enabled and "ON" or "OFF"
            refs.Toggle.TextColor3 = module.Enabled and C.green or C.sub

            if statusInfo and statusInfo.message then
                refs.Body.Text = module.Description .. "\nStatus: " .. tostring(statusInfo.message)
            end
        end

        -- Keep the base window refresh independent of optional detailed
        -- panels. In particular, never let a feature-panel call poison the
        -- status bar update in executors with thread capability restrictions.
        UI.StatusLabel.Text =
            ASTRAL.State.Runtime .. "  |  " .. ASTRAL.Scheduler:Status()

        if self.RefreshPetQueue then
            local ok, err = pcall(function() self:RefreshPetQueue() end)
            if not ok then warn("[ASTRAL UI] Pet Queue refresh:", err) end
        end

        if self.RefreshPetPens then
            local ok, err = pcall(function() self:RefreshPetPens() end)
            if not ok then warn("[ASTRAL UI] Pet Pens refresh:", err) end
        end

        if self.RefreshEggManager then
            local ok, err = pcall(function() self:RefreshEggManager() end)
            if not ok then warn("[ASTRAL UI] Egg Manager refresh:", err) end
        end
    end

    local minimized = false

    ASTRAL.Runtime:Connect(minimise.MouseButton1Click, function()
        minimized = not minimized
        content.Visible = not minimized
        side.Visible = not minimized
        status.Visible = not minimized

        shell.Size = minimized
            and UDim2.fromOffset(420, 58)
            or UDim2.fromOffset(920, 590)
    end)

    ASTRAL.Runtime:Connect(close.MouseButton1Click, function()
        ASTRAL.Runtime:Destroy()
    end)

    local dragging = false
    local dragStart
    local startPosition

    ASTRAL.Runtime:Connect(top.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = shell.Position
        end
    end)

    ASTRAL.Runtime:Connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    ASTRAL.Runtime:Connect(UIS.InputChanged, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - dragStart

            shell.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    local function responsive()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)

        local target = math.min(
            1,
            math.max(0.62, math.min(viewport.X / 980, viewport.Y / 650))
        )

        scale.Scale = target * (ASTRAL.Config.UIScale or 1)

        if viewport.X < 700 then
            side.Size = UDim2.new(0, 150, 1, -86)
            content.Position = UDim2.fromOffset(150, 58)
            content.Size = UDim2.new(1, -150, 1, -86)
        else
            side.Size = UDim2.new(0, 178, 1, -86)
            content.Position = UDim2.fromOffset(178, 58)
            content.Size = UDim2.new(1, -178, 1, -86)
        end
    end

    responsive()

    ASTRAL.Runtime:Connect(RunService.Heartbeat, function()
        UI:Refresh()
    end)

    if workspace.CurrentCamera then
        ASTRAL.Runtime:Connect(
            workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),
            responsive
        )
    end

    UI:ShowPage("Dashboard")
    UI:Refresh()

    return UI
end
