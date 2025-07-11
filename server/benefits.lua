
--| EXAMPLE USAGE

--[[

If they have plus give them +1 Multichar slot

AddEventHandler('esx:playerLoaded', function(player, xPlayer, isNew)
    local identifier = GetPlayerIdentifierByType(player, 'license'):gsub('license:', '')

    if ManagePlayer(player).hasAbo() then
        MySQL.insert('INSERT INTO `multicharacter_slots` (`identifier`, `slots`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `slots` = VALUES(`slots`)', {
            identifier,
            2,
        })
    end
end)
]]