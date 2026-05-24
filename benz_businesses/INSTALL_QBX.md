# Qbox All Businesses - Install Guide

## Required Resources

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure ox_inventory
ensure ox_target
ensure xsound
ensure qbox_all_businesses
```

## Import SQL

Import:
`qbox_all_businesses_FULL.sql`

into your database.

## Add Tablet Item

Add `business_tablet` to ox_inventory items.

Example:

```lua
['business_tablet'] = {
    label = 'Business Tablet',
    weight = 500,
    stack = false,
    close = true,
    description = 'Business management tablet'
},
```

## Features

- Qbox only
- ox_inventory
- ox_target
- ox_lib
- DJ booths
- YouTube playback
- Employee management
- Business accounts
- Supply ordering
- Delivery claiming
- Menu editing
- Fridges/stashes
- Tablet UI
- Boss management
- Per-business systems