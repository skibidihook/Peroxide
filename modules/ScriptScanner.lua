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

    for _i, value in pairs(getGc()) do
        if type(value) == "function" and isLClosure(value) and not isXClosure(value) then
            local ok, env = pcall(getfenv, value)
            local script = ok and rawget(env, "script")

            if typeof(script) == "Instance"
                and not scripts[script]
                and script:IsA("LocalScript")
                and script.Name:lower():find(query)
            then
                local okNew, object = pcall(LocalScript.new, script)
                if okNew and object then
                    scripts[script] = object
                end
            end
        end
    end

    return scripts
end

ScriptScanner.RequiredMethods = requiredMethods
ScriptScanner.Scan = scan
return ScriptScanner
