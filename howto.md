# How to link with Tebex Store

## Steps Add Package

- Goto the package you want to add
- Add the exact `Name` to the key value under `Config.Coins`

## Steps Command

- Goto the package you want to add
- Goto `Pricing`
- Add a Command to your desired server
- Put `zrx_tebex_purchase {'transid':'{transaction}', 'packagename':'{packageName}'}` as command
- Press on gear icon and set `Execute the command even if the player is offline` at `Require Player To Be Online`

## Steps Slug
- Goto the package you want to add
- Goto `Advanced`
- Set the `Slug` to the desired name, then add this name to `url` under `Config.Coins`