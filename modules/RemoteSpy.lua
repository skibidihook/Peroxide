local RemoteSpy = {}
local Remote = import("objects/Remote")

local requiredMethods = {
    ["checkCaller"] = true,
    ["newCClosure"] = true,
    ["hookFunction"] = true,
    ["isReadOnly"] = true,
    ["setReadOnly"] = true,
    ["getInfo"] = true,
    ["getMetatable"] = true,
    ["setClipboard"] = true,
    ["getNamecallMethod"] = true,
    ["getCallingScript"] = true,
}

local remoteMethods = {
    FireServer = true,
    InvokeServer = true,
    Fire = true,
    Invoke = true
}

local remotesViewing = {
    RemoteEvent = true,
    RemoteFunction = false,
    BindableEvent = false,
    BindableFunction = false
}

local methodHooks = {
    RemoteEvent = Instance.new("RemoteEvent").FireServer,
    UnreliableRemoteEvent = Instance.new("UnreliableRemoteEvent").FireServer,
    RemoteFunction = Instance.new("RemoteFunction").InvokeServer,
    BindableEvent = Instance.new("BindableEvent").Fire,
    BindableFunction = Instance.new("BindableFunction").Invoke
}

local currentRemotes = {}
local paused = false

local remoteDataEvent = Instance.new("BindableEvent")
local eventSet = false

local function connectEvent(callback)
    remoteDataEvent.Event:Connect(callback)

    if not eventSet then
        eventSet = true
    end
end

local nmcTrampoline
nmcTrampoline = hookMetaMethod(game, "__namecall", function(...)
    local instance = ...
    
    if typeof(instance) ~= "Instance" then
        return nmcTrampoline(...)
    end

    local method = getNamecallMethod()

    if method == "fireServer" then
        method = "FireServer"
    elseif method == "invokeServer" then
        method = "InvokeServer"
    end
    local remoteClassName = instance.ClassName;
    if (remoteClassName == "UnreliableRemoteEvent") then
        remoteClassName = "RemoteEvent";
    end;    
    if remotesViewing[remoteClassName] and instance ~= remoteDataEvent and remoteMethods[method] then
        local remote = currentRemotes[instance]
        local vargs = {select(2, ...)}
            
        if not remote then
            remote = Remote.new(instance)
            currentRemotes[instance] = remote
        end

        local remoteIgnored = remote.Ignored
        local remoteBlocked = remote.Blocked
        local argsIgnored = remote.AreArgsIgnored(remote, vargs)
        local argsBlocked = remote.AreArgsBlocked(remote, vargs)

        if eventSet and not paused and (not remoteIgnored and not argsIgnored) then
            local call = {
                script = getCallingScript(),
                args = vargs,
                func = getInfo(3).func
            }

            remote.IncrementCalls(remote, call)
            remoteDataEvent.Fire(remoteDataEvent, instance, call)
        end

        if remoteBlocked or argsBlocked then
            return
        end
    end

    return nmcTrampoline(...)
end)

-- vuln fix

local pcall = pcall

local function checkPermission(instance)
    if (instance.ClassName) then end
end

for _name, hook in pairs(methodHooks) do
    if (_name == "UnreliableRemoteEvent") then
        _name = "RemoteEvent";
    end;
    local originalMethod
    originalMethod = hookFunction(hook, newCClosure(function(...)
        local instance = ...

        if typeof(instance) ~= "Instance" then
            return originalMethod(...)
        end
                
        do
            local success = pcall(checkPermission, instance)
            if (not success) then return originalMethod(...) end
        end
        local remoteClassName = instance.ClassName;
        if (remoteClassName == "UnreliableRemoteEvent") then
            remoteClassName = "RemoteEvent";
        end;
        if remoteClassName == _name and remotesViewing[remoteClassName] and instance ~= remoteDataEvent then
            local remote = currentRemotes[instance]
            local vargs = {select(2, ...)}

            if not remote then
                remote = Remote.new(instance)
                currentRemotes[instance] = remote
            end

            local remoteIgnored = remote.Ignored 
            local argsIgnored = remote:AreArgsIgnored(vargs)
            
            if eventSet and not paused and (not remoteIgnored and not argsIgnored) then
                local call = {
                    script = getCallingScript(),
                    args = vargs,
                    func = getInfo(3).func
                }
    
                remote:IncrementCalls(call)
                remoteDataEvent:Fire(instance, call)
            end

            if remote.Blocked or remote:AreArgsBlocked(vargs) then
                return
            end
        end
        
        return originalMethod(...)
    end))

    px.Hooks[originalMethod] = hook
end

RemoteSpy.RemotesViewing = remotesViewing
RemoteSpy.CurrentRemotes = currentRemotes
RemoteSpy.ConnectEvent = connectEvent
RemoteSpy.RequiredMethods = requiredMethods
RemoteSpy.SetPaused = function(state) paused = state and true or false end
RemoteSpy.IsPaused = function() return paused end
return RemoteSpy
