module 'shared/debug'
module 'shared/resource'
module 'shared/table'
module 'shared/player'

QBCore = nil
Version = resource.version(Bridge.FrameworkName)

IsExport, QBCore = pcall(function()
    return exports[Bridge.FrameworkName]:GetCoreObject()
end)

if not IsExport then
    TriggerEvent(Bridge.FrameworkEvent, function(obj) QBCore = obj end)
end

Bridge.Debug('Framework', 'QBCore', Version)

RegisterNetEvent(Bridge.FrameworkPrefix .. ':Server:UpdateObject', function()
    if source ~= '' then return end
    QBCore = exports[Bridge.FrameworkName]:GetCoreObject()
    for k, v in pairs(QBCore.Shared.Items) do
        local item = {}
        if type(v) == 'string' then return end
        if not v.name then v.name = k end
        item.name = v.name
        item.label = v.label
        item.description = v.description
        item.stack = not v.unique and true
        item.weight = v.weight or 0
        item.close = v.shouldClose == nil and true or v.shouldClose
        item.type = v.type
        Framework.Items[v.name] = item
    end
end)

RegisterNetEvent(Bridge.FrameworkPrefix .. ':Server:OnPlayerLoaded', function()
    pcall(Framework.OnPlayerLoaded, source)
end)

RegisterNetEvent(Bridge.FrameworkPrefix .. ':Server:OnPlayerUnload', function()
    pcall(Framework.OnPlayerUnload, source)
end)

AddEventHandler('playerDropped', function()
    local src = source
    TriggerClientEvent(Bridge.FrameworkPrefix .. ':Client:OnPlayerUnload', src)
    pcall(Framework.OnPlayerUnload, src)
end)

RegisterNetEvent(Bridge.FrameworkPrefix .. ':Server:OnJobUpdate', function()
    pcall(Framework.OnJobUpdate, source)
end)
RegisterNetEvent(Bridge.FrameworkPrefix .. ':Server:SetDuty', function()
    pcall(Framework.OnJobDutyUpdate, source)
end)

RegisterNetEvent(Bridge.FrameworkPrefix .. ':Server:OnGangUpdate', function()
    pcall(Framework.OnGangUpdate, source)
end)

Framework.CreateCallback = function(name, cb)
    QBCore.Functions.CreateCallback(name, cb)
end

Framework.TriggerCallback = function(source, name, cb, ...)
    QBCore.Functions.TriggerClientCallback(name, source, cb, ...)
end

Framework.CreateUseableItem = function(name, cb)
    QBCore.Functions.CreateUseableItem(name, function(source, data)
        cb(source, data.name, { weight = data.weight, count = data.amount or data.count, slot = data.slot, name = data.name, metadata = data.info or data.metadata, label = data.label })
    end)
end

Framework.GetPlayerFromId = function(source)
    return QBCore.Functions.GetPlayer(source)
end

Framework.GetOfflinePlayerByIdentifier = function(citizenid)
    if not citizenid then return nil end

    local Player = QBCore.Functions.GetOfflinePlayerByCitizenId(citizenid)
    if not Player then return nil end

    local self = table.deepclone(Framework.Player)

    self.Identifier = Player.PlayerData.citizenid
    self.Name = Player.PlayerData.name
    self.Firstname = Player.PlayerData.charinfo.firstname
    self.Lastname = Player.PlayerData.charinfo.lastname
    self.DateOfBirth = Player.PlayerData.charinfo.birthdate or '00-00-0000'
    self.Gender = (Player.PlayerData.charinfo.gender == 0 and 'm' or 'f')
    self.Nationality = Player.PlayerData.charinfo.nationality
    self.Job.Name = Player.PlayerData.job.name
    self.Job.Label = Player.PlayerData.job.label
    self.Job.Duty = Player.PlayerData.job.onduty
    self.Job.Boss = Player.PlayerData.job.isboss
    self.Job.Grade.Name = Player.PlayerData.job.grade.name
    self.Job.Grade.Level = Player.PlayerData.job.grade.level
    self.Metadata = Player.PlayerData.metadata

    self.SetJob = function(job, grade)
        job = job:lower()
        grade = grade or '0'
        if not QBCore.Shared.Jobs[job] then return false end
        self.Job = {
            name = job,
            label = QBCore.Shared.Jobs[job].label,
            onduty = QBCore.Shared.Jobs[job].defaultDuty,
            type = QBCore.Shared.Jobs[job].type or 'none',
            grade = {
                name = 'No Grades',
                level = 0,
                payment = 30,
                isboss = false
            }
        }
        local gradeKey = tostring(grade)
        local jobGradeInfo = QBCore.Shared.Jobs[job].grades[gradeKey]
        if jobGradeInfo then
            self.Job.Grade.Name = jobGradeInfo.name
            self.PlayerData.job.grade.level = tonumber(gradeKey)
            self.PlayerData.job.grade.payment = jobGradeInfo.payment
            self.PlayerData.job.grade.isboss = jobGradeInfo.isboss or false
            self.PlayerData.job.isboss = jobGradeInfo.isboss or false
        end
        
        return true
    end

    return self
end

Framework.GetPlayer = function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local self = table.deepclone(Framework.Player)
    self.source = Player.PlayerData.source
    self.Identifier = Player.PlayerData.citizenid
    self.Name = Player.PlayerData.name
    self.Firstname = Player.PlayerData.charinfo.firstname
    self.Lastname = Player.PlayerData.charinfo.lastname
    self.DateOfBirth = Player.PlayerData.charinfo.birthdate or '00-00-0000'
    self.Gender = (Player.PlayerData.charinfo.gender == 0 and 'm' or 'f')
    self.Nationality = Player.PlayerData.charinfo.nationality
    self.Job.Name = Player.PlayerData.job.name
    self.Job.Label = Player.PlayerData.job.label
    self.Job.Duty = Player.PlayerData.job.onduty
    self.Job.Boss = Player.PlayerData.job.isboss
    self.Job.Grade.Name = Player.PlayerData.job.grade.name
    self.Job.Grade.Level = Player.PlayerData.job.grade.level

    local isGangEnabled = (Player.PlayerData.gang and next(Player.PlayerData.gang))
    if isGangEnabled then
        self.Gang.Name = Player.PlayerData.gang.name
        self.Gang.Label = Player.PlayerData.gang.label
        self.Gang.Boss = Player.PlayerData.gang.isboss
        self.Gang.Grade.Name = Player.PlayerData.gang.grade.name
        self.Gang.Grade.Level = Player.PlayerData.gang.grade.level
    end
    self.Metadata = Player.PlayerData.metadata

    self.SetJob = function(job, grade)
        return Player.Functions.SetJob(job, grade)
    end

    self.SetGang = function(gang, grade)
        return Player.Functions.SetGang(gang, grade)
    end

    self.AddMoney = function(type, amount)
        return Player.Functions.AddMoney(type, amount)
    end

    self.RemoveMoney = function(type, amount)
        return Player.Functions.RemoveMoney(type, amount)
    end

    self.GetMoney = function(type)
        return Player.Functions.GetMoney(type)
    end

    self.GetStatus = function(key)
        return Framework.Round(Player.PlayerData.metadata[key], 0)
    end

    self.SetStatus = function(key, value)
        Player.Functions.SetMetaData(key, value)
    end

    self.GetMetaData = function(key)
        if not key then return Player.PlayerData.metadata end
        return Player.Functions.GetMetaData(key)
    end

    self.SetMetaData = function(key, value)
        Player.Functions.SetMetaData(key, value)
    end

    self.HasLicense = function(name)
        return Player.PlayerData.metadata['licences'][name] or false
    end

    self.GetLicenses = function()
        return Player.PlayerData.metadata['licences']
    end

    self.AddLicense = function(name)
        local licences = Player.PlayerData.metadata['licences']
        licences[name] = true
        Player.Functions.SetMetaData("licences", licences)
    end

    self.RemoveLicense = function(name)
        local licences = Player.PlayerData.metadata['licences']
        if licences[name] then
            licences[name] = false
            Player.Functions.SetMetaData("licences", licences)
        end
    end

    return self
end

Framework.GetPlayers = function ()
    return QBCore.Functions.GetQBPlayers()
end

Framework.GetPlayerByIdentifier = function(identifier)
    return Framework.GetPlayer(QBCore.Functions.GetPlayerByCitizenId(identifier)?.PlayerData?.source)
end

local function decodeObject(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or {}
end

Framework.GetPlayersByJob = function(jobName)
    if type(jobName) ~= 'string' or jobName == '' then return {} end

    local rows = Database.query([[
        SELECT `citizenid`, `name`, `charinfo`, `job`
        FROM `players`
        WHERE JSON_UNQUOTE(JSON_EXTRACT(`job`, '$.name')) = ?
    ]], { jobName }) or {}
    local employees = {}
    local jobDefinition = QBCore.Shared.Jobs[jobName] or {}

    for i = 1, #rows do
        local row = rows[i]
        local charinfo = decodeObject(row.charinfo)
        local job = decodeObject(row.job)
        local grade = job.grade or {}
        local level = tonumber(grade.level) or 0
        local gradeDefinition = (jobDefinition.grades or {})[tostring(level)]
            or (jobDefinition.grades or {})[level] or {}
        local firstname = charinfo.firstname or ''
        local lastname = charinfo.lastname or ''
        local employee = {
            Identifier = row.citizenid,
            Name = row.name or (firstname .. ' ' .. lastname),
            Firstname = firstname,
            Lastname = lastname,
            Job = {
                Name = jobName,
                Label = job.label or jobDefinition.label or jobName,
                Duty = false,
                Boss = job.isboss == true or grade.isboss == true or gradeDefinition.isboss == true,
                Grade = {
                    Name = grade.name or gradeDefinition.name or tostring(level),
                    Level = level
                }
            }
        }

        local online = QBCore.Functions.GetPlayerByCitizenId(row.citizenid)
        if online then
            employee.source = online.PlayerData.source
            local player = Framework.GetPlayer(employee.source)
            if player then
                employee.Name = player.Name or employee.Name
                employee.Firstname = player.Firstname or employee.Firstname
                employee.Lastname = player.Lastname or employee.Lastname
                employee.Job = player.Job
            end
        end

        employees[#employees + 1] = employee
    end

    return employees
end

Framework.GetOwnedVehicles = function(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return {} end

    local rows = Database.query([[
        SELECT `id`, `plate`, `vehicle`, `mods`
        FROM `player_vehicles`
        WHERE `citizenid` = ?
    ]], { identifier }) or {}
    local vehicles = {}

    for i = 1, #rows do
        local row = rows[i]
        local properties = decodeObject(row.mods)
        vehicles[#vehicles + 1] = {
            id = row.id or row.plate,
            plate = row.plate,
            model = row.vehicle or properties.model,
            properties = properties,
            type = 'automobile'
        }
    end

    return vehicles
end

Framework.DoesJobExist = function(job, grade)
    grade = tostring(grade)
    if job and grade then
        if QBCore.Shared.Jobs[job] and QBCore.Shared.Jobs[job].grades[grade] then
            return true
        else
            return false
        end
    end
    return false
end

Framework.GetJob = function(job)
    return job and QBCore.Shared.Jobs[job] or false
end

Framework.GetJobs = function()
    return QBCore.Shared.Jobs
end

Framework.DoesGangExist = function(gang, grade)
    grade = tostring(grade)
    if gang and grade then
        if QBCore.Shared.Gangs[gang] and QBCore.Shared.Gangs[gang].grades[grade] then
            return true
        else
            return false
        end
    end
    return false
end

Framework.RegisterSociety = function(name, type)
    if type ~= 'job' and type ~= 'gang' then error('Society Type Must Be Job Or Gang', 0) return end

    if Bridge.SocietyBanking == 'qb-banking' then
        local ok, account = pcall(function() return exports['qb-banking']:GetAccount(name) end)
        if ok and not account then
            pcall(function()
                if type == 'gang' then
                    exports['qb-banking']:CreateGangAccount(name, 0)
                else
                    exports['qb-banking']:CreateJobAccount(name, 0)
                end
            end)
        end
        return
    end

    if Bridge.SocietyBanking ~= 'qb-management' and Bridge.SocietyBanking ~= 'qbx_management' then return end
    local accountType = type == 'job' and 'boss' or 'gang'
    local managementFunds = Database.scalar('SELECT `job_name` FROM `management_funds` WHERE `job_name` = ?', { name })
    if not managementFunds then
        Database.insert('INSERT INTO `management_funds` (`job_name`, `amount`, `type`) VALUES (?, ?, ?)',
            { name, 0, accountType })
    end
end

Framework.SocietyGetMoney = function(name, type)
    if type ~= 'job' and type ~= 'gang' then error('Society Type Must Be Job Or Gang', 0) return 0 end
    return Bridge.SocietyBankingGetMoney(name, type)
end

Framework.SocietyAddMoney = function(name, type, amount)
    if type ~= 'job' and type ~= 'gang' then error('Society Type Must Be Job Or Gang', 0) return false end
    return Bridge.SocietyBankingAddMoney(name, type, amount)
end

Framework.SocietyRemoveMoney = function(name, type, amount)
    if type ~= 'job' and type ~= 'gang' then error('Society Type Must Be Job Or Gang', 0) return false end
    return Bridge.SocietyBankingRemoveMoney(name, type, amount)
end

Framework.Notify = function(source, message, type, length)
    if type == "info" then type = 'primary' end
    TriggerClientEvent(Bridge.FrameworkPrefix .. ':Notify', source, message, type, length)
end

Framework.IsPlayerDead = function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    return (Player.PlayerData.metadata['isdead'] or Player.PlayerData.metadata['inlaststand'])
end

-- Returns true if the plate exists in the framework's owned-vehicles table.
-- Used by consumer resources (e.g. dusa_mechanic) to skip persistence for
-- admin /car spawns and other unowned entities. Errors fall back to true so
-- transient DB issues never silently drop player data.
Framework.IsVehicleOwned = function(plate)
    if type(plate) ~= 'string' or plate == '' then return false end
    local norm = plate:gsub('%s+', ''):upper()
    local ok, result = pcall(Database.scalar, [[
        SELECT 1 FROM player_vehicles
        WHERE UPPER(REPLACE(plate, ' ', '')) = ?
        LIMIT 1
    ]], { norm })
    if not ok then
        Bridge.Debug('Framework', 'IsVehicleOwned query failed', tostring(result))
        return true
    end
    return result ~= nil
end