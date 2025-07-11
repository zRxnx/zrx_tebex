ManagePlayer = function(player)
    local self = {}

    self.player = player
    self.identifier = GetPlayerIdentifierByType(player, 'license'):gsub('license:', '')

    self.setAbo = function(package, days)
        print(package, days)
        package = package or 'default'
        days = days or Config.Default
        local duration = days * 24 * 60 * 60
        local expiresAt = os.time() + duration
        local createdAt = os.date('%Y-%m-%d %H:%M:%S')

        MySQL.insert('INSERT INTO `zrx_tebex_abo` (`identifier`, `package`, `expires_at`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `expires_at` = VALUES(`expires_at`)', {
            self.identifier,
            package,
            expiresAt,
        })

        PLAYERS[self.player] = {}
        PLAYERS[self.player][package] = true
        PLAYERS_DATA[self.player] = {}
        PLAYERS_DATA[self.player][package] = {
            expires_at = expiresAt,
            created_at = createdAt,
        }

        print('Created/Updated User: ', self.player, expiresAt, package)
    end

    self.hasAbo = function(package)
        package = package or 'default'
        local response = MySQL.query.await('SELECT * FROM `zrx_tebex_abo` WHERE `identifier` = ? AND `package` = ?', { self.identifier, package })

        if not response[1] or tonumber(response[1].expires_at) <= 0 then
            MySQL.update.await('DELETE FROM `zrx_tebex_abo` WHERE (identifier, package) = (?, ?)', { self.identifier, package })

            PLAYERS[self.player] = {}
            PLAYERS[self.player][package] = false
            PLAYERS_DATA[self.player] = {}
            PLAYERS_DATA[self.player][package] = {}

            print('Deleted User: ', self.player, package)

            return false
        end

        PLAYERS[self.player] = {}
        PLAYERS[self.player][package] = true
        PLAYERS_DATA[self.player] = {}
        PLAYERS_DATA[self.player][package] = {
            expires_at = response[1].expires_at,
            created_at = response[1].created_at,
        }

        print('Recreated User: ', self.player, response[1].expires_at, package)

        return true
    end

    self.getDuration = function(package)
        package = package or 'default'
        if not self.hasAbo(package) then
            print('Duration: Expired')
            return false, 'Expired'
        end

        local time = {}
        local now = os.time()
        local remaining = PLAYERS_DATA[player][package].expires_at - now

        local days = math.floor(remaining / 86400)
        local hours = math.floor((remaining % 86400) / 3600)
        local minutes = math.floor((remaining % 3600) / 60)
        local seconds = remaining % 60

        if days > 0 then
            time[#time + 1] = days .. ' Days'
        end

        if hours > 0 then
            time[#time + 1] = hours .. ' Hrs'
        end

        print('Duration: ', remaining, days, hours)

        return remaining, table.concat(time, ', ')
    end

    self.getTypes = function()
        local packs = {}

        if not PLAYERS_DATA[self.player] or type(PLAYERS_DATA[self.player]) ~= 'table' then
            return {}, 'No Packages'
        end

        for package, data in pairs(PLAYERS_DATA[self.player]) do
            if package then
                packs[#packs + 1] = package
            end
        end

        return packs, table.concat(packs, ', ')
    end

    return self
end