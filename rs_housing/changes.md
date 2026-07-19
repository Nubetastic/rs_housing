# rs_housing Changes

## Housing management NUI

- Property management now uses the same visual shell as the decoration UI.
- The normal ledger view shows the house number, tax amount, calculated tax rate,
  next configured tax due date, tax reserve, and normal ledger balance.
- The player-facing account is now a single Money Ledger with line-by-line
  property information and Deposit, Withdraw, and Pay Tax actions.
- Deposit and Withdraw use matching NUI amount-entry screens showing the current
  ledger balance and the player's cash.
- Pay Tax uses `+` and `-` controls in exact tax-amount increments, never below
  zero, and shows how many configured weeks or months are already funded.
- Property transfers now list character names and server IDs for players inside
  the property's `actionsRange`, with a matching NUI server-ID entry screen.
- Tax Funds turn red when the automatic-tax reserve is below the next tax charge.
- Normal-ledger deposits and withdrawals retain their existing accounts,
  permissions, limits, and server events.
- Keyholder management now shows persistent keyholders (including offline
  characters) and nearby non-keyholders inside the property's `actionsRange`.
- Keyholders can be removed with `-`; nearby players can be added with `+`.
- Selecting a keyholder's name opens their existing permission toggles.
- Selling a property transfers both its normal-ledger balance and any unused
  tax-ledger balance to the former owner's configured default bank. Repossession
  continues to refund the normal ledger. Offline characters are supported, and
  ownership is retained if the required refund fails.
- The Sell House confirmation shows the house number, refundable Money Ledger
  balance, destination account, and a red warning when the persistent house
  inventory contains items.

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
