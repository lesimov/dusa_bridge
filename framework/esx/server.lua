module 'shared/debug'
module 'shared/resource'
module 'shared/table'
module 'shared/utils'
module 'shared/player'

ESX = nil
Version = resource.version(Bridge.FrameworkName)

-- Flag to track if gang support is available
local GangsEnabled = false

IsExport, ESX = pcall(function()
    return exports[Bridge.FrameworkName]:getSharedObject()
end)

if not IsExport then
    TriggerEvent(Bridge.FrameworkEvent, function(obj) ESX = obj end)
end

Bridge.Debug('Framework', 'ESX', Version)

local clientRequests = {}
TriggerClientCallback = function(source, name, callback, ...)
    local id = #clientRequests + 1
    clientRequests[id] = callback
    TriggerClientEvent(Bridge.Resource .. ':TriggerClientCallback', source, name, id, ...)
end

RegisterNetEvent(Bridge.Resource .. ':ClientCallback', function(requestId, ...)
    if clientRequests[requestId] then
        clientRequests[requestId](...)
        clientRequests[requestId] = nil
    end
end)

AddEventHandler(Bridge.FrameworkPrefix .. ':playerLoaded', function(playerId, xPlayer)
    -- Only query gang data if gangs are enabled
    local player = nil
    local gang = 'none'
    local grade = '0'
    
    if GangsEnabled then
        local success, result = pcall(Database.prepare, 'SELECT `gang`, `gang_grade`, `metadata` FROM `users` WHERE identifier = ?',
            { xPlayer.getIdentifier() })
        if success and result then
            player = result
            gang = player.gang or 'none'
            grade = tostring(player.gang_grade or 0)
        end
    else
        -- Query only metadata if gangs are not enabled
        local success, result = pcall(Database.prepare, 'SELECT `metadata` FROM `users` WHERE identifier = ?',
            { xPlayer.getIdentifier() })
        if success and result then
            player = result
        end
    end
    
    local gangObject = {}
    local gradeObject = {}

    -- Only process gang data if gangs are enabled and ESX.Gangs exists
    if GangsEnabled and ESX.Gangs then
        if Framework.DoesGangExist(gang, grade) then
            gangObject, gradeObject = ESX.Gangs[gang], ESX.Gangs[gang].grades[grade]
        else
            if Bridge.DebugMode then print(('[^3WARNING^7] Ignoring invalid gang for ^5%s^7 [gang: ^5%s^7, grade: ^5%s^7]')
                :format(xPlayer.getIdentifier(), gang, grade)) end
            gang, grade = 'none', '0'
            if ESX.Gangs['none'] then
                gangObject, gradeObject = ESX.Gangs['none'], ESX.Gangs['none'].grades['0']
            end
        end
    end

    -- Build gang data with defaults if gangs are not enabled
    local gangData = {}
    gangData.name = gangObject.name or 'none'
    gangData.label = gangObject.label or 'No Gang Affiliation'
    gangData.grade = tonumber(grade) or 0
    gangData.grade_name = gradeObject.name or 'none'
    gangData.grade_label = gradeObject.label or 'None'

    xPlayer.triggerEvent(Bridge.FrameworkPrefix .. ':setGang', gangData)
    xPlayer.set('gang', gangData)

    xPlayer.triggerEvent(Bridge.FrameworkPrefix .. ':setDuty', false)
    xPlayer.set('duty', false)

    local metadata = pcall(xPlayer.getMeta)
    if not metadata and player and player.metadata then
        xPlayer.triggerEvent(Bridge.FrameworkPrefix .. ':setMetadata', json.decode(player.metadata))
        xPlayer.set('metadata', json.decode(player.metadata))
    end

    pcall(Framework.OnPlayerLoaded, xPlayer.source)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        local metadata = pcall(xPlayer.getMeta)
        if not metadata then
            Database.prepare('UPDATE `users` SET `metadata` = ? WHERE `identifier` = ?',
                { json.encode(xPlayer.get('metadata')), xPlayer.getIdentifier() })
        end
    end
    TriggerClientEvent(Bridge.FrameworkPrefix .. ':playerLogout', src)
    pcall(Framework.OnPlayerUnload, src)
end)

AddEventHandler(Bridge.FrameworkPrefix .. ':playerLogout', function(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        local metadata = pcall(xPlayer.getMeta)
        if not metadata then
            Database.prepare('UPDATE `users` SET `metadata` = ? WHERE `identifier` = ?',
                { json.encode(xPlayer.get('metadata')), xPlayer.getIdentifier() })
        end
    end
    pcall(Framework.OnPlayerUnload, playerId)
end)

AddEventHandler(Bridge.FrameworkPrefix .. ':setJob', function()
    pcall(Framework.OnJobUpdate, source)
end)


AddEventHandler(Bridge.FrameworkPrefix .. ':setDuty', function(bool)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer.get('duty') == bool then return end
    xPlayer.set('duty', bool)
    TriggerClientEvent(Bridge.FrameworkPrefix .. ':setDuty', xPlayer.source, bool)
    pcall(Framework.OnJobDutyUpdate, xPlayer.source)
end)

AddEventHandler(Bridge.FrameworkPrefix .. ':setGang', function()
    pcall(Framework.OnGangUpdate, source)
end)

AddEventHandler(Bridge.FrameworkPrefix .. ':updatePlayerData', function()
    pcall(Framework.OnGangUpdate, source)
end)

Framework.CreateCallback = function(name, cb)
    ESX.RegisterServerCallback(name, cb)
end

Framework.TriggerCallback = function(source, name, cb, ...)
    local success = pcall(ESX.TriggerClientCallback, source, name, cb, ...)
    if not success then
        TriggerClientCallback(source, name, cb, ...)
    end
end

Framework.CreateUseableItem = function(name, cb)
    ESX.RegisterUsableItem(name, cb)
end

Framework.GetPlayerFromId = function(source)
    return ESX.GetPlayerFromId(source)
end

Framework.GetPlayer = function(source)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return nil end
    local self = table.deepclone(Framework.Player)
    ---@cast self Player
    local PlayerJob = xPlayer.getJob()
    local PlayerGang = xPlayer.get('gang')
    self.source = xPlayer.source
    self.Identifier = xPlayer.getIdentifier()
    self.Name = GetPlayerName(src)
    self.Firstname = xPlayer.get('firstName')
    self.Lastname = xPlayer.get('lastName')
    self.DateOfBirth = xPlayer.get('dateofbirth') or '01/01/2000'
    self.Gender = xPlayer.get("sex") or "m"
    self.Height = xPlayer.get("height") or 185
    self.Job.Name = PlayerJob.name
    self.Job.Label = PlayerJob.label
    self.Job.Duty = xPlayer.get('duty')
    self.Job.Boss = PlayerJob.grade_name == 'boss' and true or false
    self.Job.Grade.Name = PlayerJob.grade_label
    self.Job.Grade.Level = PlayerJob.grade
    -- self.Gang.Name = PlayerGang.name
    -- self.Gang.Label = PlayerGang.label
    -- self.Gang.Boss = PlayerGang.grade_name == 'boss' and true or false
    -- self.Gang.Grade.Name = PlayerGang.grade_label
    -- self.Gang.Grade.Level = PlayerGang.grade
    local getmeta, metadata = pcall(xPlayer.getMeta)
    self.Metadata = (getmeta and metadata or xPlayer.get('metadata'))

    self.SetJob = function(job, grade)
        if not ESX.DoesJobExist(job, grade) then return false end
        xPlayer.setJob(job, grade)
        return true
    end

    self.SetGang = function(gang, grade)
        -- If gangs are not enabled, return false gracefully
        if not GangsEnabled then
            if Bridge.DebugMode then print('[^3WARNING^7] Gang system is not enabled on this server') end
            return false
        end
        
        grade = tostring(grade)
        if not Framework.DoesGangExist(gang, grade) then return false end
        local gangObject, gradeObject = ESX.Gangs[gang], ESX.Gangs[gang].grades[grade]
        local gangData = {}
        gangData.name = gangObject.name
        gangData.label = gangObject.label
        gangData.grade = tonumber(grade)
        gangData.grade_name = gradeObject.name
        gangData.grade_label = gradeObject.label
        xPlayer.set('gang', gangData)
        TriggerEvent(Bridge.FrameworkPrefix .. ':setGang', xPlayer.source, gangData)
        xPlayer.triggerEvent(Bridge.FrameworkPrefix .. ':setGang', gangData)
        Database.prepare('UPDATE `users` SET gang = ?, gang_grade = ? WHERE identifier = ?',
            { gang, grade, self.Identifier })
        return true
    end

    self.AddMoney = function(type, amount)
        if type == 'cash' then type = 'money' end
        local current = self.GetMoney(type)
        xPlayer.addAccountMoney(type, amount)
        return self.GetMoney(type) == current + amount
    end

    self.RemoveMoney = function(type, amount)
        if type == 'cash' then type = 'money' end
        local current = self.GetMoney(type)
        if current < amount then return false end
        xPlayer.removeAccountMoney(type, amount)
        return self.GetMoney(type) == current - amount
    end

    self.GetMoney = function(type)
        if type == 'cash' then type = 'money' end
        return xPlayer.getAccount(type)?.money
    end

    self.GetStatus = function(key)
        local p = promise.new()
        TriggerEvent('esx_status:getStatus', src, key, function(status)
            p:resolve(Framework.Round(status.percent, 0))
        end)
        return Citizen.Await(p)
    end

    self.SetStatus = function(key, value)
        TriggerClientEvent("esx_status:set", src, key, (value * 10000))
    end

    self.GetMetaData = function(key)
        if not key then
            local success, result = pcall(xPlayer.getMeta)
            if success then return result end
            if not success then return xPlayer.get('metadata') end
        else
            local success, result = pcall(xPlayer.getMeta, key)
            if success then return result end
            if not success then return xPlayer.get('metadata')[key] end
        end
    end

    self.SetMetaData = function(key, value)
        local success, result = pcall(xPlayer.setMeta, key, value)
        if not success then
            -- esx 1.10.7
            local metadata = xPlayer.get('metadata') or {}
            metadata[key] = value
            xPlayer.set('metadata', metadata)
            xPlayer.triggerEvent(Bridge.FrameworkPrefix .. ':setMetadata', metadata)
        end
    end

    self.HasLicense = function(name)
        return (Database.scalar('SELECT 1 FROM `user_licenses` WHERE `type` = ? AND `owner` = ?', { name, self.Identifier }) ~= nil)
    end

    self.GetLicenses = function()
        local p = promise.new()
        Database.query('SELECT `type` FROM `user_licenses` WHERE `owner` = ?', { self.Identifier }, function(result)
            local licenses = {}
            for i = 1, #result do
                licenses[result[i].type] = true
            end
            p:resolve(licenses)
        end)
        return Citizen.Await(p)
    end

    self.AddLicense = function(name)
        TriggerEvent('esx_license:addLicense', src, name)
    end

    self.RemoveLicense = function(name)
        Database.prepare('DELETE FROM `user_licenses` WHERE `type` = ? AND `owner` = ?', { name, self.Identifier })
    end

    return self
end

Framework.GetPlayers = function ()
    return ESX.GetExtendedPlayers()
end

Framework.GetPlayerByIdentifier = function(identifier)
    return Framework.GetPlayer(ESX.GetPlayerFromIdentifier(identifier)?.source)
end

Framework.DoesJobExist = function(job, grade)
    return ESX.DoesJobExist(job, grade)
end

Framework.GetOfflinePlayerByIdentifier = function(identifier)
    if not identifier then return nil end

    local PlayerData = MySQL.prepare.await('SELECT identifier, firstname, lastname, dateofbirth, sex, height, job, job_grade, metadata FROM users where identifier = ?', { identifier })
    if not PlayerData then return nil end

    local self = table.deepclone(Framework.Player)
    ---@cast self Player
    if not PlayerData then return nil end

    local job = Framework.GetJob(PlayerData.job)
    
    local grades = {}

    for key, grade in pairs(job.grades) do
        grades[tonumber(key)] = {
            id = tonumber(key),
            label = grade.name,
            isboss = grade.name == 'boss' and true or false
        }
    end

    self.Identifier = PlayerData.identifier
    self.Firstname = PlayerData.firstname
    self.Lastname = PlayerData.lastname
    self.DateOfBirth = PlayerData.dateofbirth or '01/01/2000'
    self.Gender = PlayerData.sex or "m"
    self.Height = PlayerData.height or 185
    self.Job.Name = PlayerData.job
    self.Job.Label = job.label
    self.Job.Duty = false
    self.Job.Boss = grades[PlayerData.job_grade].isboss
    self.Job.Grade.Name = grades[PlayerData.job_grade].label
    self.Job.Grade.Level = PlayerData.job_grade
    self.Metadata = PlayerData.metadata

    self.SetJob = function (job, grade)
        return MySQL.prepare('UPDATE `users` SET `job` = ?, `job_grade` = ? WHERE `identifier` = ?', { job, grade, self.Identifier })
    end

    return self
end

Framework.GetJob = function(job)
    local jobs = ESX.GetJobs()
    local data = {}
    for _, v in pairs(jobs) do
        if v.name == job then
            data.label = v.label
            data.defaultDuty = true
            data.offDutyPay = false
            data.grades = {}

            for grade, value in pairs(v.grades) do
                data.grades[tostring(grade)] = {
                    name = value.label,
                    payment = value.salary,
                    isboss = value.name == 'boss' and true or false
                }
            end
        end
    end
    return data
end

Framework.GetJobs = function()
    return ESX.GetJobs()
end

Framework.DoesGangExist = function(gang, grade)
    -- If gangs are not enabled, always return false
    if not GangsEnabled or not ESX.Gangs then
        return false
    end
    
    grade = tostring(grade)
    if gang and grade then
        if ESX.Gangs[gang] and ESX.Gangs[gang].grades[grade] then
            return true
        else
            return false
        end
    end
    return false
end

-- Check if gang system is enabled on this server
Framework.IsGangSystemEnabled = function()
    return GangsEnabled
end

Framework.RegisterSociety = function(name, type)
    if type ~= 'job' and type ~= 'gang' then
        error('Society Type Must Be Job Or Gang', 0)
        return
    end
    local society_data_name = ('society_%s'):format(name)

    Database.scalar('SELECT `name` FROM `addon_account` WHERE `name` = ?', { society_data_name }, function(addon_account)
        if not addon_account then
            Database.insert('INSERT IGNORE INTO `addon_account` (`name`, `label`, `shared`) VALUES (?, ?, ?)',
                { society_data_name, Framework.FirstToUpper(name), 1 })
        end
    end)

    Database.scalar('SELECT `account_name` FROM `addon_account_data` WHERE `account_name` = ?', { society_data_name },
        function(addon_account_data)
            if not addon_account_data then
                Database.insert('INSERT IGNORE INTO `addon_account_data` (`account_name`, `money`) VALUES (?, ?)',
                    { society_data_name, 0 })
            end
        end)

    TriggerEvent('esx_addonaccount:refreshAccounts')
    TriggerEvent('esx_society:registerSociety', name, Framework.FirstToUpper(name), society_data_name, society_data_name,
        society_data_name, { type = 'public' })
end

Framework.SocietyGetMoney = function(name, type)
    if type ~= 'job' and type ~= 'gang' then
        error('Society Type Must Be Job Or Gang', 0)
        return 0
    end
    local p = promise.new()
    local society_name = ('society_%s'):format(name)
    TriggerEvent('esx_addonaccount:getSharedAccount', society_name, function(account)
        p:resolve(account.money)
    end)
    return Citizen.Await(p)
end

Framework.SocietyAddMoney = function(name, type, amount)
    if type ~= 'job' and type ~= 'gang' then
        error('Society Type Must Be Job Or Gang', 0)
        return false
    end
    local p = promise.new()
    local society_name = ('society_%s'):format(name)
    TriggerEvent('esx_addonaccount:getSharedAccount', society_name, function(account)
        if account and amount > 0 then
            account.addMoney(amount)
            p:resolve(true)
        else
            p:resolve(false)
        end
    end)
    return Citizen.Await(p)
end

Framework.SocietyRemoveMoney = function(name, type, amount)
    if type ~= 'job' and type ~= 'gang' then
        error('Society Type Must Be Job Or Gang', 0)
        return false
    end
    local p = promise.new()
    local society_name = ('society_%s'):format(name)
    TriggerEvent('esx_addonaccount:getSharedAccount', society_name, function(account)
        if account and amount > 0 and account.money >= amount then
            account.removeMoney(amount)
            p:resolve(true)
        else
            p:resolve(false)
        end
    end)
    return Citizen.Await(p)
end

Framework.Notify = function(source, message, type, length)
    TriggerClientEvent(Bridge.FrameworkPrefix .. ':showNotification', source, message, type, length)
end

Framework.IsPlayerDead = function(source)
    local p = promise.new()
    Framework.TriggerCallback(source, Bridge.Resource .. ':bridge:IsPlayerDead', function(isDead)
        p:resolve(isDead)
    end)
    return Citizen.Await(p)
end

Citizen.CreateThreadNow(function()
    ESX.Gangs = {}
    
    -- Check if gang support exists by testing for gang column in users table
    local gangColumnExists = pcall(Database.scalar, 'SELECT gang FROM users LIMIT 1')
    local gangTableExists = pcall(Database.scalar, 'SELECT 1 FROM gangs LIMIT 1')
    local gangGradesTableExists = pcall(Database.scalar, 'SELECT 1 FROM gang_grades LIMIT 1')
    
    -- Gang support is enabled only if the gang column exists in users table
    -- and the gangs/gang_grades tables exist
    if gangColumnExists and gangTableExists and gangGradesTableExists then
        GangsEnabled = true
        
        -- Load gangs from database
        local success, gangs = pcall(Database.query, 'SELECT * FROM gangs')
        if success and gangs then
            for _, v in ipairs(gangs) do
                ESX.Gangs[v.name] = v
                ESX.Gangs[v.name].grades = {}
            end
        end

        -- Load gang grades from database
        local success, gang_grades = pcall(Database.query, 'SELECT * FROM gang_grades')
        if success and gang_grades then
            for _, v in ipairs(gang_grades) do
                if ESX.Gangs[v.gang_name] then
                    ESX.Gangs[v.gang_name].grades[tostring(v.grade)] = v
                else
                    if Bridge.DebugMode then print(('[^3WARNING^7] Ignoring gang grades for ^5"%s"^0 due to missing gang')
                        :format(v.gang_name)) end
                end
            end
        end

        -- Remove gangs without grades
        for _, v in pairs(ESX.Gangs) do
            if next(v.grades) == nil then
                ESX.Gangs[v.name] = nil
                if Bridge.DebugMode then print(('[^3WARNING^7] Ignoring gang ^5"%s"^0 due to no gang grades found'):format(v
                    .name)) end
            end
        end

        -- Add default 'none' gang
        ESX.Gangs['none'] = {
            name = 'none',
            label = 'No Gang Affiliation',
            grades = { ['0'] = { grade = 0, name = 'none', label = 'None' } }
        }
        
        if Bridge.DebugMode then print('[^2INFO^7] Gang system enabled - gang tables found') end
    else
        GangsEnabled = false
        -- Set up default 'none' gang even if gangs are disabled for compatibility
        ESX.Gangs['none'] = {
            name = 'none',
            label = 'No Gang Affiliation',
            grades = { ['0'] = { grade = 0, name = 'none', label = 'None' } }
        }
        if Bridge.DebugMode then print('[^3WARNING^7] Gang system disabled - gang tables not found (this is normal if your server does not use gangs)') end
    end

    local success, result = pcall(Database.scalar, 'SELECT metadata FROM users')
    if not success then
        Database.query("ALTER TABLE `users` ADD COLUMN `metadata` LONGTEXT NULL DEFAULT NULL AFTER loadout")
    end
end)
