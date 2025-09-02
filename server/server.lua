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
