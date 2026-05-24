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
