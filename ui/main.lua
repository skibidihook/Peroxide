local Library = import("ui/Library")
local RemoteSpy = import("modules/RemoteSpy")

local RunService = game:GetService("RunService")
local Bridge = px.Bridge

local function Summarize(Value)
    local Kind = typeof(Value)

    if Kind == "Instance" then
        return Value.ClassName
    elseif Kind == "string" then
        local Text = Value
        if #Text > 18 then Text = Text:sub(1, 18) .. "..." end
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
local CallsBox = Tabs.RemoteSpy:AddRightGroupbox("Calls")

local RemoteList = RemotesBox:AddList({ Height = 260 })
local CallList = CallsBox:AddList({ Height = 300 })

local SelectedInstance = nil
local RowByInstance = {}
local ShownCalls = 0

local function DumpCall(Instance, Index, Call)
    print(`[Peroxide] {Instance:GetFullName()} call #{Index}`)

    for ArgIndex = 1, #Call.args do
        print(`  arg{ArgIndex}: {Summarize(Call.args[ArgIndex])}`)
    end

    if Bridge then
        local Described = {}

        for ArgIndex = 1, #Call.args do
            Described[ArgIndex] = Bridge.DescribeValue(Call.args[ArgIndex])
        end

        Bridge.Emit({
            Ok = true,
            Action = "RemoteCall",
            Data = {
                Remote = Instance.Name,
                Class = Instance.ClassName,
                Index = Index,
                Arguments = Described,
            },
        })
    end
end

local function SelectRemote(Instance)
    SelectedInstance = Instance
    ShownCalls = 0
    CallList:Clear()
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
            DumpCall(SelectedInstance, Index, Call)
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
        table.clear(RowByInstance)
        SelectedInstance = nil
        ShownCalls = 0
    end,
})

CallsBox:AddButton({
    Text = "Dump to console",
    Func = function()
        if not SelectedInstance then return end

        local Remote = RemoteSpy.CurrentRemotes[SelectedInstance]
        if not Remote then return end

        for Index = 1, #Remote.Logs do
            DumpCall(SelectedInstance, Index, Remote.Logs[Index])
        end
    end,
})

CallsBox:AddButton({
    Text = "Copy remote path",
    Func = function()
        if SelectedInstance and setClipboard and getInstancePath then
            setClipboard(getInstancePath(SelectedInstance))
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
