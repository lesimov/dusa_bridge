if Bridge.Context and Bridge.Context == 'client' then return end

local resourceName = Bridge.Resource

CreateThread(function()
    Wait(5000) -- Wait for server to fully start
    PerformHttpRequest("https://raw.githubusercontent.com/Dusa-DD/versioncheck/refs/heads/main/"..resourceName, function(errorCode, resultData, resultHeaders)
        if errorCode ~= 200 then
            print("^1[ERROR] ^7Failed to check latest version of " .. resourceName)
            return
        end
        
        local latestVersion = tostring(resultData):gsub("\n", "")
        local currentVersion = GetResourceMetadata(resourceName, "version", 0)
        
        if currentVersion == latestVersion then
            print("^2[" .. resourceName .. "] ^7Version check: ^2LATEST^7")
            print("^2[" .. resourceName .. "] ^7Current version: ^2" .. currentVersion .. "^7")
            print("^2[" .. resourceName .. "] ^7Resource is up to date!^7")
        else
            print("^3[" .. resourceName .. "] ^7Version check: ^1OUTDATED^7")
            print("^3[" .. resourceName .. "] ^7Current version: ^1" .. currentVersion .. "^7 | Latest version: ^2" .. latestVersion .. "^7")
            print("^3[" .. resourceName .. "] ^7Please update to latest version from your ^3keymaster!^7")
        end
    end)
end)