---@diagnostic disable: undefined-field
RegisterKeyMapping(Config.Command, Strings.cmd_desc, 'keyboard', Config.Keybind)
RegisterCommand(Config.Command, function()
    OpenBuyMenu()
end, false)
TriggerEvent('chat:addSuggestion', ('/%s'):format(Config.Command), Strings.cmd_desc, {})

OpenBuyMenu = function()
    local MENU = {}
    local coins = lib.callback.await('zrx_tebex:server:getCoins', 1000)

    MENU[#MENU+1] = {
        title = Strings.buy_coins_title,
        description = Strings.buy_coins_desc:format(math.groupdigits(coins, '.')),
        icon = '',
        readOnly = true,
    }

    MENU[#MENU+1] = {
        description = '',
        disabled = true
    }

    MENU[#MENU+1] = {
        title = Strings.buy_redeem_title,
        description = Strings.buy_redeem_desc,
        icon = '',
        arrow = true,
        onSelect = function()
            local input = lib.inputDialog(Strings.buy_redeem_alert_title, {
                { type = 'input', label = Strings.buy_redeem_alert_label, description = Strings.buy_redeem_alert_desc, required = true, min = 25, max = 25 },
            })

            if not input then
                lib.showContext('zrx_tebex:OpenBuyMenu')
                return
            end

            TriggerServerEvent('zrx_tebex:server:redeem', { tbxId = input[1] })
        end
    }

    MENU[#MENU+1] = {
        title = Strings.buy_buy_title,
        description = Strings.buy_buy_desc,
        icon = '',
        arrow = true,
        onSelect = function()
            OpenCoinShop()
        end
    }

    MENU[#MENU+1] = {
        description = '',
        disabled = true
    }

    if #Config.Shop.items > 0 then
        MENU[#MENU+1] = {
            title = Strings.buy_items_title,
            description = Strings.buy_items_desc,
            icon = '',
            arrow = true,
            onSelect = function()
                OpenShopMenuItems()
            end
        }
    end

    if #Config.Shop.vehicles > 0 then
        MENU[#MENU+1] = {
            title = Strings.buy_vehicles_title,
            description = Strings.buy_vehicles_desc,
            icon = '',
            arrow = true,
            onSelect = function()
                OpenShopMenuVehicles()
            end
        }
    end

    MENU[#MENU+1] = {
        title = Strings.buy_onetime_title,
        description = Strings.buy_onetime_desc,
        icon = '',
        arrow = true,
        onSelect = function()
            OpenShopMenuOnetime()
        end
    }

    MENU[#MENU+1] = {
        title = Strings.buy_abo_title,
        description = Strings.buy_abo_desc,
        icon = '',
        arrow = true,
        onSelect = function()
            OpenShopMenuAbo()
        end
    }

    ZRX_UTIL.createMenu({
        id = 'zrx_tebex:OpenBuyMenu',
        title = Strings.buy_title,
    }, MENU, Config.Menu.type ~= 'menu', Config.Menu.postition)
end

OpenCoinShop = function()
    local MENU = {}

    for package, data in pairs(Config.Coins) do
        MENU[#MENU+1] = {
            title = data.text,
            description = Strings.shop_desc,
            icon = '',
            arrow = true,
            onSelect = function()
                SetNuiFocus(true, false)
                SendNUIMessage({
                    action = 'openUrl',
                    url = Config.StoreUrl .. data.url
                })
                SetNuiFocus(false, false)
            end
        }
    end

    ZRX_UTIL.createMenu({
        id = 'zrx_tebex:OpenCoinShop',
        title = Strings.shop_title,
        menu = 'zrx_tebex:OpenBuyMenu',
    }, MENU, Config.Menu.type ~= 'menu', Config.Menu.postition)
end

OpenShopMenuItems = function()
    local MENU = {}

    for index, data in pairs(Config.Shop.items) do
        MENU[#MENU+1] = {
            title = data.label,
            description = Strings.ishop_desc,
            icon = '',
            arrow = true,
            metadata = {
                { label = Strings.ishop_cost_title, value = Strings.ishop_cost_desc:format(math.groupdigits(data.cost, '.')) },
            },
            onSelect = function()
                local alert = lib.alertDialog({
                    header = Strings.ishop_alert_head,
                    content = Strings.ishop_alert_desc:format(data.label, math.groupdigits(data.cost, '.')),
                    centered = true,
                    cancel = true
                })

                if alert == 'cancel' then
                    lib.showContext('zrx_tebex:OpenBuyMenu')
                    return
                end

                TriggerServerEvent('zrx_tebex:server:buy', { type = 'items', index = index })
            end
        }
    end

    ZRX_UTIL.createMenu({
        id = 'zrx_tebex:OpenShopMenuItems',
        title = Strings.ishop_title,
        menu = 'zrx_tebex:OpenBuyMenu',
    }, MENU, Config.Menu.type ~= 'menu', Config.Menu.postition)
end

OpenShopMenuVehicles = function()
    local MENU = {}
    local limits = lib.callback.await('zrx_tebex:server:getVehicleLimits', 1000)
    local title = ''
    local disabled = false
    local metadata = {}

    for index, data in pairs(Config.Shop.vehicles) do
        metadata = data.metadata
        metadata[#metadata + 1] = { label = Strings.vshop_cost_title, value = Strings.vshop_cost_desc:format(math.groupdigits(data.cost, '.')) }
        title = data.label

        if data.limited then
            print(ZRX_UTIL.fwObj.DumpTable(limits))
            title = Strings.vshop_limited_title:format(title, limits[data.model].curAmount, limits[data.model].maxAmount)
            disabled = limits[data.model].curAmount >= limits[data.model].maxAmount
        end

        MENU[#MENU+1] = {
            title = title,
            description = Strings.vshop_desc,
            icon = '',
            arrow = true,
            metadata = metadata,
            image = data.image == '' and ('https://docs.fivem.net/vehicles/%s.webp'):format(data.model:lower()) or data.image,
            disabled = disabled,
            onSelect = function()
                local alert = lib.alertDialog({
                    header = Strings.vshop_alert_head,
                    content = Strings.vshop_alert_desc:format(data.label, math.groupdigits(data.cost, '.')),
                    centered = true,
                    cancel = true
                })

                if alert == 'cancel' then
                    lib.showContext('zrx_tebex:OpenBuyMenu')
                    return
                end

                TriggerServerEvent('zrx_tebex:server:buy', { type = 'vehicles', index = index })
            end
        }

        disabled = false
    end

    ZRX_UTIL.createMenu({
        id = 'zrx_tebex:OpenShopMenuVehicles',
        title = Strings.vshop_title,
        menu = 'zrx_tebex:OpenBuyMenu',
    }, MENU, Config.Menu.type ~= 'menu', Config.Menu.postition)
end

OpenShopMenuOnetime = function()
    local MENU = {}
    local cfg = Config.Shop.onetime

        MENU[#MENU+1] = {
            title = cfg.phone_number.label,
            description = Strings.otshop_phone_desc,
            icon = '',
            arrow = true,
            disabled = not cfg.phone_number.enabled,
            metadata = {
                { label = Strings.otshop_phone_mt_cost_title, value = Strings.otshop_phone_mt_cost_desc:format(math.groupdigits(cfg.phone_number.cost, '.')) },
                { label = Strings.otshop_phone_mt_number_title, value = Config.GetPhoneNumber() },
            },
            onSelect = function()
                local max = 9

                for i = 0, Config.GetPhoneNumberMaxLength() - 1, 1 do
                    max = max .. 9
                end

                print(max)

                local input = lib.inputDialog(Strings.otshop_phone_diag_title, {
                    { type = 'number', label = Strings.otshop_phone_diag_label, description = Strings.otshop_phone_diag_desc, required = true, max = max },
                })

                if not input then
                    lib.showContext('zrx_tebex:OpenBuyMenu')
                    return
                end

                if tostring(input[1]):len() > Config.GetPhoneNumberMaxLength() then
                    ZRX_UTIL.notify(nil, Strings.otshop_phone_to_long)
                    return
                end

                local alert = lib.alertDialog({
                    header = Strings.otshop_phone_head,
                    content = Strings.otshop_phone_desc2:format(Config.PhonePrefix .. ' ' .. input[1], math.groupdigits(cfg.phone_number.cost, '.')),
                    centered = true,
                    cancel = true
                })

                if alert == 'cancel' then
                    lib.showContext('zrx_tebex:OpenBuyMenu')
                    return
                end

                TriggerServerEvent('zrx_tebex:server:buy', { type = 'onetime', index = 'phone_number', phoneNumber = input[1] })
            end
        }

        MENU[#MENU+1] = {
            title = cfg.numberplate.label,
            description = Strings.otshop_plate_desc,
            icon = '',
            arrow = true,
            disabled = not cfg.numberplate.enabled,
            metadata = {
                { label = Strings.otshop_plate_mt_cost_title, value = Strings.otshop_plate_mt_cost_desc:format(math.groupdigits(cfg.numberplate.cost, '.')) },
            },
            onSelect = function()
                local numberPlates = lib.callback.await('zrx_tebex:server:fetchOwnedVehicles', 1000)

                if #numberPlates < 1 then
                    print('Keine Fahrzeuge', ZRX_UTIL.fwObj.DumpTable(numberPlates))

                    lib.alertDialog({
                        header = Strings.otshop_plate_no_title,
                        content = Strings.otshop_plate_no_desc,
                        centered = true,
                        cancel = false
                    })

                    lib.showContext('zrx_tebex:OpenBuyMenu')

                    return
                end

                local input = lib.inputDialog(Strings.otshop_plate_diag_title, {
                    { type = 'select', label = Strings.otshop_plate_diag_label, required = true, options = numberPlates },
                    { type = 'input', label = Strings.otshop_plate_diag_label2, description = Strings.otshop_plate_diag_desc, required = true, icon = 'hashtag', min = 3, max = 8 },
                })

                if not input then
                    lib.showContext('zrx_tebex:OpenBuyMenu')
                    return
                end

                local alert = lib.alertDialog({
                    header = Strings.otshop_plate_head,
                    content = Strings.otshop_plate_desc2:format(input[2], math.groupdigits(cfg.numberplate.cost, '.')),
                    centered = true,
                    cancel = true
                })

                if alert == 'cancel' then
                    lib.showContext('zrx_tebex:OpenBuyMenu')
                    return
                end

                TriggerServerEvent('zrx_tebex:server:buy', { type = 'onetime', index = 'numberplate', oldNumberPlate = input[1], newNumberPlate = input[2] })
            end
        }

        MENU[#MENU+1] = {
            title = cfg.change_uid.label,
            description = Strings.otshop_uid_desc,
            icon = '',
            arrow = true,
            disabled = not cfg.change_uid.enabled,
            metadata = {
                { label = Strings.otshop_uid_mt_cost_title, value = Strings.otshop_uid_mt_cost_desc:format(math.groupdigits(cfg.change_uid.cost, '.')) },
                { label = Strings.otshop_uid_mt_uid_title, value = exports.zrx_uniqueid:GetPlayerUIDfromSID(cache.serverId) },
            },
            onSelect = function()
                local input = lib.inputDialog(Strings.otshop_uid_diag_title, {
                    {type = 'number', label = Strings.otshop_uid_diag_label, description = Strings.otshop_uid_diag_desc, required = true, min = 1, max = 999999 },
                })

                if not input then
                    lib.showContext('zrx_tebex:OpenBuyMenu')
                    return
                end

                local alert = lib.alertDialog({
                    header = Strings.otshop_uid_head,
                    content = Strings.otshop_uid_desc2:format(input[1], math.groupdigits(cfg.change_uid.cost, '.')),
                    centered = true,
                    cancel = true
                })

                if alert == 'cancel' then
                    lib.showContext('zrx_tebex:OpenBuyMenu')
                    return
                end

                TriggerServerEvent('zrx_tebex:server:buy', { type = 'onetime', index = 'change_uid', newUid = input[1] })
            end
        }

    ZRX_UTIL.createMenu({
        id = 'zrx_tebex:OpenShopMenuOnetime',
        title = Strings.otshop_title,
        menu = 'zrx_tebex:OpenBuyMenu',
    }, MENU, Config.Menu.type ~= 'menu', Config.Menu.postition)
end

OpenShopMenuAbo = function()
    local MENU = {}
    local cfg = Config.Shop.abo
    local hasPlus, duration = false, 0
    local metadata = {}

    for index, data in pairs(cfg) do
        hasPlus, duration = lib.callback.await('zrx_tebex:server:getDuration', 1000, index)
        metadata = {}
        print(1)

        if hasPlus then
            MENU[#MENU+1] = {
                title = data.label,
                description = Strings.ashop_has_desc,
                icon = '',
                arrow = false,
                metadata = {
                    { label = Strings.ashop_has_mt_status_title, value = Strings.ashop_has_mt_status_desc },
                    { label = Strings.ashop_has_mt_duration_title, value = duration },
                },
                readOnly = true,
            }
        else
            metadata = data.metadata
            print(ZU.fwObj.DumpTable(metadata))
            metadata[#metadata + 1] = { label = Strings.ashop_mt_cost_title, value = Strings.ashop_mt_cost_desc:format(math.groupdigits(data.cost, '.')) }
            metadata[#metadata + 1] = { label = Strings.ashop_mt_duration_title, value = Strings.ashop_mt_duration_desc:format(data.days) }
            print(ZU.fwObj.DumpTable(metadata))

            MENU[#MENU+1] = {
                title = data.label,
                description = Strings.ashop_desc,
                icon = '',
                arrow = true,
                metadata = metadata,
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = Strings.ashop_head,
                        content = Strings.ashop_desc2:format(cfg.label, data.days, math.groupdigits(data.cost, '.')),
                        centered = true,
                        cancel = true
                    })

                    if alert == 'cancel' then
                        lib.showContext('zrx_tebex:OpenBuyMenu')
                        return
                    end

                    TriggerServerEvent('zrx_tebex:server:buy', { type = 'abo', index = index })
                end
            }
        end
    end

    ZRX_UTIL.createMenu({
        id = 'zrx_tebex:OpenShopMenuAbo',
        title = Strings.ashop_title,
        menu = 'zrx_tebex:OpenBuyMenu',
    }, MENU, Config.Menu.type ~= 'menu', Config.Menu.postition)
end

RegisterNetEvent('zrx_tebex:client:reloadPhone', function()
    Config.ReloadPhone()
end)