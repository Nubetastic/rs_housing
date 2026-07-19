# rs_housing Changes

## New commands

### `/disabledproperties`

Shows or hides map blips for properties excluded by `Config.AllowProperties`.

- Permission: RSG Core `admin`
- Arguments: none
- Player-only command; it does nothing from the server console.
- Run it a second time to remove the disabled-property blips.

### `/UpdatePropertyValues`

Permanently rewrites property values in `config.lua` using `Config.PropertiesOverrides`.

- Permission: RSG Core `admin`
- Arguments: none
- Ensure `Config.PropertiesOverrides.enable = true` before running it.
- The formulas use each property's dollar purchase price:
  - `tax = floor(buyPrice * taxAmount)`
  - `sell.receive = floor(buyPrice * sellPrice)`
  - `ledgerLimit = ledgerLimit`
  - `defaultStorageWeight = defaultStorageWeight + floor(buyPrice / priceStep) * addedWeight`
- The first run creates `config.lua.property-values-backup`. Existing backups are not overwritten.

One-time updater procedure:

1. Configure `Config.PropertiesOverrides` in `config.lua`.
2. Ensure both updater files are enabled in `fxmanifest.lua`.
3. Restart `rs_housing`.
4. Run `/UpdatePropertyValues` as an admin.
5. Comment out both updater entries in `fxmanifest.lua`:
   - `client/update_property_values.lua`
   - `server/update_property_values.lua`
6. Restart `rs_housing` again. The resource then uses the permanently written values normally.

