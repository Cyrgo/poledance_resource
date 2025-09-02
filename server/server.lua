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
    
    -- Get player using Qbox framework
    if GetResourceState('qbx_core') == 'started' then
        local Player = exports.qbx_core:GetPlayer(src)
        if not Player then
            return
        end
        
        -- Check if player has enough money
        local playerMoney = Player.Functions.GetMoney('cash')
        if playerMoney < data.price then
            TriggerClientEvent('lib:notify', src, {
                title = 'Purchase Failed',
                description = 'Not enough cash! You need $' .. data.price,
                type = 'error',
                icon = 'fas fa-exclamation-triangle'
            })
            return
        end
        
        -- Remove money and add item
        if Player.Functions.RemoveMoney('cash', data.price, 'bar-purchase') then
            -- Try to add item using ox_inventory if available
            if GetResourceState('ox_inventory') == 'started' then
                local success = exports.ox_inventory:AddItem(src, data.item, 1)
                if success then
                    TriggerClientEvent('lib:notify', src, {
                        title = 'Purchase Successful',
                        description = 'You bought ' .. data.label .. ' for $' .. data.price,
                        type = 'success',
                        icon = 'fas fa-shopping-cart'
                    })
                else
                    -- Refund if item couldn't be added
                    Player.Functions.AddMoney('cash', data.price, 'bar-purchase-refund')
                    TriggerClientEvent('lib:notify', src, {
                        title = 'Purchase Failed',
                        description = 'Your inventory is full!',
                        type = 'error',
                        icon = 'fas fa-exclamation-triangle'
                    })
                end
            else
                -- Fallback: try qbx_core inventory
                local success = Player.Functions.AddItem(data.item, 1)
                if success then
                    TriggerClientEvent('lib:notify', src, {
                        title = 'Purchase Successful',
                        description = 'You bought ' .. data.label .. ' for $' .. data.price,
                        type = 'success',
                        icon = 'fas fa-shopping-cart'
                    })
                else
                    -- Refund if item couldn't be added
                    Player.Functions.AddMoney('cash', data.price, 'bar-purchase-refund')
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
