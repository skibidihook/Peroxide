local Bridge = {}
local RemoteSpy = import("modules/RemoteSpy")
local HttpService = game:GetService("HttpService")

local Tag = "__PEROXIDE__"
local Actions = {}

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

    Bridge.Emit(Response)
    return Response
end

Bridge.Actions = Actions
Bridge.DescribeValue = DescribeValue

return Bridge
