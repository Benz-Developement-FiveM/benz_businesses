
# qbox_all_businesses

Qbox/QBX business resource for FiveM.

## New in this version

- Each food/drink station has its own item list.
- Bosses/managers can edit station menus in game.
- In-game menu edits save to the database.
- Added `menu_editor` station type.
- Food and drink items support:
  - label
  - item spawn name
  - amount
  - price
  - craft time
  - ingredients

## Required resources

- qbx_core
- ox_lib
- ox_target
- ox_inventory
- oxmysql

## Install

1. Put `qbox_all_businesses` in your resources folder.
2. Add this to `server.cfg`:

```cfg
ensure qbox_all_businesses
```

3. Make sure your jobs exist:
   - burgershot
   - bahama
   - vanilla

4. Add your items to `ox_inventory/data/items.lua`.

## In-game menu editing

Each business now has an `Edit Menu` station.

Only bosses or players with grade level `4` or higher can use it.

You can change the required grade in:

```lua
Config.MenuEditorMinGrade = 4
```

## Add items to a station in config

Open `shared/config.lua`.

Food/drink stations use this format:

```lua
items = {
    {
        label = 'Burger',
        item = 'burger',
        amount = 1,
        price = 50,
        time = 4000,
        ingredients = {
            bread = 1,
            meat = 1,
            lettuce = 1
        }
    }
}
```

## Add items in game

Go to the business `Edit Menu` third-eye station.

Choose:
- station
- Add Menu Item
- fill out item label, spawn name, amount, price, craft time, ingredients

Ingredient format:

```txt
bread:1, meat:1, lettuce:1
```

## Database

The script auto-creates this table:

```sql
CREATE TABLE IF NOT EXISTS qbox_business_menus (
    business VARCHAR(50) NOT NULL,
    station VARCHAR(50) NOT NULL,
    items LONGTEXT NOT NULL,
    PRIMARY KEY (business, station)
);
```

## Station types

- `stash`
- `fridge`
- `register`
- `food`
- `drink`
- `dj`
- `wardrobe`
- `boss`
- `menu_editor`

## Notes

Billing, boss menu, wardrobe, and DJ music are hook placeholders because servers use different scripts for those systems.


## ox_inventory / ox_target setup

This version is locked to:

- `ox_inventory` for all stashes, fridges, item checks, ingredient removal, and item rewards.
- `ox_target` for all third-eye station interactions.

Start order in `server.cfg` should be:

```cfg
ensure oxmysql
ensure ox_lib
ensure ox_inventory
ensure ox_target
ensure qbx_core
ensure qbox_all_businesses
```

Main calls used:

```lua
exports.ox_target:addBoxZone(...)
exports.ox_inventory:openInventory('stash', stashId)
exports.ox_inventory:RegisterStash(...)
exports.ox_inventory:GetItemCount(source, item)
exports.ox_inventory:RemoveItem(source, item, amount)
exports.ox_inventory:AddItem(source, item, amount)
```


## Multi-framework / inventory support

See `BRIDGE_SETUP.md` for Qbox, QBCore, ESX, ox_inventory, qb-inventory, qs-inventory, lj-inventory, ps-inventory, ox_target, and qb-target setup.


## DJ Booths

DJ booths now support YouTube and Spotify links.

Each DJ station can have its own:

```lua
useRadius = 2.0,   -- how close staff must be to use the booth
hearRadius = 45.0, -- how far the music can be heard
```

Example:

```lua
{
    id = 'dj',
    type = 'dj',
    label = 'DJ Booth',
    coords = vec3(-1381.90, -616.88, 31.50),
    size = vec3(1.4, 1.4, 1.0),
    rotation = 35.0,
    useRadius = 2.0,
    hearRadius = 45.0
}
```

### Audio backend

Default backend:

```lua
Config.DJBackend = 'xsound'
```

Make sure `xsound` is started before this resource:

```cfg
ensure xsound
ensure qbox_all_businesses
```

Supported DJ controls:
- Play YouTube / Spotify link
- Stop music
- Change volume

If your server uses a different music script, set:

```lua
Config.DJBackend = 'custom'
```

Then wire these client events:

```lua
qbox_all_businesses:client:customDjPlay
qbox_all_businesses:client:customDjStop
qbox_all_businesses:client:customDjVolume
```


## Individual Business Accounts + UI

Each business now has its own account stored in the database.

Included:
- Separate account balance per business
- Recent transaction history
- Deposit cash
- Withdraw cash
- Custom UI color/title/icon per business
- `business_ui` third-eye station type

### Config

In `shared/config.lua`:

```lua
Config.EnableBusinessAccounts = true
Config.BusinessAccountAccessMinGrade = 3
Config.BusinessAccountBossOnlyWithdraw = true
```

Each business can have its own UI:

```lua
ui = {
    title = 'Burger Shot Office',
    primaryColor = '#f59e0b',
    icon = 'restaurant',
    accountLabel = 'Burger Shot Account'
}
```

### Station

```lua
{
    id = 'business_ui',
    type = 'business_ui',
    label = 'Business Account',
    coords = vec3(0.0, 0.0, 0.0),
    size = vec3(1.0, 1.0, 1.0),
    rotation = 0.0
}
```

### Database

The resource auto-creates the required SQL tables, but a manual SQL file is also included:

```txt
qbox_business_accounts.sql
```


## Employee Management

The business UI now includes an Employees section.

Bosses/managers can:
- hire employees by server ID
- fire employees
- change employee ranks/grades
- view online employees for that business

Config:

```lua
Config.EnableEmployeeManagement = true
Config.EmployeeManagementBossOnly = true
Config.HireRequiresOnlinePlayer = true
```

Default grade labels:

```lua
Config.DefaultGradeLabels = {
    [0] = 'Trainee',
    [1] = 'Employee',
    [2] = 'Senior Employee',
    [3] = 'Manager',
    [4] = 'Owner'
}
```

Notes:
- This version manages online players.
- For Qbox and QBCore it uses `player.Functions.SetJob(job, grade)`.
- For ESX it uses `xPlayer.setJob(job, grade)`.
- Offline employee management needs your server's player database schema and can be added in the bridge.


## Central Supplier + Delivery System

Added a supply system for ingredients.

### Features

- Central ingredient supplier location
- Configurable supplier item list
- Direct pickup from supplier warehouse
- Business delivery orders
- Orders paid from the business account
- Delivery timer before supplies can be claimed
- Per-business delivery station

### Config

```lua
Config.EnableSupplySystem = true
Config.DeliveryTravelTimeSeconds = 180
Config.SupplierLocations = {
    {
        id = 'main_supplier',
        label = 'Central Ingredient Supplier',
        coords = vec3(919.35, -1256.62, 25.55)
    }
}
```

Supplier items:

```lua
Config.SupplierItems = {
    { label = 'Bread', item = 'bread', price = 5, amount = 10 },
    { label = 'Meat', item = 'meat', price = 8, amount = 10 }
}
```

Business delivery station:

```lua
{
    id = 'delivery',
    type = 'delivery',
    label = 'Ingredient Deliveries',
    coords = vec3(0.0, 0.0, 0.0)
}
```

### Flow

1. Employee opens the business delivery station.
2. Employee places an ingredient order.
3. Money is removed from that business account.
4. Delivery becomes claimable after the configured travel time.
5. Employee claims the delivery and receives the ingredients.

SQL file included:

```txt
qbox_business_supply_orders.sql
```


## Business Tablet Tabs

Added tablet tabs for:
- Accounts
- Employees
- Supplies / Deliveries
- Menu Editing

Command:
`/businesstablet`

Optional item:
`business_tablet`


## Usable Business Tablet Item

The tablet is now usable as an inventory item.

### Universal tablet item

```lua
business_tablet
```

### Per-business tablet items

```lua
burgershot_tablet
bahama_tablet
vanilla_tablet
```

Add the item definitions from:

```txt
ox_inventory_items.lua
```

or copy them from:

```txt
items_example.lua
```

### Config

```lua
Config.TabletItem = 'business_tablet'

Config.BusinessTabletItems = {
    burgershot = 'burgershot_tablet',
    bahama = 'bahama_tablet',
    vanilla = 'vanilla_tablet'
}

Config.TabletRequiresItem = false
Config.DisableTabletCommand = false
```

Set this if you only want the item to open the tablet:

```lua
Config.DisableTabletCommand = true
```

Set this if you want players to physically need the item:

```lua
Config.TabletRequiresItem = true
```

### ox_inventory

Copy `ox_inventory_items.lua` into your `ox_inventory/data/items.lua`.

The items call:

```lua
qbox_all_businesses:client:useBusinessTablet
```


## Admin Business Creator

Admins can create new businesses and set station locations in game.

Command:

```txt
/businessadmin
```

Permission:

```cfg
add_ace group.admin qboxbusiness.admin allow
```

Admin features:
- create businesses
- set job/type/label
- set UI color
- add stations at current position
- set station type
- set station size
- configure DJ radius
- save businesses to SQL

SQL file:

```txt
qbox_dynamic_businesses.sql
```


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MERGED SQL FILE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All SQL tables are now combined into one file:

qbox_all_businesses_FULL.sql

Import ONLY this file.

You no longer need to import multiple SQL files.


## PERFORMANCE / RESMON

See `PERFORMANCE_GUIDE.md`.

For lowest idle resmon, enable tablet-only mode:

```lua
Config.DisableLegacyWorldStationsWhenTabletEnabled = true
Config.DisableSupplierWorldPickup = true
```


## One Tablet For All Businesses

This version uses **one universal tablet item** for every business:

```lua
business_tablet
```

There are no separate tablet items per business anymore.

How it works:
- Player uses `business_tablet`.
- Script checks the player's current job.
- Tablet opens the correct business data for that job.
- Accounts, employees, supplies/deliveries, menu editing, and DJ booths stay separate per business.

Config:

```lua
Config.UseOneTabletForAllBusinesses = true
Config.TabletItem = 'business_tablet'
Config.BusinessTabletItems = {}
```

Only add this item to your inventory:

```lua
business_tablet
```


## Qbox-Only No-Bridge Version

This build uses direct `qbx_core`, `ox_inventory`, `ox_target`, and `oxmysql` calls. Bridge files were removed.


## Job-Based Tablet UI

Added a full on-screen tablet NUI.

One `business_tablet` item opens the tablet. The script checks the player's current Qbox job and loads that business only.

Clickable tabs:
- Dashboard
- Accounts
- Employees
- Supplies / Deliveries
- Menu Editing
- DJ Booths
- Stations

Command:
`/businesstablet`

Item event:
`qbox_all_businesses:client:useBusinessTablet`


## Tablet Full Fix

The tablet has been rewired so accounts, employees, supplies/deliveries, menu editing, DJ booths, and stashes all work from one job-based tablet.


## Tablet Station Placement

The tablet can now place stashes, fridges, crafting points, menu editor spots, business account spots, delivery points, and DJ booths per business/job.


## Jobs + Tablet Setup

Run `businessjobs` to generate `generated_qbox_jobs.lua` from `Config.Businesses`. Copy those entries into `qbx_core/shared/jobs.lua`. The tablet uses the player's current Qbox job to load the correct business.


## Main Business Blips

Every business now creates a configurable map blip. See `BUSINESS_MAIN_BLIPS.md`.
