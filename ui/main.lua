local Library = import("ui/Library")
local OkTheme, ThemeManager = pcall(import, "ui/ThemeManager")
local OkSave, SaveManager = pcall(import, "ui/SaveManager")
local RemoteSpy = import("modules/RemoteSpy")
local ClosureSpy = import("modules/ClosureSpy")
local Closure = import("objects/Closure")

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Bridge = px.Bridge

local HexView = false
local SpyClosure

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

local function ToHex(Text)
    return (Text:gsub(".", function(Char)
        return string.format("%02X ", string.byte(Char))
    end))
end

local function Summarize(Value)
    local Kind = typeof(Value)

    if Kind == "Instance" then
        return Value.ClassName
    elseif Kind == "string" then
        local Text = HexView and ToHex(Value) or `"{Value}"`
        if #Text > 24 then Text = Text:sub(1, 24) .. "..." end
        return Text
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
        return HexView and ToHex(Value) or `"{Value}"`
    elseif Kind == "table" then
        return tableToString(Value)
    elseif isUserdata(Kind) then
        return userdataValue(Value)
    end

    return tostring(Value)
end

local function Location(Func)
    local Ok, Info = pcall(getInfo, Func)
    if not Ok or typeof(Info) ~= "table" then return "?" end

    local Source = Info.short_src or Info.source or "?"
    local Line = Info.linedefined or Info.currentline or 0
    return `{Source}:{Line}`
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
    ClosureSpy = Window:AddTab("ClosureSpy"),
    Settings = Window:AddTab("Settings"),
}

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

local RemoteCaptureBox = Tabs.RemoteSpy:AddLeftGroupbox("Capture")
local RemotesBox = Tabs.RemoteSpy:AddLeftGroupbox("Remotes")
local RemoteSelectedBox = Tabs.RemoteSpy:AddRightGroupbox("Selected")
local RemoteCallsBox = Tabs.RemoteSpy:AddRightGroupbox("Calls")
local RemoteArgsBox = Tabs.RemoteSpy:AddRightGroupbox("Arguments")

local RemoteList = RemotesBox:AddList({ Height = 230 })
local RemoteSelectedLabel = RemoteSelectedBox:AddLabel("Selected: none", true)
local RemoteCallList = RemoteCallsBox:AddList({ Height = 160 })
local RemoteArgList = RemoteArgsBox:AddList({ Height = 150 })

local SelectedInstance = nil
local SelectedCall = nil
local SelectedCallIndex = nil
local SelectedArgIndex = nil
local SelectedArgValue = nil
local RowByInstance = {}
local RemoteShownCalls = 0
local RemoteDirty = true

local function UpdateRemoteLabel()
    if not SelectedInstance then
        RemoteSelectedLabel:SetText("Selected: none")
        return
    end

    local Remote = RemoteSpy.CurrentRemotes[SelectedInstance]
    local Blocked = Remote and Remote.Blocked or false
    local Ignored = Remote and Remote.Ignored or false

    RemoteSelectedLabel:SetText(`Selected: {SelectedInstance.Name} [{SelectedInstance.ClassName}]\nBlocked: {tostring(Blocked)} | Ignored: {tostring(Ignored)}`)
end

local function SelectRemoteCall(Index, Call)
    SelectedCall = Call
    SelectedCallIndex = Index
    SelectedArgIndex = nil
    SelectedArgValue = nil
    RemoteArgList:Clear()

    for ArgIndex = 1, #Call.args do
        local Value = Call.args[ArgIndex]
        local Row = RemoteArgList:AddRow(`[{ArgIndex}] {typeof(Value)}: {Summarize(Value)}`, function()
            SelectedArgIndex = ArgIndex
            SelectedArgValue = Value
        end)
        Row:SetCopyValue(DescribeFull(Value))
    end
end

local function RefreshRemoteCalls()
    if not SelectedInstance then return end

    local Remote = RemoteSpy.CurrentRemotes[SelectedInstance]
    if not Remote then return end

    for Index = RemoteShownCalls + 1, #Remote.Logs do
        local Call = Remote.Logs[Index]
        RemoteCallList:AddRow(`#{Index}  {SummarizeArgs(Call.args)}`, function()
            SelectRemoteCall(Index, Call)
        end)
    end

    RemoteShownCalls = #Remote.Logs
end

local function RebuildRemoteCalls()
    RemoteCallList:Clear()
    RemoteShownCalls = 0
    RefreshRemoteCalls()
end

local function SelectRemote(Instance)
    SelectedInstance = Instance
    SelectedCall = nil
    SelectedCallIndex = nil
    SelectedArgIndex = nil
    SelectedArgValue = nil
    RemoteShownCalls = 0
    RemoteCallList:Clear()
    RemoteArgList:Clear()
    UpdateRemoteLabel()
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

local function ApplyCondition(Ignore, ByType)
    if not SelectedInstance or not SelectedArgIndex then return end

    local Remote = RemoteSpy.CurrentRemotes[SelectedInstance]
    if not Remote then return end

    local Value = ByType and typeof(SelectedArgValue) or SelectedArgValue

    if Ignore then
        Remote.IgnoreArg(Remote, SelectedArgIndex, Value, ByType)
    else
        Remote.BlockArg(Remote, SelectedArgIndex, Value, ByType)
    end
end

local WatchClasses = { "RemoteEvent", "RemoteFunction", "BindableEvent", "BindableFunction" }

for _, Class in next, WatchClasses do
    RemoteCaptureBox:AddToggle("Watch" .. Class, {
        Text = Class,
        Default = RemoteSpy.RemotesViewing[Class] and true or false,
        Callback = function(Value)
            RemoteSpy.RemotesViewing[Class] = Value
        end,
    })
end

RemoteCaptureBox:AddToggle("HexView", {
    Text = "String hex view",
    Default = false,
    Callback = function(Value)
        HexView = Value
        if SelectedCall then SelectRemoteCall(SelectedCallIndex, SelectedCall) end
        RebuildRemoteCalls()
    end,
})

RemotesBox:AddButton({
    Text = "Clear all",
    Func = function()
        for _, Remote in next, RemoteSpy.CurrentRemotes do
            Remote.Clear(Remote)
        end

        RemoteList:Clear()
        RemoteCallList:Clear()
        RemoteArgList:Clear()
        table.clear(RowByInstance)
        SelectedInstance = nil
        SelectedCall = nil
        RemoteShownCalls = 0
        UpdateRemoteLabel()
    end,
})

RemoteSelectedBox:AddButton({
    Text = "Toggle block",
    Func = function()
        local Remote = SelectedInstance and RemoteSpy.CurrentRemotes[SelectedInstance]
        if Remote then
            Remote.Block(Remote)
            UpdateRemoteLabel()
        end
    end,
}):AddButton({
    Text = "Toggle ignore",
    Func = function()
        local Remote = SelectedInstance and RemoteSpy.CurrentRemotes[SelectedInstance]
        if Remote then
            Remote.Ignore(Remote)
            UpdateRemoteLabel()
        end
    end,
})

RemoteSelectedBox:AddButton({
    Text = "Copy remote path",
    Func = function()
        if SelectedInstance and setClipboard then
            setClipboard(getInstancePath(SelectedInstance))
        end
    end,
}):AddButton({
    Text = "Clear conditions",
    Func = function()
        local Remote = SelectedInstance and RemoteSpy.CurrentRemotes[SelectedInstance]
        if Remote then
            Remote.BlockedArgs = {}
            Remote.IgnoredArgs = {}
        end
    end,
})

RemoteCallsBox:AddButton({
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

RemoteCallsBox:AddButton({
    Text = "Remove log",
    Func = function()
        local Remote = SelectedInstance and RemoteSpy.CurrentRemotes[SelectedInstance]
        if Remote and SelectedCall then
            Remote.DecrementCalls(Remote, SelectedCall)
            SelectedCall = nil
            RemoteArgList:Clear()
            RebuildRemoteCalls()
        end
    end,
}):AddButton({
    Text = "Spy function",
    Func = function()
        if SelectedCall and SelectedCall.func then
            SpyClosure(SelectedCall.func, SelectedCall.script)
        end
    end,
})

RemoteCallsBox:AddButton({
    Text = "Copy calling script",
    Func = function()
        if SelectedCall and SelectedCall.script and setClipboard then
            setClipboard(getInstancePath(SelectedCall.script))
        end
    end,
}):AddButton({
    Text = "Copy remote (JSON)",
    Func = function()
        if not SelectedInstance or not Bridge or not setClipboard then return end

        local Response = Bridge.Run({ Action = "Remote", Path = SelectedInstance:GetFullName(), Max = 50 })
        if Response.Ok then
            setClipboard(HttpService:JSONEncode(Response.Data))
        end
    end,
})

RemoteArgsBox:AddButton({
    Text = "Block value",
    Func = function() ApplyCondition(false, false) end,
}):AddButton({
    Text = "Block type",
    Func = function() ApplyCondition(false, true) end,
})

RemoteArgsBox:AddButton({
    Text = "Ignore value",
    Func = function() ApplyCondition(true, false) end,
}):AddButton({
    Text = "Ignore type",
    Func = function() ApplyCondition(true, true) end,
})

RemoteArgsBox:AddButton({
    Text = "Copy value",
    Func = function()
        if SelectedArgIndex and setClipboard then
            setClipboard(DescribeFull(SelectedArgValue))
        end
    end,
})

local ClosuresBox = Tabs.ClosureSpy:AddLeftGroupbox("Closures")
local ClosureSelectedBox = Tabs.ClosureSpy:AddRightGroupbox("Selected")
local ClosureCallsBox = Tabs.ClosureSpy:AddRightGroupbox("Calls")
local ClosureDetailBox = Tabs.ClosureSpy:AddRightGroupbox("Detail")

ClosuresBox:AddLabel("Hook a function via RemoteSpy -> Spy function", true)
local ClosureList = ClosuresBox:AddList({ Height = 220 })
local ClosureSelectedLabel = ClosureSelectedBox:AddLabel("Selected: none", true)
local ClosureCallList = ClosureCallsBox:AddList({ Height = 160 })
local ClosureDetailList = ClosureDetailBox:AddList({ Height = 170 })

local SpiedHooks = {}
local HookByData = {}
local RowByHook = {}
local SelectedHook = nil
local SelectedHookCall = nil
local ClosureShownCalls = 0
local ClosureDirty = false

local function UpdateClosureLabel()
    if not SelectedHook then
        ClosureSelectedLabel:SetText("Selected: none")
        return
    end

    ClosureSelectedLabel:SetText(`Selected: {SelectedHook.Closure.Name}\n{Location(SelectedHook.Closure.Data)}\nBlocked: {tostring(SelectedHook.Blocked)} | Ignored: {tostring(SelectedHook.Ignored)}`)
end

local function SelectHookCall(Call)
    SelectedHookCall = Call
    ClosureDetailList:Clear()

    for ArgIndex = 1, #Call.args do
        local Value = Call.args[ArgIndex]
        local Row = ClosureDetailList:AddRow(`[{ArgIndex}] {typeof(Value)}: {Summarize(Value)}`, function()
            if setClipboard then setClipboard(DescribeFull(Value)) end
        end)
        Row:SetCopyValue(DescribeFull(Value))
    end
end

local function RefreshHookCalls()
    if not SelectedHook then return end

    for Index = ClosureShownCalls + 1, #SelectedHook.Logs do
        local Call = SelectedHook.Logs[Index]
        ClosureCallList:AddRow(`#{Index}  {SummarizeArgs(Call.args)}`, function()
            SelectHookCall(Call)
        end)
    end

    ClosureShownCalls = #SelectedHook.Logs
end

local function SelectHook(Hook)
    SelectedHook = Hook
    SelectedHookCall = nil
    ClosureShownCalls = 0
    ClosureCallList:Clear()
    ClosureDetailList:Clear()
    UpdateClosureLabel()
    RefreshHookCalls()
end

local function RefreshClosures()
    for _, Hook in next, SpiedHooks do
        local Text = `{Hook.Closure.Name} x{Hook.Calls}`
        local Row = RowByHook[Hook]

        if Row then
            Row:SetText(Text)
        else
            RowByHook[Hook] = ClosureList:AddRow(Text, function()
                SelectHook(Hook)
            end)
        end
    end
end

local function ShowValues(Getter)
    if not SelectedHook then return end

    ClosureDetailList:Clear()

    local Ok, Values = pcall(Getter, SelectedHook.Closure.Data)
    if not Ok or typeof(Values) ~= "table" then return end

    for Index = 1, #Values do
        local Value = Values[Index]
        local Row = ClosureDetailList:AddRow(`[{Index}] {typeof(Value)}: {Summarize(Value)}`, function()
            if setClipboard then setClipboard(DescribeFull(Value)) end
        end)
        Row:SetCopyValue(DescribeFull(Value))
    end
end

SpyClosure = function(Func, CallingScript)
    if typeof(Func) ~= "function" then return end

    local Existing = HookByData[Func]
    if Existing then
        SelectHook(Existing)
        return
    end

    if isLClosure and not isLClosure(Func) then return end

    local Ok, ClosureObject = pcall(Closure.new, Func)
    if not Ok then return end

    local Hook = ClosureSpy.Hook.new(ClosureObject)
    if not Hook then return end

    HookByData[Func] = Hook
    table.insert(SpiedHooks, Hook)
    ClosureDirty = true
    SelectHook(Hook)
end

ClosureSpy.SetEvent(function(Hook, Call)
    Hook.IncrementCalls(Hook, Call)
    ClosureDirty = true
end)

ClosureSelectedBox:AddButton({
    Text = "Toggle block",
    Func = function()
        if SelectedHook then
            SelectedHook.Block(SelectedHook)
            UpdateClosureLabel()
        end
    end,
}):AddButton({
    Text = "Toggle ignore",
    Func = function()
        if SelectedHook then
            SelectedHook.Ignore(SelectedHook)
            UpdateClosureLabel()
        end
    end,
})

ClosureSelectedBox:AddButton({
    Text = "View constants",
    Func = function() ShowValues(getConstants) end,
}):AddButton({
    Text = "View upvalues",
    Func = function() ShowValues(getUpvalues) end,
})

ClosureSelectedBox:AddButton({
    Text = "Copy location",
    Func = function()
        if SelectedHook and setClipboard then
            setClipboard(Location(SelectedHook.Closure.Data))
        end
    end,
}):AddButton({
    Text = "Remove",
    Func = function()
        if not SelectedHook then return end

        SelectedHook.Remove(SelectedHook)
        HookByData[SelectedHook.Closure.Data] = nil
        local Row = RowByHook[SelectedHook]
        if Row then Row:Destroy() end
        RowByHook[SelectedHook] = nil

        local Position = table.find(SpiedHooks, SelectedHook)
        if Position then table.remove(SpiedHooks, Position) end

        SelectedHook = nil
        SelectedHookCall = nil
        ClosureCallList:Clear()
        ClosureDetailList:Clear()
        UpdateClosureLabel()
    end,
})

ClosureCallsBox:AddButton({
    Text = "Clear calls",
    Func = function()
        if SelectedHook then
            SelectedHook.Clear(SelectedHook)
            table.clear(SelectedHook.Logs)
            ClosureShownCalls = 0
            ClosureCallList:Clear()
            ClosureDetailList:Clear()
        end
    end,
})

local MenuBox = Tabs.Settings:AddLeftGroupbox("Menu")

MenuBox:AddButton({ Text = "Unload", Func = function() Library:Unload() end })
MenuBox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "End", NoUI = true, Text = "Menu keybind" })

Library.ToggleKeybind = Options.MenuKeybind

if OkTheme and OkSave and ThemeManager and SaveManager then
    pcall(function()
        ThemeManager:SetLibrary(Library)
        SaveManager:SetLibrary(Library)
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
        ThemeManager:SetFolder("Peroxide")
        SaveManager:SetFolder("Peroxide")
        SaveManager:BuildConfigSection(Tabs.Settings)
        ThemeManager:ApplyToTab(Tabs.Settings)
        SaveManager:LoadAutoloadConfig()
    end)
end

local Accumulator = 0

RemoteSpy.ConnectEvent(function()
    RemoteDirty = true
end)

px.Events.PeroxideRefresh = RunService.Heartbeat:Connect(function(Delta)
    Accumulator += Delta
    if Accumulator < 0.2 then return end
    Accumulator = 0

    if RemoteDirty then
        RemoteDirty = false
        RefreshRemotes()
        RefreshRemoteCalls()
    end

    if ClosureDirty then
        ClosureDirty = false
        RefreshClosures()
        RefreshHookCalls()
    end
end)

Library:OnUnload(function()
    if px and px.Exit then
        px.Exit()
    end
end)

return Window
