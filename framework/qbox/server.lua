module 'shared/debug'
module 'shared/resource'
module 'shared/table'
module 'shared/player'

QBX = nil
Version = resource.version(Bridge.FrameworkName)

if not rawget(_G, "lib") then include('ox_lib', 'init') end
include(Bridge.FrameworkName, 'modules/playerdata')
include(Bridge.FrameworkName, 'modules/lib')

Bridge.Debug('Framework', 'QBox', Version)

AddStateBagChangeHandler('isLoggedIn', nil, function(player, _, value)
    local source = tonumber(player:gsub('player:', ''), 10)
    if not source then return end
    if value then
        pcall(Framework.OnPlayerLoaded, source)
    else
        pcall(Framework.OnPlayerUnload, source)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    TriggerClientEvent('QBX:Player:Dropped', src)
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

local function UnpackCallback(arguments, i)
    if not arguments then return end
    local index = i or 1

    if index <= #arguments then
        return arguments[index], UnpackCallback(arguments, index + 1)
    end
end

Framework.CreateCallback = function(name, cb)
    lib.callback.register(name, function(source, ...)
        local p = promise.new()
        cb(source, function(...) p:resolve({...}) end, ...)
        return UnpackCallback(Citizen.Await(p))
    end)
end

Framework.TriggerCallback = function(source, name, cb, ...)
    lib.callback(name, source, cb, ...)
end

Framework.CreateUseableItem = function(name, cb)
    exports.qbx_core:CreateUseableItem(name, function(source, data)
        cb(source, data.name, { weight = data.weight, count = data.amount, slot = data.slot, name = data.name, metadata = data.info or data.metadata, label = data.label })
    end)
end

Framework.GetPlayerFromId = function(source)
    return exports[Bridge.FrameworkName]:GetPlayer(source)
end

Framework.GetOfflinePlayerByIdentifier = function(citizenid)
    if not citizenid then return nil end

    local Player = exports.qbx_core:GetOfflinePlayer(citizenid)
    if not Player then return nil end

    local self = table.deepclone(Framework.Player)

    self.Identifier = Player.PlayerData.citizenid
    self.Name = Player.PlayerData.name
    self.Firstname = Player.PlayerData.charinfo.firstname
    self.Lastname = Player.PlayerData.charinfo.lastname
    self.Phone = Player.PlayerData.charinfo.phone
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
        return exports.qbx_core:SetJob(self.Identifier, job, grade)
    end

    return self
end

Framework.GetPlayer = function(source)
    local src = source
    local Player = exports[Bridge.FrameworkName]:GetPlayer(src)
    if not Player then return nil end
    local self = table.deepclone(Framework.Player)
    self.source = Player.PlayerData.source
    self.Identifier = Player.PlayerData.citizenid
    self.Name = Player.PlayerData.name
    self.Firstname = Player.PlayerData.charinfo.firstname
    self.Lastname = Player.PlayerData.charinfo.lastname
    self.Phone = Player.PlayerData.charinfo.phone
    self.DateOfBirth = Player.PlayerData.charinfo.birthdate or '00-00-0000'
    self.Gender = (Player.PlayerData.charinfo.gender == 0 and 'm' or 'f')
    self.Nationality = Player.PlayerData.charinfo.nationality
    self.Job.Name = Player.PlayerData.job.name
    self.Job.Label = Player.PlayerData.job.label
    self.Job.Duty = Player.PlayerData.job.onduty
    self.Job.Boss = Player.PlayerData.job.isboss
    self.Job.Grade.Name = Player.PlayerData.job.grade.name
    self.Job.Grade.Level = Player.PlayerData.job.grade.level
    self.Gang.Name = Player.PlayerData.gang.name
    self.Gang.Label = Player.PlayerData.gang.label
    self.Gang.Boss = Player.PlayerData.gang.isboss
    self.Gang.Grade.Name = Player.PlayerData.gang.grade.name
    self.Gang.Grade.Level = Player.PlayerData.gang.grade.level
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
    return exports.qbx_core:GetQBPlayers()
end

Framework.GetPlayerByIdentifier = function(identifier)
    return Framework.GetPlayer(exports[Bridge.FrameworkName]:GetPlayerByCitizenId(identifier)?.PlayerData?.source)
end

Framework.CreditReady = function()
    local ok, ready, reason = pcall(function()
        return exports[Bridge.FrameworkName]:CreditReady()
    end)

    if not ok then return false, 'provider_unavailable' end
    if ready ~= true then return false, reason or 'provider_not_ready' end
    return true
end

Framework.CreditOnce = function(receiptId, identifier, account, amount)
    local ok, result = pcall(function()
        return exports[Bridge.FrameworkName]:CreditOnce(receiptId, identifier, account, amount)
    end)

    if not ok then
        return { status = 'unavailable', reason = 'provider_unavailable' }
    end
    if type(result) ~= 'table'
        or (result.status ~= 'paid'
            and result.status ~= 'pending'
            and result.status ~= 'conflict'
            and result.status ~= 'unavailable')
    then
        return { status = 'unavailable', reason = 'invalid_provider_response' }
    end

    return result
end

local function decodeObject(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end
    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or {}
end

local VEHICLE_REMOVAL_TABLE = 'dusa_bridge_qbox_vehicle_removals'
local VEHICLE_REMOVAL_SENTINEL = '__dusa_vehicle_removal_guard__'

local function normalizeVehiclePlate(plate)
    if type(plate) ~= 'string' then return nil end
    local normalized = plate:gsub('%s+', ''):upper()
    if normalized == '' or #normalized > 15 then return nil end
    return normalized
end

local function vehicleProviderReady()
    if GetResourceState('qbx_vehicles') ~= 'started' then
        return false, 'vehicle_provider_unavailable'
    end

    local ok, schema = pcall(Database.single, [[
        SELECT t.`ENGINE` AS `engine`,
               (SELECT COUNT(*)
                FROM information_schema.COLUMNS AS c
                WHERE c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = 'player_vehicles'
                  AND c.COLUMN_NAME IN ('id', 'citizenid', 'vehicle', 'hash', 'plate')) AS `required_columns`,
               (SELECT GROUP_CONCAT(s.COLUMN_NAME ORDER BY s.SEQ_IN_INDEX SEPARATOR ',')
                FROM information_schema.STATISTICS AS s
                WHERE s.TABLE_SCHEMA = DATABASE() AND s.TABLE_NAME = 'player_vehicles'
                  AND s.INDEX_NAME = 'PRIMARY' AND s.NON_UNIQUE = 0) AS `primary_columns`,
               (SELECT COALESCE(SUM(s.SUB_PART IS NOT NULL), 0)
                FROM information_schema.STATISTICS AS s
                WHERE s.TABLE_SCHEMA = DATABASE() AND s.TABLE_NAME = 'player_vehicles'
                  AND s.INDEX_NAME = 'PRIMARY' AND s.NON_UNIQUE = 0) AS `primary_prefix_parts`
        FROM information_schema.TABLES AS t
        WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = 'player_vehicles'
    ]], {})
    if not ok then return false, 'vehicle_ownership_schema_read_failed' end
    if not schema or tonumber(schema.required_columns) ~= 5 or schema.primary_columns ~= 'id'
        or tonumber(schema.primary_prefix_parts) ~= 0
    then
        return false, 'vehicle_ownership_schema_incompatible'
    end
    if schema.engine ~= 'InnoDB' then return false, 'vehicle_ownership_storage_not_transactional' end
    return true
end

local function initializeVehicleRemovalReceipts()
    local ok = pcall(Database.query, ([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `job_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
            `vehicle_id` bigint unsigned NOT NULL,
            `owner` varchar(50) COLLATE utf8mb4_bin NOT NULL,
            `plate` varchar(15) COLLATE utf8mb4_bin NOT NULL,
            `model` varchar(50) COLLATE utf8mb4_bin NOT NULL,
            `removed_at` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`job_id`),
            UNIQUE KEY `vehicle_id` (`vehicle_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]):format(VEHICLE_REMOVAL_TABLE), {})
    if not ok then return false, 'vehicle_removal_schema_create_failed' end

    ok = pcall(Database.query, ([[
        INSERT IGNORE INTO `%s` (`job_id`, `vehicle_id`, `owner`, `plate`, `model`)
        VALUES (?, 0, '', '', '')
    ]]):format(VEHICLE_REMOVAL_TABLE), { VEHICLE_REMOVAL_SENTINEL })
    if not ok then return false, 'vehicle_removal_guard_create_failed' end

    local schemaOk, schema = pcall(Database.single, [[
        SELECT `ENGINE` AS `engine`,
               (SELECT COUNT(*)
                FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'dusa_bridge_qbox_vehicle_removals') AS `column_count`
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'dusa_bridge_qbox_vehicle_removals'
    ]], {})
    if not schemaOk then return false, 'vehicle_removal_schema_read_failed' end
    if not schema or schema.engine ~= 'InnoDB' or tonumber(schema.column_count) ~= 6 then
        return false, 'vehicle_removal_schema_incompatible'
    end

    local columnsOk, rows = pcall(Database.query, [[
        SELECT COLUMN_NAME AS `name`, DATA_TYPE AS `data_type`, COLUMN_TYPE AS `column_type`,
               CHARACTER_MAXIMUM_LENGTH AS `maximum_length`, IS_NULLABLE AS `nullable`,
               COLLATION_NAME AS `collation`
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'dusa_bridge_qbox_vehicle_removals'
    ]], {})
    if not columnsOk or type(rows) ~= 'table' then
        return false, 'vehicle_removal_schema_read_failed'
    end
    local columns = {}
    for index = 1, #rows do columns[rows[index].name] = rows[index] end
    local function validColumn(name, dataType, maximumLength, collation, unsigned)
        local column = columns[name]
        if not column or column.data_type ~= dataType or column.nullable ~= 'NO'
            or (maximumLength and tonumber(column.maximum_length) ~= maximumLength)
            or (collation and column.collation ~= collation)
        then
            return false
        end
        local isUnsigned = (column.column_type or ''):lower():find('unsigned', 1, true) ~= nil
        return unsigned == nil or isUnsigned == unsigned
    end
    if not validColumn('job_id', 'varchar', 64, 'utf8mb4_bin')
        or not validColumn('vehicle_id', 'bigint', nil, nil, true)
        or not validColumn('owner', 'varchar', 50, 'utf8mb4_bin')
        or not validColumn('plate', 'varchar', 15, 'utf8mb4_bin')
        or not validColumn('model', 'varchar', 50, 'utf8mb4_bin')
        or not validColumn('removed_at', 'timestamp')
    then
        return false, 'vehicle_removal_schema_incompatible'
    end

    local indexesOk, indexes = pcall(Database.query, [[
        SELECT INDEX_NAME AS `name`, NON_UNIQUE AS `non_unique`,
               GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',') AS `columns`,
               SUM(SUB_PART IS NOT NULL) AS `prefix_parts`
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'dusa_bridge_qbox_vehicle_removals'
        GROUP BY INDEX_NAME, NON_UNIQUE
    ]], {})
    if not indexesOk or type(indexes) ~= 'table' then
        return false, 'vehicle_removal_schema_read_failed'
    end
    local primaryJob, uniqueVehicle = false, false
    for index = 1, #indexes do
        local definition = indexes[index]
        local exact = tonumber(definition.non_unique) == 0
            and tonumber(definition.prefix_parts) == 0
        if exact and definition.name == 'PRIMARY' and definition.columns == 'job_id' then
            primaryJob = true
        elseif exact and definition.columns == 'vehicle_id' then
            uniqueVehicle = true
        end
    end
    if not primaryJob or not uniqueVehicle then
        return false, 'vehicle_removal_schema_incompatible'
    end

    local guardOk, guard = pcall(Database.single, ([[
        SELECT `job_id`, `vehicle_id`, `owner`, `plate`, `model`
        FROM `%s`
        WHERE BINARY `job_id` = BINARY ?
    ]]):format(VEHICLE_REMOVAL_TABLE), { VEHICLE_REMOVAL_SENTINEL })
    if not guardOk then return false, 'vehicle_removal_guard_read_failed' end
    if not guard or tonumber(guard.vehicle_id) ~= 0 or guard.owner ~= ''
        or guard.plate ~= '' or guard.model ~= ''
    then
        return false, 'vehicle_removal_guard_incompatible'
    end
    return true
end

local function validVehicleOwnershipSnapshot(snapshot)
    if type(snapshot) ~= 'table' or snapshot.owned ~= true then return nil end
    local id = tonumber(snapshot.id)
    local plate = normalizeVehiclePlate(snapshot.plate)
    if not id or id % 1 ~= 0 or id <= 0
        or type(snapshot.owner) ~= 'string' or snapshot.owner == '' or #snapshot.owner > 50
        or not plate or plate ~= snapshot.plate
        or type(snapshot.model) ~= 'string' or snapshot.model == '' or #snapshot.model > 50
    then
        return nil
    end
    return {
        id = id,
        owner = snapshot.owner,
        plate = plate,
        model = snapshot.model,
    }
end

Framework.GetPlayersByJob = function(jobName)
    if type(jobName) ~= 'string' or jobName == '' then return {} end

    local members = exports.qbx_core:GetGroupMembers(jobName, 'job') or {}
    local jobDefinition = exports.qbx_core:GetJob(jobName) or {}
    local employees = {}

    for i = 1, #members do
        local member = members[i]
        local online = exports.qbx_core:GetPlayerByCitizenId(member.citizenid)
        local player = online or exports.qbx_core:GetOfflinePlayer(member.citizenid)
        local data = player and player.PlayerData

        if data then
            local charinfo = data.charinfo or {}
            local activeJob = data.job or {}
            local level = tonumber(member.grade) or 0
            local grade = (jobDefinition.grades or {})[level]
                or (jobDefinition.grades or {})[tostring(level)] or {}
            local firstname = charinfo.firstname or ''
            local lastname = charinfo.lastname or ''
            local employee = {
                Identifier = member.citizenid,
                Name = data.name or (firstname .. ' ' .. lastname),
                Firstname = firstname,
                Lastname = lastname,
                Phone = charinfo.phone,
                Job = {
                    Name = jobName,
                    Label = jobDefinition.label or jobName,
                    Duty = online ~= nil and activeJob.name == jobName and activeJob.onduty == true,
                    Boss = grade.isboss == true,
                    Grade = {
                        Name = grade.name or tostring(level),
                        Level = level
                    }
                }
            }

            if online then employee.source = data.source end
            employees[#employees + 1] = employee
        end
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

Framework.VehicleOwnershipReady = function(requireRemoval)
    local ready, reason = vehicleProviderReady()
    if not ready then return false, reason end
    if requireRemoval ~= true then return true end

    local ok, removalReady, removalReason = pcall(initializeVehicleRemovalReceipts)
    if not ok then return false, 'vehicle_removal_schema_unavailable' end
    if removalReady ~= true then return false, removalReason or 'vehicle_removal_schema_unavailable' end
    return true
end

Framework.GetVehicleOwnership = function(plate)
    local normalized = normalizeVehiclePlate(plate)
    if not normalized then return nil, 'invalid_vehicle_plate' end

    local ok, rows = pcall(Database.query, [[
        SELECT `id`, `citizenid`, `plate`, `vehicle`
        FROM `player_vehicles`
        WHERE BINARY UPPER(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                `plate`, ' ', ''), CHAR(9), ''), CHAR(10), ''),
                CHAR(11), ''), CHAR(12), ''), CHAR(13), '')
        ) = BINARY ?
        ORDER BY `id` ASC
        LIMIT 2
    ]], { normalized })
    if not ok or type(rows) ~= 'table' then return nil, 'vehicle_ownership_read_failed' end
    if #rows == 0 then return { owned = false } end
    if #rows ~= 1 then return nil, 'ambiguous_vehicle_plate' end

    local row = rows[1]
    local id = tonumber(row.id)
    local storedPlate = normalizeVehiclePlate(row.plate)
    if not id or id % 1 ~= 0 or id <= 0
        or type(row.citizenid) ~= 'string' or row.citizenid == '' or #row.citizenid > 50
        or storedPlate ~= normalized
        or type(row.vehicle) ~= 'string' or row.vehicle == '' or #row.vehicle > 50
    then
        return nil, 'vehicle_ownership_record_invalid'
    end

    return {
        owned = true,
        id = id,
        owner = row.citizenid,
        plate = storedPlate,
        model = row.vehicle,
    }
end

Framework.VehicleRemovalStatements = function(jobId, snapshot)
    if type(jobId) ~= 'string' or jobId == '' or #jobId > 64
        or jobId == VEHICLE_REMOVAL_SENTINEL
    then
        return nil, 'invalid_vehicle_removal_job'
    end
    local expected = validVehicleOwnershipSnapshot(snapshot)
    if not expected then return nil, 'invalid_vehicle_ownership_snapshot' end

    return {
        {
            query = ([[
                INSERT IGNORE INTO `%s` (`job_id`, `vehicle_id`, `owner`, `plate`, `model`)
                VALUES (?, 0, '', '', '')
            ]]):format(VEHICLE_REMOVAL_TABLE),
            values = { VEHICLE_REMOVAL_SENTINEL },
        },
        {
            query = [[
                SELECT `id`
                FROM `player_vehicles`
                WHERE BINARY UPPER(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        `plate`, ' ', ''), CHAR(9), ''), CHAR(10), ''),
                        CHAR(11), ''), CHAR(12), ''), CHAR(13), '')
                ) = BINARY ?
                ORDER BY `id` ASC
                FOR UPDATE
            ]],
            values = { expected.plate },
        },
        {
            query = [[
                DELETE target
                FROM `player_vehicles` AS target
                LEFT JOIN `player_vehicles` AS duplicate
                    ON duplicate.`id` <> target.`id`
                    AND BINARY UPPER(
                        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                            duplicate.`plate`, ' ', ''), CHAR(9), ''), CHAR(10), ''),
                            CHAR(11), ''), CHAR(12), ''), CHAR(13), '')
                    ) = BINARY ?
                WHERE target.`id` = ?
                  AND BINARY target.`citizenid` = BINARY ?
                  AND BINARY UPPER(
                      REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                          target.`plate`, ' ', ''), CHAR(9), ''), CHAR(10), ''),
                          CHAR(11), ''), CHAR(12), ''), CHAR(13), '')
                  ) = BINARY ?
                  AND BINARY target.`vehicle` = BINARY ?
                  AND duplicate.`id` IS NULL
            ]],
            values = {
                expected.plate, expected.id, expected.owner, expected.plate, expected.model,
            },
        },
        {
            query = ([[
                INSERT INTO `%s` (`job_id`, `vehicle_id`, `owner`, `plate`, `model`)
                VALUES (IF(ROW_COUNT() = 1, ?, ?), ?, ?, ?, ?)
            ]]):format(VEHICLE_REMOVAL_TABLE),
            values = {
                jobId, VEHICLE_REMOVAL_SENTINEL, expected.id,
                expected.owner, expected.plate, expected.model,
            },
        },
    }
end

Framework.VehicleRemovalCommitted = function(jobId, snapshot)
    if type(jobId) ~= 'string' or jobId == '' or #jobId > 64
        or jobId == VEHICLE_REMOVAL_SENTINEL
    then
        return false, 'invalid_vehicle_removal_job'
    end
    local expected = validVehicleOwnershipSnapshot(snapshot)
    if not expected then return false, 'invalid_vehicle_ownership_snapshot' end

    local ok, receipt = pcall(Database.single, ([[
        SELECT `job_id`, `vehicle_id`, `owner`, `plate`, `model`
        FROM `%s`
        WHERE BINARY `job_id` = BINARY ?
    ]]):format(VEHICLE_REMOVAL_TABLE), { jobId })
    if not ok then return false, 'vehicle_removal_receipt_read_failed' end
    if not receipt then return false, 'vehicle_removal_not_committed' end
    if receipt.job_id ~= jobId or tonumber(receipt.vehicle_id) ~= expected.id
        or receipt.owner ~= expected.owner or receipt.plate ~= expected.plate
        or receipt.model ~= expected.model
    then
        return false, 'vehicle_removal_receipt_conflict'
    end
    return true
end

-- World cleanup must disable Qbox persistence, including when ownership is kept.
-- This export changes only the entity; it does not delete the ownership record.
Framework.DeleteWorldVehicle = function(vehicle)
    if not DoesEntityExist(vehicle) then return true end
    if GetResourceState(Bridge.FrameworkName) ~= 'started' then
        return false, 'vehicle_provider_unavailable'
    end
    local ok = pcall(function() exports[Bridge.FrameworkName]:DeleteVehicle(vehicle) end)
    if not ok then return false, 'vehicle_world_removal_failed' end
    return true
end

Framework.DoesJobExist = function(job, grade)
    if type(job) ~= 'string' or job == '' or grade == nil then return false end

    local ok, jobs = pcall(function()
        return exports[Bridge.FrameworkName]:GetJobs()
    end)
    if not ok or type(jobs) ~= 'table' then return false end

    local jobData = jobs[job]
    local grades = jobData and jobData.grades
    if type(grades) ~= 'table' then return false end

    local numericGrade = tonumber(grade)
    return grades[grade] ~= nil
        or grades[tostring(grade)] ~= nil
        or (numericGrade ~= nil and grades[numericGrade] ~= nil)
end

Framework.GetJob = function(job)
    return exports.qbx_core:GetJob(job)
end

Framework.GetJobs = function()
    return exports.qbx_core:GetJobs()
end

Framework.DoesGangExist = function(gang, grade)
    grade = tostring(grade)
    if gang and grade then
        if QBX.Shared.Gangs[gang] and QBX.Shared.Gangs[gang].grades[grade] then
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
    TriggerClientEvent('ox_lib:notify', source, { description = message, type = type, duration = length })
end

Framework.IsPlayerDead = function(source)
    local Player = exports[Bridge.FrameworkName]:GetPlayer(source)
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

Framework.CreateCallback(('%s:SpawnVehicle'):format(Bridge.Resource), function(source, cb, model, coords, warp)
    local netId = SpawnVehicle(source, model, coords, warp)
    if not netId or netId == 0 then cb(0) end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then cb(0) end
    cb(netId)
end)