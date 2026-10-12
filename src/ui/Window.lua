return function(ASTRAL)
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")

    local player = Players.LocalPlayer

    local UI = {
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

            UI:Refresh()
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

        UI.StatusLabel.Text =
            ASTRAL.State.Runtime .. "  |  " .. ASTRAL.Scheduler:Status()
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
