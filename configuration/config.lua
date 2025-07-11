---@diagnostic disable: param-type-mismatch
math = lib.math

Config = {}

Config.Command = 'zrx_tebex'
Config.Keybind = 'F7'
Config.StoreUrl = 'https://tebex.zrxnx.at/'

Config.Menu = {
    type = 'context', --| context or menu
    postition = 'top-left' --| top-left, top-right, bottom-left or bottom-right
}

Config.Coins = {
    ['500 Coins'] = { --| EXACT Packagename
        amount = 500, --| Coins to give
        text = '€ 4,99 | 500 Coins', --| Displaytext
        url = '500-coins', --| URL of the package
    },
    ['1100 Coins'] = {
        amount = 1100,
        text = '€ 9,99 | 1100 Coins',
        url = '1100-coins',
    },
    ['2300 Coins'] = {
        amount = 2300,
        text = '€ 19,99 | 2300 Coins',
        url = '2300-coins',
    },
    ['4000 Coins'] = {
        amount = 4000,
        text = '€ 34,99 | 4000 Coins',
        url = '4000-coins',
    },
}

Config.Shop = {
    items = {
        {
            cost = 100, --| Coin Cost
            item = 'burger', --| Item Name
            amount = 1, --| Amount
            metadata = nil, --| Metadata

            label = 'Burger', --| Displayname
        },
    },

    vehicles = {
        {
            cost = 1200, --| Coin Cost
            model = 'jugular', --| Model name
            type = 'automobile', --| https://docs.fivem.net/natives/?_0xA273060E
            parking = 'SanAndreasAvenue', --| Default parking
            limited = false, --| disable: false | enable: number

            label = 'Jugular', --| Displayname
            image = '', --| Image Preview | Only needed for addon vehicles

            metadata = {
                { label = 'KMH', value = '190' },
            }
        },
    },

    onetime = {
        phone_number = { --| Configure it on the bottom of this file
            enabled = true,
            cost = 500, --| Coin Cost
            label = 'Phone Number', --| Displayname
        },

        numberplate = { --| Configure it on the bottom of this file
            enabled = true,
            cost = 500, --| Coin Cost
            label = 'Vehicle Numberplate', --| Displayname
        },

        change_uid = { --| Only support zrx_uniqueid
            enabled = true,
            cost = 500, --| Coin Cost
            label = 'Change UID', --| Displayname
        },
    },

    abo = {
        plus = { --| YOU NEED TO IMPLEMENT THIS TO YOUR SCRIPT BY YOURSELF!!! | IF YOU DONT KNOW HOW TO CODE DONT USE THIS | server/benefits.lua is an example
            enabled = false,
            cost = 500, --| Coin Cost
            label = 'Plus', --| Displayname
            days = 14, --| Duration

            metadata = { --| Benefit display
                { label = 'Exclusive giveaways', value = '✅' },
                { label = 'Exclusive daily rewards', value = '✅' },
                { label = 'Discord rank', value = '✅' },
                { label = 'Discord lounge', value = '✅' },
            }
        }
    }
}

--| Admin Groups
Config.Groups = {
    admin = true
}

Config.Notify = function(player, msg, title, type, color, time)
    if IsDuplicityVersion() then
        TriggerClientEvent('ox_lib:notify', player, {
            title = title,
            description = msg,
            type = type,
            duration = time,
            style = {
                color = color
            }
        })
    else
        lib.notify({
            title = title,
            description = msg,
            type = type,
            duration = time,
            style = {
                color = color
            }
        })
    end
end

--| PHONE CONFIG

Config.PhonePrefix = '000' --| String

Config.GetPhoneNumber = function(player)
    if IsDuplicityVersion() then
        return exports['lb-phone']:GetEquippedPhoneNumber(player)
    else
        return exports['lb-phone']:GetEquippedPhoneNumber()
    end
end

Config.GetPhoneNumberMaxLength = function()
    if IsDuplicityVersion() then
        return exports['lb-phone']:GetConfig().PhoneNumber.Length
    else
        return exports['lb-phone']:GetConfig().PhoneNumber.Length
    end
end

--| Client Side
Config.ReloadPhone = function()
    exports['lb-phone']:ToggleOpen(false, true)
    Wait(100)
    exports['lb-phone']:ReloadPhone()
end

--| VEHICLE CONFIG

--| Server side obv?
Config.DoesPlateExist = function(plate)
    return MySQL.scalar.await('SELECT 1 FROM `owned_vehicles` WHERE TRIM(`plate`) = TRIM(?)', { plate })
end

--| Server side obv?
Config.GetVehicleByPlate = function(plate)
    plate = ZRX_UTIL.trim(plate)
    local vehicles = GetAllVehicles()
    local vehicle = 0

    for k, data in pairs(vehicles) do
        if plate:lower() == ZRX_UTIL.trim(GetVehicleNumberPlateText(data)):lower() then
            vehicle = data
            break
        end
    end

    return vehicle
end