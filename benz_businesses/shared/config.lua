Config = {}

-- QBOX DEFAULT SETTINGS
Config.Framework = 'qbox'
Config.Inventory = 'ox_inventory'
Config.Target = 'ox_target'

Config.EnableBusinessTablet = true
Config.TabletItem = 'business_tablet'
Config.TabletCommand = 'businesstablet'

Config.TargetDistance = 2.0
Config.Debug = false

Config.MenuEditorMinGrade = 4
Config.BusinessAccountAccessMinGrade = 3
Config.SupplyOrderMinGrade = 1

Config.BusinessAccountBossOnlyWithdraw = false
Config.DeliveryTravelTimeSeconds = 180

Config.AllowYoutubeLinks = true
Config.AllowSpotifyLinks = false

Config.DefaultDJUseRadius = 2.0
Config.DefaultDJHearRadius = 35.0

Config.DisableLegacyWorldStationsWhenTabletEnabled = true
Config.FreeStationItems = false

Config.StationIcons = {
    food = 'fa-solid fa-burger',
    drink = 'fa-solid fa-mug-hot',
    stash = 'fa-solid fa-box-open',
    fridge = 'fa-solid fa-snowflake',
    register = 'fa-solid fa-cash-register',
    dj = 'fa-solid fa-music',
    business_ui = 'fa-solid fa-tablet-screen-button',
    boss = 'fa-solid fa-user-tie',
    delivery = 'fa-solid fa-truck'
}

Config.DefaultGradeLabels = {
    [0] = 'Trainee',
    [1] = 'Employee',
    [2] = 'Senior Employee',
    [3] = 'Manager',
    [4] = 'Owner'
}
-- Performance / resmon optimization
Config.PerformanceMode = true
Config.RegisterZonesOnStart = true
Config.DisableLegacyWorldStationsWhenTabletEnabled = true
Config.JobCacheRefreshMs = 2500
Config.DisableSupplierWorldPickup = false
Config.DisableAdminRefreshSpam = true



-- Admin business creator
Config.EnableAdminBusinessCreator = true
Config.AdminBusinessCommand = 'businessadmin'
Config.AdminPermission = 'admin' -- ace permission/group check
Config.AdminCreateDefaultStashSlots = 60
Config.AdminCreateDefaultStashWeight = 150000

Config.AdminStationTypes = {
    'stash',
    'fridge',
    'register',
    'food',
    'drink',
    'dj',
    'boss',
    'wardrobe',
    'menu_editor',
    'business_ui',
    'delivery'
}



-- Business tablet
Config.EnableBusinessTablet = true
Config.TabletCommand = 'businesstablet'
Config.TabletItem = 'business_tablet'
Config.TabletRequiresItem = true
-- Qbox-only settings
Config.Framework = 'qbox'
Config.Inventory = 'ox_inventory'
Config.Target = 'ox_target'





-- Central ingredient supplier / delivery system
Config.EnableSupplySystem = true
Config.SupplyOrderMinGrade = 1
Config.SupplyManageMinGrade = 3
Config.DeliveryTravelTimeSeconds = 180
Config.DeliveryPickupExpireMinutes = 60

Config.SupplierLocations = {
    {
        id = 'main_supplier',
        label = 'Central Ingredient Supplier',
        coords = vec3(919.35, -1256.62, 25.55),
        size = vec3(2.0, 2.0, 1.5),
        rotation = 0.0,
        useRadius = 2.5
    }
}

Config.SupplierItems = {
    { label = 'Bread', item = 'bread', price = 5, amount = 10 },
    { label = 'Meat', item = 'meat', price = 8, amount = 10 },
    { label = 'Lettuce', item = 'lettuce', price = 4, amount = 10 },
    { label = 'Potato', item = 'potato', price = 3, amount = 10 },
    { label = 'Cup', item = 'cup', price = 2, amount = 25 },
    { label = 'Syrup', item = 'syrup', price = 6, amount = 10 },
    { label = 'Ice', item = 'ice', price = 2, amount = 25 },
    { label = 'Fruit', item = 'fruit', price = 5, amount = 10 }
}

-- Employee management settings
Config.EnableEmployeeManagement = true
Config.EmployeeManagementBossOnly = true

-- If true, hiring uses the closest player ID typed in UI.
-- Recommended: have the player nearby and enter their server ID.
Config.HireRequiresOnlinePlayer = true

-- Grade labels used if your framework does not return job grade labels.
Config.DefaultGradeLabels = {
    [0] = 'Trainee',
    [1] = 'Employee',
    [2] = 'Senior Employee',
    [3] = 'Manager',
    [4] = 'Owner'
}

-- Business account and UI settings
Config.EnableBusinessAccounts = true
Config.BusinessAccountAccessMinGrade = 3
Config.BusinessAccountBossOnlyWithdraw = true

-- Cash mode:
-- 'framework' uses your framework money functions through the bridge.
-- 'custom' lets you wire your own money system in server/bridge.lua.
Config.BusinessAccountCashMode = 'framework'

-- DJ settings
-- DJBackend options: 'xsound', 'custom'
Config.DJBackend = Config.DJBackend or 'xsound'
Config.AllowYoutubeLinks = true
Config.AllowSpotifyLinks = true
Config.DefaultDJUseRadius = 2.0
Config.DefaultDJHearRadius = 35.0
Config.DefaultDJVolume = 0.25
Config.MaxDJVolume = 1.0

-- Billing hook options: 'custom', 'qb-phone', 'okokBilling', 'jim-payments'
Config.Billing = Config.Billing or 'custom'

-- Stash behavior for non-ox inventories:
-- Qbox-only: stashes use ox_inventory directly.
Config.NonOxStashSlots = Config.NonOxStashSlots or 50
Config.NonOxStashWeight = Config.NonOxStashWeight or 100000



Config.Debug = false
Config.TargetDistance = 2.0

-- If true, players with boss access can edit business menus in game.
Config.EnableInGameMenuEditing = true

-- Minimum grade that can edit menus if job.isboss is not set.
Config.MenuEditorMinGrade = 4

-- If true, every station item gets added straight to player inventory.
-- If false, station items can require ingredients.
Config.FreeStationItems = false

Config.StationIcons = {
    stash = 'fa-solid fa-box',
    fridge = 'fa-solid fa-snowflake',
    register = 'fa-solid fa-cash-register',
    food = 'fa-solid fa-utensils',
    drink = 'fa-solid fa-martini-glass',
    dj = 'fa-solid fa-music',
    wardrobe = 'fa-solid fa-shirt',
    boss = 'fa-solid fa-user-tie',
    menu_editor = 'fa-solid fa-pen-to-square',
    business_ui = 'fa-solid fa-building-columns'
}

-- Station item format:
-- {
--     label = 'Burger',
--     item = 'burger',
--     amount = 1,
--     price = 50,
--     time = 4000,
--     ingredients = { bread = 1, meat = 1 }
-- }
--
-- In-game edited menus are saved in the database and override these defaults.

Config.Businesses = {
    {
        id = 'burgershot',
        label = 'Burger Shot',
        type = 'restaurant',
        job = 'burgershot',
        ui = {
            title = 'Burger Shot Office',
            primaryColor = '#f59e0b',
            icon = 'restaurant',
            accountLabel = 'Burger Shot Account'
        },
        stations = {
            {
                id = 'storage',
                type = 'stash',
                label = 'Storage',
                coords = vec3(-1196.18, -897.14, 13.98),
                size = vec3(1.2, 1.0, 1.0),
                rotation = 35.0,
                slots = 60,
                weight = 150000
            },
            {
                id = 'fridge',
                type = 'fridge',
                label = 'Fridge',
                coords = vec3(-1199.16, -895.12, 13.98),
                size = vec3(1.2, 1.0, 1.0),
                rotation = 35.0,
                slots = 50,
                weight = 120000
            },
            {
                id = 'grill',
                type = 'food',
                label = 'Cook Food',
                coords = vec3(-1198.43, -900.18, 13.98),
                size = vec3(1.2, 1.0, 1.0),
                rotation = 35.0,
                items = {
                    { label = 'Burger', item = 'burger', amount = 1, price = 50, time = 4000, ingredients = { bread = 1, meat = 1, lettuce = 1 } },
                    { label = 'Fries', item = 'fries', amount = 1, price = 25, time = 3000, ingredients = { potato = 2 } }
                }
            },
            {
                id = 'drinks',
                type = 'drink',
                label = 'Make Drinks',
                coords = vec3(-1196.70, -895.77, 13.98),
                size = vec3(1.2, 1.0, 1.0),
                rotation = 35.0,
                items = {
                    { label = 'Soda', item = 'cola', amount = 1, price = 20, time = 2500, ingredients = { cup = 1, syrup = 1 } }
                }
            },
            {
                id = 'register',
                type = 'register',
                label = 'Register',
                coords = vec3(-1194.95, -892.80, 13.98),
                size = vec3(0.8, 0.8, 1.0),
                rotation = 35.0
            },
            {
                id = 'boss',
                type = 'boss',
                label = 'Boss Menu',
                coords = vec3(-1201.22, -895.54, 13.98),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 35.0,
                bossOnly = true
            },
            {
                id = 'menu_editor',
                type = 'menu_editor',
                label = 'Edit Menu',
                coords = vec3(-1202.10, -896.20, 13.98),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 35.0,
                bossOnly = true
            },
            {
                id = 'business_ui',
                type = 'business_ui',
                label = 'Business Account',
                coords = vec3(-1202.90, -896.85, 13.98),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 0.0,
                bossOnly = false
            },
            {
                id = 'delivery',
                type = 'delivery',
                label = 'Ingredient Deliveries',
                coords = vec3(-1203.80, -897.50, 13.98),
                size = vec3(1.5, 1.5, 1.0),
                rotation = 0.0,
                bossOnly = false
            }
        }
    },

    {
        id = 'bahama',
        label = 'Bahama Mamas',
        type = 'nightclub',
        job = 'bahama',
        ui = {
            title = 'Bahama Mamas Office',
            primaryColor = '#a855f7',
            icon = 'nightclub',
            accountLabel = 'Bahama Mamas Account'
        },
        stations = {
            {
                id = 'bar_storage',
                type = 'stash',
                label = 'Bar Storage',
                coords = vec3(-1386.12, -606.74, 30.32),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 35.0,
                slots = 80,
                weight = 180000
            },
            {
                id = 'bar',
                type = 'drink',
                label = 'Mix Drinks',
                coords = vec3(-1387.84, -608.45, 30.32),
                size = vec3(1.2, 1.0, 1.0),
                rotation = 35.0,
                items = {
                    { label = 'Cocktail', item = 'cocktail', amount = 1, price = 75, time = 3500, ingredients = { cup = 1, ice = 1, fruit = 1 } },
                    { label = 'Club Soda', item = 'club_soda', amount = 1, price = 35, time = 2500, ingredients = { cup = 1, ice = 1 } }
                }
            },
            {
                id = 'register',
                type = 'register',
                label = 'Register',
                coords = vec3(-1389.05, -608.88, 30.32),
                size = vec3(0.8, 0.8, 1.0),
                rotation = 35.0
            },
            {
                id = 'dj',
                type = 'dj',
                label = 'DJ Booth',
                useRadius = 2.0,
                hearRadius = 45.0,
                coords = vec3(-1381.90, -616.88, 31.50),
                size = vec3(1.4, 1.4, 1.0),
                rotation = 35.0
            },
            {
                id = 'wardrobe',
                type = 'wardrobe',
                label = 'Wardrobe',
                coords = vec3(-1374.25, -626.50, 30.82),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 35.0
            },
            {
                id = 'boss',
                type = 'boss',
                label = 'Boss Menu',
                coords = vec3(-1367.12, -623.48, 30.32),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 35.0,
                bossOnly = true
            },
            {
                id = 'menu_editor',
                type = 'menu_editor',
                label = 'Edit Menu',
                coords = vec3(-1368.12, -624.48, 30.32),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 35.0,
                bossOnly = true
            },
            {
                id = 'business_ui',
                type = 'business_ui',
                label = 'Business Account',
                coords = vec3(-1369.12, -625.20, 30.32),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 0.0,
                bossOnly = false
            },
            {
                id = 'delivery',
                type = 'delivery',
                label = 'Ingredient Deliveries',
                coords = vec3(-1370.15, -626.15, 30.32),
                size = vec3(1.5, 1.5, 1.0),
                rotation = 0.0,
                bossOnly = false
            }
        }
    },

    {
        id = 'vanilla',
        label = 'Vanilla Unicorn',
        type = 'stripclub',
        job = 'vanilla',
        ui = {
            title = 'Vanilla Unicorn Office',
            primaryColor = '#ec4899',
            icon = 'stripclub',
            accountLabel = 'Vanilla Unicorn Account'
        },
        stations = {
            {
                id = 'storage',
                type = 'stash',
                label = 'Storage',
                coords = vec3(95.30, -1293.80, 29.27),
                size = vec3(1.2, 1.0, 1.0),
                rotation = 30.0,
                slots = 80,
                weight = 180000
            },
            {
                id = 'bar',
                type = 'drink',
                label = 'Make Drinks',
                coords = vec3(129.20, -1281.44, 29.27),
                size = vec3(1.2, 1.0, 1.0),
                rotation = 30.0,
                items = {
                    { label = 'Mocktail', item = 'mocktail', amount = 1, price = 50, time = 3000, ingredients = { cup = 1, ice = 1, fruit = 1 } }
                }
            },
            {
                id = 'register',
                type = 'register',
                label = 'Register',
                coords = vec3(128.56, -1283.22, 29.27),
                size = vec3(0.8, 0.8, 1.0),
                rotation = 30.0
            },
            {
                id = 'dj',
                type = 'dj',
                label = 'DJ Booth',
                useRadius = 2.0,
                hearRadius = 45.0,
                coords = vec3(119.68, -1286.68, 28.27),
                size = vec3(1.4, 1.4, 1.0),
                rotation = 30.0
            },
            {
                id = 'wardrobe',
                type = 'wardrobe',
                label = 'Wardrobe',
                coords = vec3(107.78, -1305.86, 28.77),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 30.0
            },
            {
                id = 'boss',
                type = 'boss',
                label = 'Boss Menu',
                coords = vec3(95.02, -1294.84, 29.27),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 30.0,
                bossOnly = true
            },
            {
                id = 'menu_editor',
                type = 'menu_editor',
                label = 'Edit Menu',
                coords = vec3(96.00, -1295.50, 29.27),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 30.0,
                bossOnly = true
            },
            {
                id = 'business_ui',
                type = 'business_ui',
                label = 'Business Account',
                coords = vec3(96.80, -1296.10, 29.27),
                size = vec3(1.0, 1.0, 1.0),
                rotation = 0.0,
                bossOnly = false
            },
            {
                id = 'delivery',
                type = 'delivery',
                label = 'Ingredient Deliveries',
                coords = vec3(97.60, -1297.05, 29.27),
                size = vec3(1.5, 1.5, 1.0),
                rotation = 0.0,
                bossOnly = false
            }
        }
    }
}


-- Per-business tablet items.
-- If a business is not listed here, Config.TabletItem is used.
Config.BusinessTabletItems = {}

-- Set true if you want employees to only open the tablet from the item.
Config.DisableTabletCommand = false


-- One tablet for every business
Config.UseOneTabletForAllBusinesses = true
Config.TabletItem = 'business_tablet'

-- Keep this empty so all jobs use the same tablet item.
Config.BusinessTabletItems = {}


-- Renewed Banking integration for Qbox
Config.Banking = 'renewed' -- 'renewed' or 'local'
Config.RenewedBankingResource = 'Renewed-Banking'
Config.RenewedBusinessAccountPrefix = '' -- leave empty to use job name as account
Config.RenewedBusinessAccountTitleSuffix = ' Business Account'
Config.UseRenewedTransactions = true



-- Tablet DJ booth placement
Config.AllowTabletDJPlacement = true
Config.DJPlacementMinGrade = 3
Config.DefaultPlacedDJUseRadius = 2.0
Config.DefaultPlacedDJHearRadius = 45.0
Config.DefaultPlacedDJSize = vec3(1.4, 1.4, 1.0)


-- Tablet station placement
Config.AllowTabletStationPlacement = true
Config.StationPlacementMinGrade = 3

Config.PlaceableStationTypes = {
    'stash',
    'fridge',
    'register',
    'food',
    'drink',
    'menu_editor',
    'business_ui',
    'delivery',
    'dj'
}

Config.DefaultPlacedStationSize = vec3(1.4, 1.4, 1.0)
Config.DefaultPlacedStashSlots = 60
Config.DefaultPlacedStashWeight = 150000
Config.DefaultPlacedFridgeSlots = 60
Config.DefaultPlacedFridgeWeight = 150000


-- Qbox job setup helper
-- Qbox jobs usually live in qbx_core/shared/jobs.lua.
-- This script can generate a ready-to-copy jobs file from Config.Businesses.
Config.AutoGenerateQboxJobs = true
Config.DefaultBusinessJobType = 'business'
Config.DefaultBusinessJobDuty = true
Config.DefaultBusinessJobOffDutyPay = false
Config.DefaultBusinessJobGrades = {
    [0] = { name = 'trainee', payment = 50 },
    [1] = { name = 'employee', payment = 75 },
    [2] = { name = 'senior', payment = 100 },
    [3] = { name = 'manager', payment = 125 },
    [4] = { name = 'owner', isboss = true, payment = 150 }
}


-- Placed station access
Config.PlacedStationsJobLocked = true -- placed stations are locked to the business/job that placed them


-- Third-eye access
Config.AllStationsUseThirdEye = true
Config.OpenTabletForCraftingStations = true -- food/drink stations open tablet station UI by default


-- E-key station interaction
Config.UseEToInteractStations = false
Config.UseThirdEyeStations = true
Config.EInteractDistance = 2.0
Config.EInteractDrawDistance = 15.0
Config.EInteractKey = 38 -- E
Config.EInteractText = '[THIRD EYE] Use %s'


-- Registered job station access
-- If true, every station is accessible only by its registered Config.Businesses job.
-- Static stations use business.job. Placed stations save/use the placing business job.
Config.RegisteredJobStationAccess = true
Config.DisableDefaultConfigStations = true -- disables all hardcoded Config.Businesses stations; use admin/tablet placement only
Config.UseEToInteractStations = false
Config.UseThirdEyeStations = true
Config.EInteractDistance = 2.0
Config.EInteractDrawDistance = 15.0
Config.EInteractKey = 38
Config.EInteractText = '[THIRD EYE] Use %s'


-- Station deletion
Config.AllowTabletStationDeletion = true
Config.StationDeletionMinGrade = 3
Config.StaticStationDeletionAllowed = false -- only SQL/dynamic stations can be deleted by default


-- Delivery blips
Config.EnableDeliveryBlips = true
Config.DeliveryBlipSprite = 478
Config.DeliveryBlipColor = 5
Config.DeliveryBlipScale = 0.75
Config.DeliveryBlipShortRange = true
Config.DeliveryBlipLabelFormat = '%s Delivery'


-- DJ placement fix
Config.FixDJPlacementUseGenericStation = true
Config.DefaultPlacedDJLabel = 'DJ Booth'
Config.DefaultPlacedDJSize = vec3(1.4, 1.4, 1.0)
Config.DefaultPlacedDJUseRadius = 2.0
Config.DefaultPlacedDJHearRadius = 45.0


-- Admin business panel
Config.EnableAdminPanel = true
Config.AdminPanelCommand = 'businessadmin'
Config.AdminPanelAce = 'qboxbusiness.admin'
Config.AdminPanelAllowGod = true
Config.AdminPanelAllowAdmin = true
Config.AdminPanelCanEditStaticBusinesses = true
Config.AdminPanelCanDeleteDynamicStations = true


-- Discord ID admin permissions
-- Add Discord IDs without "discord:".
-- Example: '123456789012345678'
Config.AdminPanelDiscordIds = {
    -- '123456789012345678',
}

-- If true, Discord IDs listed above can open /businessadmin.
Config.AdminPanelUseDiscordIds = true


-- FiveM ACE permissions for admin panel
Config.AdminPanelAce = 'qboxbusiness.admin'
Config.AdminPanelCommandAce = 'command.businessadmin'
Config.AdminPanelAllowAceGroups = true
Config.AdminPanelAceGroups = {
    'group.admin',
    'group.god',
    'admin',
    'god'
}


-- Main business map blips
Config.EnableBusinessMainBlips = true
Config.BusinessBlipsJobOnly = false -- false = everyone can see; true = only employees can see their business blip
Config.BusinessBlipShortRange = true
Config.BusinessBlipDefaultSprite = 439
Config.BusinessBlipDefaultColor = 2
Config.BusinessBlipDefaultScale = 0.75

-- Optional per-business blip overrides.
-- coords is optional. If missing, the first station coordinate will be used.
Config.BusinessBlips = {
     burgershot = { sprite = 106, color = 1, scale = 0.8, label = 'Burger Shot', coords = vec3(-1196.14, -891.49, 13.98) },
     bahama = { sprite = 93, color = 27, scale = 0.8, label = 'Bahama Mamas', coords = vec3(-1393.95, -600.03, 41.94) },
     vanilla = { sprite = 121, color = 8, scale = 0.8, label = 'Vanilla Unicorn', coords = vec3(112.36, -1287.31, 27.46) }
}


-- Blip toggles
Config.EnableAllBlips = true
Config.EnableBusinessMainBlips = true
Config.EnableDeliveryBlips = true

-- If true, business blips only show for employees of that business job.
Config.BusinessBlipsJobOnly = false

-- If true, delivery blips only show for employees of that business job.
Config.DeliveryBlipsJobOnly = true


-- Delivery timers
-- Default delivery time if a business is not listed below.
Config.DefaultDeliveryTimeSeconds = 180

-- Per-business delivery times in seconds.
-- Uses business.id from Config.Businesses.
Config.BusinessDeliveryTimes = {
    -- burgershot = 180,
    -- bahama = 300,
    -- vanilla = 420
}

-- Tablet timer refresh display is handled client-side.
Config.ShowDeliveryCountdowns = true


-- Admin supply store editor
Config.AdminCanEditSupplyStore = true
Config.UseDatabaseSupplyStore = true


-- Per-business supply stores
Config.UsePerBusinessSupplyStores = true
Config.AdminCanEditBusinessSupplyStores = true


-- Admin business create/delete
Config.AdminCanCreateDeleteBusinesses = true
Config.DynamicBusinessesEnabled = true

-- This build removes all default hardcoded stations from Config.Businesses.
-- Create stations from the admin/tablet station menu so they are saved in qbox_business_stations
-- and locked to the business job that owns them.
if Config.DisableDefaultConfigStations then
    for _, business in pairs(Config.Businesses or {}) do
        business.stations = {}
    end
end
