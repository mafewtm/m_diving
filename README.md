# m_diving

Just another diving resource

## Dependencies

- qbx_core
- ox_lib
- ox_inventory

## Items (for ox_inventory)

```lua
['metalscrap'] = {
    label = 'Metal Scrap',
    weight = 100,
},

['diving_gear'] = {
    label = 'Diving Gear',
    weight = 30000,
    client = {
        export = 'm_diving.UseDivingGear'
    }
},

['gold_coin'] = {
    label = 'Gold Coin',
    weight = 30,
},
```