local Config = require 'config.config'

lib.addCommand('newpole', {
    help = 'Add a new dance pole',
    params = {},
    restricted = 'group.admin'
}, function(source, args, raw)
    TriggerClientEvent('bm_dance:pole', source)
end)

-- Handle NPC earnings from pole dancing
RegisterNetEvent('bm_dance:earnMoney', function(npcCount)
    local src = source
    
    if not Config.NPCEarnings.enabled then
        return
    end
    
    -- Validate NPC count
    if not npcCount or npcCount <= 0 then
        return
    end
    
    -- Limit the maximum NPCs that can contribute
    local actualNPCCount = math.min(npcCount, Config.NPCEarnings.maxNPCsCount)
    
    -- Calculate earnings per NPC
    local totalEarnings = 0
    for i = 1, actualNPCCount do
        local npcEarning = math.random(Config.NPCEarnings.minEarnings, Config.NPCEarnings.maxEarnings)
        totalEarnings = totalEarnings + npcEarning
    end
    
    -- Give money using Qbox framework
    if GetResourceState('qbx_core') == 'started' then
        local Player = exports.qbx_core:GetPlayer(src)
        if Player then
            Player.Functions.AddMoney('cash', totalEarnings, 'pole-dance-tips')
            
            if Config.NPCEarnings.enableNotifications then
                TriggerClientEvent('bm_dance:notifyEarnings', src, totalEarnings, actualNPCCount)
            end
        end
    else
        -- Fallback for other frameworks
        print('[POLEDANCE] Warning: No compatible framework found for money handling')
    end
end)

-- Handle bar item purchases
RegisterNetEvent('bm_bar:buyItem', function(data)
    local src = source

    if not data or not data.item or not data.price then
        return
    end
    local quantity = tonumber(data.quantity) or 1
    if quantity < 1 then quantity = 1 end

    -- Get player using Qbox framework
    if GetResourceState('qbx_core') == 'started' then
        local Player = exports.qbx_core:GetPlayer(src)
        if not Player then
            return
        end
        local totalPrice = data.price * quantity

        -- Check if player has enough money
        local playerMoney = Player.Functions.GetMoney('cash')
        if playerMoney < totalPrice then
            TriggerClientEvent('lib:notify', src, {
                title = 'Purchase Failed',
                description = 'Not enough cash! You need $' .. totalPrice,
                type = 'error',
                icon = 'fas fa-exclamation-triangle'
            })
            return
        end
        
        -- Optional: pre-check capacity when ox_inventory is present
        if GetResourceState('ox_inventory') == 'started' then
            local can = exports.ox_inventory:CanCarryItem(src, data.item, quantity)
            if not can then
                TriggerClientEvent('lib:notify', src, {
                    title = 'Purchase Failed',
                    description = 'Your inventory is full!',
                    type = 'error',
                    icon = 'fas fa-exclamation-triangle'
                })
                return
            end
        end

        -- Remove money and add item(s)
        if Player.Functions.RemoveMoney('cash', totalPrice, 'bar-purchase') then
            -- Try to add item using ox_inventory if available
            if GetResourceState('ox_inventory') == 'started' then
                local success = exports.ox_inventory:AddItem(src, data.item, quantity)
                if success then
                    TriggerClientEvent('lib:notify', src, {
                        title = 'Purchase Successful',
                        description = ('You bought %dx %s for $%d'):format(quantity, data.label, totalPrice),
                        type = 'success',
                        icon = 'fas fa-shopping-cart'
                    })
                else
                    -- Refund if item couldn't be added
                    Player.Functions.AddMoney('cash', totalPrice, 'bar-purchase-refund')
                    TriggerClientEvent('lib:notify', src, {
                        title = 'Purchase Failed',
                        description = 'Your inventory is full!',
                        type = 'error',
                        icon = 'fas fa-exclamation-triangle'
                    })
                end
            else
                -- Fallback: try qbx_core inventory
                local success = Player.Functions.AddItem(data.item, quantity)
                if success then
                    TriggerClientEvent('lib:notify', src, {
                        title = 'Purchase Successful',
                        description = ('You bought %dx %s for $%d'):format(quantity, data.label, totalPrice),
                        type = 'success',
                        icon = 'fas fa-shopping-cart'
                    })
                else
                    -- Refund if item couldn't be added
                    Player.Functions.AddMoney('cash', totalPrice, 'bar-purchase-refund')
                    TriggerClientEvent('lib:notify', src, {
                        title = 'Purchase Failed',
                        description = 'Your inventory is full!',
                        type = 'error',
                        icon = 'fas fa-exclamation-triangle'
                    })
                end
            end
        else
            TriggerClientEvent('lib:notify', src, {
                title = 'Purchase Failed',
                description = 'Transaction error occurred',
                type = 'error',
                icon = 'fas fa-exclamation-triangle'
            })
        end
    else
        -- Fallback for other frameworks
        print('[POLEDANCE] Warning: No compatible framework found for item purchases')
        TriggerClientEvent('lib:notify', src, {
            title = 'Purchase Failed',
            description = 'Shop system not available',
            type = 'error',
            icon = 'fas fa-exclamation-triangle'
        })
    end
end)
