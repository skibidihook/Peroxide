--!nocheck
--!nolint UnknownGlobal, DeprecatedGlobal, BuiltinGlobalWrite
--!optimize 2

local CloneRef = cloneref or (function(x) return x end)
local InputService = CloneRef(game:GetService('UserInputService'))
local TextService = CloneRef(game:GetService('TextService'))
local GuiService = CloneRef(game:GetService('GuiService'))
local Teams = CloneRef(game:GetService('Teams'))
local Players = CloneRef(game:GetService('Players'))
local RunService = CloneRef(game:GetService('RunService'))
local TweenService = CloneRef(game:GetService('TweenService'))
local PreRender = RunService.PreRender

local function GetMouseX()
    return InputService:GetMouseLocation().X
end
local function GetMouseY()
    return InputService:GetMouseLocation().Y - GuiService:GetGuiInset().Y
end

local ScreenGui = Instance.new('ScreenGui')
if protectgui then protectgui(ScreenGui) end
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Parent = gethui()

local Toggles = {}
local Options = {}
getgenv().Toggles = Toggles
getgenv().Options = Options

local Library = {
    Registry = {}, RegistryMap = {}, HudRegistry = {},
    FontColor = Color3.fromRGB(255, 255, 255),
    MainColor = Color3.fromRGB(28, 28, 28),
    BackgroundColor = Color3.fromRGB(20, 20, 20),
    AccentColor = Color3.fromRGB(0, 85, 255),
    OutlineColor = Color3.fromRGB(50, 50, 50),
    RiskColor = Color3.fromRGB(255, 50, 50),
    Black = Color3.new(0, 0, 0),
    Font = Enum.Font.Code,
    OpenedFrames = {}, DependencyBoxes = {}, Signals = {},
    ScreenGui = ScreenGui,
}

local RainbowStep, Hue = 0, 0
table.insert(Library.Signals, PreRender:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0
        Hue = Hue + (1 / 400)
        if Hue > 1 then Hue = 0 end
        Library.CurrentRainbowHue = Hue
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1)
    end
end))

local function GetPlayersString()
    local List = Players:GetPlayers()
    for i = 1, #List do List[i] = List[i].Name end
    table.sort(List)
    return List
end

local function GetTeamsString()
    local List = Teams:GetTeams()
    for i = 1, #List do List[i] = List[i].Name end
    table.sort(List)
    return List
end

function Library:SafeCallback(f, ...)
    if not f then return end
    if not Library.NotifyOnError then return f(...) end
    local Ok, Err = pcall(f, ...)
    if not Ok then
        local _, i = Err:find(':%d+: ')
        return Library:Notify(i and Err:sub(i + 1) or Err, 3)
    end
end

function Library:AttemptSave()
    if Library.SaveManager then Library.SaveManager:Save() end
end

function Library:Create(Class, Properties)
    local Inst = type(Class) == 'string' and Instance.new(Class) or Class
    for Prop, Val in next, Properties do Inst[Prop] = Val end
    return Inst
end

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1
    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0), Thickness = 1,
        LineJoinMode = Enum.LineJoinMode.Miter, Parent = Inst,
    })
end

function Library:AddToRegistry(Inst, Properties, IsHud)
    local Data = { Instance = Inst, Properties = Properties, Idx = #Library.Registry + 1 }
    table.insert(Library.Registry, Data)
    Library.RegistryMap[Inst] = Data
    if IsHud then table.insert(Library.HudRegistry, Data) end
end

function Library:RemoveFromRegistry(Inst)
    local Data = Library.RegistryMap[Inst]
    if not Data then return end
    for i = #Library.Registry, 1, -1 do
        if Library.Registry[i] == Data then
            table.remove(Library.Registry, i)
            break
        end
    end
    for i = #Library.HudRegistry, 1, -1 do
        if Library.HudRegistry[i] == Data then
            table.remove(Library.HudRegistry, i)
            break
        end
    end
    Library.RegistryMap[Inst] = nil
end

function Library:UpdateColorsUsingRegistry()
    for _, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx]
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end
    end
end

function Library:CreateLabel(Properties, IsHud)
    local Label = Library:Create('TextLabel', {
        BackgroundTransparency = 1, Font = Library.Font,
        TextColor3 = Library.FontColor, TextSize = 16,
        TextStrokeTransparency = 0,
    })
    Library:ApplyTextStroke(Label)
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor' }, IsHud)
    return Library:Create(Label, Properties)
end

function Library:MakeDraggable(Inst, Cutoff)
    Inst.Active = true
    Inst.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local ObjPos = Vector2.new(GetMouseX() - Inst.AbsolutePosition.X, GetMouseY() - Inst.AbsolutePosition.Y)
        if ObjPos.Y > (Cutoff or 40) then return end
        while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            Inst.Position = UDim2.new(
                0, GetMouseX() - ObjPos.X + (Inst.Size.X.Offset * Inst.AnchorPoint.X),
                0, GetMouseY() - ObjPos.Y + (Inst.Size.Y.Offset * Inst.AnchorPoint.Y)
            )
            PreRender:Wait()
        end
    end)
end

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14)
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
        Size = UDim2.fromOffset(X + 5, Y + 4), ZIndex = 100,
        Parent = Library.ScreenGui, Visible = false,
    })
    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1), Size = UDim2.fromOffset(X, Y),
        TextSize = 14, Text = InfoStr, TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = Tooltip.ZIndex + 1,
        Parent = Tooltip,
    })
    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor' })
    local IsHovering = false
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        IsHovering = true
        Tooltip.Position = UDim2.fromOffset(GetMouseX() + 15, GetMouseY() + 12)
        Tooltip.Visible = true
        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(GetMouseX() + 15, GetMouseY() + 12)
        end
    end)
    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Inst, Properties, PropertiesDefault)
    local function Apply(Props)
        local Reg = Library.RegistryMap[Inst]
        for Property, ColorIdx in next, Props do
            Inst[Property] = Library[ColorIdx] or ColorIdx
            if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx end
        end
    end
    HighlightInstance.MouseEnter:Connect(function() Apply(Properties) end)
    HighlightInstance.MouseLeave:Connect(function() Apply(PropertiesDefault) end)
end

function Library:MouseIsOverOpenedFrame()
    local MX, MY = GetMouseX(), GetMouseY()
    for Frame in next, Library.OpenedFrames do
        local P, S = Frame.AbsolutePosition, Frame.AbsoluteSize
        if MX >= P.X and MX <= P.X + S.X and MY >= P.Y and MY <= P.Y + S.Y then
            return true
        end
    end
end

function Library:IsMouseOverFrame(Frame)
    local MX, MY = GetMouseX(), GetMouseY()
    local P, S = Frame.AbsolutePosition, Frame.AbsoluteSize
    return MX >= P.X and MX <= P.X + S.X and MY >= P.Y and MY <= P.Y + S.Y
end

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do Depbox:Update() end
end

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    local Alpha = (Value - MinA) / (MaxA - MinA)
    return (1 - Alpha) * MinB + Alpha * MaxB
end

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local B = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return B.X, B.Y
end

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color)
    return Color3.fromHSV(H, S, V / 1.5)
end
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    if Library.UnfocusTextBox then Library:UnfocusTextBox() end
    for i = #Library.Signals, 1, -1 do
        table.remove(Library.Signals, i):Disconnect()
    end
    if Library.OnUnload then Library.OnUnload() end
    ScreenGui:Destroy()
end

function Library:OnUnload(Callback) Library.OnUnload = Callback end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Inst)
    if Library.RegistryMap[Inst] then Library:RemoveFromRegistry(Inst) end
end))


local ActiveTextBox

local CharMap = {
    Zero = { '0', ')' }, One = { '1', '!' }, Two = { '2', '@' },
    Three = { '3', '#' }, Four = { '4', '$' }, Five = { '5', '%' },
    Six = { '6', '^' }, Seven = { '7', '&' }, Eight = { '8', '*' },
    Nine = { '9', '(' },
    Minus = { '-', '_' }, Equals = { '=', '+' },
    LeftBracket = { '[', '{' }, RightBracket = { ']', '}' },
    BackSlash = { '\\', '|' }, Semicolon = { ';', ':' },
    Quote = { "'", '"' }, Comma = { ',', '<' },
    Period = { '.', '>' }, Slash = { '/', '?' },
    Backquote = { '`', '~' }, Space = { ' ', ' ' },
    KeypadZero = { '0' }, KeypadOne = { '1' }, KeypadTwo = { '2' },
    KeypadThree = { '3' }, KeypadFour = { '4' }, KeypadFive = { '5' },
    KeypadSix = { '6' }, KeypadSeven = { '7' }, KeypadEight = { '8' },
    KeypadNine = { '9' }, KeypadPeriod = { '.' }, KeypadPlus = { '+' },
    KeypadMinus = { '-' }, KeypadMultiply = { '*' }, KeypadDivide = { '/' },
}

local function KeyToChar(KeyCode)
    local Name = KeyCode.Name
    local Shift = InputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or InputService:IsKeyDown(Enum.KeyCode.RightShift)
    if #Name == 1 then
        return Shift and Name or string.lower(Name)
    end
    local Entry = CharMap[Name]
    if not Entry then return nil end
    return (Shift and Entry[2]) or Entry[1]
end

local function GetControls()
    local LocalPlayer = Players.LocalPlayer
    local Scripts = LocalPlayer and LocalPlayer:FindFirstChild('PlayerScripts')
    local Module = Scripts and Scripts:FindFirstChild('PlayerModule')
    if not Module then return nil end
    local Ok, Controls = pcall(function() return require(Module):GetControls() end)
    return Ok and Controls or nil
end

local SavedCameraType
local function SetMovementEnabled(Enabled)
    local Controls = GetControls()
    if Controls then
        pcall(function()
            if Enabled then Controls:Enable() else Controls:Disable() end
        end)
    end
    local Camera = workspace.CurrentCamera
    if not Camera then return end
    if Enabled then
        if SavedCameraType ~= nil then
            pcall(function() Camera.CameraType = SavedCameraType end)
            SavedCameraType = nil
        end
    elseif SavedCameraType == nil then
        SavedCameraType = Camera.CameraType
        pcall(function() Camera.CameraType = Enum.CameraType.Scriptable end)
    end
end

function Library:CreateTextBox(Properties)
    local Container = Properties.Parent
    local Padding = 2
    local Box = {
        Value = tostring(Properties.Default or ''),
        Focused = false,
        Alive = true,
        Numeric = Properties.Numeric or false,
        MaxLength = Properties.MaxLength,
        Placeholder = Properties.Placeholder or '',
    }
    Box.Region = Properties.ClickRegion or Container

    local Label = Library:Create('TextLabel', {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(Padding, 0),
        Size = UDim2.new(1, -Padding, 1, 0),
        Font = Library.Font, TextColor3 = Library.FontColor,
        TextSize = Properties.TextSize or 14, TextStrokeTransparency = 0,
        TextXAlignment = Properties.TextXAlignment or Enum.TextXAlignment.Left,
        Text = '', ZIndex = Properties.ZIndex or 7, Parent = Container,
    })
    Library:ApplyTextStroke(Label)
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor' })
    Box.Label = Label
    Label.Destroying:Connect(function() Box.Alive = false end)

    function Box:Render()
        if not Box.Alive then return end
        if Box.Value == '' and not Box.Focused then
            Label.Text = Box.Placeholder
            Label.TextColor3 = Color3.fromRGB(190, 190, 190)
        else
            Label.Text = Box.Focused and (Box.Value .. '|') or Box.Value
            Label.TextColor3 = Library.FontColor
        end
        if Box.Focused then
            local Avail = Container.AbsoluteSize.X - Padding * 2
            local Width = Library:GetTextBounds(Label.Text, Label.Font, Label.TextSize, Vector2.new(math.huge, math.huge))
            Label.Position = UDim2.fromOffset((Avail > 0 and Width > Avail) and Padding - (Width - Avail) or Padding, 0)
        else
            Label.Position = UDim2.fromOffset(Padding, 0)
        end
    end

    function Box:Set(Text, FireChanged)
        Text = tostring(Text)
        if Box.MaxLength and #Text > Box.MaxLength then Text = string.sub(Text, 1, Box.MaxLength) end
        Box.Value = Text
        Box:Render()
        if FireChanged and Box.Changed then Library:SafeCallback(Box.Changed, Box.Value) end
    end

    function Box:Append(Char)
        local Candidate = Box.Value .. Char
        if Box.MaxLength and #Candidate > Box.MaxLength then return end
        if Box.Numeric and Candidate ~= '' and not tonumber(Candidate) then return end
        Box:Set(Candidate, true)
    end

    function Box:IsFocused() return Box.Focused end

    function Box:Focus()
        if ActiveTextBox and ActiveTextBox ~= Box then ActiveTextBox:Unfocus(false) end
        ActiveTextBox = Box
        Box.Focused = true
        Box:Render()
        task.spawn(SetMovementEnabled, false)
    end

    function Box:Unfocus(EnterPressed)
        if ActiveTextBox ~= Box then return end
        ActiveTextBox = nil
        Box.Focused = false
        Box:Render()
        if Box.FocusLostCallback then
            Library:SafeCallback(Box.FocusLostCallback, EnterPressed and true or false)
        end
        task.spawn(SetMovementEnabled, true)
    end

    function Box:OnChanged(Func) Box.Changed = Func end
    function Box:OnFocusLost(Func) Box.FocusLostCallback = Func end

    Box.Region.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then Box:Focus() end
    end)

    Box:Render()
    return Box
end

function Library:UnfocusTextBox()
    if ActiveTextBox then ActiveTextBox:Unfocus(false) end
end

Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
    local Box = ActiveTextBox
    local Kind = Input.UserInputType
    if Kind == Enum.UserInputType.MouseButton1 then
        if Box and not Library:IsMouseOverFrame(Box.Region) then Box:Unfocus(false) end
        return
    end
    if not Box or Kind ~= Enum.UserInputType.Keyboard then return end
    local Key = Input.KeyCode
    if Key == Enum.KeyCode.Return or Key == Enum.KeyCode.KeypadEnter then
        Box:Unfocus(true)
    elseif Key == Enum.KeyCode.Escape then
        Box:Unfocus(false)
    elseif Key == Enum.KeyCode.Backspace then
        Box:Set(string.sub(Box.Value, 1, -2), true)
    else
        local Char = KeyToChar(Key)
        if Char then Box:Append(Char) end
    end
end))

Library:GiveSignal(InputService.WindowFocusReleased:Connect(function()
    if ActiveTextBox then ActiveTextBox:Unfocus(false) end
end))

local function CreateOutlinedBox(Properties)
    local Outer = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0),
        Size = Properties.Size, Position = Properties.Position or UDim2.new(),
        ZIndex = Properties.ZIndex or 5, Parent = Properties.Parent,
    })
    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Properties.InnerColor or Library.MainColor,
        BorderColor3 = Library.OutlineColor, BorderMode = Enum.BorderMode.Inset,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = (Properties.ZIndex or 5) + 1, Parent = Outer,
    })
    Library:AddToRegistry(Outer, { BorderColor3 = 'Black' })
    Library:AddToRegistry(Inner, {
        BackgroundColor3 = Properties.InnerColorIdx or 'MainColor',
        BorderColor3 = 'OutlineColor',
    })
    return Outer, Inner
end

local BaseAddons = {}
do
    local Funcs = {}

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel
        assert(Info.Default, 'AddColorPicker: Missing default value.')

        local ColorPicker = {
            Value = Info.Default, Transparency = Info.Transparency or 0,
            Type = 'ColorPicker',
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function() end,
        }

        function ColorPicker:SetHSVFromRGB(Color)
            ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color)
        end
        ColorPicker:SetHSVFromRGB(ColorPicker.Value)

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value,
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value),
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(0, 28, 0, 14), ZIndex = 6, Parent = ToggleLabel,
        })

        Library:Create('Frame', {
            BorderSizePixel = 0, Size = UDim2.new(0, 27, 0, 13),
            BackgroundColor3 = Color3.fromRGB(140, 140, 140), ZIndex = 5,
            Visible = not not Info.Transparency, Parent = DisplayFrame,
        })

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color',
            BackgroundColor3 = Color3.new(1, 1, 1), BorderColor3 = Color3.new(0, 0, 0),
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253),
            Visible = false, ZIndex = 15, Parent = ScreenGui,
        })

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18)
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 16, Parent = PickerFrameOuter,
        })

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 2), ZIndex = 17, Parent = PickerFrameInner,
        })

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0), Position = UDim2.new(0, 4, 0, 25),
            Size = UDim2.new(0, 200, 0, 200), ZIndex = 17, Parent = PickerFrameInner,
        })
        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 18, Parent = SatVibMapOuter,
        })
        local SatVibMap = Library:Create('Frame', {
            BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1),
            ZIndex = 18, Parent = SatVibMapInner,
        })

        local SatOverlay = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 18, Parent = SatVibMap,
        })
        Library:Create('UIGradient', {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
            }), Parent = SatOverlay,
        })

        local VibOverlay = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 19, Parent = SatVibMap,
        })
        Library:Create('UIGradient', {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0),
            }), Rotation = 90, Parent = VibOverlay,
        })

        local CursorOuter = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 6, 0, 6),
            BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
            ZIndex = 19, Parent = SatVibMap,
        })
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = CursorOuter })

        Library:Create('UICorner', {
            CornerRadius = UDim.new(1, 0),
            Parent = Library:Create('Frame', {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(0, 4, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0, ZIndex = 20, Parent = CursorOuter,
            }),
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0), Position = UDim2.new(0, 208, 0, 25),
            Size = UDim2.new(0, 15, 0, 200), ZIndex = 17, Parent = PickerFrameInner,
        })
        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 18, Parent = HueSelectorOuter,
        })
        local HueCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0, 0.5),
            BorderColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 0, 1),
            ZIndex = 18, Parent = HueSelectorInner,
        })

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0), Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20), ZIndex = 18, Parent = PickerFrameInner,
        })
        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 18, Parent = HueBoxOuter,
        })
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)),
            }), Rotation = 90, Parent = HueBoxInner,
        })

        local HueBox = Library:CreateTextBox({
            Parent = HueBoxInner, ClickRegion = HueBoxInner,
            Default = '#FFFFFF', Placeholder = 'Hex color', ZIndex = 20,
        })

        local RgbBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0), Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20), ZIndex = 18, Parent = PickerFrameInner,
        })
        local RgbBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 18, Parent = RgbBoxOuter,
        })
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)),
            }), Rotation = 90, Parent = RgbBoxInner,
        })
        local RgbBox = Library:CreateTextBox({
            Parent = RgbBoxInner, ClickRegion = RgbBoxInner,
            Default = '255, 255, 255', Placeholder = 'RGB color', ZIndex = 20,
        })

        local TransparencyBoxInner, TransparencyCursor
        if Info.Transparency then
            local TransOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0), Position = UDim2.fromOffset(4, 251),
                Size = UDim2.new(1, -8, 0, 15), ZIndex = 19, Parent = PickerFrameInner,
            })
            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value, BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 19, Parent = TransOuter,
            })
            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' })

            local TransGradFrame = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 1, 0), ZIndex = 20, Parent = TransparencyBoxInner,
            })
            Library:Create('UIGradient', {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0),
                }), Parent = TransGradFrame,
            })

            TransparencyCursor = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0),
                BorderColor3 = Color3.new(0, 0, 0), Size = UDim2.new(0, 1, 1, 0),
                ZIndex = 21, Parent = TransparencyBoxInner,
            })
        end

        Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(5, 5),
            TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14,
            Text = ColorPicker.Title, TextWrapped = false,
            ZIndex = 16, Parent = PickerFrameInner,
        })

        local ContextMenu = {}
        ContextMenu.Container = Library:Create('Frame', {
            BorderColor3 = Color3.new(), ZIndex = 14, Visible = false, Parent = ScreenGui,
        })
        ContextMenu.Inner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.fromScale(1, 1),
            ZIndex = 15, Parent = ContextMenu.Container,
        })
        Library:Create('UIListLayout', {
            Name = 'Layout', FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = ContextMenu.Inner,
        })
        Library:Create('UIPadding', { Name = 'Padding', PaddingLeft = UDim.new(0, 4), Parent = ContextMenu.Inner })

        local function UpdateMenuPosition()
            ContextMenu.Container.Position = UDim2.fromOffset(
                DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X + 4,
                DisplayFrame.AbsolutePosition.Y + 1
            )
        end
        local function UpdateMenuSize()
            local W = 60
            for _, L in next, ContextMenu.Inner:GetChildren() do
                if L:IsA('TextLabel') then W = math.max(W, L.TextBounds.X) end
            end
            ContextMenu.Container.Size = UDim2.fromOffset(W + 8, ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4)
        end
        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(UpdateMenuPosition)
        ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(UpdateMenuSize)
        task.spawn(UpdateMenuPosition)
        task.spawn(UpdateMenuSize)

        Library:AddToRegistry(ContextMenu.Inner, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })

        function ContextMenu:Show() self.Container.Visible = true end
        function ContextMenu:Hide() self.Container.Visible = false end
        function ContextMenu:AddOption(Str, Callback)
            Callback = type(Callback) == 'function' and Callback or function() end
            local Button = Library:CreateLabel({
                Active = false, Size = UDim2.new(1, 0, 0, 15), TextSize = 13,
                Text = Str, ZIndex = 16, Parent = self.Inner,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            Library:OnHighlight(Button, Button, { TextColor3 = 'AccentColor' }, { TextColor3 = 'FontColor' })
            Button.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then Callback() end
            end)
        end

        ContextMenu:AddOption('Copy color', function()
            Library.ColorClipboard = ColorPicker.Value
            Library:Notify('Copied color!', 2)
        end)
        ContextMenu:AddOption('Paste color', function()
            if not Library.ColorClipboard then return Library:Notify('You have not copied a color!', 2) end
            ColorPicker:SetValueRGB(Library.ColorClipboard)
        end)
        ContextMenu:AddOption('Copy HEX', function()
            pcall(setclipboard, ColorPicker.Value:ToHex())
            Library:Notify('Copied hex code to clipboard!', 2)
        end)
        ContextMenu:AddOption('Copy RGB', function()
            pcall(setclipboard, table.concat({
                math.floor(ColorPicker.Value.R * 255),
                math.floor(ColorPicker.Value.G * 255),
                math.floor(ColorPicker.Value.B * 255),
            }, ', '))
            Library:Notify('Copied RGB values to clipboard!', 2)
        end)

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor' })
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(RgbBoxInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

        local SeqTable = {}
        for H = 0, 1, 0.1 do
            table.insert(SeqTable, ColorSequenceKeypoint.new(H, Color3.fromHSV(H, 1, 1)))
        end
        Library:Create('UIGradient', { Color = ColorSequence.new(SeqTable), Rotation = 90, Parent = HueSelectorInner })

        HueBox:OnFocusLost(function()
            local Ok, Result = pcall(Color3.fromHex, HueBox.Value)
            if Ok and typeof(Result) == 'Color3' then
                ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Result)
            end
            ColorPicker:Display()
        end)
        RgbBox:OnFocusLost(function()
            local R, G, B = RgbBox.Value:match('(%d+),%s*(%d+),%s*(%d+)')
            if R and G and B then
                ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(R, G, B))
            end
            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)
            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value,
                BackgroundTransparency = ColorPicker.Transparency,
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value),
            })
            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0)
            end
            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0)
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0)
            HueBox:Set('#' .. ColorPicker.Value:ToHex(), false)
            RgbBox:Set(table.concat({
                math.floor(ColorPicker.Value.R * 255),
                math.floor(ColorPicker.Value.G * 255),
                math.floor(ColorPicker.Value.B * 255),
            }, ', '), false)
            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value)
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value)
        end

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func
            Func(ColorPicker.Value)
        end
        function ColorPicker:Show()
            for Frame in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false
                    Library.OpenedFrames[Frame] = nil
                end
            end
            PickerFrameOuter.Visible = true
            Library.OpenedFrames[PickerFrameOuter] = true
        end
        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false
            Library.OpenedFrames[PickerFrameOuter] = nil
        end
        function ColorPicker:SetValue(HSV, Transparency)
            ColorPicker.Transparency = Transparency or 0
            ColorPicker:SetHSVFromRGB(Color3.fromHSV(HSV[1], HSV[2], HSV[3]))
            ColorPicker:Display()
        end
        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Display()
        end

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local MinX = SatVibMap.AbsolutePosition.X
                local MaxX = MinX + SatVibMap.AbsoluteSize.X
                local MinY = SatVibMap.AbsolutePosition.Y
                local MaxY = MinY + SatVibMap.AbsoluteSize.Y
                local MX, MY = math.clamp(GetMouseX(), MinX, MaxX), math.clamp(GetMouseY(), MinY, MaxY)
                ColorPicker.Sat = (MX - MinX) / (MaxX - MinX)
                ColorPicker.Vib = 1 - ((MY - MinY) / (MaxY - MinY))
                ColorPicker:Display()
                PreRender:Wait()
            end
            Library:AttemptSave()
        end)

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local MinY = HueSelectorInner.AbsolutePosition.Y
                local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y
                ColorPicker.Hue = (math.clamp(GetMouseY(), MinY, MaxY) - MinY) / (MaxY - MinY)
                ColorPicker:Display()
                PreRender:Wait()
            end
            Library:AttemptSave()
        end)

        DisplayFrame.InputBegan:Connect(function(Input)
            if Library:MouseIsOverOpenedFrame() then return end
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end)

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = TransparencyBoxInner.AbsolutePosition.X
                    local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X
                    ColorPicker.Transparency = 1 - ((math.clamp(GetMouseX(), MinX, MaxX) - MinX) / (MaxX - MinX))
                    ColorPicker:Display()
                    PreRender:Wait()
                end
                Library:AttemptSave()
            end)
        end

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local P, S = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize
                local MX, MY = GetMouseX(), GetMouseY()
                if MX < P.X or MX > P.X + S.X or MY < (P.Y - 21) or MY > P.Y + S.Y then
                    ColorPicker:Hide()
                end
                if not Library:IsMouseOverFrame(ContextMenu.Container) then ContextMenu:Hide() end
            end
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display()
        ColorPicker.DisplayFrame = DisplayFrame
        Options[Idx] = ColorPicker
        return self
    end

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self
        local ToggleLabel = self.TextLabel
        assert(Info.Default, 'AddKeyPicker: Missing default value.')

        local KeyPicker = {
            Value = Info.Default, Toggled = false, Mode = Info.Mode or 'Toggle',
            Type = 'KeyPicker',
            Callback = Info.Callback or function() end,
            ChangedCallback = Info.ChangedCallback or function() end,
            SyncToggleState = Info.SyncToggleState or false,
        }
        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0),
            Size = UDim2.new(0, 28, 0, 15), ZIndex = 6, Parent = ToggleLabel,
        })
        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 7, Parent = PickOuter,
        })
        Library:AddToRegistry(PickInner, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0), TextSize = 13, Text = Info.Default,
            TextWrapped = true, ZIndex = 8, Parent = PickInner,
        })

        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0),
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1),
            Size = UDim2.new(0, 60, 0, 47), Visible = false, ZIndex = 14, Parent = ScreenGui,
        })
        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1)
        end)

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 15, Parent = ModeSelectOuter,
        })
        Library:AddToRegistry(ModeSelectInner, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })
        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = ModeSelectInner,
        })

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18),
            TextSize = 13, Visible = false, ZIndex = 110, Parent = Library.KeybindContainer,
        }, true)

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' }
        local ModeButtons = {}
        for _, Mode in next, Modes do
            local ModeButton = {}
            local Label = Library:CreateLabel({
                Active = false, Size = UDim2.new(1, 0, 0, 15), TextSize = 13,
                Text = Mode, ZIndex = 16, Parent = ModeSelectInner,
            })
            function ModeButton:Select()
                for _, B in next, ModeButtons do B:Deselect() end
                KeyPicker.Mode = Mode
                Label.TextColor3 = Library.AccentColor
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor'
                ModeSelectOuter.Visible = false
            end
            function ModeButton:Deselect()
                KeyPicker.Mode = nil
                Label.TextColor3 = Library.FontColor
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor'
            end
            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select()
                    Library:AttemptSave()
                end
            end)
            if Mode == KeyPicker.Mode then ModeButton:Select() end
            ModeButtons[Mode] = ModeButton
        end

        function KeyPicker:Update()
            if not Info.NoUI then DisplayLabel.Text = KeyPicker.Value end
            local State = KeyPicker:GetState()
            local ListMode = Library.KeypickerListMode or 3
            local ShowInList = false
            if ListMode == 3 or ListMode == 'All' then
                ShowInList = true
            elseif ListMode == 2 or ListMode == 'Toggled' then
                ShowInList = (KeyPicker.Mode == 'Toggle' and KeyPicker.Toggled)
            elseif ListMode == 1 or ListMode == 'Active' then
                ShowInList = State
            end
            if KeyPicker.Value == 'None' and ListMode ~= 3 and ListMode ~= 'All' then ShowInList = false end

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode)
            ContainerLabel.Visible = ShowInList
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor
            if Library.RegistryMap[ContainerLabel] then
                Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor'
            end

            local YSize, XSize, Visible = 0, 0, 0
            for _, L in next, Library.KeybindContainer:GetChildren() do
                if L:IsA('TextLabel') and L.Visible then
                    Visible = Visible + 1
                    YSize = YSize + 18
                    if L.TextBounds.X > XSize then XSize = L.TextBounds.X end
                end
            end
            if Library.KeybindFrameEnabled == false then
                Library.KeybindFrame.Visible = false
            else
                Library.KeybindFrame.Visible = (Visible > 0)
            end
            if Visible > 0 then
                Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
            end
        end

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then return true end
            if KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then return false end
                local Key = KeyPicker.Value
                if Key == 'MB1' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
                if Key == 'MB2' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
                return InputService:IsKeyDown(Enum.KeyCode[Key])
            end
            return KeyPicker.Toggled
        end

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2]
            DisplayLabel.Text = Key
            KeyPicker.Value = Key
            ModeButtons[Mode]:Select()
            KeyPicker:Update()
        end
        function KeyPicker:OnClick(Callback) KeyPicker.Clicked = Callback end
        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then table.insert(ParentObj.Addons, KeyPicker) end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false
        PickOuter.InputBegan:Connect(function(Input)
            if Library:MouseIsOverOpenedFrame() then return end
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Picking = true
                DisplayLabel.Text = ''
                local Break, Text = false, ''
                task.spawn(function()
                    while not Break do
                        if Text == '...' then Text = '' end
                        Text = Text .. '.'
                        DisplayLabel.Text = Text
                        task.wait(0.4)
                    end
                end)
                task.wait(0.2)

                local Event
                Event = InputService.InputBegan:Connect(function(I)
                    local Key
                    if I.UserInputType == Enum.UserInputType.Keyboard then
                        Key = I.KeyCode.Name
                    elseif I.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1'
                    elseif I.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2'
                    end
                    Break = true
                    Picking = false
                    DisplayLabel.Text = Key
                    KeyPicker.Value = Key
                    Library:SafeCallback(KeyPicker.ChangedCallback, I.KeyCode or I.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, I.KeyCode or I.UserInputType)
                    Library:AttemptSave()
                    Event:Disconnect()
                end)
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                ModeSelectOuter.Visible = true
            end
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if ActiveTextBox then return end
            if not Picking then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value
                    if (Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1)
                       or (Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2)
                       or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key) then
                        KeyPicker.Toggled = not KeyPicker.Toggled
                        KeyPicker:DoClick()
                    end
                end
                KeyPicker:Update()
            end
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local P, S = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize
                local MX, MY = GetMouseX(), GetMouseY()
                if MX < P.X or MX > P.X + S.X or MY < (P.Y - 21) or MY > P.Y + S.Y then
                    ModeSelectOuter.Visible = false
                end
            end
        end))
        Library:GiveSignal(InputService.InputEnded:Connect(function()
            if not Picking then KeyPicker:Update() end
        end))

        KeyPicker:Update()
        Options[Idx] = KeyPicker
        return self
    end

    BaseAddons.__index = Funcs
    BaseAddons.__namecall = function(Table, Key, ...) return Funcs[Key](...) end
end

local BaseGroupbox = {}
do
    local Funcs = {}

    function Funcs:AddBlank(Size)
        Library:Create('Frame', {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Size),
            ZIndex = 1, Parent = self.Container,
        })
    end

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {}
        local Groupbox = self
        local Container = self.Container
        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15), TextSize = 14, Text = Text,
            TextWrapped = DoesWrap or false, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5, Parent = Container,
        })
        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4), FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                SortOrder = Enum.SortOrder.LayoutOrder, Parent = TextLabel,
            })
        end

        Label.TextLabel = TextLabel
        Label.Container = Container
        function Label:SetText(NewText)
            TextLabel.Text = NewText
            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(NewText, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end
            Groupbox:Resize()
        end

        if not DoesWrap then setmetatable(Label, BaseAddons) end
        self:AddBlank(5)
        self:Resize()
        return Label
    end

    local function ProcessButtonParams(Obj, ...)
        local Props = select(1, ...)
        if type(Props) == 'table' then
            Obj.Text, Obj.Func, Obj.DoubleClick, Obj.Tooltip = Props.Text, Props.Func, Props.DoubleClick, Props.Tooltip
        else
            Obj.Text, Obj.Func = select(1, ...), select(2, ...)
        end
        assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.')
    end

    local function CreateBaseButton(Button)
        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0),
            Size = UDim2.new(1, -4, 0, 20), ZIndex = 5,
        })
        local Inner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = Outer,
        })
        local Label = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0), TextSize = 14, Text = Button.Text,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6, Parent = Inner,
        })
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)),
            }), Rotation = 90, Parent = Inner,
        })
        Library:AddToRegistry(Outer, { BorderColor3 = 'Black' })
        Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        Library:OnHighlight(Outer, Outer, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' })
        return Outer, Inner, Label
    end

    local function ValidateClick(Input)
        if Library:MouseIsOverOpenedFrame() then return false end
        return Input.UserInputType == Enum.UserInputType.MouseButton1
    end

    local function InitEvents(Button)
        local function WaitForEvent(Event, Timeout, Validator)
            local Bindable = Instance.new('BindableEvent')
            local Connection = Event:Once(function(...)
                Bindable:Fire(type(Validator) == 'function' and Validator(...) or false)
            end)
            task.delay(Timeout, function()
                Connection:Disconnect()
                Bindable:Fire(false)
            end)
            return Bindable.Event:Wait()
        end

        Button.Outer.InputBegan:Connect(function(Input)
            if not ValidateClick(Input) or Button.Locked then return end
            if Button.DoubleClick then
                Library:RemoveFromRegistry(Button.Label)
                Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })
                Button.Label.TextColor3 = Library.AccentColor
                Button.Label.Text = 'Are you sure?'
                Button.Locked = true
                local Clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)
                Library:RemoveFromRegistry(Button.Label)
                Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })
                Button.Label.TextColor3 = Library.FontColor
                Button.Label.Text = Button.Text
                task.defer(rawset, Button, 'Locked', false)
                if Clicked then Library:SafeCallback(Button.Func) end
                return
            end
            Library:SafeCallback(Button.Func)
        end)
    end

    function Funcs:AddButton(...)
        local Button = {}
        ProcessButtonParams(Button, ...)
        local Container = self.Container

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container
        InitEvents(Button)

        function Button:AddTooltip(Tooltip)
            if type(Tooltip) == 'string' then Library:AddToolTip(Tooltip, self.Outer) end
            return self
        end

        function Button:AddButton(...)
            local SubButton = {}
            ProcessButtonParams(SubButton, ...)
            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)
            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)
            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer
            function SubButton:AddTooltip(Tooltip)
                if type(Tooltip) == 'string' then Library:AddToolTip(Tooltip, self.Outer) end
                return SubButton
            end
            if type(SubButton.Tooltip) == 'string' then SubButton:AddTooltip(SubButton.Tooltip) end
            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then Button:AddTooltip(Button.Tooltip) end

        self:AddBlank(5)
        self:Resize()
        return Button
    end

    function Funcs:AddDivider()
        local Container = self.Container
        self:AddBlank(2)
        local DivOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0),
            Size = UDim2.new(1, -4, 0, 5), ZIndex = 5, Parent = Container,
        })
        local DivInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = DivOuter,
        })
        Library:AddToRegistry(DivOuter, { BorderColor3 = 'Black' })
        Library:AddToRegistry(DivInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        self:AddBlank(9)
        self:Resize()
    end

    function Funcs:AddList(Info)
        Info = Info or {}
        local List = {}
        local Container = self.Container
        local Height = Info.Height or 180

        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0),
            Size = UDim2.new(1, -4, 0, Height), ZIndex = 5, Parent = Container,
        })
        local Inner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = Outer,
        })
        Library:AddToRegistry(Outer, { BorderColor3 = 'Black' })
        Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

        local Scroll = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2),
            CanvasSize = UDim2.new(), ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.OutlineColor,
            BottomImage = '', TopImage = '', ZIndex = 7, Parent = Inner,
        })
        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = Scroll,
        })
        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Scroll.CanvasSize = UDim2.fromOffset(0, Layout.AbsoluteContentSize.Y)
        end)

        List.Rows = {}
        List.Selected = nil
        List.Scroll = Scroll

        function List:AddRow(Text, OnClick)
            local Row = {}
            local Button = Library:Create('TextButton', {
                AutoButtonColor = false, BackgroundColor3 = Library.AccentColor,
                BackgroundTransparency = 1, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 16), Text = '', ZIndex = 8, Parent = Scroll,
            })
            local Label = Library:CreateLabel({
                Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -6, 1, 0),
                TextSize = 14, Text = Text, TextXAlignment = Enum.TextXAlignment.Left,
                TextScaled = false, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,
                ClipsDescendants = true, ZIndex = 9, Parent = Button,
            })

            Row.Button = Button
            Row.Label = Label

            function Row:SetText(NewText) Label.Text = NewText end
            function Row:SetColor(Color) Label.TextColor3 = Color end
            function Row:SetSelected(State) Button.BackgroundTransparency = State and 0.8 or 1 end
            function Row:SetCopyValue(Value) Row.CopyValue = Value end
            function Row:Destroy() Button:Destroy() end

            Button.MouseButton1Click:Connect(function()
                if List.Selected and List.Selected ~= Row then List.Selected:SetSelected(false) end
                List.Selected = Row
                Row:SetSelected(true)
                if OnClick then Library:SafeCallback(OnClick, Row) end
            end)

            Button.MouseButton2Click:Connect(function()
                local Copied = Row.CopyValue or Label.Text
                pcall(setclipboard, Copied)
                Library:Notify('Copied to clipboard!', 2)
            end)

            table.insert(List.Rows, Row)
            return Row
        end

        function List:Clear()
            for _, Row in next, List.Rows do Row:Destroy() end
            table.clear(List.Rows)
            List.Selected = nil
        end

        function List:IsEmpty()
            return #List.Rows == 0
        end

        self:AddBlank(5)
        self:Resize()
        return List
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')
        local Textbox = {
            Value = Info.Default or '', Numeric = Info.Numeric or false,
            Finished = Info.Finished or false, Type = 'Input',
            Callback = Info.Callback or function() end,
        }
        local Container = self.Container

        Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15), TextSize = 14, Text = Info.Text,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = Container,
        })
        self:AddBlank(1)

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0),
            Size = UDim2.new(1, -4, 0, 20), ZIndex = 5, Parent = Container,
        })
        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = TextBoxOuter,
        })
        Library:AddToRegistry(TextBoxInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        Library:OnHighlight(TextBoxOuter, TextBoxOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' })

        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, TextBoxOuter) end

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)),
            }), Rotation = 90, Parent = TextBoxInner,
        })

        local InnerContainer = Library:Create('Frame', {
            BackgroundTransparency = 1, ClipsDescendants = true,
            Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -5, 1, 0),
            ZIndex = 7, Parent = TextBoxInner,
        })

        local Box = Library:CreateTextBox({
            Parent = InnerContainer,
            ClickRegion = TextBoxInner,
            Default = Info.Default or '',
            Placeholder = Info.Placeholder or '',
            Numeric = Info.Numeric or false,
            MaxLength = Info.MaxLength,
            ZIndex = 7,
        })

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then Text = Text:sub(1, Info.MaxLength) end
            if Textbox.Numeric and not tonumber(Text) and #Text > 0 then Text = Textbox.Value end
            Textbox.Value = Text
            Box:Set(Text, false)
            Library:SafeCallback(Textbox.Callback, Textbox.Value)
            Library:SafeCallback(Textbox.Changed, Textbox.Value)
        end

        if Textbox.Finished then
            Box:OnFocusLost(function(Enter)
                if not Enter then return end
                Textbox:SetValue(Box.Value)
                Library:AttemptSave()
            end)
        else
            Box:OnChanged(function()
                Textbox:SetValue(Box.Value)
                Library:AttemptSave()
            end)
        end

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func
            Func(Textbox.Value)
        end

        self:AddBlank(5)
        self:Resize()
        Options[Idx] = Textbox
        return Textbox
    end

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddToggle: Missing `Text` string.')
        local Toggle = {
            Value = Info.Default or false, Type = 'Toggle',
            Callback = Info.Callback or function() end,
            Addons = {}, Risky = Info.Risky,
        }
        local Container = self.Container

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0),
            Size = UDim2.new(0, 13, 0, 13), ZIndex = 5, Parent = Container,
        })
        Library:AddToRegistry(ToggleOuter, { BorderColor3 = 'Black' })

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = ToggleOuter,
        })
        Library:AddToRegistry(ToggleInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 216, 1, 0), Position = UDim2.new(1, 6, 0, 0),
            TextSize = 14, Text = Info.Text, TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6, Parent = ToggleInner,
        })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4), FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = ToggleLabel,
        })

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1, Size = UDim2.new(0, 170, 1, 0),
            ZIndex = 8, Parent = ToggleOuter,
        })
        Library:OnHighlight(ToggleRegion, ToggleOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' })

        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, ToggleRegion) end

        function Toggle:UpdateColors() Toggle:Display() end

        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor
            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor'
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor'
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func
            Func(Toggle.Value)
        end

        function Toggle:SetValue(Bool)
            Bool = not not Bool
            Toggle.Value = Bool
            Toggle:Display()
            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end
            Library:SafeCallback(Toggle.Callback, Toggle.Value)
            Library:SafeCallback(Toggle.Changed, Toggle.Value)
            Library:UpdateDependencyBoxes()
        end

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave()
            end
        end)

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display()
        self:AddBlank(Info.BlankSize or 7)
        self:Resize()
        Toggle.TextLabel = ToggleLabel
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)
        Toggles[Idx] = Toggle
        Library:UpdateDependencyBoxes()
        return Toggle
    end

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.')
        assert(Info.Text, 'AddSlider: Missing slider text.')
        assert(Info.Min, 'AddSlider: Missing minimum value.')
        assert(Info.Max, 'AddSlider: Missing maximum value.')
        assert(Info.Rounding, 'AddSlider: Missing rounding value.')

        local Slider = {
            Value = Info.Default, Min = Info.Min, Max = Info.Max,
            Rounding = Info.Rounding, MaxSize = 232, Type = 'Slider',
            Callback = Info.Callback or function() end,
        }
        local Container = self.Container

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10), TextSize = 14, Text = Info.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Bottom,
                ZIndex = 5, Parent = Container,
            })
            self:AddBlank(3)
        end

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0),
            Size = UDim2.new(1, -4, 0, 13), ZIndex = 5, Parent = Container,
        })
        Library:AddToRegistry(SliderOuter, { BorderColor3 = 'Black' })

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = SliderOuter,
        })
        Library:AddToRegistry(SliderInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor, BorderColor3 = Library.AccentColorDark,
            Size = UDim2.new(0, 0, 1, 0), ZIndex = 7, Parent = SliderInner,
        })
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor', BorderColor3 = 'AccentColorDark' })

        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
            Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0),
            ZIndex = 8, Parent = Fill,
        })
        Library:AddToRegistry(HideBorderRight, { BackgroundColor3 = 'AccentColor' })

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0), TextSize = 14, Text = 'Infinite',
            ZIndex = 9, Parent = SliderInner,
        })
        Library:OnHighlight(SliderOuter, SliderOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' })

        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, SliderOuter) end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor
            Fill.BorderColor3 = Library.AccentColorDark
        end

        function Slider:Display()
            local Suffix = Info.Suffix or ''
            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = tostring(Slider.Value) .. Suffix
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix)
            end
            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize))
            Fill.Size = UDim2.new(0, X, 1, 0)
            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0)
        end

        function Slider:OnChanged(Func)
            Slider.Changed = Func
            Func(Slider.Value)
        end

        local function Round(Value)
            if Slider.Rounding == 0 then return math.floor(Value) end
            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max))
        end

        function Slider:SetValue(Str)
            local Num = tonumber(Str)
            if not Num then return end
            Slider.Value = math.clamp(Num, Slider.Min, Slider.Max)
            Slider:Display()
            Library:SafeCallback(Slider.Callback, Slider.Value)
            Library:SafeCallback(Slider.Changed, Slider.Value)
        end

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 or Library:MouseIsOverOpenedFrame() then return end
            local mPos = GetMouseX()
            local gPos = Fill.Size.X.Offset
            local Diff = mPos - (Fill.AbsolutePosition.X + gPos)
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local nMPos = GetMouseX()
                local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize)
                local nValue = Slider:GetValueFromXOffset(nX)
                local OldValue = Slider.Value
                Slider.Value = nValue
                Slider:Display()
                if nValue ~= OldValue then
                    Library:SafeCallback(Slider.Callback, Slider.Value)
                    Library:SafeCallback(Slider.Changed, Slider.Value)
                end
                PreRender:Wait()
            end
            Library:AttemptSave()
        end)

        Slider:Display()
        self:AddBlank(Info.BlankSize or 6)
        self:Resize()
        Options[Idx] = Slider
        return Slider
    end

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString()
            Info.AllowNull = true
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString()
            Info.AllowNull = true
        end
        assert(Info.Values, 'AddDropdown: Missing dropdown value list.')
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')
        if not Info.Text then Info.Compact = true end

        local Dropdown = {
            Values = Info.Values, Value = Info.Multi and {}, Multi = Info.Multi,
            Type = 'Dropdown', SpecialType = Info.SpecialType,
            Callback = Info.Callback or function() end,
        }
        local Container = self.Container

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10), TextSize = 14, Text = Info.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Bottom,
                ZIndex = 5, Parent = Container,
            })
            self:AddBlank(3)
        end

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0),
            Size = UDim2.new(1, -4, 0, 20), ZIndex = 5, Parent = Container,
        })
        Library:AddToRegistry(DropdownOuter, { BorderColor3 = 'Black' })

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6, Parent = DropdownOuter,
        })
        Library:AddToRegistry(DropdownInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)),
            }), Rotation = 90, Parent = DropdownInner,
        })

        local DropdownArrow = Library:CreateLabel({
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
            Size = UDim2.new(0, 12, 0, 12), Text = '▼', TextSize = 10,
            ZIndex = 8, Parent = DropdownInner,
        })

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -5, 1, 0),
            TextSize = 14, Text = '--', TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true, ZIndex = 7, Parent = DropdownInner,
        })
        Library:OnHighlight(DropdownOuter, DropdownOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' })

        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, DropdownOuter) end

        local MAX_DROPDOWN_ITEMS = 8

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderColor3 = Color3.new(0, 0, 0),
            ZIndex = 20, Visible = false, Parent = ScreenGui,
        })

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1)
        end
        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end
        RecalculateListPosition()
        RecalculateListSize()
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition)

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = 21, Parent = ListOuter,
        })
        Library:AddToRegistry(ListInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 21, Parent = ListInner,
            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            ScrollBarThickness = 3, ScrollBarImageColor3 = Library.AccentColor,
        })
        Library:AddToRegistry(Scrolling, { ScrollBarImageColor3 = 'AccentColor' })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0), FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = Scrolling,
        })

        function Dropdown:Display()
            local Str = ''
            if Info.Multi then
                for _, Value in next, Dropdown.Values do
                    if Dropdown.Value[Value] then Str = Str .. Value .. ', ' end
                end
                Str = Str:sub(1, #Str - 2)
            else
                Str = Dropdown.Value or ''
            end
            ItemList.Text = Str == '' and '--' or Str
        end

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {}
                for Value in next, Dropdown.Value do table.insert(T, Value) end
                return T
            end
            return Dropdown.Value and 1 or 0
        end

        function Dropdown:BuildDropdownList()
            local Buttons = {}
            for _, E in next, Scrolling:GetChildren() do
                if not E:IsA('UIListLayout') then E:Destroy() end
            end
            local Count = 0
            for _, Value in next, Dropdown.Values do
                local Tbl = {}
                Count = Count + 1
                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
                    BorderMode = Enum.BorderMode.Middle, Size = UDim2.new(1, -1, 0, 20),
                    ZIndex = 23, Active = true, Parent = Scrolling,
                })
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
                local ButtonLabel = Library:CreateLabel({
                    Active = false, Size = UDim2.new(1, -6, 1, 0),
                    Position = UDim2.new(0, 6, 0, 0), TextSize = 14, Text = Value,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 25, Parent = Button,
                })
                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                )

                local Selected
                function Tbl:UpdateButton()
                    Selected = Info.Multi and Dropdown.Value[Value] or Dropdown.Value == Value
                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor'
                end

                ButtonLabel.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    local Try = not Selected
                    if Dropdown:GetActiveValues() == 1 and not Try and not Info.AllowNull then return end
                    if Info.Multi then
                        Dropdown.Value[Value] = Try and true or nil
                    else
                        Dropdown.Value = Try and Value or nil
                        for _, Other in next, Buttons do Other:UpdateButton() end
                    end
                    Tbl:UpdateButton()
                    Dropdown:Display()
                    Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                    Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
                    Library:AttemptSave()
                end)

                Tbl:UpdateButton()
                Dropdown:Display()
                Buttons[Button] = Tbl
            end
            Scrolling.CanvasSize = UDim2.fromOffset(0, Count * 20 + 1)
            RecalculateListSize(math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1)
        end

        function Dropdown:SetValues(NewValues)
            if NewValues then Dropdown.Values = NewValues end
            Dropdown:BuildDropdownList()
        end

        function Dropdown:OpenDropdown()
            ListOuter.Visible = true
            Library.OpenedFrames[ListOuter] = true
            DropdownArrow.Rotation = 180
        end
        function Dropdown:CloseDropdown()
            ListOuter.Visible = false
            Library.OpenedFrames[ListOuter] = nil
            DropdownArrow.Rotation = 0
        end

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func
            Func(Dropdown.Value)
        end

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local NTable = {}
                for Value in next, Val do
                    if table.find(Dropdown.Values, Value) then NTable[Value] = true end
                end
                Dropdown.Value = NTable
            elseif not Val then
                Dropdown.Value = nil
            elseif table.find(Dropdown.Values, Val) then
                Dropdown.Value = Val
            end
            Dropdown:BuildDropdownList()
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
        end

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 or Library:MouseIsOverOpenedFrame() then return end
            if ListOuter.Visible then Dropdown:CloseDropdown() else Dropdown:OpenDropdown() end
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            local P, S = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize
            local MX, MY = GetMouseX(), GetMouseY()
            if MX < P.X or MX > P.X + S.X or MY < (P.Y - 21) or MY > P.Y + S.Y then
                Dropdown:CloseDropdown()
            end
        end))

        Dropdown:BuildDropdownList()
        Dropdown:Display()

        local Defaults = {}
        if type(Info.Default) == 'string' then
            local I = table.find(Dropdown.Values, Info.Default)
            if I then table.insert(Defaults, I) end
        elseif type(Info.Default) == 'table' then
            for _, V in next, Info.Default do
                local I = table.find(Dropdown.Values, V)
                if I then table.insert(Defaults, I) end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index]
                    break
                end
            end
            Dropdown:BuildDropdownList()
            Dropdown:Display()
        end

        self:AddBlank(Info.BlankSize or 5)
        self:Resize()
        Options[Idx] = Dropdown
        return Dropdown
    end

    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {} }
        local Groupbox = self
        local Container = self.Container

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
            Visible = false, Parent = Container,
        })
        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
            Visible = true, Parent = Holder,
        })
        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder, Parent = Frame,
        })

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y)
            Groupbox:Resize()
        end
        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Depbox:Resize() end)
        Holder:GetPropertyChangedSignal('Visible'):Connect(function() Depbox:Resize() end)

        function Depbox:Update()
            for _, Dep in next, Depbox.Dependencies do
                if Dep[1].Type == 'Toggle' and Dep[1].Value ~= Dep[2] then
                    Holder.Visible = false
                    Depbox:Resize()
                    return
                end
            end
            Holder.Visible = true
            Depbox:Resize()
        end

        function Depbox:SetupDependencies(Dependencies)
            for _, Dep in next, Dependencies do
                assert(type(Dep) == 'table', 'SetupDependencies: Dependency is not of type `table`.')
                assert(Dep[1], 'SetupDependencies: Dependency is missing element argument.')
                assert(Dep[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.')
            end
            Depbox.Dependencies = Dependencies
            Depbox:Update()
        end

        Depbox.Container = Frame
        setmetatable(Depbox, BaseGroupbox)
        table.insert(Library.DependencyBoxes, Depbox)
        return Depbox
    end

    BaseGroupbox.__index = Funcs
    BaseGroupbox.__namecall = function(Table, Key, ...) return Funcs[Key](...) end
end

do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 40),
        Size = UDim2.new(0, 300, 0, 200), ZIndex = 100, Parent = ScreenGui,
    })
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4), FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = Library.NotificationArea,
    })

    local WatermarkOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0), Position = UDim2.new(0, 100, 0, -25),
        Size = UDim2.new(0, 213, 0, 20), ZIndex = 200, Visible = false, Parent = ScreenGui,
    })
    local WatermarkInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor, BorderColor3 = Library.AccentColor,
        BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 201, Parent = WatermarkOuter,
    })
    Library:AddToRegistry(WatermarkInner, { BorderColor3 = 'AccentColor' })

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 202, Parent = WatermarkInner,
    })
    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        }), Rotation = -90, Parent = InnerFrame,
    })
    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            })
        end,
    })
    Library.WatermarkText = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0), Size = UDim2.new(1, -4, 1, 0),
        TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 203, Parent = InnerFrame,
    })
    Library.Watermark = WatermarkOuter
    Library:MakeDraggable(Library.Watermark)

    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5), BorderColor3 = Color3.new(0, 0, 0),
        Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(0, 210, 0, 20),
        Visible = false, ZIndex = 100, Parent = ScreenGui,
    })
    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
        BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 101, Parent = KeybindOuter,
    })
    Library:AddToRegistry(KeybindInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' }, true)
    Library:AddToRegistry(Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2), ZIndex = 102, Parent = KeybindInner,
    }), { BackgroundColor3 = 'AccentColor' }, true)
    Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left, Text = 'Keybinds',
        ZIndex = 104, Parent = KeybindInner,
    })
    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -20),
        Position = UDim2.new(0, 0, 0, 20), ZIndex = 1, Parent = KeybindInner,
    })
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = KeybindContainer,
    })
    Library:Create('UIPadding', { PaddingLeft = UDim.new(0, 5), Parent = KeybindContainer })
    Library.KeybindFrame = KeybindOuter
    Library.KeybindContainer = KeybindContainer
    Library:MakeDraggable(KeybindOuter)
end

function Library:SetWatermarkVisibility(Bool) Library.Watermark.Visible = Bool end

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14)
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, Y * 1.5 + 3)
    Library:SetWatermarkVisibility(true)
    Library.WatermarkText.Text = Text
end

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14)
    YSize = YSize + 7

    local NotifyOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0), Position = UDim2.new(0, 100, 0, 10),
        Size = UDim2.new(0, 0, 0, YSize), ClipsDescendants = true,
        ZIndex = 100, Parent = Library.NotificationArea,
    })
    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
        BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 101, Parent = NotifyOuter,
    })
    Library:AddToRegistry(NotifyInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' }, true)

    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 102, Parent = NotifyInner,
    })
    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        }), Rotation = -90, Parent = InnerFrame,
    })
    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            })
        end,
    })
    Library:CreateLabel({
        Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(1, -4, 1, 0),
        Text = Text, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14,
        ZIndex = 103, Parent = InnerFrame,
    })
    Library:AddToRegistry(Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
        Position = UDim2.new(0, -1, 0, -1), Size = UDim2.new(0, 3, 1, 2),
        ZIndex = 104, Parent = NotifyOuter,
    }), { BackgroundColor3 = 'AccentColor' }, true)

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 12, 0, YSize), 'Out', 'Quad', 0.4, true)
    task.spawn(function()
        task.wait(Time or 5)
        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.4, true)
        task.wait(0.4)
        NotifyOuter:Destroy()
    end)
end

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }
    if type(...) == 'table' then
        Config = ...
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end
    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end
    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = { Tabs = {} }

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint, BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0, Position = Config.Position, Size = Config.Size,
        Visible = false, ZIndex = 1, Parent = ScreenGui,
    })
    Library:MakeDraggable(Outer, 25)

    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor, BorderColor3 = Library.AccentColor,
        BorderMode = Enum.BorderMode.Inset, Position = UDim2.new(0, 1, 0, 1),
        Size = UDim2.new(1, -2, 1, -2), ZIndex = 1, Parent = Outer,
    })
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'AccentColor' })

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 7, 0, 0), Size = UDim2.new(0, 0, 0, 25),
        Text = Config.Title, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 1, Parent = Inner,
    })

    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 8, 0, 25), Size = UDim2.new(1, -16, 1, -33),
        ZIndex = 1, Parent = Inner,
    })
    Library:AddToRegistry(MainSectionOuter, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })

    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Color3.new(0, 0, 0),
        BorderMode = Enum.BorderMode.Inset, Position = UDim2.new(),
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 1, Parent = MainSectionOuter,
    })
    Library:AddToRegistry(MainSectionInner, { BackgroundColor3 = 'BackgroundColor' })

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 8),
        Size = UDim2.new(1, -16, 0, 21), ZIndex = 1, Parent = MainSectionInner,
    })
    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = TabArea,
    })
    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 8, 0, 30), Size = UDim2.new(1, -16, 1, -38),
        ZIndex = 2, Parent = MainSectionInner,
    })
    Library:AddToRegistry(TabContainer, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

    function Window:SetWindowTitle(Title) WindowLabel.Text = Title end

    function Window:AddTab(Name)
        local Tab = { Groupboxes = {}, Tabboxes = {} }
        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16)

        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
            Size = UDim2.new(0, TabButtonWidth + 12, 1, 0), ZIndex = 1, Parent = TabArea,
        })
        Library:AddToRegistry(TabButton, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })

        Library:CreateLabel({
            Position = UDim2.new(), Size = UDim2.new(1, 0, 1, -1),
            Text = Name, ZIndex = 1, Parent = TabButton,
        })
        local Blocker = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor, BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1),
            BackgroundTransparency = 1, ZIndex = 3, Parent = TabButton,
        })
        Library:AddToRegistry(Blocker, { BackgroundColor3 = 'MainColor' })

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame', BackgroundTransparency = 1,
            Position = UDim2.new(), Size = UDim2.new(1, 0, 1, 0),
            Visible = false, ZIndex = 2, Parent = TabContainer,
        })

        local function MakeSide(PositionX)
            local Side = Library:Create('ScrollingFrame', {
                BackgroundTransparency = 1, BorderSizePixel = 0,
                Position = UDim2.new(PositionX, PositionX == 0 and 7 or 5, 0, 7),
                Size = UDim2.new(0.5, -10, 0, 509), CanvasSize = UDim2.new(),
                BottomImage = '', TopImage = '', ScrollBarThickness = 0,
                ZIndex = 2, Parent = TabFrame,
            })
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = Side,
            })
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y)
            end)
            return Side
        end
        local LeftSide = MakeSide(0)
        local RightSide = MakeSide(0.5)

        function Tab:ShowTab()
            for _, T in next, Window.Tabs do T:HideTab() end
            Blocker.BackgroundTransparency = 0
            TabButton.BackgroundColor3 = Library.MainColor
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor'
            TabFrame.Visible = true
        end
        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1
            TabButton.BackgroundColor3 = Library.BackgroundColor
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor'
            TabFrame.Visible = false
        end
        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position
            TabListLayout:ApplyLayout()
        end

        function Tab:AddGroupbox(Info)
            local Groupbox = {}
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 0, 509),
                ZIndex = 2, Parent = Info.Side == 1 and LeftSide or RightSide,
            })
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Color3.new(0, 0, 0),
                Size = UDim2.new(1, -2, 1, -2), Position = UDim2.new(0, 1, 0, 1),
                ZIndex = 4, Parent = BoxOuter,
            })
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor' })

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 2), ZIndex = 5, Parent = BoxInner,
            })
            Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor' })

            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 4, 0, 2),
                TextSize = 14, Text = Info.Name,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = BoxInner,
            })

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1, Position = UDim2.new(0, 4, 0, 20),
                Size = UDim2.new(1, -4, 1, -20), ZIndex = 1, Parent = BoxInner,
            })
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder, Parent = Container,
            })

            function Groupbox:Resize()
                local Size = 0
                for _, E in next, Groupbox.Container:GetChildren() do
                    if not E:IsA('UIListLayout') and E.Visible then Size = Size + E.Size.Y.Offset end
                end
                BoxOuter.Size = UDim2.new(1, 0, 0, 24 + Size)
            end

            Groupbox.Container = Container
            setmetatable(Groupbox, BaseGroupbox)
            Groupbox:AddBlank(3)
            Groupbox:Resize()
            Tab.Groupboxes[Info.Name] = Groupbox
            return Groupbox
        end
        function Tab:AddLeftGroupbox(Name) return Tab:AddGroupbox({ Side = 1, Name = Name }) end
        function Tab:AddRightGroupbox(Name) return Tab:AddGroupbox({ Side = 2, Name = Name }) end

        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {} }
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset, Size = UDim2.new(1, 0, 0, 0),
                ZIndex = 2, Parent = Info.Side == 1 and LeftSide or RightSide,
            })
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor, BorderColor3 = Color3.new(0, 0, 0),
                Size = UDim2.new(1, -2, 1, -2), Position = UDim2.new(0, 1, 0, 1),
                ZIndex = 4, Parent = BoxOuter,
            })
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor' })

            Library:AddToRegistry(Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 2), ZIndex = 10, Parent = BoxInner,
            }), { BackgroundColor3 = 'AccentColor' })

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 1),
                Size = UDim2.new(1, 0, 0, 18), ZIndex = 5, Parent = BoxInner,
            })
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                SortOrder = Enum.SortOrder.LayoutOrder, Parent = TabboxButtons,
            })

            function Tabbox:AddTab(Name)
                local SubTab = {}
                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor, BorderColor3 = Color3.new(0, 0, 0),
                    Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 6, Parent = TabboxButtons,
                })
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor' })

                Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0), TextSize = 14, Text = Name,
                    TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7, Parent = Button,
                })
                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor, BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1),
                    Visible = false, ZIndex = 9, Parent = Button,
                })
                Library:AddToRegistry(Block, { BackgroundColor3 = 'BackgroundColor' })

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1, Position = UDim2.new(0, 4, 0, 20),
                    Size = UDim2.new(1, -4, 1, -20), ZIndex = 1, Visible = false, Parent = BoxInner,
                })
                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder, Parent = Container,
                })

                function SubTab:Show()
                    for _, T in next, Tabbox.Tabs do T:Hide() end
                    Container.Visible = true
                    Block.Visible = true
                    Button.BackgroundColor3 = Library.BackgroundColor
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor'
                    SubTab:Resize()
                end
                function SubTab:Hide()
                    Container.Visible = false
                    Block.Visible = false
                    Button.BackgroundColor3 = Library.MainColor
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor'
                end
                function SubTab:Resize()
                    local TabCount = 0
                    for _ in next, Tabbox.Tabs do TabCount = TabCount + 1 end
                    for _, B in next, TabboxButtons:GetChildren() do
                        if not B:IsA('UIListLayout') then B.Size = UDim2.new(1 / TabCount, 0, 1, 0) end
                    end
                    if not Container.Visible then return end
                    local Size = 0
                    for _, E in next, SubTab.Container:GetChildren() do
                        if not E:IsA('UIListLayout') and E.Visible then Size = Size + E.Size.Y.Offset end
                    end
                    BoxOuter.Size = UDim2.new(1, 0, 0, 24 + Size)
                end

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        SubTab:Show()
                        SubTab:Resize()
                    end
                end)

                SubTab.Container = Container
                Tabbox.Tabs[Name] = SubTab
                setmetatable(SubTab, BaseGroupbox)
                SubTab:AddBlank(3)
                SubTab:Resize()
                if #TabboxButtons:GetChildren() == 2 then SubTab:Show() end
                return SubTab
            end

            Tab.Tabboxes[Info.Name or ''] = Tabbox
            return Tabbox
        end
        function Tab:AddLeftTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 1 }) end
        function Tab:AddRightTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 2 }) end

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then Tab:ShowTab() end
        end)

        if #TabContainer:GetChildren() == 1 then Tab:ShowTab() end
        Window.Tabs[Name] = Tab
        return Tab
    end

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1, Size = UDim2.new(), Visible = true,
        Text = '', Modal = false, Parent = ScreenGui,
    })

    local TransparencyCache = {}
    local Toggled, Fading = false, false

    function Library:Toggle()
        if Fading then return end
        local FadeTime = Config.MenuFadeTime
        Fading = true
        Toggled = not Toggled
        ModalElement.Modal = Toggled
        if not Toggled and Library.UnfocusTextBox then Library:UnfocusTextBox() end

        if Toggled then
            Outer.Visible = true
            task.spawn(function()
                local State = InputService.MouseIconEnabled
                local Cursor = Drawing.new('Triangle')
                Cursor.Thickness = 1
                Cursor.Filled = true
                Cursor.Visible = true
                local CursorOutline = Drawing.new('Triangle')
                CursorOutline.Thickness = 1
                CursorOutline.Filled = false
                CursorOutline.Color = Color3.new(0, 0, 0)
                CursorOutline.Visible = true

                while Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false
                    local Pos = InputService:GetMouseLocation()
                    Cursor.Color = Library.AccentColor
                    Cursor.PointA = Vector2.new(Pos.X, Pos.Y)
                    Cursor.PointB = Vector2.new(Pos.X + 16, Pos.Y + 6)
                    Cursor.PointC = Vector2.new(Pos.X + 6, Pos.Y + 16)
                    CursorOutline.PointA = Cursor.PointA
                    CursorOutline.PointB = Cursor.PointB
                    CursorOutline.PointC = Cursor.PointC
                    PreRender:Wait()
                end

                InputService.MouseIconEnabled = State
                Cursor:Remove()
                CursorOutline:Remove()
            end)
        end

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {}
            if Desc:IsA('ImageLabel') then
                table.insert(Properties, 'ImageTransparency')
                table.insert(Properties, 'BackgroundTransparency')
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                table.insert(Properties, 'TextTransparency')
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                table.insert(Properties, 'BackgroundTransparency')
            elseif Desc:IsA('UIStroke') then
                table.insert(Properties, 'Transparency')
            end

            local Cache = TransparencyCache[Desc]
            if not Cache then
                Cache = {}
                TransparencyCache[Desc] = Cache
            end
            for _, Prop in next, Properties do
                if not Cache[Prop] then Cache[Prop] = Desc[Prop] end
                if Cache[Prop] == 1 then continue end
                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), {
                    [Prop] = Toggled and Cache[Prop] or 1,
                }):Play()
            end
        end

        task.wait(FadeTime)
        Outer.Visible = Toggled
        Fading = false
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if ActiveTextBox and KeyToChar(Input.KeyCode) then return end
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and not Processed) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer
    return Window
end

local function OnPlayerChange()
    local PlayerList = GetPlayersString()
    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList)
        end
    end
end
Library:GiveSignal(Players.PlayerAdded:Connect(OnPlayerChange))
Library:GiveSignal(Players.PlayerRemoving:Connect(OnPlayerChange))

getgenv().Library = Library
return Library