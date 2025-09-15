# Database Layer

## Supported Database Systems

Dusa Bridge provides a unified database abstraction layer that works across different database implementations, currently focusing on OXMySQL with extensible architecture for future database systems.

## OXMySQL Integration

### Configuration
- **Resource Name**: `oxmysql`
- **Modern MySQL wrapper for FiveM**

### Features
- Prepared statements
- Connection pooling
- Transaction support
- Async/sync operations
- Performance optimization

### Connection Setup

```sql
-- MySQL Database Schema Example
CREATE DATABASE IF NOT EXISTS `your_server_db`;
USE `your_server_db`;

-- Example: Player data table
CREATE TABLE IF NOT EXISTS `players` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(255) NOT NULL,
    `name` varchar(50) NOT NULL,
    `money` int(11) DEFAULT 5000,
    `bank` int(11) DEFAULT 0,
    `job` varchar(50) DEFAULT 'unemployed',
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
);

-- Example: Inventory table
CREATE TABLE IF NOT EXISTS `inventory` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(255) NOT NULL,
    `item` varchar(50) NOT NULL,
    `count` int(11) DEFAULT 1,
    `metadata` text,
    PRIMARY KEY (`id`),
    KEY `identifier` (`identifier`)
);
```

## Unified Database API

### Basic Operations

```lua
-- Execute query (INSERT, UPDATE, DELETE)
Database.Execute(query, params, callback)

-- Fetch single result
Database.Fetch(query, params, callback)

-- Fetch multiple results
Database.FetchAll(query, params, callback)

-- Insert and get inserted ID
Database.Insert(query, params, callback)

-- Update records
Database.Update(query, params, callback)
```

### Examples

#### Player Data Management

```lua
-- Create new player
local function CreatePlayer(identifier, name)
    Database.Execute('INSERT INTO players (identifier, name) VALUES (?, ?)',
        {identifier, name}, function(result)
            if result.affectedRows > 0 then
                print('Player created successfully')
            else
                print('Failed to create player')
            end
        end)
end

-- Get player data
local function GetPlayerData(identifier, callback)
    Database.Fetch('SELECT * FROM players WHERE identifier = ?',
        {identifier}, function(result)
            if result then
                callback(result)
            else
                callback(nil)
            end
        end)
end

-- Update player money
local function UpdatePlayerMoney(identifier, money, bank)
    Database.Execute('UPDATE players SET money = ?, bank = ? WHERE identifier = ?',
        {money, bank, identifier}, function(result)
            print('Money updated for player:', identifier)
        end)
end

-- Get top players by money
local function GetTopPlayers(callback)
    Database.FetchAll('SELECT name, money + bank as total_money FROM players ORDER BY total_money DESC LIMIT 10',
        {}, function(results)
            callback(results)
        end)
end
```

#### Inventory Management

```lua
-- Add item to inventory
local function AddItemToInventory(identifier, item, count, metadata)
    local metadataJson = json.encode(metadata or {})

    Database.Execute('INSERT INTO inventory (identifier, item, count, metadata) VALUES (?, ?, ?, ?)',
        {identifier, item, count, metadataJson}, function(result)
            if result.affectedRows > 0 then
                print('Item added to inventory')
            end
        end)
end

-- Get player inventory
local function GetPlayerInventory(identifier, callback)
    Database.FetchAll('SELECT * FROM inventory WHERE identifier = ?',
        {identifier}, function(results)
            local inventory = {}

            for _, row in pairs(results) do
                table.insert(inventory, {
                    item = row.item,
                    count = row.count,
                    metadata = json.decode(row.metadata) or {}
                })
            end

            callback(inventory)
        end)
end

-- Update item count
local function UpdateItemCount(identifier, item, newCount)
    if newCount <= 0 then
        Database.Execute('DELETE FROM inventory WHERE identifier = ? AND item = ?',
            {identifier, item})
    else
        Database.Execute('UPDATE inventory SET count = ? WHERE identifier = ? AND item = ?',
            {newCount, identifier, item})
    end
end

-- Get item by metadata
local function FindItemByMetadata(identifier, item, metadataKey, metadataValue, callback)
    Database.FetchAll('SELECT * FROM inventory WHERE identifier = ? AND item = ?',
        {identifier, item}, function(results)
            for _, row in pairs(results) do
                local metadata = json.decode(row.metadata) or {}
                if metadata[metadataKey] == metadataValue then
                    callback(row)
                    return
                end
            end
            callback(nil)
        end)
end
```

## Advanced Database Operations

### Transactions

```lua
-- Transaction example for money transfer
local function TransferMoney(fromIdentifier, toIdentifier, amount, callback)
    -- Start transaction
    Database.Execute('START TRANSACTION', {}, function()
        -- Check sender balance
        Database.Fetch('SELECT money FROM players WHERE identifier = ? FOR UPDATE',
            {fromIdentifier}, function(sender)
                if not sender or sender.money < amount then
                    Database.Execute('ROLLBACK', {})
                    callback(false, 'Insufficient funds')
                    return
                end

                -- Deduct from sender
                Database.Execute('UPDATE players SET money = money - ? WHERE identifier = ?',
                    {amount, fromIdentifier}, function()
                        -- Add to receiver
                        Database.Execute('UPDATE players SET money = money + ? WHERE identifier = ?',
                            {amount, toIdentifier}, function()
                                -- Commit transaction
                                Database.Execute('COMMIT', {}, function()
                                    callback(true, 'Transfer completed')
                                end)
                            end)
                    end)
            end)
    end)
end
```

### Batch Operations

```lua
-- Batch insert items
local function BatchInsertItems(items, callback)
    local values = {}
    local params = {}

    for _, item in pairs(items) do
        table.insert(values, '(?, ?, ?, ?)')
        table.insert(params, item.identifier)
        table.insert(params, item.item)
        table.insert(params, item.count)
        table.insert(params, json.encode(item.metadata or {}))
    end

    local query = 'INSERT INTO inventory (identifier, item, count, metadata) VALUES ' .. table.concat(values, ', ')

    Database.Execute(query, params, function(result)
        callback(result.affectedRows)
    end)
end

-- Batch update player data
local function BatchUpdatePlayers(updates, callback)
    local completed = 0
    local total = #updates

    for _, update in pairs(updates) do
        Database.Execute('UPDATE players SET money = ?, bank = ? WHERE identifier = ?',
            {update.money, update.bank, update.identifier}, function()
                completed = completed + 1
                if completed == total then
                    callback(true)
                end
            end)
    end
end
```

### Complex Queries

```lua
-- Get player statistics
local function GetPlayerStatistics(identifier, callback)
    local query = [[
        SELECT
            p.name,
            p.money,
            p.bank,
            p.job,
            COUNT(i.id) as item_count,
            SUM(i.count) as total_items
        FROM players p
        LEFT JOIN inventory i ON p.identifier = i.identifier
        WHERE p.identifier = ?
        GROUP BY p.identifier
    ]]

    Database.Fetch(query, {identifier}, function(result)
        callback(result)
    end)
end

-- Get server statistics
local function GetServerStatistics(callback)
    local stats = {}
    local queries = {
        {
            name = 'total_players',
            query = 'SELECT COUNT(*) as count FROM players'
        },
        {
            name = 'total_money',
            query = 'SELECT SUM(money + bank) as total FROM players'
        },
        {
            name = 'total_items',
            query = 'SELECT SUM(count) as total FROM inventory'
        }
    }

    local completed = 0

    for _, q in pairs(queries) do
        Database.Fetch(q.query, {}, function(result)
            stats[q.name] = result.count or result.total or 0
            completed = completed + 1

            if completed == #queries then
                callback(stats)
            end
        end)
    end
end
```

## Database Configuration

### OXMySQL Configuration

```lua
-- override.lua
override.database = 'oxmysql'
override.databasename = 'oxmysql'
```

### Connection String

```cfg
# In server.cfg
set mysql_connection_string "mysql://username:password@localhost/database_name?charset=utf8mb4"
```

### Custom Database Integration

```lua
-- For future database systems
override.database = 'custom_db'
override.databasename = 'my_database_system'
```

## Performance Optimization

### Connection Pooling

```lua
-- OXMySQL automatically handles connection pooling
-- Configure in oxmysql resource

-- connection_string with pool settings
set mysql_connection_string "mysql://user:pass@localhost/db?charset=utf8mb4&pool_min=5&pool_max=20"
```

### Query Optimization

```lua
-- Use prepared statements (automatic with bridge)
Database.Execute('SELECT * FROM players WHERE identifier = ?', {identifier})

-- Index optimization
-- Add proper indexes to your database tables
-- CREATE INDEX idx_player_identifier ON players(identifier);
-- CREATE INDEX idx_inventory_identifier ON inventory(identifier);

-- Limit results for large datasets
Database.FetchAll('SELECT * FROM players ORDER BY created_at DESC LIMIT ?', {50})

-- Use specific columns instead of SELECT *
Database.FetchAll('SELECT identifier, name, money FROM players WHERE job = ?', {'police'})
```

### Caching Layer

```lua
-- Simple caching implementation
local DatabaseCache = {}
DatabaseCache.cache = {}
DatabaseCache.ttl = 300000 -- 5 minutes

function DatabaseCache.Get(key, fetchFunction, callback)
    local cached = DatabaseCache.cache[key]

    if cached and (GetGameTimer() - cached.timestamp) < DatabaseCache.ttl then
        callback(cached.data)
        return
    end

    fetchFunction(function(data)
        DatabaseCache.cache[key] = {
            data = data,
            timestamp = GetGameTimer()
        }
        callback(data)
    end)
end

-- Usage example
DatabaseCache.Get('player_' .. identifier, function(cb)
    Database.Fetch('SELECT * FROM players WHERE identifier = ?', {identifier}, cb)
end, function(playerData)
    -- Use cached or fresh data
    ProcessPlayerData(playerData)
end)
```

## Database Migrations

### Migration System

```lua
-- Migration management
local Migrations = {}
Migrations.currentVersion = 0

function Migrations.Run()
    Database.Fetch('SELECT version FROM migrations ORDER BY version DESC LIMIT 1', {}, function(result)
        local currentVersion = result and result.version or 0
        Migrations.currentVersion = currentVersion

        local migrations = Migrations.GetPendingMigrations(currentVersion)

        for _, migration in pairs(migrations) do
            Migrations.RunMigration(migration)
        end
    end)
end

function Migrations.RunMigration(migration)
    print('Running migration:', migration.name)

    Database.Execute(migration.sql, {}, function(result)
        if result.affectedRows >= 0 then
            Database.Execute('INSERT INTO migrations (version, name, executed_at) VALUES (?, ?, ?)',
                {migration.version, migration.name, os.date('%Y-%m-%d %H:%M:%S')})
            print('Migration completed:', migration.name)
        else
            print('Migration failed:', migration.name)
        end
    end)
end

-- Migration definitions
Migrations.definitions = {
    {
        version = 1,
        name = 'create_migrations_table',
        sql = [[
            CREATE TABLE IF NOT EXISTS migrations (
                version INT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ]]
    },
    {
        version = 2,
        name = 'add_job_grade_to_players',
        sql = 'ALTER TABLE players ADD COLUMN job_grade INT DEFAULT 0'
    },
    {
        version = 3,
        name = 'create_inventory_metadata_index',
        sql = 'CREATE INDEX idx_inventory_metadata ON inventory(metadata(255))'
    }
}
```

## Error Handling

### Database Error Management

```lua
-- Centralized error handling
local function SafeDatabaseOperation(operation, params, callback, errorCallback)
    operation(params, function(result)
        if result then
            callback(result)
        else
            if errorCallback then
                errorCallback('Database operation failed')
            else
                print('Database error: Operation failed')
            end
        end
    end)
end

-- Usage
SafeDatabaseOperation(
    Database.Fetch,
    {'SELECT * FROM players WHERE identifier = ?', {identifier}},
    function(playerData)
        -- Success
        ProcessPlayerData(playerData)
    end,
    function(error)
        -- Error handling
        print('Failed to load player:', error)
        Framework.Notify(source, 'Failed to load player data', 'error')
    end
)

-- Retry mechanism
local function DatabaseOperationWithRetry(operation, params, callback, maxRetries)
    maxRetries = maxRetries or 3
    local attempts = 0

    local function attemptOperation()
        attempts = attempts + 1

        operation(params, function(result)
            if result then
                callback(result)
            elseif attempts < maxRetries then
                print('Database operation failed, retrying... Attempt:', attempts)
                SetTimeout(1000 * attempts, attemptOperation) -- Exponential backoff
            else
                print('Database operation failed after', maxRetries, 'attempts')
                callback(nil)
            end
        end)
    end

    attemptOperation()
end
```

## Database Utilities

### Data Validation

```lua
-- Input sanitization and validation
local DatabaseUtils = {}

function DatabaseUtils.ValidateIdentifier(identifier)
    if not identifier or type(identifier) ~= 'string' then
        return false
    end

    -- Basic identifier validation
    return identifier:match('^%w+:%w+$') ~= nil
end

function DatabaseUtils.SanitizeInput(input)
    if type(input) == 'string' then
        -- Remove potentially dangerous characters
        return input:gsub('[<>"\']', '')
    end
    return input
end

function DatabaseUtils.ValidateItemData(item, count, metadata)
    local errors = {}

    if not item or type(item) ~= 'string' or item == '' then
        table.insert(errors, 'Invalid item name')
    end

    if not count or type(count) ~= 'number' or count <= 0 then
        table.insert(errors, 'Invalid item count')
    end

    if metadata and type(metadata) ~= 'table' then
        table.insert(errors, 'Invalid metadata format')
    end

    return #errors == 0, errors
end
```

### Backup and Maintenance

```lua
-- Database maintenance utilities
function DatabaseUtils.CleanupOldData()
    -- Remove old inventory items with 0 count
    Database.Execute('DELETE FROM inventory WHERE count <= 0', {})

    -- Remove inactive players (example: not logged in for 90 days)
    Database.Execute('DELETE FROM players WHERE last_login < DATE_SUB(NOW(), INTERVAL 90 DAY)', {})

    print('Database cleanup completed')
end

-- Schedule regular cleanup
CreateThread(function()
    while true do
        Wait(24 * 60 * 60 * 1000) -- Every 24 hours
        DatabaseUtils.CleanupOldData()
    end
end)
```

## Troubleshooting Database Issues

### Common Issues

1. **Connection Failed**: Check MySQL server status and connection string
2. **Query Timeout**: Optimize queries and check server performance
3. **Data Corruption**: Implement proper validation and constraints
4. **Memory Issues**: Use connection pooling and limit result sets

### Debug Tools

```lua
-- Database query logger
local function LogDatabaseQuery(query, params, executionTime)
    if Bridge.DebugMode then
        print(('Database Query: %s | Params: %s | Time: %dms'):format(
            query,
            json.encode(params),
            executionTime
        ))
    end
end

-- Database health check
RegisterCommand('dbhealth', function()
    local startTime = GetGameTimer()

    Database.Fetch('SELECT 1 as test', {}, function(result)
        local endTime = GetGameTimer()
        local responseTime = endTime - startTime

        if result and result.test == 1 then
            print(('Database: Healthy (Response time: %dms)'):format(responseTime))
        else
            print('Database: Unhealthy')
        end
    end)
end, true)
```