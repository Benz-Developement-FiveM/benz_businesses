
function getBusiness(id)
    for _, business in pairs(Config.Businesses or {}) do
        if business.id == id then
            return business
        end
    end
end

-- Early Qbox helpers used by startup/tablet/job handlers.
function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

function getJob(src)
    local player = getPlayer(src)
    return player and player.PlayerData and player.PlayerData.job or nil
end

Config = Config or {}

local BusinessMenus = {}


function ensureDynamicBusinessesTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS qbox_dynamic_businesses (
            id VARCHAR(50) NOT NULL PRIMARY KEY,
            label VARCHAR(100) NOT NULL,
            type VARCHAR(50) NOT NULL DEFAULT 'business',
            job VARCHAR(50) NOT NULL,
            ui LONGTEXT NULL,
            blip LONGTEXT NULL,
            created_by VARCHAR(100) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])

    -- Older installs of this resource already have qbox_dynamic_businesses without blip/updated_at.
    -- CREATE TABLE IF NOT EXISTS will not add new columns, so migrate safely on every startup.
    pcall(function() MySQL.query.await('ALTER TABLE qbox_dynamic_businesses ADD COLUMN blip LONGTEXT NULL AFTER ui') end)
    pcall(function() MySQL.query.await('ALTER TABLE qbox_dynamic_businesses ADD COLUMN created_by VARCHAR(100) NULL AFTER blip') end)
    pcall(function() MySQL.query.await('ALTER TABLE qbox_dynamic_businesses ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP') end)
end

local function businessExists(id)
    for _, business in pairs(Config.Businesses or {}) do
        if business.id == id then return true end
    end

    return false
end

local function loadDynamicBusinesses()
    if not Config.DynamicBusinessesEnabled then return end
    ensureDynamicBusinessesTable()

    local rows = MySQL.query.await('SELECT * FROM qbox_dynamic_businesses ORDER BY label ASC') or {}

    for _, row in pairs(rows) do
        if not businessExists(row.id) then
            local okUi, ui = pcall(json.decode, row.ui or '{}')
            ui = okUi and ui or {}

            local okBlip, blip = pcall(json.decode, row.blip or '{}')
            blip = okBlip and blip or {}

            Config.Businesses[#Config.Businesses + 1] = {
                id = row.id,
                label = row.label,
                type = row.type,
                job = row.job,
                ui = ui,
                blip = blip,
                stations = {},
                dynamic = true
            }
        end
    end
end



local SupplyStoreItems = {}

function ensureBusinessSupplyItemsTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS qbox_business_supply_store_items (
            business VARCHAR(50) NOT NULL,
            item VARCHAR(100) NOT NULL,
            label VARCHAR(100) NOT NULL,
            price INT NOT NULL DEFAULT 0,
            amount INT NOT NULL DEFAULT 1,
            enabled TINYINT NOT NULL DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (business, item)
        )
    ]])
end



local function ensureSupplyItemsTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS qbox_business_supply_items (
            item VARCHAR(100) NOT NULL PRIMARY KEY,
            label VARCHAR(100) NOT NULL,
            price INT NOT NULL DEFAULT 0,
            amount INT NOT NULL DEFAULT 1,
            enabled TINYINT NOT NULL DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
end



local function initSupplyStore()
    ensureBusinessSupplyItemsTable()
    ensureBusinessSupplyItemsTable()
    ensureSupplyItemsTable()

    if Config.UseDatabaseSupplyStore then
        for _, item in pairs(Config.SupplierItems or {}) do
            MySQL.insert.await([[
                INSERT IGNORE INTO qbox_business_supply_items (item, label, price, amount, enabled)
                VALUES (?, ?, ?, ?, ?)
            ]], {
                item.item,
                item.label or item.item,
                tonumber(item.price) or 0,
                tonumber(item.amount) or 1,
                1
            })
        end
    end

    local rows = MySQL.query.await('SELECT * FROM qbox_business_supply_items WHERE enabled = 1 ORDER BY label ASC') or {}
    SupplyStoreItems = {}

    for _, row in pairs(rows) do
        SupplyStoreItems[#SupplyStoreItems + 1] = {
            item = row.item,
            label = row.label,
            price = tonumber(row.price) or 0,
            amount = tonumber(row.amount) or 1
        }
    end
end

local function getSupplyStoreItems(includeDisabled)
    if not Config.UseDatabaseSupplyStore then
        return Config.SupplierItems or {}
    end

    ensureSupplyItemsTable()

    if includeDisabled then
        local rows = MySQL.query.await('SELECT * FROM qbox_business_supply_items ORDER BY label ASC') or {}
        local items = {}

        for _, row in pairs(rows) do
            items[#items + 1] = {
                item = row.item,
                label = row.label,
                price = tonumber(row.price) or 0,
                amount = tonumber(row.amount) or 1,
                enabled = tonumber(row.enabled) == 1
            }
        end

        return items
    end

    return SupplyStoreItems or {}
end




local DynamicBusinessStations = {}

-- Early dynamic stations callback used by client startup E-interact/target registration.
-- Registered near the top so clients never request it before it exists.
lib.callback.register('qbox_all_businesses:server:getDynamicStations', function(src)
    local stations = {}

    for _, business in pairs(Config.Businesses or {}) do
        for _, station in pairs((DynamicBusinessStations and DynamicBusinessStations[business.id]) or {}) do
            stations[#stations + 1] = {
                businessId = business.id,
                job = station.accessJob or station.job or business.job,
                accessJob = station.accessJob or station.job or business.job,
                id = station.id,
                type = station.type,
                label = station.label,
                coords = station.coords and {
                    x = station.coords.x,
                    y = station.coords.y,
                    z = station.coords.z
                } or nil,
                size = station.size and {
                    x = station.size.x,
                    y = station.size.y,
                    z = station.size.z
                } or {
                    x = 1.4,
                    y = 1.4,
                    z = 1.0
                },
                rotation = station.rotation or 0.0,
                useRadius = station.useRadius,
                hearRadius = station.hearRadius,
                bossOnly = station.bossOnly,
                dynamic = true
            }
        end
    end

    return stations
end)



local function normalizeStation(row)
    local ok, coords = pcall(json.decode, row.coords or '{}')
    coords = ok and coords or { x = 0.0, y = 0.0, z = 0.0 }

    local okSettings, settings = pcall(json.decode, row.settings or '{}')
    settings = okSettings and settings or {}

    local size = settings.size or { x = 1.4, y = 1.4, z = 1.0 }

    local station = {
        id = row.station_id,
        job = row.job,
        accessJob = row.job,
        type = row.type,
        label = row.label,
        coords = vec3(coords.x, coords.y, coords.z),
        size = vec3(size.x or 1.4, size.y or 1.4, size.z or 1.0),
        rotation = tonumber(row.rotation) or 0.0,
        dynamic = true
    }

    for k, v in pairs(settings) do
        if k ~= 'size' then
            station[k] = v
        end
    end

    return station
end

local function initDynamicBusinessStations()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS qbox_business_stations (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            business VARCHAR(50) NOT NULL,
            job VARCHAR(50) NULL,
            station_id VARCHAR(80) NOT NULL,
            type VARCHAR(50) NOT NULL,
            label VARCHAR(100) NOT NULL,
            coords LONGTEXT NOT NULL,
            rotation FLOAT NOT NULL DEFAULT 0,
            settings LONGTEXT NULL,
            created_by VARCHAR(100) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    -- Backwards compatibility: old DJ placement table
    pcall(function()
        MySQL.query.await('ALTER TABLE qbox_business_stations ADD COLUMN job VARCHAR(50) NULL AFTER business')
    end)

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS qbox_business_dj_booths (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            business VARCHAR(50) NOT NULL,
            booth_id VARCHAR(80) NOT NULL,
            label VARCHAR(100) NOT NULL,
            coords LONGTEXT NOT NULL,
            rotation FLOAT NOT NULL DEFAULT 0,
            use_radius FLOAT NOT NULL DEFAULT 2.0,
            hear_radius FLOAT NOT NULL DEFAULT 45.0,
            created_by VARCHAR(100) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    local rows = MySQL.query.await('SELECT * FROM qbox_business_stations') or {}

    for _, row in pairs(rows) do
        local station = normalizeStation(row)
        local business = getBusiness(row.business)
        if business then
            station.job = station.job or business.job
            station.accessJob = station.accessJob or station.job or business.job
        end

        DynamicBusinessStations[row.business] = DynamicBusinessStations[row.business] or {}
        DynamicBusinessStations[row.business][#DynamicBusinessStations[row.business] + 1] = station
    end

    -- Load old DJ booths too, if any exist.
    local oldDjRows = MySQL.query.await('SELECT * FROM qbox_business_dj_booths') or {}
    for _, row in pairs(oldDjRows) do
        local ok, coords = pcall(json.decode, row.coords or '{}')
        coords = ok and coords or { x = 0.0, y = 0.0, z = 0.0 }

        DynamicBusinessStations[row.business] = DynamicBusinessStations[row.business] or {}
        DynamicBusinessStations[row.business][#DynamicBusinessStations[row.business] + 1] = {
            id = row.booth_id,
            job = (getBusiness(row.business) and getBusiness(row.business).job) or nil,
            accessJob = (getBusiness(row.business) and getBusiness(row.business).job) or nil,
            type = 'dj',
            label = row.label,
            coords = vec3(coords.x, coords.y, coords.z),
            size = Config.DefaultPlacedDJSize or Config.DefaultPlacedStationSize or vec3(1.4, 1.4, 1.0),
            rotation = tonumber(row.rotation) or 0.0,
            useRadius = tonumber(row.use_radius) or Config.DefaultPlacedDJUseRadius or 2.0,
            hearRadius = tonumber(row.hear_radius) or Config.DefaultPlacedDJHearRadius or 45.0,
            dynamic = true
        }
    end

    -- Register dynamic stashes/fridges.
    for _, business in pairs(Config.Businesses or {}) do
        for _, station in pairs(DynamicBusinessStations[business.id] or {}) do
            if station.type == 'stash' or station.type == 'fridge' then
                exports.ox_inventory:RegisterStash(
                    business.id .. '_' .. station.id,
                    business.label .. ' - ' .. station.label,
                    station.slots or 60,
                    station.weight or 150000,
                    false
                )
            end
        end
    end
end

local function getAllBusinessStations(business)
    local stations = {}

    -- Default/static config stations are disabled for this resource build.
    -- Stations should be created from the admin/tablet menu and saved in qbox_business_stations.
    if not Config.DisableDefaultConfigStations then
        for _, station in pairs(business.stations or {}) do
            station.job = station.job or business.job
            station.accessJob = station.accessJob or station.job or business.job
            stations[#stations + 1] = station
        end
    end

    for _, station in pairs(DynamicBusinessStations[business.id] or {}) do
        station.job = station.job or business.job
        station.accessJob = station.accessJob or station.job or business.job
        stations[#stations + 1] = station
    end

    return stations
end


local function getAnyStation(business, stationId)
    if not business then return nil end

    for _, station in pairs(getAllBusinessStations(business)) do
        if station.id == stationId then
            return station
        end
    end

    return nil
end



local function canPlaceStation(src, business)
    if not Config.AllowTabletStationPlacement then return false end

    local job = getJob(src)
    if not job or not business or job.name ~= business.job then return false end
    if job.isboss then return true end
    if job.grade and job.grade.level and job.grade.level >= (Config.StationPlacementMinGrade or 3) then return true end

    return false
end

local function canPlaceDJBooth(src, business)
    if not Config.AllowTabletDJPlacement then return false end

    local job = getJob(src)
    if not job or not business or job.name ~= business.job then return false end
    if job.isboss then return true end
    if job.grade and job.grade.level and job.grade.level >= (Config.DJPlacementMinGrade or 3) then return true end

    return false
end


local function notify(src, title, description, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title or 'Business',
        description = description or '',
        type = ntype or 'inform',
        duration = 5000,
        position = 'top-right'
    })
end

local function getBusiness(id)
    for _, business in pairs(Config.Businesses or {}) do
        if business.id == id then return business end
    end
end

local function getBusinessByJob(jobName)
    for _, business in pairs(Config.Businesses or {}) do
        if business.job == jobName then return business end
    end
end

local function getPlayerBusiness(src)
    local job = getJob(src)
    if not job then return nil end
    return getBusinessByJob(job.name)
end

local function getStation(business, stationId)
    if not business then return nil end
    for _, station in pairs(getAllBusinessStations(business)) do
        if station.id == stationId then return station end
    end
end


local function canUseStationByJob(src, business, station, bossOnly)
    if not business or not station then return false end

    local job = getJob(src)
    if not job then return false end

    local requiredJob = station.accessJob or station.job or business.job
    if Config.RegisteredJobStationAccess and requiredJob and job.name ~= requiredJob then
        return false
    end

    if job.name ~= business.job and (not requiredJob or job.name ~= requiredJob) then
        return false
    end

    if bossOnly or station.bossOnly then
        if job.isboss then return true end
        if job.grade and job.grade.level and job.grade.level >= (Config.MenuEditorMinGrade or 4) then return true end
        return false
    end

    return true
end

local function canDeleteStation(src, business, station)
    if not Config.AllowTabletStationDeletion then return false end
    if not business or not station then return false end
    if not station.dynamic then return false end

    local job = getJob(src)
    if not job then return false end

    local requiredJob = station.accessJob or station.job or business.job
    if requiredJob and job.name ~= requiredJob then return false end

    if job.isboss then return true end
    if job.grade and job.grade.level and job.grade.level >= (Config.StationDeletionMinGrade or 3) then return true end

    return false
end




local function hasBusinessJob(src, business, bossOnly)
    local job = getJob(src)
    if not job or not business or job.name ~= business.job then return false end

    if bossOnly then
        if job.isboss then return true end
        if job.grade and job.grade.level and job.grade.level >= (Config.MenuEditorMinGrade or 4) then return true end
        return false
    end

    return true
end

local function getPlayerIdentity(src)
    local player = getPlayer(src)
    if not player or not player.PlayerData then
        return 'unknown', GetPlayerName(src) or 'Unknown'
    end

    local citizenid = player.PlayerData.citizenid or 'unknown'
    local info = player.PlayerData.charinfo or {}
    local name = ((info.firstname or '') .. ' ' .. (info.lastname or '')):gsub('^%s*(.-)%s*$', '%1')
    if name == '' then name = GetPlayerName(src) or 'Unknown' end

    return citizenid, name
end

local function getPlayerName(src)
    local _, name = getPlayerIdentity(src)
    return name
end

local function getCash(src)
    return exports.qbx_core:GetMoney(src, 'cash') or 0
end

local function removeCash(src, amount, reason)
    return exports.qbx_core:RemoveMoney(src, 'cash', amount, reason or 'business-action')
end

local function addCash(src, amount, reason)
    return exports.qbx_core:AddMoney(src, 'cash', amount, reason or 'business-action')
end




local function getBusinessAccountName(business)
    return (Config.RenewedBusinessAccountPrefix or '') .. business.job
end

local function renewedStarted()
    local resource = Config.RenewedBankingResource or 'Renewed-Banking'
    return GetResourceState(resource) == 'started'
end

local function getBusinessAccountBalance(business)
    if not business then return 0 end

    if Config.Banking == 'renewed' and renewedStarted() then
        local ok, balance = pcall(function()
            return exports[Config.RenewedBankingResource or 'Renewed-Banking']:getAccountMoney(getBusinessAccountName(business))
        end)

        if ok then
            return tonumber(balance) or 0
        end

        print(('^1[qbox_all_businesses] Renewed Banking getAccountMoney failed for %s^0'):format(getBusinessAccountName(business)))
    end

    local row = MySQL.single.await('SELECT balance FROM qbox_business_accounts WHERE business = ?', { business.id })
    return row and tonumber(row.balance) or 0
end

local function renewedTransaction(business, amount, title, message, issuer, receiver, transType)
    if Config.Banking ~= 'renewed' or not Config.UseRenewedTransactions or not renewedStarted() then return end

    pcall(function()
        exports[Config.RenewedBankingResource or 'Renewed-Banking']:handleTransaction(
            getBusinessAccountName(business),
            title or (business.label .. (Config.RenewedBusinessAccountTitleSuffix or ' Account')),
            tonumber(amount) or 0,
            message or 'Business transaction',
            issuer or business.label,
            receiver or business.label,
            transType or 'deposit'
        )
    end)
end

local function addBusinessAccountMoney(business, amount, title, message, issuer, receiver)
    amount = math.floor(tonumber(amount) or 0)
    if not business or amount <= 0 then return false end

    if Config.Banking == 'renewed' and renewedStarted() then
        local ok, result = pcall(function()
            return exports[Config.RenewedBankingResource or 'Renewed-Banking']:addAccountMoney(getBusinessAccountName(business), amount)
        end)

        -- Renewed Banking versions may return true or nil on success. Only false means failed.
        if ok and result ~= false then
            renewedTransaction(business, amount, title or (business.label .. ' Deposit'), message or 'Business deposit', issuer, receiver, 'deposit')
            return true
        end

        print(('^1[qbox_all_businesses] Renewed Banking addAccountMoney failed for %s amount %s^0'):format(getBusinessAccountName(business), amount))
        return false
    end

    MySQL.update.await('UPDATE qbox_business_accounts SET balance = balance + ? WHERE business = ?', { amount, business.id })
    return true
end

local function removeBusinessAccountMoney(business, amount, title, message, issuer, receiver)
    amount = math.floor(tonumber(amount) or 0)
    if not business or amount <= 0 then return false end

    if getBusinessAccountBalance(business) < amount then
        return false
    end

    if Config.Banking == 'renewed' and renewedStarted() then
        local ok, result = pcall(function()
            return exports[Config.RenewedBankingResource or 'Renewed-Banking']:removeAccountMoney(getBusinessAccountName(business), amount)
        end)

        -- Renewed Banking versions may return true or nil on success. Only false means failed.
        if ok and result ~= false then
            renewedTransaction(business, amount, title or (business.label .. ' Withdrawal'), message or 'Business withdrawal', issuer, receiver, 'withdraw')
            return true
        end

        print(('^1[qbox_all_businesses] Renewed Banking removeAccountMoney failed for %s amount %s^0'):format(getBusinessAccountName(business), amount))
        return false
    end

    MySQL.update.await('UPDATE qbox_business_accounts SET balance = balance - ? WHERE business = ?', { amount, business.id })
    return true
end


local function parseIngredients(input)
    if type(input) == 'table' then return input end

    local ingredients = {}
    input = tostring(input or '')

    for part in string.gmatch(input, '([^,]+)') do
        local itemName, itemAmount = part:match('^%s*([%w_%-]+)%s*:?%s*(%d+)%s*$')
        if itemName and itemAmount then
            ingredients[itemName] = tonumber(itemAmount)
        end
    end

    return ingredients
end

local function getDefaultStationItems(station)
    return station.items or station.recipes or {}
end

local function getStationItems(businessId, stationId)
    if BusinessMenus[businessId] and BusinessMenus[businessId][stationId] then
        return BusinessMenus[businessId][stationId]
    end

    local business = getBusiness(businessId)
    local station = getStation(business, stationId)
    return station and getDefaultStationItems(station) or {}
end

local function setStationItems(businessId, stationId, items)
    BusinessMenus[businessId] = BusinessMenus[businessId] or {}
    BusinessMenus[businessId][stationId] = items or {}
end

local function saveStationItems(businessId, stationId)
    MySQL.insert.await([[
        INSERT INTO qbox_business_menus (business, station, items)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE items = VALUES(items)
    ]], { businessId, stationId, json.encode(getStationItems(businessId, stationId)) })
end

local function getBusinessBalance(businessId)
    local business = getBusiness(businessId)
    if not business then return 0 end
    return getBusinessAccountBalance(business)
end

local function addBusinessTransaction(src, businessId, action, amount, note)
    local citizenid, name = getPlayerIdentity(src)

    MySQL.insert.await([[
        INSERT INTO qbox_business_transactions (business, citizenid, player_name, action, amount, note)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { businessId, citizenid, name, action, tonumber(amount) or 0, note or '' })
end

local function canUseAccount(src, business)
    local job = getJob(src)
    if not job or not business or job.name ~= business.job then return false end
    if job.isboss then return true end
    if job.grade and job.grade.level and job.grade.level >= (Config.BusinessAccountAccessMinGrade or 3) then return true end
    return false
end

local function canWithdraw(src, business)
    local job = getJob(src)
    if not job or not business or job.name ~= business.job then return false end
    if job.isboss then return true end
    if not Config.BusinessAccountBossOnlyWithdraw and canUseAccount(src, business) then return true end
    if job.grade and job.grade.level and job.grade.level >= (Config.MenuEditorMinGrade or 4) then return true end
    return false
end

local function canOrderSupplies(src, business)
    local job = getJob(src)
    if not job or not business or job.name ~= business.job then return false end
    if job.isboss then return true end
    if job.grade and job.grade.level and job.grade.level >= (Config.SupplyOrderMinGrade or 1) then return true end
    return false
end


local function seedBusinessSupplyStore(businessId)
    ensureBusinessSupplyItemsTable()

    for _, item in pairs(getSupplyStoreItems and getSupplyStoreItems(false) or Config.SupplierItems or {}) do
        MySQL.insert.await([[
            INSERT IGNORE INTO qbox_business_supply_store_items
            (business, item, label, price, amount, enabled)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            businessId,
            item.item,
            item.label or item.item,
            tonumber(item.price) or 0,
            tonumber(item.amount) or 1,
            1
        })
    end
end

local function getBusinessSupplyStoreItems(businessId, includeDisabled)
    if not Config.UsePerBusinessSupplyStores then
        return getSupplyStoreItems and getSupplyStoreItems(includeDisabled) or Config.SupplierItems or {}
    end

    ensureBusinessSupplyItemsTable()
    seedBusinessSupplyStore(businessId)

    local sql = 'SELECT * FROM qbox_business_supply_store_items WHERE business = ?'
    if not includeDisabled then
        sql = sql .. ' AND enabled = 1'
    end
    sql = sql .. ' ORDER BY label ASC'

    local rows = MySQL.query.await(sql, { businessId }) or {}
    local items = {}

    for _, row in pairs(rows) do
        items[#items + 1] = {
            business = row.business,
            item = row.item,
            label = row.label,
            price = tonumber(row.price) or 0,
            amount = tonumber(row.amount) or 1,
            enabled = tonumber(row.enabled) == 1
        }
    end

    return items
end

local function getBusinessSupplierItem(businessId, itemName)
    for _, item in pairs(getBusinessSupplyStoreItems(businessId, false) or {}) do
        if item.item == itemName then
            return item
        end
    end
end


local function getSupplierItem(itemName)
    for _, item in pairs(getSupplyStoreItems(false) or {}) do
        if item.item == itemName then return item end
    end
end

local function getOnlineEmployees(jobName)
    local employees = {}

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local job = getJob(src)

        if job and job.name == jobName then
            employees[#employees + 1] = {
                source = src,
                name = getPlayerName(src),
                grade = job.grade and job.grade.level or 0,
                gradeLabel = job.grade and (job.grade.name or job.grade.label) or 'Employee',
                isboss = job.isboss or false
            }
        end
    end

    table.sort(employees, function(a, b)
        return (a.grade or 0) > (b.grade or 0)
    end)

    return employees
end

local function getJobGrades()
    local grades = {}
    for grade, label in pairs(Config.DefaultGradeLabels or {}) do
        grades[#grades + 1] = { grade = tonumber(grade), label = label }
    end

    if #grades == 0 then
        grades = {
            { grade = 0, label = 'Trainee' },
            { grade = 1, label = 'Employee' },
            { grade = 2, label = 'Senior Employee' },
            { grade = 3, label = 'Manager' },
            { grade = 4, label = 'Owner' }
        }
    end

    table.sort(grades, function(a, b) return a.grade < b.grade end)
    return grades
end

local function initDatabase()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS qbox_business_menus (
            business VARCHAR(50) NOT NULL,
            station VARCHAR(50) NOT NULL,
            items LONGTEXT NOT NULL,
            PRIMARY KEY (business, station)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS qbox_business_accounts (
            business VARCHAR(50) NOT NULL PRIMARY KEY,
            balance INT NOT NULL DEFAULT 0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS qbox_business_transactions (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            business VARCHAR(50) NOT NULL,
            citizenid VARCHAR(100) NULL,
            player_name VARCHAR(100) NULL,
            action VARCHAR(50) NOT NULL,
            amount INT NOT NULL,
            note VARCHAR(255) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS qbox_business_supply_orders (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            business VARCHAR(50) NOT NULL,
            ordered_by VARCHAR(100) NULL,
            ordered_name VARCHAR(100) NULL,
            status VARCHAR(30) NOT NULL DEFAULT 'in_transit',
            total INT NOT NULL DEFAULT 0,
            items LONGTEXT NOT NULL,
            delivery_ready_at INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    local rows = MySQL.query.await('SELECT business, station, items FROM qbox_business_menus') or {}
    for _, row in pairs(rows) do
        local ok, decoded = pcall(json.decode, row.items or '[]')
        if ok and decoded then
            setStationItems(row.business, row.station, decoded)
        end
    end

    -- Load database-created businesses before accounts/stashes/blips are initialized.
    -- Without this, newly-created restaurants exist until restart but their saved blip/business rows are not reloaded.
    loadDynamicBusinesses()

    for _, business in pairs(Config.Businesses or {}) do
        MySQL.insert.await('INSERT IGNORE INTO qbox_business_accounts (business, balance) VALUES (?, ?)', { business.id, 0 })

        for _, station in pairs(getAllBusinessStations(business)) do
            if station.type == 'stash' or station.type == 'fridge' then
                exports.ox_inventory:RegisterStash(
                    business.id .. '_' .. station.id,
                    business.label .. ' - ' .. station.label,
                    station.slots or 50,
                    station.weight or 100000,
                    false
                )
            end
        end
    end
end


local function buildQboxJobDefinition(business)
    local grades = {}

    for grade, data in pairs(Config.DefaultBusinessJobGrades or {}) do
        grades[tostring(grade)] = {
            name = data.name or ('grade_' .. tostring(grade)),
            payment = data.payment or 50,
            isboss = data.isboss or false
        }
    end

    return {
        label = business.label,
        type = business.type or Config.DefaultBusinessJobType or 'business',
        defaultDuty = Config.DefaultBusinessJobDuty ~= false,
        offDutyPay = Config.DefaultBusinessJobOffDutyPay == true,
        grades = grades
    }
end

local function luaSerialize(value, indent)
    indent = indent or 0
    local pad = string.rep('    ', indent)

    if type(value) == 'table' then
        local out = "{\n"
        for k, v in pairs(value) do
            local key
            if type(k) == 'number' then
                key = '[' .. k .. ']'
            else
                key = "['" .. tostring(k) .. "']"
            end

            out = out .. pad .. '    ' .. key .. ' = ' .. luaSerialize(v, indent + 1) .. ',\n'
        end
        return out .. pad .. '}'
    elseif type(value) == 'string' then
        return string.format('%q', value)
    elseif type(value) == 'boolean' then
        return value and 'true' or 'false'
    else
        return tostring(value)
    end
end

local function generateQboxJobsFile()
    if not Config.AutoGenerateQboxJobs then return end

    local jobs = {}

    for _, business in pairs(Config.Businesses or {}) do
        if business.job and business.job ~= '' then
            jobs[business.job] = buildQboxJobDefinition(business)
        end
    end

    local content = "-- Generated by qbox_all_businesses\n"
    content = content .. "-- Copy these job entries into qbx_core/shared/jobs.lua if your server does not auto-load jobs.\n\n"
    content = content .. "return " .. luaSerialize(jobs, 0) .. "\n"

    SaveResourceFile(GetCurrentResourceName(), "generated_qbox_jobs.lua", content, -1)
    print(('^2[qbox_all_businesses]^7 Generated %s Qbox job definitions in generated_qbox_jobs.lua'):format(#(Config.Businesses or {})))
end

lib.callback.register('qbox_all_businesses:server:getBusinessJobs', function(src)
    local jobs = {}

    for _, business in pairs(Config.Businesses or {}) do
        jobs[#jobs + 1] = {
            business = business.id,
            label = business.label,
            job = business.job,
            type = business.type
        }
    end

    return jobs
end)

RegisterCommand('businessjobs', function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'qboxbusiness.admin') then
        notify(src, 'Business Jobs', 'You do not have permission.', 'error')
        return
    end

    generateQboxJobsFile()

    if src ~= 0 then
        notify(src, 'Business Jobs', 'Generated qbox job file in the resource folder.', 'success')
    end
end, false)


CreateThread(function()
    initDatabase()
    initDynamicBusinessStations()

    if Config.TabletItem then
        exports.qbx_core:CreateUseableItem(Config.TabletItem, function(source)
            TriggerClientEvent('qbox_all_businesses:client:openTablet', source)
        end)
    end

    print('^2[qbox_all_businesses]^7 Qbox business system loaded successfully.')
end)

lib.callback.register('qbox_all_businesses:server:getStationItems', function(src, businessId, stationId)
    local business = getBusiness(businessId)
    if not business or not hasBusinessJob(src, business, false) then return {} end
    return getStationItems(businessId, stationId)
end)



lib.callback.register('qbox_all_businesses:server:getAllThirdEyeStations', function(src)
    local stations = {}

    for _, business in pairs(Config.Businesses or {}) do
        for _, station in pairs(getAllBusinessStations(business)) do
            stations[#stations + 1] = {
                businessId = business.id,
                job = station.job or business.job,
                accessJob = station.accessJob or station.job or business.job,
                id = station.id,
                type = station.type,
                label = station.label,
                coords = { x = station.coords.x, y = station.coords.y, z = station.coords.z },
                size = station.size and { x = station.size.x, y = station.size.y, z = station.size.z } or { x = 1.0, y = 1.0, z = 1.0 },
                rotation = station.rotation,
                useRadius = station.useRadius,
                hearRadius = station.hearRadius,
                bossOnly = station.bossOnly
            }
        end
    end

    return stations
end)


lib.callback.register('qbox_all_businesses:server:getDynamicStations', function(src)
    local stations = {}

    for _, business in pairs(Config.Businesses or {}) do
        for _, station in pairs(DynamicBusinessStations[business.id] or {}) do
            stations[#stations + 1] = {
                businessId = business.id,
                job = station.job or business.job,
                accessJob = station.accessJob or station.job or business.job,
                id = station.id,
                type = station.type,
                label = station.label,
                coords = { x = station.coords.x, y = station.coords.y, z = station.coords.z },
                size = station.size and { x = station.size.x, y = station.size.y, z = station.size.z } or { x = 1.4, y = 1.4, z = 1.0 },
                rotation = station.rotation,
                useRadius = station.useRadius,
                hearRadius = station.hearRadius,
                bossOnly = station.bossOnly
            }
        end
    end

    return stations
end)

lib.callback.register('qbox_all_businesses:server:getTabletData', function(src)
    local business = getPlayerBusiness(src)
    if not business or not hasBusinessJob(src, business, false) then return nil end

    local transactions = MySQL.query.await([[
        SELECT player_name, action, amount, note, created_at
        FROM qbox_business_transactions
        WHERE business = ?
        ORDER BY id DESC
        LIMIT 25
    ]], { business.id }) or {}

    local orders = MySQL.query.await([[
        SELECT id, business, ordered_name, status, total, items, delivery_ready_at, created_at
        FROM qbox_business_supply_orders
        WHERE business = ?
        ORDER BY id DESC
        LIMIT 25
    ]], { business.id }) or {}

    for _, order in pairs(orders) do
        local ok, decoded = pcall(json.decode, order.items or '[]')
        order.items = ok and decoded or {}
        order.readyAt = tonumber(order.delivery_ready_at or 0)
        order.remainingSeconds = math.max(0, order.readyAt - os.time())
        order.ready = os.time() >= order.readyAt
        order.timerLabel = order.ready and 'Ready' or tostring(order.remainingSeconds)
    end

    local menuStations = {}
    local djStations = {}
    local stashStations = {}
    local allStations = {}

    for _, station in pairs(getAllBusinessStations(business)) do
        allStations[#allStations + 1] = {
            id = station.id,
            type = station.type,
            label = station.label,
            dynamic = station.dynamic == true,
            job = station.job or business.job,
            accessJob = station.accessJob or station.job or business.job,
            canDelete = canDeleteStation(src, business, station)
        }

        if station.type == 'food' or station.type == 'drink' then
            menuStations[#menuStations + 1] = {
                id = station.id,
                label = station.label,
                type = station.type,
                items = getStationItems(business.id, station.id)
            }
        elseif station.type == 'dj' then
            djStations[#djStations + 1] = {
                id = station.id,
                label = station.label,
                useRadius = station.useRadius or Config.DefaultDJUseRadius or 2.0,
                hearRadius = station.hearRadius or Config.DefaultDJHearRadius or 35.0
            }
        elseif station.type == 'stash' or station.type == 'fridge' then
            stashStations[#stashStations + 1] = {
                id = station.id,
                label = station.label,
                type = station.type
            }
        end
    end

    return {
        business = {
            id = business.id,
            label = business.label,
            type = business.type,
            job = business.job,
            ui = business.ui or {}
        },
        account = {
            balance = getBusinessBalance(business.id),
            cash = getCash(src),
            canWithdraw = canWithdraw(src, business),
            transactions = transactions
        },
        employees = getOnlineEmployees(business.job),
        grades = getJobGrades(),
        supply = {
            supplierItems = getBusinessSupplyStoreItems(business.id, false),
            orders = orders
        },
        menuStations = menuStations,
        djStations = djStations,
        stashStations = stashStations,
        allStations = allStations,
        canDeleteStations = Config.AllowTabletStationDeletion == true,
        canPlaceDJ = canPlaceDJBooth(src, business),
        canPlaceStations = canPlaceStation(src, business),
        placeableStationTypes = Config.PlaceableStationTypes or {}
    }
end)


local function doBusinessDeposit(src, business, amount, note)
    if not business or not canUseAccount(src, business) then
        notify(src, 'Business Account', 'You do not have access to this account.', 'error')
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        notify(src, business.label, 'Invalid deposit amount.', 'error')
        return
    end

    if getCash(src) < amount then
        notify(src, business.label, 'You do not have enough cash.', 'error')
        return
    end

    if not removeCash(src, amount, 'business-account-deposit') then
        notify(src, business.label, 'Could not remove cash.', 'error')
        return
    end

    if not addBusinessAccountMoney(business, amount, business.label .. ' Deposit', note or 'Cash deposit', getPlayerName(src), business.label) then
        -- Refund player if Renewed Banking/local account deposit failed.
        addCash(src, amount, 'business-account-deposit-refund')
        notify(src, business.label, 'Deposit failed. Your cash was refunded.', 'error')
        return
    end

    addBusinessTransaction(src, business.id, 'deposit', amount, note or 'Cash deposit')
    notify(src, business.label, 'Deposited $' .. amount .. '.', 'success')
end

local function doBusinessWithdraw(src, business, amount, note)
    if not business or not canWithdraw(src, business) then
        notify(src, 'Business Account', 'Only management can withdraw.', 'error')
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        notify(src, business.label, 'Invalid withdrawal amount.', 'error')
        return
    end

    if getBusinessAccountBalance(business) < amount then
        notify(src, business.label, 'Business account has insufficient funds.', 'error')
        return
    end

    if not removeBusinessAccountMoney(business, amount, business.label .. ' Withdrawal', note or 'Cash withdrawal', business.label, getPlayerName(src)) then
        notify(src, business.label, 'Withdrawal failed.', 'error')
        return
    end

    if not addCash(src, amount, 'business-account-withdraw') then
        -- Put money back if player cash add failed.
        addBusinessAccountMoney(business, amount, business.label .. ' Withdrawal Refund', 'Withdrawal cash payout failed, refunding account', business.label, business.label)
        notify(src, business.label, 'Could not add cash. Business account was refunded.', 'error')
        return
    end

    addBusinessTransaction(src, business.id, 'withdraw', amount, note or 'Cash withdrawal')
    notify(src, business.label, 'Withdrew $' .. amount .. '.', 'success')
end

RegisterNetEvent('qbox_all_businesses:server:businessDeposit', function(businessId, amount, note)
    local src = source
    doBusinessDeposit(src, getBusiness(businessId), amount, note)
end)

RegisterNetEvent('qbox_all_businesses:server:businessWithdraw', function(businessId, amount, note)
    local src = source
    doBusinessWithdraw(src, getBusiness(businessId), amount, note)
end)

RegisterNetEvent('qbox_all_businesses:server:tabletDeposit', function(amount, note)
    local src = source
    doBusinessDeposit(src, getPlayerBusiness(src), amount, note)
end)

RegisterNetEvent('qbox_all_businesses:server:tabletWithdraw', function(amount, note)
    local src = source
    doBusinessWithdraw(src, getPlayerBusiness(src), amount, note)
end)



local function getBusinessDeliveryTime(business)
    if not business then return Config.DefaultDeliveryTimeSeconds or 180 end

    local byId = Config.BusinessDeliveryTimes and Config.BusinessDeliveryTimes[business.id]
    if byId then return tonumber(byId) or Config.DefaultDeliveryTimeSeconds or 180 end

    local byJob = Config.BusinessDeliveryTimes and Config.BusinessDeliveryTimes[business.job]
    if byJob then return tonumber(byJob) or Config.DefaultDeliveryTimeSeconds or 180 end

    return Config.DefaultDeliveryTimeSeconds or Config.DeliveryTravelTimeSeconds or 180
end


RegisterNetEvent('qbox_all_businesses:server:tabletCreateSupplyOrder', function(items)
    local src = source
    local business = getPlayerBusiness(src)
    if not business or not canOrderSupplies(src, business) then
        notify(src, 'Supplies', 'You cannot order supplies.', 'error')
        return
    end

    if type(items) ~= 'table' then return end

    local orderItems = {}
    local total = 0

    for _, entry in pairs(items) do
        local supplierItem = getBusinessSupplierItem(business.id, entry.item)
        local packs = math.floor(tonumber(entry.quantity) or 0)

        if supplierItem and packs > 0 then
            local amount = (supplierItem.amount or 1) * packs
            local lineTotal = (supplierItem.price or 0) * packs

            orderItems[#orderItems + 1] = {
                label = supplierItem.label,
                item = supplierItem.item,
                packs = packs,
                amount = amount,
                price = supplierItem.price,
                total = lineTotal
            }

            total += lineTotal
        end
    end

    if total <= 0 or #orderItems == 0 then
        notify(src, business.label, 'No supplies selected.', 'error')
        return
    end

    if getBusinessAccountBalance(business) < total then
        notify(src, business.label, 'Business account does not have enough funds.', 'error')
        return
    end

    if not removeBusinessAccountMoney(business, total, business.label .. ' Supply Order', 'Ingredient delivery order', business.label, 'Supplier') then
        notify(src, business.label, 'Could not charge the business account.', 'error')
        return
    end

    local citizenid, name = getPlayerIdentity(src)
    local readyAt = os.time() + getBusinessDeliveryTime(business)

    MySQL.insert.await([[
        INSERT INTO qbox_business_supply_orders (business, ordered_by, ordered_name, status, total, items, delivery_ready_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { business.id, citizenid, name, 'in_transit', total, json.encode(orderItems), readyAt })

    addBusinessTransaction(src, business.id, 'supply_order', total, 'Ingredient delivery order')
    notify(src, business.label, 'Supply order placed for $' .. total .. '.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:tabletClaimSupplyOrder', function(orderId)
    local src = source
    local business = getPlayerBusiness(src)
    if not business or not canOrderSupplies(src, business) then return end

    orderId = tonumber(orderId)
    if not orderId then return end

    local order = MySQL.single.await('SELECT * FROM qbox_business_supply_orders WHERE id = ? AND business = ?', { orderId, business.id })
    if not order then return notify(src, business.label, 'Order not found.', 'error') end
    if order.status ~= 'in_transit' then return notify(src, business.label, 'Order is not claimable.', 'error') end
    if os.time() < tonumber(order.delivery_ready_at or 0) then return notify(src, business.label, 'Delivery has not arrived yet.', 'error') end

    local ok, decoded = pcall(json.decode, order.items or '[]')
    if not ok then return end

    for _, item in pairs(decoded) do
        exports.ox_inventory:AddItem(src, item.item, item.amount or 1)
    end

    MySQL.update.await('UPDATE qbox_business_supply_orders SET status = ? WHERE id = ?', { 'claimed', orderId })
    addBusinessTransaction(src, business.id, 'supply_claim', 0, 'Claimed delivery #' .. orderId)
    notify(src, business.label, 'Delivery claimed.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:tabletHire', function(targetId, grade)
    local src = source
    local business = getPlayerBusiness(src)
    if not business or not canWithdraw(src, business) then return notify(src, 'Employees', 'Only management can hire.', 'error') end

    targetId = tonumber(targetId)
    grade = tonumber(grade) or 0
    if not targetId or not GetPlayerName(targetId) then return notify(src, business.label, 'Invalid player ID.', 'error') end

    exports.qbx_core:SetJob(targetId, business.job, grade)
    addBusinessTransaction(src, business.id, 'hire', 0, 'Hired ' .. getPlayerName(targetId))
    notify(src, business.label, 'Employee hired.', 'success')
    notify(targetId, business.label, 'You were hired at ' .. business.label .. '.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:tabletFire', function(targetId)
    local src = source
    local business = getPlayerBusiness(src)
    if not business or not canWithdraw(src, business) then return notify(src, 'Employees', 'Only management can fire.', 'error') end

    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return notify(src, business.label, 'Invalid player ID.', 'error') end

    local targetJob = getJob(targetId)
    if not targetJob or targetJob.name ~= business.job then return notify(src, business.label, 'That player does not work here.', 'error') end

    exports.qbx_core:SetJob(targetId, 'unemployed', 0)
    addBusinessTransaction(src, business.id, 'fire', 0, 'Fired ' .. getPlayerName(targetId))
    notify(src, business.label, 'Employee fired.', 'success')
    notify(targetId, business.label, 'You were fired from ' .. business.label .. '.', 'error')
end)

RegisterNetEvent('qbox_all_businesses:server:tabletSetRank', function(targetId, grade)
    local src = source
    local business = getPlayerBusiness(src)
    if not business or not canWithdraw(src, business) then return notify(src, 'Employees', 'Only management can change ranks.', 'error') end

    targetId = tonumber(targetId)
    grade = tonumber(grade) or 0
    if not targetId or not GetPlayerName(targetId) then return notify(src, business.label, 'Invalid player ID.', 'error') end

    local targetJob = getJob(targetId)
    if not targetJob or targetJob.name ~= business.job then return notify(src, business.label, 'That player does not work here.', 'error') end

    exports.qbx_core:SetJob(targetId, business.job, grade)
    addBusinessTransaction(src, business.id, 'rank', 0, 'Changed rank for ' .. getPlayerName(targetId))
    notify(src, business.label, 'Rank changed.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:tabletAddMenuItem', function(stationId, data)
    local src = source
    local business = getPlayerBusiness(src)
    if not business or not canWithdraw(src, business) then return notify(src, 'Menu', 'Only management can edit menus.', 'error') end

    local station = getAnyStation(business, stationId)
    if not station or (station.type ~= 'food' and station.type ~= 'drink') then return end

    local label = tostring(data.label or '')
    local item = tostring(data.item or '')
    if label == '' or item == '' then return notify(src, business.label, 'Label and item name are required.', 'error') end

    local items = getStationItems(business.id, station.id)
    items[#items + 1] = {
        label = label,
        item = item,
        amount = tonumber(data.amount) or 1,
        price = tonumber(data.price) or 0,
        time = tonumber(data.time) or 2500,
        ingredients = parseIngredients(data.ingredients)
    }

    setStationItems(business.id, station.id, items)
    saveStationItems(business.id, station.id)
    notify(src, business.label, 'Menu item added.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:tabletRemoveMenuItem', function(stationId, index)
    local src = source
    local business = getPlayerBusiness(src)
    if not business or not canWithdraw(src, business) then return notify(src, 'Menu', 'Only management can edit menus.', 'error') end

    local station = getAnyStation(business, stationId)
    if not station then return end

    local items = getStationItems(business.id, station.id)
    index = tonumber(index)
    if not index or not items[index] then return end

    table.remove(items, index)
    setStationItems(business.id, station.id, items)
    saveStationItems(business.id, station.id)
    notify(src, business.label, 'Menu item removed.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:craft', function(businessId, stationId, itemIndex)
    local src = source
    local business = getBusiness(businessId)
    local station = getAnyStation(business, stationId)
    if not business or not station or not hasBusinessJob(src, business, false) then return end
    if not canUseStationByJob(src, business, station, false) then
        notify(src, business.label, 'You do not have access to this crafting station.', 'error')
        return
    end

    local items = getStationItems(business.id, station.id)
    local recipe = items[tonumber(itemIndex)]
    if not recipe then return end

    if not Config.FreeStationItems then
        for item, amount in pairs(recipe.ingredients or {}) do
            if (exports.ox_inventory:GetItemCount(src, item) or 0) < amount then
                return notify(src, business.label, 'Missing ingredient: ' .. item, 'error')
            end
        end

        for item, amount in pairs(recipe.ingredients or {}) do
            exports.ox_inventory:RemoveItem(src, item, amount)
        end
    end

    if recipe.time and recipe.time > 0 then Wait(recipe.time) end
    exports.ox_inventory:AddItem(src, recipe.item, recipe.amount or 1)
    notify(src, business.label, 'Created ' .. (recipe.label or recipe.item), 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:tabletOpenStash', function(stationId)
    local src = source
    local business = getPlayerBusiness(src)
    local station = getAnyStation(business, stationId)
    if not business or not station then return end
    if not canUseStationByJob(src, business, station, false) then
        notify(src, business.label, 'You do not have access to this station.', 'error')
        return
    end
    if station.type ~= 'stash' and station.type ~= 'fridge' then return end

    TriggerClientEvent('qbox_all_businesses:client:tabletOpenStash', src, business.id .. '_' .. station.id)
end)

local function isAllowedDjUrl(url)
    local lower = string.lower(tostring(url or ''))
    if Config.AllowYoutubeLinks and (lower:find('youtube.com', 1, true) or lower:find('youtu.be', 1, true) or lower:find('music.youtube.com', 1, true)) then return true end
    if Config.AllowSpotifyLinks and lower:find('spotify.com', 1, true) then return true end
    return false
end

local function djSoundId(businessId, stationId)
    return ('business_dj_%s_%s'):format(businessId, stationId)
end




RegisterNetEvent('qbox_all_businesses:server:tabletDeleteStation', function(stationId)
    local src = source
    local business = getPlayerBusiness(src)
    if not business then return end

    stationId = tostring(stationId or '')
    if stationId == '' then return end

    local station
    local stationIndex

    for index, data in pairs(DynamicBusinessStations[business.id] or {}) do
        if data.id == stationId then
            station = data
            stationIndex = index
            break
        end
    end

    if not station then
        notify(src, business.label, 'Only placed stations can be deleted.', 'error')
        return
    end

    if not canDeleteStation(src, business, station) then
        notify(src, business.label, 'You do not have permission to delete this station.', 'error')
        return
    end

    MySQL.update.await('DELETE FROM qbox_business_stations WHERE business = ? AND station_id = ?', {
        business.id,
        stationId
    })

    -- Backwards compatibility for old placed DJ booths.
    if station.type == 'dj' then
        MySQL.update.await('DELETE FROM qbox_business_dj_booths WHERE business = ? AND booth_id = ?', {
            business.id,
            stationId
        })
    end

    table.remove(DynamicBusinessStations[business.id], stationIndex)

    notify(src, business.label, 'Station deleted. Restart the resource if the old E prompt/target does not disappear immediately.', 'success')
    TriggerClientEvent('qbox_all_businesses:client:removePlacedStation', -1, business.id, stationId)
end)


RegisterNetEvent('qbox_all_businesses:server:tabletPlaceStation', function(data)
    local src = source
    local business = getPlayerBusiness(src)

    if not business or not canPlaceStation(src, business) then
        notify(src, 'Stations', 'You do not have permission to place stations.', 'error')
        return
    end

    data = data or {}
    local stationType = tostring(data.type or ''):lower()
    local allowed = false

    for _, allowedType in pairs(Config.PlaceableStationTypes or {}) do
        if stationType == allowedType then
            allowed = true
            break
        end
    end

    if not allowed then
        notify(src, business.label, 'Invalid station type.', 'error')
        return
    end

    local coords = data.coords or {}
    if not coords.x or not coords.y or not coords.z then
        notify(src, business.label, 'Invalid station location.', 'error')
        return
    end

    local label = tostring(data.label or stationType)
    local stationId = tostring(data.stationId or (stationType .. '_' .. os.time() .. '_' .. math.random(1000, 9999))):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    local rotation = tonumber(data.rotation) or 0.0

    local size = {
        x = tonumber(data.sizeX) or 1.4,
        y = tonumber(data.sizeY) or 1.4,
        z = tonumber(data.sizeZ) or 1.0
    }

    local settings = {
        size = size
    }

    if stationType == 'stash' then
        settings.slots = tonumber(data.slots) or Config.DefaultPlacedStashSlots or 60
        settings.weight = tonumber(data.weight) or Config.DefaultPlacedStashWeight or 150000
    elseif stationType == 'fridge' then
        settings.slots = tonumber(data.slots) or Config.DefaultPlacedFridgeSlots or 60
        settings.weight = tonumber(data.weight) or Config.DefaultPlacedFridgeWeight or 150000
    elseif stationType == 'dj' then
        settings.useRadius = tonumber(data.useRadius) or Config.DefaultPlacedDJUseRadius or 2.0
        settings.hearRadius = tonumber(data.hearRadius) or Config.DefaultPlacedDJHearRadius or 45.0
    elseif stationType == 'food' or stationType == 'drink' then
        settings.items = {}
    elseif stationType == 'menu_editor' or stationType == 'business_ui' then
        settings.bossOnly = stationType == 'menu_editor'
    end

    local _, createdBy = getPlayerIdentity(src)

    MySQL.insert.await([[
        INSERT INTO qbox_business_stations
        (business, job, station_id, type, label, coords, rotation, settings, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        business.id,
        business.job,
        stationId,
        stationType,
        label,
        json.encode({ x = coords.x, y = coords.y, z = coords.z }),
        rotation,
        json.encode(settings),
        createdBy
    })

    local station = {
        id = stationId,
        job = business.job,
        accessJob = business.job,
        type = stationType,
        label = label,
        coords = vec3(coords.x, coords.y, coords.z),
        size = vec3(size.x, size.y, size.z),
        rotation = rotation,
        dynamic = true
    }

    for k, v in pairs(settings) do
        if k ~= 'size' then station[k] = v end
    end

    DynamicBusinessStations[business.id] = DynamicBusinessStations[business.id] or {}
    DynamicBusinessStations[business.id][#DynamicBusinessStations[business.id] + 1] = station

    if stationType == 'stash' or stationType == 'fridge' then
        exports.ox_inventory:RegisterStash(
            business.id .. '_' .. stationId,
            business.label .. ' - ' .. label,
            station.slots or 60,
            station.weight or 150000,
            false
        )
    end

    notify(src, business.label, label .. ' placed and saved.', 'success')

    TriggerClientEvent('qbox_all_businesses:client:addPlacedStationZone', -1, business.id, business.job, {
        id = stationId,
        job = business.job,
        accessJob = business.job,
        type = stationType,
        label = label,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        size = size,
        rotation = rotation,
        useRadius = station.useRadius,
        hearRadius = station.hearRadius,
        bossOnly = station.bossOnly
    })
end)


RegisterNetEvent('qbox_all_businesses:server:tabletPlaceDJBooth', function(data)
    local src = source
    local business = getPlayerBusiness(src)

    if not business or not canPlaceStation(src, business) then
        notify(src, 'DJ Booths', 'You do not have permission to place DJ booths.', 'error')
        return
    end

    data = data or {}
    data.type = 'dj'
    data.label = tostring(data.label or Config.DefaultPlacedDJLabel or 'DJ Booth')
    data.stationId = tostring(data.stationId or ('dj_' .. os.time() .. '_' .. math.random(1000, 9999))):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')

    local coords = data.coords or {}
    if not coords.x or not coords.y or not coords.z then
        notify(src, business.label, 'Invalid DJ booth location.', 'error')
        return
    end

    local rotation = tonumber(data.rotation) or 0.0
    local useRadius = math.max(1.0, math.min(10.0, tonumber(data.useRadius) or Config.DefaultPlacedDJUseRadius or 2.0))
    local hearRadius = math.max(5.0, math.min(150.0, tonumber(data.hearRadius) or Config.DefaultPlacedDJHearRadius or 45.0))

    local size = {
        x = tonumber(data.sizeX) or 1.4,
        y = tonumber(data.sizeY) or 1.4,
        z = tonumber(data.sizeZ) or 1.0
    }

    local settings = {
        size = size,
        useRadius = useRadius,
        hearRadius = hearRadius
    }

    local _, createdBy = getPlayerIdentity(src)

    MySQL.insert.await([[
        INSERT INTO qbox_business_stations
        (business, job, station_id, type, label, coords, rotation, settings, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        business.id,
        business.job,
        data.stationId,
        'dj',
        data.label,
        json.encode({ x = coords.x, y = coords.y, z = coords.z }),
        rotation,
        json.encode(settings),
        createdBy
    })

    local station = {
        id = data.stationId,
        job = business.job,
        accessJob = business.job,
        type = 'dj',
        label = data.label,
        coords = vec3(coords.x, coords.y, coords.z),
        size = vec3(size.x, size.y, size.z),
        rotation = rotation,
        useRadius = useRadius,
        hearRadius = hearRadius,
        dynamic = true
    }

    DynamicBusinessStations[business.id] = DynamicBusinessStations[business.id] or {}
    DynamicBusinessStations[business.id][#DynamicBusinessStations[business.id] + 1] = station

    notify(src, business.label, 'DJ booth placed and saved.', 'success')

    TriggerClientEvent('qbox_all_businesses:client:addPlacedStationZone', -1, business.id, business.job, {
        id = station.id,
        job = business.job,
        accessJob = business.job,
        type = 'dj',
        label = station.label,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        size = size,
        rotation = rotation,
        useRadius = useRadius,
        hearRadius = hearRadius
    })
end)


RegisterNetEvent('qbox_all_businesses:server:tabletDjPlay', function(stationId, url, volume)
    local src = source
    local business = getPlayerBusiness(src)
    local station = getAnyStation(business, stationId)
    if not business or not station or station.type ~= 'dj' then return end
    if not canUseStationByJob(src, business, station, false) then
        notify(src, business.label, 'You do not have access to this DJ booth.', 'error')
        return
    end
    if not isAllowedDjUrl(url) then return notify(src, business.label, 'Only YouTube or Spotify links are allowed.', 'error') end

    local vol = math.max(1, math.min(100, tonumber(volume) or 25)) / 100.0

    TriggerClientEvent('qbox_all_businesses:client:djPlay', -1, {
        soundId = djSoundId(business.id, station.id),
        url = url,
        volume = vol,
        coords = station.coords,
        hearRadius = station.hearRadius or Config.DefaultDJHearRadius or 35.0
    })

    notify(src, business.label, 'DJ started.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:tabletDjStop', function(stationId)
    local src = source
    local business = getPlayerBusiness(src)
    if not business then return end
    TriggerClientEvent('qbox_all_businesses:client:djStop', -1, djSoundId(business.id, stationId))
    notify(src, business.label, 'DJ stopped.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:tabletDjVolume', function(stationId, volume)
    local src = source
    local business = getPlayerBusiness(src)
    if not business then return end
    local vol = math.max(1, math.min(100, tonumber(volume) or 25)) / 100.0
    TriggerClientEvent('qbox_all_businesses:client:djVolume', -1, djSoundId(business.id, stationId), vol)
end)

RegisterNetEvent('qbox_all_businesses:server:bill', function(businessId, targetId, amount, account, reason)
    local src = source
    local business = getBusiness(businessId)

    if not business or not hasBusinessJob(src, business, false) then
        notify(src, 'Register', 'You do not have access to this register.', 'error')
        return
    end

    targetId = tonumber(targetId)
    amount = math.floor(tonumber(amount) or 0)
    account = tostring(account or 'cash'):lower()
    reason = tostring(reason or 'Business purchase')

    if account ~= 'cash' and account ~= 'bank' then
        notify(src, business.label, 'Payment method must be cash or bank.', 'error')
        return
    end

    if not targetId or targetId <= 0 or not GetPlayerName(targetId) then
        notify(src, business.label, 'Invalid customer server ID.', 'error')
        return
    end

    if amount <= 0 then
        notify(src, business.label, 'Invalid charge amount.', 'error')
        return
    end

    local balance = exports.qbx_core:GetMoney(targetId, account) or 0
    if balance < amount then
        notify(src, business.label, 'Customer does not have enough ' .. account .. '.', 'error')
        notify(targetId, business.label, 'You do not have enough ' .. account .. ' for this charge.', 'error')
        return
    end

    local removed = exports.qbx_core:RemoveMoney(targetId, account, amount, 'business-register-charge')
    if not removed then
        notify(src, business.label, 'Could not charge the customer.', 'error')
        return
    end

    local added = addBusinessAccountMoney(
        business,
        amount,
        business.label .. ' Register Charge',
        reason,
        getPlayerName(targetId),
        business.label
    )

    if not added then
        exports.qbx_core:AddMoney(targetId, account, amount, 'business-register-refund')
        notify(src, business.label, 'Business account deposit failed. Customer was refunded.', 'error')
        notify(targetId, business.label, 'The charge failed and was refunded.', 'error')
        return
    end

    addBusinessTransaction(src, business.id, 'register_charge', amount, ('%s via %s from %s'):format(reason, account, getPlayerName(targetId)))

    notify(src, business.label, ('Charged %s $%s from %s.'):format(getPlayerName(targetId), amount, account), 'success')
    notify(targetId, business.label, ('You were charged $%s from %s for %s.'):format(amount, account, reason), 'success')
end)


RegisterCommand('businessgivetablet', function(src)
    if src == 0 then return end
    if not IsPlayerAceAllowed(src, 'qboxbusiness.admin') then
        notify(src, 'Business Tablet', 'You do not have permission.', 'error')
        return
    end

    exports.ox_inventory:AddItem(src, Config.TabletItem or 'business_tablet', 1)
    notify(src, 'Business Tablet', 'Tablet item added.', 'success')
end, false)


-- Admin Panel

local function getPlayerDiscordId(src)
    for _, identifier in pairs(GetPlayerIdentifiers(src)) do
        local discordId = identifier:match('discord:(%d+)')
        if discordId then
            return discordId
        end
    end

    return nil
end

local function isDiscordAdmin(src)
    if not Config.AdminPanelUseDiscordIds then return false end

    local discordId = getPlayerDiscordId(src)
    if not discordId then return false end

    for _, allowedId in pairs(Config.AdminPanelDiscordIds or {}) do
        allowedId = tostring(allowedId):gsub('discord:', '')
        if discordId == allowedId then
            return true
        end
    end

    return false
end



local function isAceGroupAllowed(src)
    if not Config.AdminPanelAllowAceGroups then return false end

    for _, aceName in pairs(Config.AdminPanelAceGroups or {}) do
        if IsPlayerAceAllowed(src, aceName) then
            return true
        end
    end

    return false
end

local function isBusinessAdmin(src)
    if not Config.EnableAdminPanel then return false end
    if src == 0 then return true end

    -- Discord allowlist support.
    if isDiscordAdmin and isDiscordAdmin(src) then
        return true
    end

    -- Standard FiveM ACE permission.
    if IsPlayerAceAllowed(src, Config.AdminPanelAce or 'qboxbusiness.admin') then
        return true
    end

    -- FiveM command ACE, useful with:
    -- add_ace group.admin command.businessadmin allow
    if IsPlayerAceAllowed(src, Config.AdminPanelCommandAce or 'command.businessadmin') then
        return true
    end

    -- Optional group ACE checks.
    if isAceGroupAllowed(src) then
        return true
    end

    return false
end


local function numberOrDefault(value, default)
    local n = tonumber(value)
    if n == nil then return default end
    return n
end

local function boolFromAdmin(value, default)
    if value == nil then return default end
    if value == true or value == 'true' or value == 1 or value == '1' or value == 'on' then return true end
    if value == false or value == 'false' or value == 0 or value == '0' then return false end
    return default
end

local function tableCoords(coords)
    if not coords then return nil end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

local function getFirstBusinessStationCoords(business)
    for _, station in pairs(getAllBusinessStations(business) or {}) do
        if station.coords then
            return tableCoords(station.coords)
        end
    end
    return nil
end

local function makeBusinessBlipFromAdminData(data, business)
    data = data or {}
    local current = business and business.blip or {}

    local coords = nil
    if data.blipCoords and tonumber(data.blipCoords.x) and tonumber(data.blipCoords.y) and tonumber(data.blipCoords.z) then
        coords = {
            x = numberOrDefault(data.blipCoords.x, 0.0),
            y = numberOrDefault(data.blipCoords.y, 0.0),
            z = numberOrDefault(data.blipCoords.z, 0.0)
        }
    elseif tonumber(data.blipX) and tonumber(data.blipY) and tonumber(data.blipZ) then
        coords = {
            x = numberOrDefault(data.blipX, 0.0),
            y = numberOrDefault(data.blipY, 0.0),
            z = numberOrDefault(data.blipZ, 0.0)
        }
    elseif current and current.coords then
        coords = tableCoords(current.coords)
    end

    return {
        enabled = boolFromAdmin(data.blipEnabled, current.enabled ~= false),
        label = tostring(data.blipLabel or current.label or (business and business.label) or data.label or ''),
        sprite = math.floor(numberOrDefault(data.blipSprite, current.sprite or Config.BusinessBlipDefaultSprite or 439)),
        color = math.floor(numberOrDefault(data.blipColor, current.color or Config.BusinessBlipDefaultColor or 2)),
        scale = numberOrDefault(data.blipScale, current.scale or Config.BusinessBlipDefaultScale or 0.75),
        shortRange = boolFromAdmin(data.blipShortRange, current.shortRange ~= nil and current.shortRange or Config.BusinessBlipShortRange ~= false),
        coords = coords
    }
end


local function saveDynamicBusinessToDatabase(business)
    if not business or not business.id then return false end
    ensureDynamicBusinessesTable()

    local ok, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO qbox_dynamic_businesses (id, label, type, job, ui, blip)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                label = VALUES(label),
                type = VALUES(type),
                job = VALUES(job),
                ui = VALUES(ui),
                blip = VALUES(blip)
        ]], {
            business.id,
            business.label or business.id,
            business.type or 'business',
            business.job or business.id,
            json.encode(business.ui or {}),
            json.encode(business.blip or {})
        })
    end)

    if not ok then
        print(('[qbox_all_businesses] Failed to save dynamic business %s: %s'):format(tostring(business.id), tostring(err)))
        return false
    end

    return true
end

local function getBusinessBlipPayload()
    local list = {}

    for _, business in pairs(Config.Businesses or {}) do
        local blip = business.blip or {}
        if blip and blip.coords and blip.enabled ~= false then
            local coords = tableCoords(blip.coords) or getFirstBusinessStationCoords(business)
            if coords then
                list[#list + 1] = {
                    id = business.id,
                    label = blip.label or business.label,
                    job = business.job,
                    blip = {
                        enabled = blip.enabled ~= false,
                        label = blip.label or business.label,
                        sprite = tonumber(blip.sprite) or Config.BusinessBlipDefaultSprite or 439,
                        color = tonumber(blip.color) or Config.BusinessBlipDefaultColor or 2,
                        scale = tonumber(blip.scale) or Config.BusinessBlipDefaultScale or 0.75,
                        shortRange = blip.shortRange ~= nil and blip.shortRange or Config.BusinessBlipShortRange ~= false,
                        coords = coords
                    }
                }
            end
        end
    end

    return list
end

local function getSingleBusinessBlipPayload(business)
    if not business then return nil end
    local blip = business.blip or {}
    if blip.enabled == false then return nil end

    local coords = tableCoords(blip.coords) or getFirstBusinessStationCoords(business)
    if not coords then return nil end

    return {
        id = business.id,
        label = blip.label or business.label,
        job = business.job,
        blip = {
            enabled = blip.enabled ~= false,
            label = blip.label or business.label,
            sprite = tonumber(blip.sprite) or Config.BusinessBlipDefaultSprite or 439,
            color = tonumber(blip.color) or Config.BusinessBlipDefaultColor or 2,
            scale = tonumber(blip.scale) or Config.BusinessBlipDefaultScale or 0.75,
            shortRange = blip.shortRange ~= nil and blip.shortRange or Config.BusinessBlipShortRange ~= false,
            coords = coords
        }
    }
end

local function broadcastSingleBusinessBlip(business)
    local payload = getSingleBusinessBlipPayload(business)
    if payload then
        TriggerClientEvent('qbox_all_businesses:client:updateBusinessBlipNow', -1, payload)
    elseif business and business.id then
        TriggerClientEvent('qbox_all_businesses:client:removeBusinessBlipNow', -1, business.id)
    end
end


local function broadcastBusinessBlips()
    TriggerClientEvent('qbox_all_businesses:client:setBusinessBlips', -1, getBusinessBlipPayload())
end


local function getAdminBusinessPayload()
    local list = {}

    for _, business in pairs(Config.Businesses or {}) do
        local allStations = {}

        for _, station in pairs(getAllBusinessStations(business)) do
            allStations[#allStations + 1] = {
                id = station.id,
                type = station.type,
                label = station.label,
                dynamic = station.dynamic == true,
                job = station.job or business.job,
                accessJob = station.accessJob or station.job or business.job,
                coords = station.coords and { x = station.coords.x, y = station.coords.y, z = station.coords.z } or nil,
                rotation = station.rotation or 0.0,
                useRadius = station.useRadius,
                hearRadius = station.hearRadius,
                slots = station.slots,
                weight = station.weight,
                bossOnly = station.bossOnly
            }
        end

        list[#list + 1] = {
            id = business.id,
            label = business.label,
            type = business.type,
            job = business.job,
            dynamic = business.dynamic == true,
            ui = business.ui or {},
            blip = business.blip or {},
            stationCount = #allStations,
            stations = allStations,
            balance = getBusinessAccountBalance(business),
            supplyItems = getBusinessSupplyStoreItems(business.id, true)
        }
    end

    table.sort(list, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)

    return list
end


lib.callback.register('qbox_all_businesses:server:getBusinessBlips', function(_)
    return getBusinessBlipPayload()
end)

lib.callback.register('qbox_all_businesses:server:isAdminPanelAllowed', function(src)
    return isBusinessAdmin(src)
end)

lib.callback.register('qbox_all_businesses:server:getAdminPanelData', function(src)
    if not isBusinessAdmin(src) then return nil end

    return {
        businesses = getAdminBusinessPayload(),
        supplyItems = getSupplyStoreItems(true),
        placeableTypes = Config.PlaceableStationTypes or {
            'stash', 'fridge', 'register', 'food', 'drink', 'menu_editor', 'business_ui', 'delivery', 'dj'
        },
        settings = {
            canEditStatic = Config.AdminPanelCanEditStaticBusinesses == true,
            canDeleteDynamicStations = Config.AdminPanelCanDeleteDynamicStations ~= false
        }
    }
end)


local function buildAdminResult(ok, message)
    return {
        ok = ok == true,
        message = message or '',
        adminData = {
            businesses = getAdminBusinessPayload(),
            supplyItems = getSupplyStoreItems(true),
            placeableTypes = Config.PlaceableStationTypes or {
                'stash', 'fridge', 'register', 'food', 'drink', 'menu_editor', 'business_ui', 'delivery', 'dj'
            },
            settings = {
                canEditStatic = Config.AdminPanelCanEditStaticBusinesses == true,
                canDeleteDynamicStations = Config.AdminPanelCanDeleteDynamicStations ~= false
            }
        },
        blips = getBusinessBlipPayload()
    }
end

lib.callback.register('qbox_all_businesses:server:adminUpdateBusinessImmediate', function(src, businessId, data)
    if not isBusinessAdmin(src) then
        notify(src, 'Business Admin', 'You do not have permission.', 'error')
        return buildAdminResult(false, 'no_permission')
    end

    data = data or {}

    local business = getBusiness(businessId)
    if not business then
        notify(src, 'Business Admin', 'Business not found.', 'error')
        return buildAdminResult(false, 'not_found')
    end

    business.label = tostring(data.label or business.label)
    business.type = tostring(data.type or business.type)
    business.job = tostring(data.job or business.job)

    business.ui = business.ui or {}
    business.ui.title = tostring(data.uiTitle or business.ui.title or (business.label .. ' Tablet'))
    business.ui.primaryColor = tostring(data.primaryColor or business.ui.primaryColor or '#38bdf8')

    business.blip = makeBusinessBlipFromAdminData(data, business)

    local saved = saveDynamicBusinessToDatabase(business)
    broadcastSingleBusinessBlip(business)
    broadcastBusinessBlips()

    notify(src, 'Business Admin', saved and 'Business updated and blip moved on the map.' or 'Business updated, but database save failed. Check server console.', saved and 'success' or 'error')
    return buildAdminResult(saved, saved and 'saved' or 'db_failed')
end)

lib.callback.register('qbox_all_businesses:server:adminCreateBusinessImmediate', function(src, data)
    if not isBusinessAdmin(src) or not Config.AdminCanCreateDeleteBusinesses then
        notify(src, 'Business Admin', 'You do not have permission.', 'error')
        return buildAdminResult(false, 'no_permission')
    end

    data = data or {}

    local id = tostring(data.id or ''):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    local label = tostring(data.label or id)
    local businessType = tostring(data.type or 'business')
    local job = tostring(data.job or id):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    local uiTitle = tostring(data.uiTitle or (label .. ' Tablet'))
    local primaryColor = tostring(data.primaryColor or '#38bdf8')

    if id == '' or job == '' then
        notify(src, 'Business Admin', 'Business ID and job are required.', 'error')
        return buildAdminResult(false, 'missing_id_or_job')
    end

    if businessExists(id) then
        notify(src, 'Business Admin', 'A business with that ID already exists.', 'error')
        return buildAdminResult(false, 'already_exists')
    end

    ensureDynamicBusinessesTable()

    local ui = {
        title = uiTitle,
        primaryColor = primaryColor
    }

    local blip = makeBusinessBlipFromAdminData(data, {
        id = id,
        label = label,
        type = businessType,
        job = job,
        ui = ui,
        blip = {}
    })

    local business = {
        id = id,
        label = label,
        type = businessType,
        job = job,
        ui = ui,
        blip = blip or {},
        stations = {},
        dynamic = true
    }

    local saved = saveDynamicBusinessToDatabase(business)
    if not saved then
        notify(src, 'Business Admin', 'Business was created in memory, but the database save failed. Check server console.', 'error')
        return buildAdminResult(false, 'db_failed')
    end

    Config.Businesses[#Config.Businesses + 1] = business
    DynamicBusinessStations[id] = DynamicBusinessStations[id] or {}

    if seedBusinessSupplyStore then
        seedBusinessSupplyStore(id)
    end

    pcall(function()
        MySQL.insert.await('INSERT IGNORE INTO qbox_business_accounts (business, balance) VALUES (?, ?)', { id, 0 })
    end)

    broadcastSingleBusinessBlip(business)
    broadcastBusinessBlips()
    notify(src, 'Business Admin', 'Business created and blip placed on the map: ' .. label, 'success')
    return buildAdminResult(true, 'saved')
end)

RegisterNetEvent('qbox_all_businesses:server:adminUpdateBusiness', function(businessId, data)
    local src = source
    if not isBusinessAdmin(src) then
        notify(src, 'Business Admin', 'You do not have permission.', 'error')
        return
    end

    local business = getBusiness(businessId)
    if not business then
        notify(src, 'Business Admin', 'Business not found.', 'error')
        return
    end

    business.label = tostring(data.label or business.label)
    business.type = tostring(data.type or business.type)
    business.job = tostring(data.job or business.job)

    business.ui = business.ui or {}
    business.ui.title = tostring(data.uiTitle or business.ui.title or (business.label .. ' Tablet'))
    business.ui.primaryColor = tostring(data.primaryColor or business.ui.primaryColor or '#38bdf8')

    business.blip = makeBusinessBlipFromAdminData(data, business)

    local saved = saveDynamicBusinessToDatabase(business)

    broadcastSingleBusinessBlip(business)
    broadcastBusinessBlips()
    notify(src, 'Business Admin', saved and 'Business updated and blip saved.' or 'Business updated, but database save failed. Check server console.', saved and 'success' or 'error')
end)

RegisterNetEvent('qbox_all_businesses:server:adminTeleportToStation', function(businessId, stationId)
    local src = source
    if not isBusinessAdmin(src) then return end

    local business = getBusiness(businessId)
    local station = getAnyStation(business, stationId)
    if not station or not station.coords then
        notify(src, 'Business Admin', 'Station not found.', 'error')
        return
    end

    TriggerClientEvent('qbox_all_businesses:client:adminTeleport', src, {
        x = station.coords.x,
        y = station.coords.y,
        z = station.coords.z
    })
end)

RegisterNetEvent('qbox_all_businesses:server:adminDeleteStation', function(businessId, stationId)
    local src = source
    if not isBusinessAdmin(src) then
        notify(src, 'Business Admin', 'You do not have permission.', 'error')
        return
    end

    local business = getBusiness(businessId)
    if not business then return end

    stationId = tostring(stationId or '')
    local station
    local stationIndex

    for index, data in pairs(DynamicBusinessStations[business.id] or {}) do
        if data.id == stationId then
            station = data
            stationIndex = index
            break
        end
    end

    if not station then
        notify(src, business.label, 'Only placed/dynamic stations can be deleted from the admin panel.', 'error')
        return
    end

    MySQL.update.await('DELETE FROM qbox_business_stations WHERE business = ? AND station_id = ?', {
        business.id,
        stationId
    })

    if station.type == 'dj' then
        MySQL.update.await('DELETE FROM qbox_business_dj_booths WHERE business = ? AND booth_id = ?', {
            business.id,
            stationId
        })
    end

    table.remove(DynamicBusinessStations[business.id], stationIndex)

    TriggerClientEvent('qbox_all_businesses:client:removePlacedStation', -1, business.id, stationId)
    notify(src, 'Business Admin', 'Station deleted.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:adminPlaceStation', function(businessId, data)
    local src = source
    if not isBusinessAdmin(src) then
        notify(src, 'Business Admin', 'You do not have permission.', 'error')
        return
    end

    local business = getBusiness(businessId)
    if not business then
        notify(src, 'Business Admin', 'Business not found.', 'error')
        return
    end

    -- Reuse station placement logic with explicit business by temporarily duplicating the safe insert path.
    data = data or {}
    local stationType = tostring(data.type or ''):lower()
    local allowed = false

    for _, allowedType in pairs(Config.PlaceableStationTypes or {}) do
        if stationType == allowedType then
            allowed = true
            break
        end
    end

    if not allowed then
        notify(src, 'Business Admin', 'Invalid station type.', 'error')
        return
    end

    local coords = data.coords or {}
    if not coords.x or not coords.y or not coords.z then
        notify(src, 'Business Admin', 'Invalid station location.', 'error')
        return
    end

    local label = tostring(data.label or stationType)
    local stationId = tostring(data.stationId or (stationType .. '_' .. os.time() .. '_' .. math.random(1000, 9999))):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    local rotation = tonumber(data.rotation) or 0.0

    local size = {
        x = tonumber(data.sizeX) or 1.4,
        y = tonumber(data.sizeY) or 1.4,
        z = tonumber(data.sizeZ) or 1.0
    }

    local settings = { size = size }

    if stationType == 'stash' then
        settings.slots = tonumber(data.slots) or Config.DefaultPlacedStashSlots or 60
        settings.weight = tonumber(data.weight) or Config.DefaultPlacedStashWeight or 150000
    elseif stationType == 'fridge' then
        settings.slots = tonumber(data.slots) or Config.DefaultPlacedFridgeSlots or 60
        settings.weight = tonumber(data.weight) or Config.DefaultPlacedFridgeWeight or 150000
    elseif stationType == 'dj' then
        settings.useRadius = tonumber(data.useRadius) or Config.DefaultPlacedDJUseRadius or 2.0
        settings.hearRadius = tonumber(data.hearRadius) or Config.DefaultPlacedDJHearRadius or 45.0
    elseif stationType == 'food' or stationType == 'drink' then
        settings.items = {}
    elseif stationType == 'menu_editor' or stationType == 'business_ui' then
        settings.bossOnly = stationType == 'menu_editor'
    end

    local _, createdBy = getPlayerIdentity(src)

    MySQL.insert.await([[
        INSERT INTO qbox_business_stations
        (business, job, station_id, type, label, coords, rotation, settings, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        business.id,
        business.job,
        stationId,
        stationType,
        label,
        json.encode({ x = coords.x, y = coords.y, z = coords.z }),
        rotation,
        json.encode(settings),
        createdBy
    })

    local station = {
        id = stationId,
        job = business.job,
        accessJob = business.job,
        type = stationType,
        label = label,
        coords = vec3(coords.x, coords.y, coords.z),
        size = vec3(size.x, size.y, size.z),
        rotation = rotation,
        dynamic = true
    }

    for k, v in pairs(settings) do
        if k ~= 'size' then station[k] = v end
    end

    DynamicBusinessStations[business.id] = DynamicBusinessStations[business.id] or {}
    DynamicBusinessStations[business.id][#DynamicBusinessStations[business.id] + 1] = station

    if stationType == 'stash' or stationType == 'fridge' then
        exports.ox_inventory:RegisterStash(
            business.id .. '_' .. stationId,
            business.label .. ' - ' .. label,
            station.slots or 60,
            station.weight or 150000,
            false
        )
    end

    TriggerClientEvent('qbox_all_businesses:client:addPlacedStationZone', -1, business.id, business.job, {
        id = stationId,
        job = business.job,
        accessJob = business.job,
        type = stationType,
        label = label,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        size = size,
        rotation = rotation,
        useRadius = station.useRadius,
        hearRadius = station.hearRadius,
        bossOnly = station.bossOnly
    })

    notify(src, 'Business Admin', 'Station placed for ' .. business.label .. '.', 'success')
end)



lib.callback.register('qbox_all_businesses:server:getAdminSupplyItems', function(src)
    if not isBusinessAdmin(src) then return {} end
    return getSupplyStoreItems(true)
end)

RegisterNetEvent('qbox_all_businesses:server:adminSaveSupplyItem', function(data)
    local src = source
    if not isBusinessAdmin(src) or not Config.AdminCanEditSupplyStore then
        notify(src, 'Supply Store', 'You do not have permission.', 'error')
        return
    end

    data = data or {}
    local item = tostring(data.item or ''):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    local label = tostring(data.label or item)
    local price = math.max(0, math.floor(tonumber(data.price) or 0))
    local amount = math.max(1, math.floor(tonumber(data.amount) or 1))
    local enabled = data.enabled == nil and true or data.enabled == true

    if item == '' then
        notify(src, 'Supply Store', 'Item name is required.', 'error')
        return
    end

    MySQL.insert.await([[
        INSERT INTO qbox_business_supply_items (item, label, price, amount, enabled)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            label = VALUES(label),
            price = VALUES(price),
            amount = VALUES(amount),
            enabled = VALUES(enabled)
    ]], { item, label, price, amount, enabled and 1 or 0 })

    initSupplyStore()
    notify(src, 'Supply Store', 'Supply item saved.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:adminDeleteSupplyItem', function(itemName)
    local src = source
    if not isBusinessAdmin(src) or not Config.AdminCanEditSupplyStore then
        notify(src, 'Supply Store', 'You do not have permission.', 'error')
        return
    end

    itemName = tostring(itemName or ''):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    if itemName == '' then return end

    MySQL.update.await('DELETE FROM qbox_business_supply_items WHERE item = ?', { itemName })
    initSupplyStore()
    notify(src, 'Supply Store', 'Supply item deleted.', 'success')
end)



RegisterCommand('businessadmin_server', function(src)
    if src == 0 then return end
    if isBusinessAdmin and isBusinessAdmin(src) then
        TriggerClientEvent('qbox_all_businesses:client:openAdminPanel', src)
    else
        notify(src, 'Business Admin', 'You do not have permission.', 'error')
    end
end, false)


RegisterNetEvent('qbox_all_businesses:server:adminSaveBusinessSupplyItem', function(data)
    local src = source
    if not isBusinessAdmin(src) or not Config.AdminCanEditBusinessSupplyStores then
        notify(src, 'Business Supplies', 'You do not have permission.', 'error')
        return
    end

    data = data or {}
    local business = getBusiness(data.businessId)
    if not business then
        notify(src, 'Business Supplies', 'Business not found.', 'error')
        return
    end

    local item = tostring(data.item or ''):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    local label = tostring(data.label or item)
    local price = math.max(0, math.floor(tonumber(data.price) or 0))
    local amount = math.max(1, math.floor(tonumber(data.amount) or 1))
    local enabled = data.enabled == nil and true or data.enabled == true

    if item == '' then
        notify(src, 'Business Supplies', 'Item name is required.', 'error')
        return
    end

    ensureBusinessSupplyItemsTable()

    MySQL.insert.await([[
        INSERT INTO qbox_business_supply_store_items
        (business, item, label, price, amount, enabled)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            label = VALUES(label),
            price = VALUES(price),
            amount = VALUES(amount),
            enabled = VALUES(enabled)
    ]], {
        business.id,
        item,
        label,
        price,
        amount,
        enabled and 1 or 0
    })

    notify(src, 'Business Supplies', 'Supply item saved for ' .. business.label .. '.', 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:adminDeleteBusinessSupplyItem', function(data)
    local src = source
    if not isBusinessAdmin(src) or not Config.AdminCanEditBusinessSupplyStores then
        notify(src, 'Business Supplies', 'You do not have permission.', 'error')
        return
    end

    data = data or {}
    local business = getBusiness(data.businessId)
    if not business then return end

    local itemName = tostring(data.item or ''):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    if itemName == '' then return end

    MySQL.update.await('DELETE FROM qbox_business_supply_store_items WHERE business = ? AND item = ?', {
        business.id,
        itemName
    })

    notify(src, 'Business Supplies', 'Supply item removed from ' .. business.label .. '.', 'success')
end)



RegisterNetEvent('qbox_all_businesses:server:adminCreateBusiness', function(data)
    local src = source
    if not isBusinessAdmin(src) or not Config.AdminCanCreateDeleteBusinesses then
        notify(src, 'Business Admin', 'You do not have permission.', 'error')
        return
    end

    data = data or {}

    local id = tostring(data.id or ''):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    local label = tostring(data.label or id)
    local businessType = tostring(data.type or 'business')
    local job = tostring(data.job or id):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    local uiTitle = tostring(data.uiTitle or (label .. ' Tablet'))
    local primaryColor = tostring(data.primaryColor or '#38bdf8')

    if id == '' or job == '' then
        notify(src, 'Business Admin', 'Business ID and job are required.', 'error')
        return
    end

    if businessExists(id) then
        notify(src, 'Business Admin', 'A business with that ID already exists.', 'error')
        return
    end

    ensureDynamicBusinessesTable()

    local ui = {
        title = uiTitle,
        primaryColor = primaryColor
    }

    local blip = makeBusinessBlipFromAdminData(data, {
        id = id,
        label = label,
        type = businessType,
        job = job,
        ui = ui,
        blip = {}
    })

    local business = {
        id = id,
        label = label,
        type = businessType,
        job = job,
        ui = ui,
        blip = blip or {},
        stations = {},
        dynamic = true
    }

    local saved = saveDynamicBusinessToDatabase(business)
    if not saved then
        notify(src, 'Business Admin', 'Business was created in memory, but the database save failed. Check server console.', 'error')
        return
    end

    Config.Businesses[#Config.Businesses + 1] = business
    DynamicBusinessStations[id] = DynamicBusinessStations[id] or {}

    if seedBusinessSupplyStore then
        seedBusinessSupplyStore(id)
    end

    pcall(function()
        MySQL.insert.await('INSERT IGNORE INTO qbox_business_accounts (business, balance) VALUES (?, ?)', { id, 0 })
    end)

    broadcastSingleBusinessBlip(business)
    broadcastBusinessBlips()
    notify(src, 'Business Admin', 'Business created and blip saved: ' .. label, 'success')
end)

RegisterNetEvent('qbox_all_businesses:server:adminDeleteBusiness', function(businessId)
    local src = source
    if not isBusinessAdmin(src) or not Config.AdminCanCreateDeleteBusinesses then
        notify(src, 'Business Admin', 'You do not have permission.', 'error')
        return
    end

    businessId = tostring(businessId or '')
    local business = getBusiness(businessId)

    if not business then
        notify(src, 'Business Admin', 'Business not found.', 'error')
        return
    end

    if not business.dynamic and not Config.AdminPanelCanEditStaticBusinesses then
        notify(src, 'Business Admin', 'Static config businesses cannot be deleted.', 'error')
        return
    end

    ensureDynamicBusinessesTable()

    MySQL.update.await('DELETE FROM qbox_dynamic_businesses WHERE id = ?', { businessId })
    MySQL.update.await('DELETE FROM qbox_business_stations WHERE business = ?', { businessId })
    MySQL.update.await('DELETE FROM qbox_business_supply_store_items WHERE business = ?', { businessId })
    MySQL.update.await('DELETE FROM qbox_business_accounts WHERE business = ?', { businessId })
    MySQL.update.await('DELETE FROM qbox_business_transactions WHERE business = ?', { businessId })
    pcall(function()
        MySQL.update.await('DELETE FROM qbox_business_supply_orders WHERE business = ?', { businessId })
    end)

    for i = #Config.Businesses, 1, -1 do
        if Config.Businesses[i].id == businessId then
            table.remove(Config.Businesses, i)
            break
        end
    end

    DynamicBusinessStations[businessId] = nil

    TriggerClientEvent('qbox_all_businesses:client:removeBusinessZones', -1, businessId)
    TriggerClientEvent('qbox_all_businesses:client:removeBusinessBlipNow', -1, businessId)
    broadcastBusinessBlips()
    notify(src, 'Business Admin', 'Business deleted: ' .. business.label, 'success')
end)

