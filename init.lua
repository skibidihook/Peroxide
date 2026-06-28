local environment = assert(getgenv, "<PX> ~ Your exploit is not supported")()

if px then
    px.Exit()
elseif oh then
    oh.Exit()
end

local web = true
local user = "skibidihook" -- change if you're using a fork
local branch = "main"
local importCache = {}

local function resolveBase64()
    if crypt then
        if crypt.base64decode then return crypt.base64decode end
        if crypt.base64 and crypt.base64.decode then return crypt.base64.decode end
    end

    if base64decode then return base64decode end
    if base64 and base64.decode then return base64.decode end
    if syn and syn.crypt and syn.crypt.base64decode then return syn.crypt.base64decode end
end

local base64decode = resolveBase64()

if not base64decode then
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}

    for index = 1, #alphabet do
        lookup[alphabet:sub(index, index)] = index - 1
    end

    base64decode = function(data)
        data = data:gsub("[^" .. alphabet .. "=]", "")

        local result = {}
        local value = 0
        local bits = 0

        for index = 1, #data do
            local char = data:sub(index, index)

            if char ~= "=" then
                value = value * 64 + lookup[char]
                bits = bits + 6

                if bits >= 8 then
                    bits = bits - 8
                    result[#result + 1] = string.char(math.floor(value / (2 ^ bits)) % 256)
                    value = value % (2 ^ bits)
                end
            end
        end

        return table.concat(result)
    end
end

local function decodeAsset(data)
    return base64decode(data)
end

local uiAsset = decodeAsset("cmJ4YXNzZXRpZDovLzExMzg5MTM3OTM3")
local assetsAsset = decodeAsset("cmJ4YXNzZXRpZDovLzUwNDIxMTQ5ODI=")

environment.decodeAsset = decodeAsset
environment.uiAsset = uiAsset
environment.assetsAsset = assetsAsset

local function hasMethods(methods)
    for name in pairs(methods) do
        if not environment[name] then
            return false
        end
    end

    return true
end

local function useMethods(module)
    for name, method in pairs(module) do
        if method then
            environment[name] = method
        end
    end
end

local globalMethods = {
    checkCaller = checkcaller,
    newCClosure = newcclosure,
    hookFunction = hookfunction,
    getGc = getgc,
    getInfo = debug.getinfo or getinfo,
    getSenv = getsenv,
    getMenv = getmenv or getsenv,
    getContext = getthreadidentity or (syn and syn.get_thread_identity),
    getConnections = getconnections,
    getScriptClosure = getscriptclosure or getscriptfunction,
    getNamecallMethod = getnamecallmethod,
    getCallingScript = getcallingscript,
    getLoadedModules = getloadedmodules,
    getConstants = debug.getconstants or getconstants,
    getUpvalues = debug.getupvalues or getupvalues,
    getProtos = debug.getprotos or getprotos,
    getStack = debug.getstack or getstack,
    getConstant = debug.getconstant or getconstant,
    getUpvalue = debug.getupvalue or getupvalue,
    getProto = debug.getproto or getproto,
    getMetatable = getrawmetatable or debug.getmetatable,
    getHui = gethui,
    setClipboard = setclipboard or toclipboard,
    setConstant = debug.setconstant or setconstant,
    setContext = setthreadidentity or (syn and syn.set_thread_identity),
    setUpvalue = debug.setupvalue or setupvalue,
    setStack = debug.setstack or setstack,
    setReadOnly = setreadonly,
    isLClosure = islclosure or (iscclosure and function(closure) return not iscclosure(closure) end),
    isReadOnly = isreadonly,
    isXClosure = isexecutorclosure or checkclosure or is_synapse_function,
    hookMetaMethod = hookmetamethod or (hookfunction and function(object, method, hook) return hookfunction(getMetatable(object)[method], hook) end),
    readFile = readfile,
    writeFile = writefile,
    makeFolder = makefolder,
    isFolder = isfolder,
    isFile = isfile,
}

local oldGetUpvalue = globalMethods.getUpvalue
local oldGetUpvalues = globalMethods.getUpvalues

globalMethods.getUpvalue = function(closure, index)
    if type(closure) == "table" then
        return oldGetUpvalue(closure.Data, index)
    end

    return oldGetUpvalue(closure, index)
end

globalMethods.getUpvalues = function(closure)
    if type(closure) == "table" then
        return oldGetUpvalues(closure.Data)
    end

    return oldGetUpvalues(closure)
end

environment.hasMethods = hasMethods
environment.px = {
    Events = {},
    Hooks = {},
    Cache = importCache,
    Methods = globalMethods,
    Constants = {
        Types = {
            ["nil"] = "",
            table = "",
            string = "",
            number = "",
            boolean = "",
            userdata = "",
            vector = "",
            ["function"] = "",
            ["thread"] = "",
            ["integral"] = ""
        },
        Syntax = {
            ["nil"] = Color3.fromRGB(244, 135, 113),
            table = Color3.fromRGB(225, 225, 225),
            string = Color3.fromRGB(225, 150, 85),
            number = Color3.fromRGB(170, 225, 127),
            boolean = Color3.fromRGB(127, 200, 255),
            userdata = Color3.fromRGB(225, 225, 225),
            vector = Color3.fromRGB(225, 225, 225),
            ["function"] = Color3.fromRGB(225, 225, 225),
            ["thread"] = Color3.fromRGB(225, 225, 225),
            ["unnamed_function"] = Color3.fromRGB(175, 175, 175)
        }
    },
    Exit = function()
        for _i, event in pairs(px.Events) do
            event:Disconnect()
        end

        for original, hook in pairs(px.Hooks) do
            local hookType = type(hook)
            if hookType == "function" then
                hookFunction(hook, original)
            elseif hookType == "table" then
                hookFunction(hook.Closure.Data, hook.Original)
            end
        end

        local ui = importCache[uiAsset]
        local assets = importCache[assetsAsset]

        if ui then
            unpack(ui):Destroy()
        end

        if assets then
            unpack(assets):Destroy()
        end
    end
}

environment.Peroxide = environment.px
environment.oh = environment.px

if getConnections then 
    for __, connection in pairs(getConnections(game:GetService("ScriptContext").Error)) do

        local conn = getrawmetatable(connection)
        local old = conn and conn.__index

        setReadOnly(conn, false)

        if old then
            conn.__index = newcclosure(function(t, k)
                if k == "Connected" then
                    return true
                end
                return old(t, k)
            end)
        end

        setReadOnly(conn, true)
        connection:Disable()
    end
end

useMethods(globalMethods)

function environment.import(asset)
    if importCache[asset] then
        return unpack(importCache[asset])
    end

    local url = "https://raw.githubusercontent.com/" .. user .. "/Peroxide/" .. branch .. '/' .. asset .. ".lua?_=" .. tostring(tick())
    local source

    for _attempt = 1, 3 do
        local ok, result = pcall(game.HttpGetAsync, game, url)
        if ok and type(result) == "string" and #result > 0 then
            source = result
            break
        end
        task.wait(0.3)
    end

    if not source then
        error("<PX> failed to fetch " .. asset)
    end

    local chunk, compileError = loadstring(source, asset .. '.lua')
    if not chunk then
        error("<PX> failed to compile " .. asset .. ": " .. tostring(compileError))
    end

    local assets = { chunk() }
    importCache[asset] = assets
    return unpack(assets)
end

useMethods({ import = environment.import })

useMethods(import("methods/string"))
useMethods(import("methods/table"))
useMethods(import("methods/userdata"))
useMethods(import("methods/environment"))

environment.px.Bridge = import("modules/Bridge")
