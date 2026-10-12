return function(ASTRAL)
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local player = Players.LocalPlayer

    local UI = { Pages = {}, Nav = {}, ModuleCards = {}, Refreshers = {} }
    ASTRAL.UI = UI

    local function new(class, props)
        local o = Instance.new(class)
        for k,v in pairs(props or {}) do o[k]=v end
        return o
    end
    local function corner(parent, px) new("UICorner", {CornerRadius=UDim.new(0,px or 10), Parent=parent}) end
    local function stroke(parent, transparency) new("UIStroke", {Color=Color3.fromRGB(54,63,84), Transparency=transparency or 0, Thickness=1, Parent=parent}) end
    local C = {
        bg=Color3.fromRGB(11,14,22), panel=Color3.fromRGB(18,22,33), panel2=Color3.fromRGB(24,29,43),
        accent=Color3.fromRGB(124,92,255), text=Color3.fromRGB(239,241,248), sub=Color3.fromRGB(153,163,184),
        green=Color3.fromRGB(83,210,139), amber=Color3.fromRGB(245,184,73)
    }

    local root = new("ScreenGui", {Name="ASTRAL_1_DEV", ResetOnSpawn=false, IgnoreGuiInset=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    UI.Root = root
    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    pcall(function() root.Parent=parent end)
    if not root.Parent then root.Parent=player:WaitForChild("PlayerGui") end

    local shell = new("Frame", {Name="Shell", Size=UDim2.fromOffset(920,590), AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5), BackgroundColor3=C.bg, BorderSizePixel=0, Parent=root})
    UI.Shell=shell; corner(shell,14); stroke(shell,.15)
    local scale = new("UIScale", {Scale=1, Parent=shell})

    local top = new("Frame", {Size=UDim2.new(1,0,0,58), BackgroundColor3=C.panel, BorderSizePixel=0, Parent=shell}); corner(top,14)
    new("Frame", {Position=UDim2.new(0,0,1,-14), Size=UDim2.new(1,0,0,14), BackgroundColor3=C.panel, BorderSizePixel=0, Parent=top})
    new("TextLabel", {Text="✦  ASTRAL", Position=UDim2.fromOffset(18,0), Size=UDim2.new(0,260,1,0), BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=20, TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Left, Parent=top})
    local ver = new("TextLabel", {Text=ASTRAL.Version, AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,-92,.5,0), Size=UDim2.fromOffset(130,28), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=12, TextColor3=C.sub, TextXAlignment=Enum.TextXAlignment.Right, Parent=top})
    local min = new("TextButton", {Text="—", Position=UDim2.new(1,-72,0,13), Size=UDim2.fromOffset(26,30), BackgroundTransparency=1, TextColor3=C.sub, TextSize=18, Parent=top})
    local close = new("TextButton", {Text="×", Position=UDim2.new(1,-40,0,13), Size=UDim2.fromOffset(26,30), BackgroundTransparency=1, TextColor3=C.sub, TextSize=20, Parent=top})

    local side = new("Frame", {Position=UDim2.fromOffset(0,58), Size=UDim2.new(0,178,1,-86), BackgroundColor3=C.panel, BorderSizePixel=0, Parent=shell})
    local navList = new("UIListLayout", {Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder, Parent=side})
    new("UIPadding", {PaddingTop=UDim.new(0,12), PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), Parent=side})

    local content = new("Frame", {Position=UDim2.fromOffset(178,58), Size=UDim2.new(1,-178,1,-86), BackgroundTransparency=1, Parent=shell})
    local status = new("Frame", {Position=UDim2.new(0,0,1,-28), Size=UDim2.new(1,0,0,28), BackgroundColor3=C.panel, BorderSizePixel=0, Parent=shell})
    UI.StatusLabel = new("TextLabel", {Text="BOOTING", Position=UDim2.fromOffset(14,0), Size=UDim2.new(.5,-14,1,0), BackgroundTransparency=1, Font=Enum.Font.GothamMedium, TextSize=11, TextColor3=C.green, TextXAlignment=Enum.TextXAlignment.Left, Parent=status})
    new("TextLabel", {Text="ASTRAL FOUNDATION", Position=UDim2.new(.5,0,0,0), Size=UDim2.new(.5,-14,1,0), BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10, TextColor3=C.sub, TextXAlignment=Enum.TextXAlignment.Right, Parent=status})

    local pages = {"Dashboard","Autofarm","Pets","Eggs","Pet Pens","Neon Factory","Events","Inventory","Diagnostics","Settings"}
    local icons = {Dashboard="⌂",Autofarm="⚡",Pets="◆",Eggs="◉",["Pet Pens"]="▦",["Neon Factory"]="✦",Events="★",Inventory="▣",Diagnostics="⌁",Settings="⚙"}

    function UI:ShowPage(name)
        ASTRAL.State.CurrentPage=name
        for n,p in pairs(self.Pages) do p.Visible=(n==name) end
        for n,b in pairs(self.Nav) do b.BackgroundColor3=(n==name) and C.panel2 or C.panel; b.TextColor3=(n==name) and C.text or C.sub end
    end

    for i,name in ipairs(pages) do
        local b=new("TextButton", {Text=(icons[name] or "•").."   "..name, Size=UDim2.new(1,0,0,38), BackgroundColor3=C.panel, BorderSizePixel=0, AutoButtonColor=false, Font=Enum.Font.GothamMedium, TextSize=12, TextColor3=C.sub, TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=i, Parent=side}); corner(b,8)
        UI.Nav[name]=b
        ASTRAL.Runtime:Connect(b.MouseButton1Click,function() UI:ShowPage(name) end)
        local p=new("ScrollingFrame", {Name=name, Size=UDim2.fromScale(1,1), CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollBarThickness=3, ScrollBarImageColor3=C.accent, BackgroundTransparency=1, BorderSizePixel=0, Visible=false, Parent=content})
        new("UIPadding", {PaddingTop=UDim.new(0,20),PaddingBottom=UDim.new(0,20),PaddingLeft=UDim.new(0,22),PaddingRight=UDim.new(0,22),Parent=p})
        new("UIListLayout", {Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder,Parent=p})
        UI.Pages[name]=p
    end

    function UI:Heading(page,title,subtitle)
        local holder=new("Frame", {Size=UDim2.new(1,0,0,62),BackgroundTransparency=1,Parent=self.Pages[page]})
        new("TextLabel", {Text=title,Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=23,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,Parent=holder})
        new("TextLabel", {Text=subtitle or "",Position=UDim2.fromOffset(0,32),Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=12,TextColor3=C.sub,TextXAlignment=Enum.TextXAlignment.Left,Parent=holder})
    end
    function UI:Card(page,title,body,badge)
        local f=new("Frame", {Size=UDim2.new(1,0,0,86),BackgroundColor3=C.panel,BorderSizePixel=0,Parent=self.Pages[page]}); corner(f,10); stroke(f,.55)
        new("TextLabel", {Text=title,Position=UDim2.fromOffset(14,11),Size=UDim2.new(1,-150,0,24),BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=14,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
        new("TextLabel", {Text=body or "",Position=UDim2.fromOffset(14,39),Size=UDim2.new(1,-28,0,34),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=11,TextWrapped=true,TextColor3=C.sub,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Parent=f})
        if badge then new("TextLabel", {Text=badge,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,11),Size=UDim2.fromOffset(112,24),BackgroundColor3=C.panel2,BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=10,TextColor3=C.amber,Parent=f}); corner(f:FindFirstChildOfClass("TextLabel") and f:GetChildren()[#f:GetChildren()] or f,7) end
        return f
    end

    UI:Heading("Dashboard","Dashboard","ASTRAL 1.0 clean rebuild — architecture first, automation second.")
    local dash=UI:Card("Dashboard","Runtime","Initialising…","FOUNDATION")
    UI.DashBody=dash:GetChildren()[4] or dash:FindFirstChildWhichIsA("TextLabel")
    UI:Card("Dashboard","Migration policy","v0.8.3b remains frozen. Known-good features will be migrated one module at a time.","SAFE BASELINE")

    local descriptions={
        Autofarm="Pet and baby needs, ailment exclusions and task scheduling.", Pets="Pet queue, friendship and potion progression.", Eggs="Egg purchasing, hatch targets and priorities.", ["Pet Pens"]="Pet assignment, XP/Bucks claiming and automatic replacement.", ["Neon Factory"]="Plan and execute Normal → Neon → Mega progression.", Events="Seasonal event plugins such as Halloween 2026.", Inventory="Inventory metadata, collection goals, purchases and lures."
    }
    for page,desc in pairs(descriptions) do UI:Heading(page,page,desc) end
    for _,id in ipairs(ASTRAL.Modules.Order) do
        local m=ASTRAL.Modules:Get(id)
        if UI.Pages[m.Page] then UI:Card(m.Page,m.Name,m.Description,"NOT IMPLEMENTED") end
    end

    UI:Heading("Diagnostics","Diagnostics","Runtime visibility for development and long unattended sessions.")
    local diag=UI:Card("Diagnostics","System status","","LIVE")
    local diagText=new("TextLabel", {Text="",Position=UDim2.fromOffset(14,38),Size=UDim2.new(1,-28,0,38),BackgroundTransparency=1,Font=Enum.Font.Code,TextSize=11,TextColor3=C.sub,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Parent=diag})
    UI:Card("Diagnostics","Activity log","The foundation records module/runtime events here. Detailed copy/export tools come in a later build.","DEV")

    UI:Heading("Settings","Settings","Foundation UI and runtime preferences.")
    UI:Card("Settings","Responsive interface","Desktop and narrow-screen layouts are handled automatically from viewport size.","ENABLED")
    UI:Card("Settings","Gameplay automation","No gameplay automation is included in dev.1.","DISABLED")

    function UI:Refresh()
        local implemented,total=ASTRAL.Modules:Counts()
        diagText.Text=string.format("Runtime: %-10s  Scheduler: %s\nModules: %d/%d implemented  Uptime: %s",ASTRAL.State.Runtime,ASTRAL.Scheduler:Status(),implemented,total,ASTRAL.State:Uptime())
        UI.StatusLabel.Text=ASTRAL.State.Runtime.."  •  "..ASTRAL.Scheduler:Status()
    end

    local minimized=false
    ASTRAL.Runtime:Connect(min.MouseButton1Click,function() minimized=not minimized; content.Visible=not minimized; side.Visible=not minimized; status.Visible=not minimized; shell.Size=minimized and UDim2.fromOffset(420,58) or UDim2.fromOffset(920,590) end)
    ASTRAL.Runtime:Connect(close.MouseButton1Click,function() ASTRAL.Runtime:Destroy() end)

    local dragging, dragStart, startPos
    ASTRAL.Runtime:Connect(top.InputBegan,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=input.Position; startPos=shell.Position end end)
    ASTRAL.Runtime:Connect(UIS.InputEnded,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
    ASTRAL.Runtime:Connect(UIS.InputChanged,function(input) if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then local d=input.Position-dragStart; shell.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)

    local function responsive()
        local cam=workspace.CurrentCamera; local vp=cam and cam.ViewportSize or Vector2.new(1280,720)
        local target=math.min(1, math.max(.62, math.min(vp.X/980,vp.Y/650)))
        scale.Scale=target * (ASTRAL.Config.UIScale or 1)
        if vp.X < 700 then side.Size=UDim2.new(0,150,1,-86); content.Position=UDim2.fromOffset(150,58); content.Size=UDim2.new(1,-150,1,-86) else side.Size=UDim2.new(0,178,1,-86); content.Position=UDim2.fromOffset(178,58); content.Size=UDim2.new(1,-178,1,-86) end
    end
    responsive()
    ASTRAL.Runtime:Connect(RunService.Heartbeat,function() UI:Refresh() end)
    if workspace.CurrentCamera then ASTRAL.Runtime:Connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),responsive) end
    UI:ShowPage("Dashboard")
    return UI
end
