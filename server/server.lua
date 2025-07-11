---@diagnostic disable: redundant-return-value
PLAYERS = {}
PLAYERS_DATA = {}

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    local TEBEX_SECRET = GetConvar('sv_tebexSecret', '')

    if TEBEX_SECRET == '' then
        error('Tebex secret not set')
        StopResource(res)
    end
end)

AddEventHandler('esx:playerLoaded', function(player, xPlayer, isNew)
    ManagePlayer(player).hasAbo()
    GetCoins(player)
end)

CreateThread(function()
    lib.versionCheck('zrxnx/zrx_tebex')

    MySQL.Sync.execute([[
        CREATE Table IF NOT EXISTS `zrx_tebex` (
            `id` int(100) NOT NULL AUTO_INCREMENT,
            `tbxId` varchar(25) DEFAULT NULL,
            `packageName` varchar(100) DEFAULT NULL,
            `claimed` BIT(1) DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB;
    ]])

    MySQL.Sync.execute([[
        CREATE Table IF NOT EXISTS `zrx_tebex_coins` (
            `id` int(100) NOT NULL AUTO_INCREMENT,
            `identifier` varchar(50) DEFAULT NULL,
            `coins` int(100) DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB;
    ]])

    MySQL.Sync.execute([[
        CREATE Table IF NOT EXISTS `zrx_tebex_limited` (
            `model` varchar(100) DEFAULT NULL,
            `count` int(100) DEFAULT 0,
            PRIMARY KEY (`model`)
        ) ENGINE=InnoDB;
    ]])

    MySQL.Sync.execute([[
        CREATE TABLE IF NOT EXISTS `zrx_tebex_abo` (
            `id` INT(100) NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(50) NOT NULL,
            `package` longtext NOT NULL,
            `expires_at` longtext NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_identifier_package` (`identifier`, `package`)
        ) ENGINE=InnoDB;
    ]])

    for index, data in pairs(Config.Shop.vehicles) do
        MySQL.insert.await('INSERT IGNORE INTO `zrx_tebex_limited` (model) VALUES (?)', {
            data.model
        })
    end
end)

lib.cron.new('*/15 * * * *', function()
    local packs = {}

    for player, state in pairs(ZRX_UTIL.getPlayers()) do
        packs = ManagePlayer(player).getTypes()

        for i, abo in pairs(packs) do
            ManagePlayer(player).hasAbo(abo)
        end
    end
end)

-- {'transid':'{transaction}', 'packagename':'{packageName}'}
RegisterCommand('zrx_tebex_purchase', function(source, args)
    print(args[1])
    if source ~= 0 then return end

    local buyData = json.decode(args[1])
    local tbxId = buyData.transid
    local packageName = buyData.packagename

    MySQL.insert.await('INSERT INTO `zrx_tebex` (tbxId, packageName) VALUES (?, ?)', {
        tbxId, packageName
    })

    print('Transaction insert', tbxId, packageName)
    lib.logger(-1, 'zrx_tebex:purchase', args[1])
end, true)

lib.callback.register('zrx_tebex:server:getCoins', function(player)
    return GetCoins(player)
end)

lib.callback.register('zrx_tebex:server:fetchOwnedVehicles', function(player)
    local xPlayer = ZRX_UTIL.fwObj.GetPlayerFromId(player)
    local formatted = {}
    local response = MySQL.query.await('SELECT * FROM `owned_vehicles` WHERE `owner` = ?', {
        xPlayer.identifier
    })

    for index, data in pairs(response) do
        formatted[#formatted + 1] = {
            value = data.plate,
            label = data.plate
        }
    end

    return formatted
end)

lib.callback.register('zrx_tebex:server:getVehicleLimits', function()
    local response = MySQL.query.await('SELECT * FROM `zrx_tebex_limited`', {})
    local formatted = {}
    local cfg = Config.Shop.vehicles

    for index, data in pairs(response) do
        for index2, data2 in pairs(cfg) do
            if data2.limited and data.model == data2.model then
                formatted[data2.model] = {
                    curAmount = data.count,
                    maxAmount = data2.limited
                }
            end
        end
    end

    return formatted
end)

lib.callback.register('zrx_tebex:server:getDuration', function(player, package)
    return ManagePlayer(player).getDuration(package)
end)

RegisterNetEvent('zrx_tebex:server:redeem', function(data)
    local tbxId = data.tbxId
    local player = source
    local identifier = GetPlayerIdentifierByType(player, 'license'):gsub('license:', '')
    local response = MySQL.query.await('SELECT * FROM `zrx_tebex` WHERE `tbxId` = ?', {
        tbxId
    })

    if not response[1] then
        print('No package', tbxId)
        return
    end

    local claimed = response[1].claimed
    local packageName = response[1].packageName
    print(claimed)

    if claimed then
        print('Package alrdy claimed', tbxId, packageName, claimed)
        ZRX_UTIL.notify(player, Strings.tbx_code_alrdy_redeemed, 'Tebex', 'error')
        return
    end

    local targetCoins = Config.Coins[packageName].amount

    local response = MySQL.query.await('SELECT * FROM `zrx_tebex_coins` WHERE `identifier` = ?', {
        identifier
    })

    if response[1] then
        local coinsToAdd = response[1].coins+targetCoins
        MySQL.update.await('UPDATE zrx_tebex_coins SET coins = ? WHERE identifier = ?', {
            coinsToAdd, identifier
        })

        Player(player).state:set('zrx_tebex:coins', coinsToAdd, true)
        print('Coins redeem', tbxId, packageName, coinsToAdd)
    else
        MySQL.insert.await('INSERT INTO `zrx_tebex_coins` (identifier, coins) VALUES (?, ?)', {
            identifier, targetCoins
        })

        Player(player).state:set('zrx_tebex:coins', targetCoins, true)
        print('Coins redeem2', tbxId, packageName, targetCoins)
    end

    lib.logger(player, 'zrx_tebex:redeemCode', 'Code redeemed ' .. tbxId .. ' ' .. packageName .. ' ' .. targetCoins)
    ZRX_UTIL.notify(player, Strings.tbx_code_redeem:format(targetCoins), 'Tebex', 'success')

    MySQL.update.await('UPDATE zrx_tebex SET claimed = 1 WHERE tbxId = ?', {
        tbxId
    })
end)

RegisterNetEvent('zrx_tebex:server:buy', function(data)
    local player = source
    print('datareceived', ZRX_UTIL.fwObj.DumpTable(data))
    if not data.type or not data.index then return end
    if not Config.Shop?[data.type]?[data.index] then return end

    local cfg = Config.Shop[data.type][data.index]
    local identifier = GetPlayerIdentifierByType(player, 'license'):gsub('license:', '')
    local response = MySQL.query.await('SELECT * FROM `zrx_tebex_coins` WHERE `identifier` = ?', {
        identifier
    })

    if not response[1] then
        ZRX_UTIL.notify(player, Strings.buy_to_less, 'Tebex', 'error')
        return
    end
    local targetCoins = response[1].coins

    if targetCoins < cfg.cost then
        print('notenoughcoins', data.type, data.index, cfg.cost, targetCoins)
        ZRX_UTIL.notify(player, Strings.buy_to_less, 'Tebex', 'error')
        return
    end

    print('wanttobuy', data.type, data.index)

    if data.type == 'items' then
        if ZRX_UTIL.inv == 'ox' then
            ZRX_UTIL.invObj:AddItem(player, cfg.item, cfg.amount, cfg.metadata)
        else
            ZRX_UTIL.fwObj.GetPlayerFromId(player).addInventoryItem(cfg.item, cfg.amount)
        end

        print('itemadded', cfg.item, cfg.amount, cfg.metadata)
        lib.logger(player, 'zrx_tebex:buyItem', 'Buy Item ' .. cfg.item .. ' ' .. cfg.amount)
    elseif data.type == 'vehicles' then
        local coords = GetEntityCoords(GetPlayerPed(player))
        local plate = ''
        local vehicle = 0
        local responseModel

        if cfg?.limited then
            responseModel = MySQL.query.await('SELECT * FROM `zrx_tebex_limited` WHERE `model` = ?', {
                cfg.model
            })

            if responseModel[1].count >= cfg.limited then
                print('limited reached', cfg.model)
                return
            end
        end

        if GetResourceState('mVehicle') ~= 'missing' then
            exports.mVehicle:CreateVehicle({
                vehicle  = { model = cfg.model, fuelLevel = 100 },
                job      = nil,
                source   = player,
                owner    = identifier,
                setOwner = true,
                intocar  = false,
                coords   = vec3(coords.x, coords.y, coords.z - 10.0),
            }, function(VehicleData, Vehicle)
                vehicle = Vehicle.entity
                plate = Vehicle.plate
            end)

            while not DoesEntityExist(vehicle) do
                print('Wait')
                Wait(100)
            end

            DeleteEntity(vehicle)

            MySQL.update.await('UPDATE owned_vehicles SET stored = 1, parking = ?, pound = NULL WHERE plate = ?', {
                cfg.parking, plate
            })
        else
            local networkId = ZRX_UTIL.fwObj.OneSync.SpawnVehicle(cfg.model,vec3(coords.x, coords.y, coords.z - 10.0), 0, {}, nil, cfg.type)
            local xPlayer = ZRX_UTIL.fwObj.GetPlayerFromId(player)

            Wait(200)
            vehicle = NetworkGetEntityFromNetworkId(networkId)
            Wait(200)

            plate = GetVehicleNumberPlateText(vehicle)

            local props = {
                plate = plate,
                fuelLevel = 100.0,
                model = joaat(cfg.model),
                engineHealth = 1000.0,
                bodyHealth = 1000.0,
                tankHealth = 1000.0,
            }

            MySQL.insert.await('INSERT INTO `owned_vehicles` (owner, plate, stored, vehicle, type, parking) VALUES (?, ?, ?, ?, ?, ?)', {
                xPlayer.identifier, plate, 1, json.encode(props), cfg.type, cfg.parking
            })

            DeleteEntity(vehicle)
        end

        if cfg?.limited then
            MySQL.update.await('UPDATE zrx_tebex_limited SET count = ? WHERE model = ?', {
                responseModel[1].count + 1, cfg.model
            })
        end

        print('vehicleparked', plate)
        lib.logger(player, 'zrx_tebex:buyVehicle', 'Buy Vehicle ' .. cfg.model .. ' ' .. cfg.type .. ' ' .. plate)
        ZRX_UTIL.notify(player, Strings.buy_veh_parked:format(plate), 'Tebex', 'success')
    elseif data.type == 'onetime' then
        if data.index == 'phone_number' then
            local oldPhoneNumber = Config.GetPhoneNumber(player)
            local newPhoneNumber = data.phoneNumber
            local maxLength = Config.GetPhoneNumberMaxLength()

            print(maxLength, type(maxLength))

            print('received', oldPhoneNumber, newPhoneNumber, maxLength)

            if type(newPhoneNumber) ~= 'number' then
                print('phone number invalid', newPhoneNumber, newPhoneNumber:len(), type(newPhoneNumber))
                return
            end

            if tostring(newPhoneNumber):len() > maxLength then
                print('phone number to long', newPhoneNumber, newPhoneNumber:len(), maxLength)
                return
            end

            local fetchPhoneNumber = Config.PhonePrefix .. newPhoneNumber
            local response = MySQL.query.await('SELECT * FROM `phone_phones` WHERE `phone_number` = ?', {
                fetchPhoneNumber
            })

            if response[1] then
                print('phone number taken', newPhoneNumber, ZRX_UTIL.fwObj.DumpTable(response[1]))
                ZRX_UTIL.notify(player, Strings.buy_phone_alrdy_taken, 'Tebex', 'error')
                return
            end

            local setPhoneNumber = Config.PhonePrefix .. newPhoneNumber
            local re = MySQL.update.await('UPDATE phone_phones SET phone_number = ? WHERE phone_number = ?', {
                setPhoneNumber, oldPhoneNumber
            })

            print(ZRX_UTIL.fwObj.DumpTable(re))

            lib.logger(player, 'zrx_tebex:buyPhonenumber', 'Buy Phonenumber ' .. oldPhoneNumber .. ' ' .. newPhoneNumber)
            TriggerClientEvent('zrx_tebex:client:reloadPhone', player)
            ZRX_UTIL.notify(player, Strings.buy_phone_changed, 'Tebex', 'success')
        elseif data.index == 'numberplate' then
            local oldNumberPlate = data.oldNumberPlate
            local newNumberPlate = data.newNumberPlate

            print('received', oldNumberPlate, newNumberPlate)

            if not IsValidPlate(newNumberPlate) then
                print('numberplate wrong format', oldNumberPlate, newNumberPlate)
                ZRX_UTIL.notify(player, Strings.buy_plate_wrong_format, 'Tebex', 'error')
                return
            end

            local returned = Config.DoesPlateExist(newNumberPlate)
            --print(ZRX_UTIL.fwObj.DumpTable(returned))
            if returned then
                print('numberplateexist', oldNumberPlate, newNumberPlate)
                ZRX_UTIL.notify(player, Strings.buy_plate_alrdy_taken, 'Tebex', 'error')
                return
            end

            local vehicle = Config.GetVehicleByPlate(oldNumberPlate)
            local response = MySQL.query.await('SELECT * FROM `owned_vehicles` WHERE `plate` = ?', { oldNumberPlate })
            local props = json.decode(response[1].vehicle)
            props.plate = newNumberPlate

            --print(ZRX_UTIL.fwObj.DumpTable(vehicle))
            if DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end

            MySQL.update.await('UPDATE owned_vehicles SET plate = ?, stored = 1, pound = NULL, vehicle = ? WHERE plate = ?', {
                newNumberPlate, json.encode(props), oldNumberPlate
            })

            lib.logger(player, 'zrx_tebex:buyPlate', 'Buy Plate ' .. oldNumberPlate .. ' ' .. newNumberPlate)
            ZRX_UTIL.notify(player, Strings.buy_plate_changed, 'Tebex', 'success')
        elseif data.index == 'change_uid' then
            local oldUid = exports.zrx_uniqueid:GetPlayerUIDfromSID(player)
            local newUid = data.newUid
            print('received', oldUid, newUid)
            local state = exports.zrx_uniqueid:ChangePlayerUID(player, oldUid, newUid)

            if not state then
                print('UID alrdy taken', oldUid, newUid)
                ZRX_UTIL.notify(player, Strings.buy_uid_alrdy_taken, 'Tebex', 'error')
                return
            end

            lib.logger(player, 'zrx_tebex:buyUID', 'Buy UID ' .. oldUid .. ' ' .. newUid)
            ZRX_UTIL.notify(player, Strings.buy_uid_changed, 'Tebex', 'success')
        end
    elseif data.type == 'abo' then
        local hasAbo = ManagePlayer(player).hasAbo(data.index)

        if hasAbo then
            print('hasAbo', data.type)
            return
        end

        ManagePlayer(player).setAbo(data.index, cfg.days)
        print('redeem plus', data.index, cfg.days)
        lib.logger(player, 'zrx_tebex:buyAbo', 'Buy Abo ' .. data.index .. ' ' .. cfg.days)
        ZRX_UTIL.notify(player, Strings.buy_abo:format(cfg.label, cfg.days), 'Tebex', 'success')
    end

    local coinsToAdd = targetCoins - cfg.cost

    MySQL.update.await('UPDATE zrx_tebex_coins SET coins = ? WHERE identifier = ?', {
        coinsToAdd, identifier
    })

    Player(player).state:set('zrx_tebex:coins', coinsToAdd, true)
    print('coinsremoved', cfg.cost, targetCoins, coinsToAdd)
    lib.logger(player, 'zrx_tebex:coinsRemoved', 'Coins Removed ' .. cfg.cost .. ' ' .. targetCoins .. ' ' .. coinsToAdd)
end)

AddCoins = function(executor, player, amount)
    local target = player
    local targetCoins = amount
    local identifier = GetPlayerIdentifierByType(tostring(target), 'license'):gsub('license:', '')

    local response = MySQL.query.await('SELECT * FROM `zrx_tebex_coins` WHERE `identifier` = ?', {
        identifier
    })

    if response[1] then
        local coinsToAdd = targetCoins + response[1].coins

        MySQL.update.await('UPDATE zrx_tebex_coins SET coins = ? WHERE identifier = ?', {
            coinsToAdd, identifier
        })

        Player(player).state:set('zrx_tebex:coins', coinsToAdd, true)
        print('Coins added', response[1]?.coins, targetCoins, coinsToAdd)
    else
        MySQL.insert.await('INSERT INTO `zrx_tebex_coins` (identifier, coins) VALUES (?, ?)', {
           identifier, targetCoins
        })

        Player(player).state:set('zrx_tebex:coins', targetCoins, true)
        print('Coins added2', targetCoins)
    end

    lib.logger(executor, 'zrx_tebex:coinsAdd', 'Coins Added to ' .. target .. ' ' .. targetCoins)
    ZRX_UTIL.notify(executor, Strings.add_executor:format(GetPlayerName(target), targetCoins), 'Tebex', 'success')
    ZRX_UTIL.notify(target, Strings.add_target:format(targetCoins), 'Tebex', 'info')
end
exports('addCoins', AddCoins)

RegisterCommand('addcoins', function(source, args)
    if not args[1] or type(tonumber(args[1])) ~= 'number' or type(tonumber(args[2])) ~= 'number' then
        return
    end

    local xPlayer = ZRX_UTIL.fwObj.GetPlayerFromId(source)

    if not Config.Groups[xPlayer.group] then
        return
    end

    AddCoins(source, tonumber(args[1]), tonumber(args[2]))
end, true)

RemCoins = function(executor, player, amount)
    local target = player
    local targetCoins = amount
    local identifier = GetPlayerIdentifierByType(tostring(target), 'license'):gsub('license:', '')

    local response = MySQL.query.await('SELECT * FROM `zrx_tebex_coins` WHERE `identifier` = ?', {
        identifier
    })

    if response[1] then
        local coinsToAdd = response[1].coins - targetCoins

        MySQL.update.await('UPDATE zrx_tebex_coins SET coins = ? WHERE identifier = ?', {
            coinsToAdd, identifier
        })

        print('Coins removed', response[1].coins, targetCoins, coinsToAdd)

        Player(player).state:set('zrx_tebex:coins', coinsToAdd, true)
        lib.logger(executor, 'zrx_tebex:coinsRem', 'Coins Removed to ' .. target .. ' ' .. targetCoins .. ' ' .. coinsToAdd)
        ZRX_UTIL.notify(executor, Strings.rem_executor:format(GetPlayerName(target), targetCoins), 'Tebex', 'success')
        ZRX_UTIL.notify(target, Strings.rem_target:format(targetCoins), 'Tebex', 'info')
    else
        print('Player has no coins')
        ZRX_UTIL.notify(executor, 'Der Spieler hat keine Coins', 'Tebex', 'error')
    end
end
exports('remCoins', RemCoins)

RegisterCommand('remcoins', function(source, args)
    if not args[1] or type(tonumber(args[1])) ~= 'number' or type(tonumber(args[2])) ~= 'number' then
        return
    end

    local xPlayer = ZRX_UTIL.fwObj.GetPlayerFromId(source)

    if not Config.Groups[xPlayer.group] then
        return
    end

    RemCoins(source, tonumber(args[1]), tonumber(args[2]))
end, true)

SetCoins = function(executor, player, amount)
    local target = player
    local targetCoins = amount
    local identifier = GetPlayerIdentifierByType(tostring(target), 'license'):gsub('license:', '')

    local response = MySQL.query.await('SELECT * FROM `zrx_tebex_coins` WHERE `identifier` = ?', {
        identifier
    })

    if response[1] then
        MySQL.update.await('UPDATE zrx_tebex_coins SET coins = ? WHERE identifier = ?', {
            targetCoins, identifier
        })

        print('Coins set', targetCoins)
    else
        MySQL.insert.await('INSERT INTO `zrx_tebex_coins` (identifier, coins) VALUES (?, ?)', {
            identifier, targetCoins
        })

        print('Coins set', targetCoins)
    end

    Player(player).state:set('zrx_tebex:coins', targetCoins, true)
    lib.logger(executor, 'zrx_tebex:coinsSet', 'Coins set to ' .. target .. ' ' .. targetCoins)
    ZRX_UTIL.notify(executor, Strings.set_executor:format(GetPlayerName(target), targetCoins), 'Tebex', 'success')
    ZRX_UTIL.notify(target, Strings.set_target:format(targetCoins), 'Tebex', 'info')
end
exports('setCoins', SetCoins)

RegisterCommand('setcoins', function(source, args)
    if not args[1] or type(tonumber(args[1])) ~= 'number' or type(tonumber(args[2])) ~= 'number' then
        return
    end

    local xPlayer = ZRX_UTIL.fwObj.GetPlayerFromId(source)

    if not Config.Groups[xPlayer.group] then
        return
    end

    SetCoins(source, tonumber(args[1]), tonumber(args[2]))
end, true)

IsValidPlate = function(plate)
    if #plate > 8 then
        print(2)
        return false
    end

    if not plate:match('^%w+$') then
        print(4)
        return false
    end

    return true
end

GetCoins = function(player)
    local identifier = GetPlayerIdentifierByType(player, 'license'):gsub('license:', '')
    local coins = 0
    local response = MySQL.query.await('SELECT * FROM `zrx_tebex_coins` WHERE `identifier` = ?', {
        identifier
    })

    if response[1] then
        coins = response[1].coins
    end

    Player(player).state:set('zrx_tebex:coins', coins, true)

    return coins
end

exports('getCoins', function(player)
    return GetCoins(player)
end)

exports('setAbo', function(target, package, days)
    if not target then return end

    ManagePlayer(target).setAbo(package, days)
end)

exports('getDuration', function(target, package)
    if not target then return end

    local remain, text = ManagePlayer(target).getDuration(package)

    return remain, text
end)

exports('hasAbo', function(target, package)
    if not target then return end

    return ManagePlayer(target).hasAbo(package)
end)