local ScriptScanner = {}
local LocalScript = import("objects/LocalScript")

local requiredMethods = {
    ["getGc"] = true,
    ["getSenv"] = true,
    ["getProtos"] = true,
    ["getConstants"] = true,
    ["getScriptClosure"] = true,
    ["isXClosure"] = true
}

local function scan(query)
    local scripts = {}
    query = (query or ""):lower()

    local list = (getscripts and getscripts())
        or (getrunningscripts and getrunningscripts())
        or {}

    for _i, script in pairs(list) do
        if typeof(script) == "Instance"
            and not scripts[script]
            and (script:IsA("LocalScript") or script:IsA("Script"))
            and script.Name:lower():find(query, 1, true)
        then
            local okNew, object = pcall(LocalScript.new, script)
            if okNew and object then
                scripts[script] = object
            else
                scripts[script] = { Instance = script, Constants = {}, Protos = {} }
            end
        end
    end

    return scripts
end

ScriptScanner.RequiredMethods = requiredMethods
ScriptScanner.Scan = scan
return ScriptScanner
