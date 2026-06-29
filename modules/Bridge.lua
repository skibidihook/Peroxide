local Bridge = {}
local RemoteSpy = import("modules/RemoteSpy")
local ClosureSpy = import("modules/ClosureSpy")
local HttpService = game:GetService("HttpService")

local Tag = "__PEROXIDE__"
local Actions = {}

Bridge.Echo = false

local function DescribeValue(Value)
    local ValueType = typeof(Value)
    local Described = { Type = ValueType }

    if ValueType == "Instance" then
        Described.ClassName = Value.ClassName
        Described.Name = Value.Name
        local Ok, Path = pcall(getInstancePath, Value)
        Described.Value = (Ok and Path) or Value.Name
    elseif ValueType == "string" or ValueType == "number" or ValueType == "boolean" then
        Described.Value = Value
    elseif ValueType == "table" then
        local Ok, Encoded = pcall(tableToString, Value)
        Described.Value = (Ok and Encoded) or tostring(Value)
    elseif isUserdata(ValueType) then
        local Ok, Encoded = pcall(userdataValue, Value)
        Described.Value = (Ok and Encoded) or tostring(Value)
    else
        Described.Value = tostring(Value)
    end

    return Described
end

local function DescribeArguments(Arguments)
    local Described = {}

    if typeof(Arguments) == "table" then
        for Index = 1, #Arguments do
            Described[Index] = DescribeValue(Arguments[Index])
        end
    end

    return Described
end

local function DescribeRemote(Instance, Remote, MaxLogs)
    local Source = Remote.Logs
    local Count = #Source
    local Start = 1

    if MaxLogs and MaxLogs > 0 and Count > MaxLogs then
        Start = Count - MaxLogs + 1
    end

    local Logs = {}

    for Index = Start, Count do
        local Call = Source[Index]
        local CallingScript = Call.script

        Logs[#Logs + 1] = {
            Script = CallingScript and DescribeValue(CallingScript) or nil,
            Arguments = DescribeArguments(Call.args)
        }
    end

    local Path
    local Ok, Result = pcall(getInstancePath, Instance)
    if Ok then
        Path = Result
    end

    return {
        Name = Instance.Name,
        Class = Instance.ClassName,
        Path = Path,
        Calls = Remote.Calls,
        Blocked = Remote.Blocked,
        Ignored = Remote.Ignored,
        Logs = Logs
    }
end

local function CountRemotes()
    local Total = 0

    for _ in next, RemoteSpy.CurrentRemotes do
        Total = Total + 1
    end

    return Total
end

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

local function BuildScript(Instance, Call)
    local OkPath, Path = pcall(getInstancePath, Instance)
    local OkArgs, Arguments = pcall(tableToString, Call.args)
    local Method = MethodFor(Instance.ClassName)

    return `local arguments = {OkArgs and Arguments or "{}"}\n\n{OkPath and Path or Instance.Name}:{Method}(unpack(arguments))`
end

local function FindRemote(Payload)
    for Instance, Remote in next, RemoteSpy.CurrentRemotes do
        if Payload.Path and Instance:GetFullName() == Payload.Path then
            return Instance, Remote
        end

        if Payload.Name and Instance.Name == Payload.Name then
            return Instance, Remote
        end
    end
end

local function ResolveCall(Remote, Index)
    return Remote.Logs[Index or #Remote.Logs]
end

function Actions.Ping()
    return { Name = "Peroxide" }
end

function Actions.Status()
    return {
        Name = "Peroxide",
        Viewing = RemoteSpy.RemotesViewing,
        Remotes = CountRemotes(),
        Status = px.getStatus and px.getStatus() or nil
    }
end

function Actions.GetViewing()
    return RemoteSpy.RemotesViewing
end

function Actions.SetViewing(Payload)
    local Classes = Payload.Classes

    if typeof(Classes) == "table" then
        for Class, State in next, Classes do
            RemoteSpy.RemotesViewing[Class] = State and true or false
        end
    end

    return RemoteSpy.RemotesViewing
end

function Actions.Start()
    for Class in next, RemoteSpy.RemotesViewing do
        RemoteSpy.RemotesViewing[Class] = true
    end

    return RemoteSpy.RemotesViewing
end

function Actions.Stop()
    for Class in next, RemoteSpy.RemotesViewing do
        RemoteSpy.RemotesViewing[Class] = false
    end

    return RemoteSpy.RemotesViewing
end

function Actions.Pause(Payload)
    local State = Payload.State and true or false

    RemoteSpy.SetPaused(State)
    pcall(function() ClosureSpy.SetPaused(State) end)
    return { Paused = State }
end

function Actions.CaptureActors()
    if not RemoteSpy.CaptureActors then error("actors not supported") end

    return { Hooked = RemoteSpy.CaptureActors() }
end

function Actions.RemoteLogs(Payload)
    local MaxLogs = Payload.Max
    local Limit = Payload.Limit
    local Remotes = {}

    for Instance, Remote in next, RemoteSpy.CurrentRemotes do
        if Remote.Calls > 0 then
            Remotes[#Remotes + 1] = DescribeRemote(Instance, Remote, MaxLogs)
        end

        if Limit and #Remotes >= Limit then
            break
        end
    end

    return Remotes
end

function Actions.ClearRemotes()
    local Cleared = 0

    for _, Remote in next, RemoteSpy.CurrentRemotes do
        Remote.Clear(Remote)
        Cleared = Cleared + 1
    end

    return { Cleared = Cleared }
end

function Actions.Remote(Payload)
    local Instance, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    return DescribeRemote(Instance, Remote, Payload.Max)
end

function Actions.SetBlocked(Payload)
    local _, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    Remote.Blocked = Payload.State and true or false
    return { Blocked = Remote.Blocked }
end

function Actions.SetIgnored(Payload)
    local _, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    Remote.Ignored = Payload.State and true or false
    return { Ignored = Remote.Ignored }
end

function Actions.ClearRemote(Payload)
    local _, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    Remote.Clear(Remote)
    return { Cleared = true }
end

function Actions.Repeat(Payload)
    local Instance, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    local Call = ResolveCall(Remote, Payload.Index)
    if not Call then error("call not found") end

    local Method = MethodFor(Instance.ClassName)

    task.spawn(function()
        pcall(function()
            Instance[Method](Instance, unpack(Call.args))
        end)
    end)

    return { Repeated = true }
end

function Actions.GenerateScript(Payload)
    local Instance, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    local Call = ResolveCall(Remote, Payload.Index)
    if not Call then error("call not found") end

    return { Script = BuildScript(Instance, Call) }
end

function Actions.BlockArg(Payload)
    local _, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    Remote.BlockArg(Remote, Payload.Index, Payload.Value, Payload.ByType and true or false)
    return { Ok = true }
end

function Actions.IgnoreArg(Payload)
    local _, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    Remote.IgnoreArg(Remote, Payload.Index, Payload.Value, Payload.ByType and true or false)
    return { Ok = true }
end

function Actions.ClearConditions(Payload)
    local _, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    Remote.BlockedArgs = {}
    Remote.IgnoredArgs = {}
    return { Ok = true }
end

function Actions.RemoveLog(Payload)
    local _, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    local Call = ResolveCall(Remote, Payload.Index)
    if not Call then error("call not found") end

    Remote.DecrementCalls(Remote, Call)
    return { Ok = true }
end

function Actions.Trace(Payload)
    local _, Remote = FindRemote(Payload)
    if not Remote then error("remote not found") end

    local Call = ResolveCall(Remote, Payload.Index)
    if not Call or not Call.func then error("call or func not found") end

    local Ok, Info = pcall(getInfo, Call.func)
    if not Ok or typeof(Info) ~= "table" then error("no function info") end

    return {
        Name = (Info.name and Info.name ~= "" and Info.name) or "unnamed",
        Source = Info.short_src or Info.source,
        Line = Info.linedefined or Info.currentline,
    }
end

function Actions.Eval(Payload)
    local Source = Payload.Source

    if typeof(Source) ~= "string" then
        error("missing source")
    end

    local Chunk, CompileError = loadstring(Source, "Peroxide.Bridge")

    if not Chunk then
        error(CompileError)
    end

    local Results = { pcall(Chunk) }
    local Ok = table.remove(Results, 1)

    if not Ok then
        error(Results[1])
    end

    local Described = {}

    for Index = 1, #Results do
        Described[Index] = DescribeValue(Results[Index])
    end

    return Described
end

function Bridge.Emit(Response)
    local Ok, Encoded = pcall(HttpService.JSONEncode, HttpService, Response)

    if not Ok then
        Encoded = HttpService:JSONEncode({ Ok = false, Error = "encode failure" })
    end

    print(`{Tag}{Encoded}`)
    return Encoded
end

function Bridge.Run(Payload)
    if typeof(Payload) == "string" then
        local Ok, Decoded = pcall(HttpService.JSONDecode, HttpService, Payload)
        Payload = (Ok and typeof(Decoded) == "table" and Decoded) or { Action = Payload }
    end

    Payload = Payload or {}

    local Action = Actions[Payload.Action]
    local Response

    if Action then
        local Ok, Result = pcall(Action, Payload)

        if Ok then
            Response = { Ok = true, Action = Payload.Action, Data = Result }
        else
            Response = { Ok = false, Action = Payload.Action, Error = tostring(Result) }
        end
    else
        Response = { Ok = false, Action = Payload.Action, Error = "unknown action" }
    end

    if Bridge.Echo then
        Bridge.Emit(Response)
    end

    return Response
end

Bridge.Actions = Actions
Bridge.DescribeValue = DescribeValue

return Bridge
