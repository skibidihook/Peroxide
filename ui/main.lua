local Library = import("ui/Library")
local RemoteSpy = import("modules/RemoteSpy")

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Bridge = px.Bridge

local function MethodFor(ClassName)
    if ClassName == "RemoteFunction" then
        return "InvokeServer"
    elseif ClassName == "BindableEvent" then
        return "Fire"
    elseif ClassName == "BindableFunction" then
        return "Invoke"
    end

    return "FireServer"
end

local function Summarize(Value)
    local Kind = typeof(Value)

    if Kind == "Instance" then
        return Value.ClassName
    elseif Kind == "string" then
        local Text = Value
        if #Text > 22 then Text = Text:sub(1, 22) .. "..." end
        return `"{Text}"`
    elseif Kind == "table" then
        return "{table}"
    elseif Kind == "number" or Kind == "boolean" then
        return tostring(Value)
    end

    return Kind
end

local function SummarizeArgs(Arguments)
    local Parts = {}

    for Index = 1, #Arguments do
        Parts[Index] = Summarize(Arguments[Index])
    end

    return (#Parts > 0 and table.concat(Parts, ", ")) or "(no args)"
end

local function DescribeFull(Value)
    local Kind = typeof(Value)

    if Kind == "Instance" then
        return getInstancePath(Value)
    elseif Kind == "string" then
        return `"{Value}"`
    elseif Kind == "table" then
        return tableToString(Value)
    elseif isUserdata(Kind) then
        return userdataValue(Value)
    end

    return tostring(Value)
end

local function GenerateScript(Instance, Call)
    local Path = getInstancePath(Instance)
    local Method = MethodFor(Instance.ClassName)
    local Arguments = tableToString(Call.args)

    return `local arguments = {Arguments}\n\n{Path}:{Method}(unpack(arguments))`
end

local function RepeatCall(Instance, Call)
    task.spawn(function()
        local Method = MethodFor(Instance.ClassName)
        pcall(function()
            Instance[Method](Instance, unpack(Call.args))
        end)
    end)
end

local Window = Library:CreateWindow({
    Title = "Peroxide",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    RemoteSpy = Window:AddTab("RemoteSpy"),
    Settings = Window:AddTab("Settings"),
}

local CaptureBox = Tabs.RemoteSpy:AddLeftGroupbox("Capture")
local RemotesBox = Tabs.RemoteSpy:AddLeftGroupbox("Remotes")
local SelectedBox = Tabs.RemoteSpy:AddRightGroupbox("Selected")
local CallsBox = Tabs.RemoteSpy:AddRightGroupbox("Calls")
local ArgsBox = Tabs.RemoteSpy:AddRightGroupbox("Arguments")

local RemoteList = RemotesBox:AddList({ Height = 240 })
local SelectedLabel = SelectedBox:AddLabel("Selected: none", true)
local CallList = CallsBox:AddList({ Height = 170 })
local ArgList = ArgsBox:AddList({ Height = 150 })

local SelectedInstance = nil
local SelectedCall = nil
local RowByInstance = {}
local ShownCalls = 0

local function UpdateSelectedLabel()
    if not SelectedInstance then
        SelectedLabel:SetText("Selected: none")
        return
    end

    local Remote = RemoteSpy.CurrentRemotes[SelectedInstance]
    local Blocked = Remote and Remote.Blocked or false
    local Ignored = Remote and Remote.Ignored or false

    SelectedLabel:SetText(`Selected: {SelectedInstance.Name} [{SelectedInstance.ClassName}]\nBlocked: {tostring(Blocked)} | Ignored: {tostring(Ignored)}`)
end

local function SelectCall(Index, Call)
    SelectedCall = Call
    ArgList:Clear()

    for ArgIndex = 1, #Call.args do
        local Value = Call.args[ArgIndex]
        ArgList:AddRow(`[{ArgIndex}] {typeof(Value)}: {Summarize(Value)}`, function()
            if setClipboard then setClipboard(DescribeFull(Value)) end
        end)
    end
end

local function SelectRemote(Instance)
    SelectedInstance = Instance
    SelectedCall = nil
    ShownCalls = 0
    CallList:Clear()
    ArgList:Clear()
    UpdateSelectedLabel()
end

local function RefreshRemotes()
    for Instance, Remote in next, RemoteSpy.CurrentRemotes do
        local Text = `{Instance.Name} [{Instance.ClassName}] x{Remote.Calls}`
        local Row = RowByInstance[Instance]

        if Row then
            Row:SetText(Text)
        else
            RowByInstance[Instance] = RemoteList:AddRow(Text, function()
                SelectRemote(Instance)
            end)
        end
    end
end

local function RefreshCalls()
    if not SelectedInstance then return end

    local Remote = RemoteSpy.CurrentRemotes[SelectedInstance]
    if not Remote then return end

    local Logs = Remote.Logs

    for Index = ShownCalls + 1, #Logs do
        local Call = Logs[Index]
        CallList:AddRow(`#{Index}  {SummarizeArgs(Call.args)}`, function()
            SelectCall(Index, Call)
        end)
    end

    ShownCalls = #Logs
end

local WatchClasses = { "RemoteEvent", "RemoteFunction", "BindableEvent", "BindableFunction" }

for _, Class in next, WatchClasses do
    CaptureBox:AddToggle("Watch" .. Class, {
        Text = Class,
        Default = RemoteSpy.RemotesViewing[Class] and true or false,
        Callback = function(Value)
            RemoteSpy.RemotesViewing[Class] = Value
        end,
    })
end

RemotesBox:AddButton({
    Text = "Clear all",
    Func = function()
        for _, Remote in next, RemoteSpy.CurrentRemotes do
            Remote.Clear(Remote)
        end

        RemoteList:Clear()
        CallList:Clear()
        ArgList:Clear()
        table.clear(RowByInstance)
        SelectedInstance = nil
        SelectedCall = nil
        ShownCalls = 0
        UpdateSelectedLabel()
    end,
})

SelectedBox:AddButton({
    Text = "Toggle block",
    Func = function()
        local Remote = SelectedInstance and RemoteSpy.CurrentRemotes[SelectedInstance]
        if Remote then
            Remote.Block(Remote)
            UpdateSelectedLabel()
        end
    end,
}):AddButton({
    Text = "Toggle ignore",
    Func = function()
        local Remote = SelectedInstance and RemoteSpy.CurrentRemotes[SelectedInstance]
        if Remote then
            Remote.Ignore(Remote)
            UpdateSelectedLabel()
        end
    end,
})

SelectedBox:AddButton({
    Text = "Copy remote path",
    Func = function()
        if SelectedInstance and setClipboard then
            setClipboard(getInstancePath(SelectedInstance))
        end
    end,
})

CallsBox:AddButton({
    Text = "Repeat call",
    Func = function()
        if SelectedInstance and SelectedCall then
            RepeatCall(SelectedInstance, SelectedCall)
        end
    end,
}):AddButton({
    Text = "Generate script",
    Func = function()
        if SelectedInstance and SelectedCall and setClipboard then
            setClipboard(GenerateScript(SelectedInstance, SelectedCall))
        end
    end,
})

CallsBox:AddButton({
    Text = "Copy calling script",
    Func = function()
        if SelectedCall and SelectedCall.script and setClipboard then
            setClipboard(getInstancePath(SelectedCall.script))
        end
    end,
})

CallsBox:AddButton({
    Text = "Copy remote (JSON)",
    Func = function()
        if not SelectedInstance or not Bridge or not setClipboard then return end

        local Response = Bridge.Run({ Action = "Remote", Path = SelectedInstance:GetFullName(), Max = 50 })
        if Response.Ok then
            setClipboard(HttpService:JSONEncode(Response.Data))
        end
    end,
})

local Dirty = true

RemoteSpy.ConnectEvent(function()
    Dirty = true
end)

local Accumulator = 0

px.Events.PeroxideRemoteSpy = RunService.Heartbeat:Connect(function(Delta)
    Accumulator += Delta
    if Accumulator < 0.2 then return end
    Accumulator = 0

    if not Dirty then return end
    Dirty = false

    RefreshRemotes()
    RefreshCalls()
end)

local MenuBox = Tabs.Settings:AddLeftGroupbox("Menu")

MenuBox:AddButton({ Text = "Unload", Func = function() Library:Unload() end })
MenuBox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "End", NoUI = true, Text = "Menu keybind" })

Library.ToggleKeybind = Options.MenuKeybind

Library:OnUnload(function()
    if px and px.Exit then
        px.Exit()
    end
end)

return Window
