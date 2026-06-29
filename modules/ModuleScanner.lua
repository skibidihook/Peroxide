local ModuleScanner = {}
local ModuleScript = import("objects/ModuleScript")

local requiredMethods = {
    ["getMenv"] = true,
    ["getProtos"] = true,
    ["getConstants"] = true,
    ["getScriptClosure"] = true,
    ["getLoadedModules"] = true
}

local function scan(query)
    local modules = {}
    query = (query or ""):lower()

    local function consider(module)
        if typeof(module) == "Instance"
            and not modules[module]
            and module:IsA("ModuleScript")
            and module.Name:lower():find(query, 1, true)
        then
            local okNew, object = pcall(ModuleScript.new, module)
            if okNew and object then
                modules[module] = object
            else
                modules[module] = { Instance = module, Constants = {}, Protos = {} }
            end
        end
    end

    for _i, module in pairs(game:GetDescendants()) do
        consider(module)
    end

    if getnilinstances then
        for _i, instance in pairs(getnilinstances()) do
            consider(instance)
        end
    end

    if getLoadedModules then
        for _i, module in pairs(getLoadedModules()) do
            consider(module)
        end
    end

    return modules
end

ModuleScanner.Scan = scan
ModuleScanner.RequiredMethods = requiredMethods
return ModuleScanner