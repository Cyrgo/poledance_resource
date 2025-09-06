local polePoints = {}
local poleProps = {}
local modelTargs = {}
local changingZones = {}
local isDancing = false
local currentScene = nil
local earningThread = nil
local bartenderNPC = nil
local bartenderBlip = nil
local stripperNPCs = {}
local stripperScenes = {}
local Config = require 'config.config'

local function OpenChangingRoom()
    if GetResourceState('illenium-appearance') ~= 'started' then
        lib.notify({ title = 'Changing Room', description = 'Appearance not started', type = 'error' })
        print('[POLEDANCE] Changing Room: illenium-appearance not started')
        return
    end
    TriggerEvent('illenium-appearance:client:openClothingShopMenu', true)
end

-- Helper function to enumerate all peds
function EnumeratePeds()
    return coroutine.wrap(function()
        local iter, id = FindFirstPed()
        if not id or id == 0 then
            EndFindPed(iter)
            return
        end
        
        local enum = {handle = iter, destructor = EndFindPed}
        setmetatable(enum, entityEnumerator)
        
        local next = true
        repeat
            coroutine.yield(id)
            next, id = FindNextPed(iter)
        until not next
        
        enum.destructor, enum.handle = nil, nil
        EndFindPed(iter)
    end)
end

-- Entity enumerator metatable
entityEnumerator = {
    __gc = function(enum)
        if enum.destructor and enum.handle then
            enum.destructor(enum.handle)
        end
    end
}

-- Function to count nearby NPCs
local function GetNearbyNPCCount()
    if not Config.NPCEarnings.enabled then
        return 0
    end
    
    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    local nearbyNPCs = 0
    
    -- Get all peds in the area
    for ped in EnumeratePeds() do
        if ped ~= playerPed and DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(playerCoords - pedCoords)
            
            -- Check if ped is within radius and is an NPC (not player)
            if distance <= Config.NPCEarnings.checkRadius and not IsPedAPlayer(ped) then
                -- Additional checks to ensure it's a valid NPC
                if not IsPedDeadOrDying(ped, true) and GetPedType(ped) ~= 28 then -- 28 is animal type
                    nearbyNPCs = nearbyNPCs + 1
                end
            end
        end
    end
    
    return nearbyNPCs
end

-- Function to start earning money from NPCs
local function StartEarningMoney()
    if not Config.NPCEarnings.enabled or earningThread then
        return
    end
    
    earningThread = CreateThread(function()
        while isDancing do
            local npcCount = GetNearbyNPCCount()
            
            if npcCount > 0 then
                TriggerServerEvent('bm_dance:earnMoney', npcCount)
            end
            
            Wait(Config.NPCEarnings.earningInterval)
        end
        earningThread = nil
    end)
end

-- Function to stop earning money
local function StopEarningMoney()
    if earningThread then
        earningThread = nil
    end
end

-- Function to spawn bartender NPC
local function SpawnBartender()
    if not Config.Bartender.enabled then
        return
    end
    
    -- Remove existing bartender if exists
    if bartenderNPC then
        DeletePed(bartenderNPC)
        bartenderNPC = nil
    end
    
    -- Remove existing blip
    if bartenderBlip then
        RemoveBlip(bartenderBlip)
        bartenderBlip = nil
    end
    
    -- Request model
    lib.requestModel(Config.Bartender.model)
    
    -- Create NPC
    bartenderNPC = CreatePed(4, Config.Bartender.model, Config.Bartender.position.x, Config.Bartender.position.y, Config.Bartender.position.z - 1.0, Config.Bartender.position.w, false, true)
    
    -- Configure NPC
    SetEntityInvincible(bartenderNPC, true)
    FreezeEntityPosition(bartenderNPC, true)
    SetBlockingOfNonTemporaryEvents(bartenderNPC, true)
    SetPedDiesWhenInjured(bartenderNPC, false)
    SetPedCanPlayAmbientAnims(bartenderNPC, true)
    SetPedCanRagdollFromPlayerImpact(bartenderNPC, false)
    SetEntityCanBeDamaged(bartenderNPC, false)
    SetPedCanBeTargetted(bartenderNPC, false)
    
    -- Create blip if enabled
    if Config.Bartender.blip.enabled then
        bartenderBlip = AddBlipForCoord(Config.Bartender.position.x, Config.Bartender.position.y, Config.Bartender.position.z)
        SetBlipSprite(bartenderBlip, Config.Bartender.blip.sprite)
        SetBlipColour(bartenderBlip, Config.Bartender.blip.color)
        SetBlipScale(bartenderBlip, Config.Bartender.blip.scale)
        SetBlipAsShortRange(bartenderBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.Bartender.blip.name)
        EndTextCommandSetBlipName(bartenderBlip)
    end
    
    -- Add ox_target interaction
    if Config.Target == 'ox' then
        exports.ox_target:addLocalEntity(bartenderNPC, {
            {
                label = 'Order Drinks & Food',
                name = 'bartender_menu',
                icon = 'fas fa-cocktail',
                distance = 2.5,
                onSelect = function()
                    TriggerEvent('bm_bar:showMenu')
                end
            }
        })
    end
    
    print('[POLEDANCE] Bartender NPC spawned at', Config.Bartender.position)
end

-- Function to cleanup bartender
local function CleanupBartender()
    if bartenderNPC then
        if Config.Target == 'ox' then
            exports.ox_target:removeLocalEntity(bartenderNPC)
        end
        DeletePed(bartenderNPC)
        bartenderNPC = nil
    end
    
    if bartenderBlip then
        RemoveBlip(bartenderBlip)
        bartenderBlip = nil
    end
end

-- Function to spawn stripper NPCs at poles
local function NPCPlayLapDance(npc, anim)
    if not npc or not DoesEntityExist(npc) then return end
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(npc, anim.dict, anim.anim, 1.0, 1.0, -1, 1, 0, false, false, false)
end

local function StartStripperCycle(poleIndex)
    local data = stripperNPCs[poleIndex]
    if not data then return end
    local interval = Config.StripperNPCs.danceInterval or 180000
    SetTimeout(interval, function()
        local d = stripperNPCs[poleIndex]
        if not d then return end
        -- Only switch if present at pole
        if d.isPresent and DoesEntityExist(d.npc) then
            local animations = Config.StripperNPCs.lapDanceAnimations
            if animations and #animations > 0 then
                local newIndex = math.random(1, #animations)
                -- try not to repeat same anim back-to-back
                if d.currentAnimIndex and #animations > 1 then
                    for _ = 1, 3 do
                        if newIndex ~= d.currentAnimIndex then break end
                        newIndex = math.random(1, #animations)
                    end
                end
                d.currentAnimIndex = newIndex
                d.animation = animations[newIndex]
                ClearPedTasks(d.npc)
                NPCPlayLapDance(d.npc, d.animation)
            end
        end
        -- Schedule next regardless; guard will prevent if dismissed
        StartStripperCycle(poleIndex)
    end)
end

-- Function to spawn stripper NPCs at poles
local function SpawnStripperNPCs()
    if not Config.StripperNPCs.enabled then
        return
    end
    
    for poleIndex, pole in pairs(Config.Poles) do
        if not stripperNPCs[poleIndex] then
            -- Select random model
            local randomModel = Config.StripperNPCs.models[math.random(1, #Config.StripperNPCs.models)]
            
            -- Request model
            lib.requestModel(randomModel)
            
            -- Create NPC near the pole
            local npc = CreatePed(4, randomModel, pole.position.x, pole.position.y, pole.position.z - 1.0, pole.position.w, false, true)
            
            -- Configure NPC
            SetEntityInvincible(npc, true)
            SetBlockingOfNonTemporaryEvents(npc, true)
            SetPedDiesWhenInjured(npc, false)
            SetPedCanPlayAmbientAnims(npc, true)
            SetPedCanRagdollFromPlayerImpact(npc, false)
            SetEntityCanBeDamaged(npc, false)
            SetPedCanBeTargetted(npc, false)
            
            -- Use CreateThread to handle NPC dancing asynchronously
            CreateThread(function()
                -- Position NPC at pole first
                SetEntityCoords(npc, pole.position.x, pole.position.y, pole.position.z - 1.0, false, false, false, false)
                SetEntityHeading(npc, pole.position.w)
                Wait(300)

                -- Start with a random lap dance
                local lapAnims = Config.StripperNPCs.lapDanceAnimations
                local animIndex = 1
                if lapAnims and #lapAnims > 0 then
                    animIndex = math.random(1, #lapAnims)
                end
                local chosen = (lapAnims and lapAnims[animIndex])
                if chosen then
                    NPCPlayLapDance(npc, chosen)
                end
                stripperScenes[poleIndex] = nil
            end)
            
            -- Store NPC and scene data
            stripperNPCs[poleIndex] = {
                npc = npc,
                originalPosition = pole.position,
                isPresent = true,
                model = randomModel,
                animation = nil,
                currentAnimIndex = nil
            }
            -- Record current anim index
            local lapAnims = Config.StripperNPCs.lapDanceAnimations
            if lapAnims and #lapAnims > 0 then
                local idx = math.random(1, #lapAnims)
                stripperNPCs[poleIndex].currentAnimIndex = idx
                stripperNPCs[poleIndex].animation = lapAnims[idx]
            end
            stripperScenes[poleIndex] = nil

            -- Start periodic alternation of lap dances
            StartStripperCycle(poleIndex)
            
            print('[POLEDANCE] Spawned stripper NPC at pole', poleIndex)
        end
    end
end

-- Function to dismiss stripper NPC from pole
local function DismissStripperNPC(poleIndex)
    local stripperData = stripperNPCs[poleIndex]
    if not stripperData or not stripperData.isPresent then
        return
    end
    
    local npc = stripperData.npc
    
    -- Stop any synchronized scene (not used for lap dances)
    if stripperScenes[poleIndex] then
        NetworkStopSynchronisedScene(stripperScenes[poleIndex])
        stripperScenes[poleIndex] = nil
    end
    
    -- Clear animations and make NPC walk away
    ClearPedTasks(npc)
    SetPedCanPlayAmbientAnims(npc, true)
    
    -- Calculate random walk away position
    local originalPos = stripperData.originalPosition
    local angle = math.random() * 2 * math.pi
    local distance = Config.StripperNPCs.walkAwayDistance
    local walkPos = vec3(
        originalPos.x + math.cos(angle) * distance,
        originalPos.y + math.sin(angle) * distance,
        originalPos.z
    )
    
    -- Make NPC walk away
    TaskGoToCoordAnyMeans(npc, walkPos.x, walkPos.y, walkPos.z, 1.0, 0, 0, 786603, 0xbf800000)
    
    -- Mark as dismissed
    stripperData.isPresent = false
    
    print('[POLEDANCE] Dismissed stripper NPC from pole', poleIndex)
    
    -- Set timer to return NPC
    SetTimeout(Config.StripperNPCs.returnDelay, function()
        ReturnStripperNPC(poleIndex)
    end)
end

-- Function to return stripper NPC to pole
function ReturnStripperNPC(poleIndex)
    local stripperData = stripperNPCs[poleIndex]
    if not stripperData or stripperData.isPresent then
        return
    end
    
    local npc = stripperData.npc
    local pole = stripperData.originalPosition
    
    -- Check if player is still near the pole
    local playerCoords = GetEntityCoords(cache.ped)
    local distance = #(pole.xyz - playerCoords)
    
    if distance > Config.StripperNPCs.playerDetectionRadius then
        -- Clear tasks and move NPC back to pole
        ClearPedTasks(npc)
        SetEntityCoords(npc, pole.x, pole.y, pole.z - 1.0, false, false, false, false)
        SetEntityHeading(npc, pole.w)
        
    -- Restart lap dance animation when returning
    CreateThread(function()
        Wait(500) -- Wait to ensure positioning
        local lapAnims = Config.StripperNPCs.lapDanceAnimations
        if lapAnims and #lapAnims > 0 then
            local newIndex = math.random(1, #lapAnims)
            stripperData.currentAnimIndex = newIndex
            stripperData.animation = lapAnims[newIndex]
            NPCPlayLapDance(npc, stripperData.animation)
        end
        stripperScenes[poleIndex] = nil
        stripperData.isPresent = true
    end)
        
        print('[POLEDANCE] Returned stripper NPC to pole', poleIndex)
    else
        -- Player still near, try again later
        SetTimeout(Config.StripperNPCs.returnDelay, function()
            ReturnStripperNPC(poleIndex)
        end)
    end
end

-- Function to cleanup stripper NPCs
local function CleanupStripperNPCs()
    for poleIndex, stripperData in pairs(stripperNPCs) do
        if stripperData.npc then
            if stripperScenes[poleIndex] then
                NetworkStopSynchronisedScene(stripperScenes[poleIndex])
            end
            DeletePed(stripperData.npc)
        end
    end
    stripperNPCs = {}
    stripperScenes = {}
end

-- Function to dismiss NPCs when player starts dancing at their pole
local function DismissNPCAtPlayerPole()
    if not Config.StripperNPCs.enabled then
        return
    end
    
    local playerCoords = GetEntityCoords(cache.ped)
    
    -- Find which pole the player is dancing at
    for poleIndex, pole in pairs(Config.Poles) do
        local distance = #(pole.position.xyz - playerCoords)
        if distance <= 3.0 then -- Player is at this pole
            local stripperData = stripperNPCs[poleIndex]
            if stripperData and stripperData.isPresent then
                DismissStripperNPC(poleIndex)
                print('[POLEDANCE] Player started dancing, dismissed NPC from pole', poleIndex)
                break -- Only dismiss from one pole
            end
        end
    end
end


local function StopDancing()
    print('[POLEDANCE] Stopping dance - isDancing:', isDancing, 'currentScene:', currentScene)
    if not isDancing then return end
    
    isDancing = false
    
    -- Stop earning money from NPCs
    StopEarningMoney()
    
    -- Stop synchronized scene if one is active
    if currentScene then
        NetworkStopSynchronisedScene(currentScene)
        currentScene = nil
    end
    
    -- Clear any animations
    ClearPedTasks(cache.ped)
    ClearPedSecondaryTask(cache.ped)
    
    lib.notify({ title = 'Dance', description = 'Dance cancelled', type = 'inform' })
end

-- Build bar menu options dynamically
local function buildBarMenuOptions()
    local options = {
        { title = 'Vanilla Unicorn Bar' },
        { 
            title = 'Drinks', 
            description = 'Alcoholic beverages',
            icon = 'fas fa-wine-glass',
            menu = 'bar_drinks_menu'
        },
        { 
            title = 'Food', 
            description = 'Bar snacks and meals',
            icon = 'fas fa-hamburger',
            menu = 'bar_food_menu'
        }
    }
    return options
end

local function buildDrinksMenu()
    local options = {{ title = 'Available Drinks' }}
    
    for _, drink in pairs(Config.BarMenu.drinks) do
        table.insert(options, {
            title = drink.label,
            description = '$' .. drink.price,
            icon = 'fas fa-cocktail',
            event = 'bm_bar:purchase',
            args = { type = 'drink', item = drink }
        })
    end
    
    return options
end

local function buildFoodMenu()
    local options = {{ title = 'Available Food' }}
    
    for _, food in pairs(Config.BarMenu.food) do
        table.insert(options, {
            title = food.label,
            description = '$' .. food.price,
            icon = 'fas fa-utensils',
            event = 'bm_bar:purchase',
            args = { type = 'food', item = food }
        })
    end
    
    return options
end

-- Register bar menu contexts
lib.registerContext({
    id = 'bar_main_menu',
    title = 'Vanilla Unicorn Bar',
    options = buildBarMenuOptions()
})

lib.registerContext({
    id = 'bar_drinks_menu',
    title = 'Bar Drinks',
    menu = 'bar_main_menu',
    options = buildDrinksMenu()
})

lib.registerContext({
    id = 'bar_food_menu',
    title = 'Bar Food',
    menu = 'bar_main_menu',
    options = buildFoodMenu()
})

lib.registerContext({
    id = 'dance_menu',
    title = 'Select Your Dance',
    options = {
        { title = 'Dance Options' }, {
        title = 'Cancel Dance',
        icon = 'times',
        onSelect = function()
            print('[POLEDANCE] Cancelling dance via menu')
            StopDancing()
        end,
    }, {
        title = 'Pole Dance #1',
        icon = 'shoe-prints',
        event = 'bm_dance:start',
        args = { dance = 1 }
    }, {
        title = 'Pole Dance #2',
        icon = 'shoe-prints',
        event = 'bm_dance:start',
        args = { dance = 2 }
    }, {
        title = 'Pole Dance #3',
        icon = 'shoe-prints',
        event = 'bm_dance:start',
        args = { dance = 3 }
    }, {
        title = 'Lap Dance #1',
        icon = 'shoe-prints',
        event = 'bm_dance:start',
        args = {
            lapdance = 1,
            anim = 'lap_dance_girl',
            dict = 'mp_safehouse'
        }
    }, {
        title = 'Lap Dance #2',
        icon = 'shoe-prints',
        event = 'bm_dance:start',
        args = {
            lapdance = 2,
            anim = 'priv_dance_idle',
            dict = 'mini@strip_club@private_dance@idle'
        }
    }, {
        title = 'Lap Dance #3',
        icon = 'shoe-prints',
        event = 'bm_dance:start',
        args = {
            lapdance = 3,
            anim = 'priv_dance_p1',
            dict = 'mini@strip_club@private_dance@part1'
        }
    }, {
        title = 'Lap Dance #4',
        icon = 'shoe-prints',
        event = 'bm_dance:start',
        args = {
            lapdance = 4,
            anim = 'priv_dance_p2',
            dict = 'mini@strip_club@private_dance@part2'
        }
    }, {
        title = 'Lap Dance #5',
        icon = 'shoe-prints',
        event = 'bm_dance:start',
        args = {
            lapdance = 5,
            anim = 'priv_dance_p3',
            dict = 'mini@strip_club@private_dance@part3'
        }
    }, {
        title = 'Lap Dance #6',
        icon = 'shoe-prints',
        event = 'bm_dance:start',
        args = {
            lapdance = 6,
            anim = 'yacht_ld_f',
            dict = 'oddjobs@assassinate@multi@yachttarget@lapdance'
        }
    }
    }
})

lib.addKeybind({
    name = 'cancelpoledance',
    description = 'Cancel PoleDance',
    defaultKey = 'x',
    onReleased = function(self)
        if not isDancing then return end -- Check if the player is dancing or not.
        print('[POLEDANCE] Cancelling dance via X keybind')
        StopDancing()
    end
})

lib.addKeybind({
    name = 'poledancemenu',
    description = 'Open Dance Menu (while dancing)',
    defaultKey = 'e',
    onReleased = function(self)
        if isDancing then
            print('[POLEDANCE] Opening dance menu while dancing')
            lib.showContext('dance_menu')
        end
    end
})

local function StartRay()
    lib.showTextUI('[E] to copy  \n[DEL] to cancel')
    while true do
        local _, _, endCoords, _, _ = lib.raycast.cam(1, 4, 10)
        DrawMarker(21, endCoords.x, endCoords.y, endCoords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.1, 0.1, 0.1, 255, 255,
            255, 255, false, true, 0, false, false, false, false)
        if IsControlJustPressed(0, 38) or IsControlJustReleased(0, 38) then
            lib.hideTextUI()
            return endCoords
        elseif IsControlJustPressed(0, 178) or IsControlJustReleased(0, 178) then
            lib.hideTextUI()
            return nil
        end
        Wait(0)
    end
end

local function DestroyTargets()
    for _, pole in ipairs(polePoints) do
        if Config.Target == 'ox' then
            exports.ox_target:removeZone(pole)
            if Config.UseModels then
                for _, v in pairs(modelTargs) do
                    exports.ox_target:removeModel('prop_strip_pole_01', v)
                end
            end
        elseif Config.Target == 'qb' then
            exports['qb-target']:RemoveZone(pole)
        elseif Config.Target == 'lib' then
            pole:remove()
        end
    end
    for _, zone in ipairs(changingZones) do
        if Config.Target == 'ox' then
            exports.ox_target:removeZone(zone)
        elseif Config.Target == 'qb' then
            exports['qb-target']:RemoveZone(zone)
        elseif Config.Target == 'lib' then
            zone:remove()
        end
    end
    for _, pole in ipairs(poleProps) do
        if DoesEntityExist(pole) then
            DeleteObject(pole)
            DeleteEntity(pole)
        end
    end
end

local function CreateTargets()
    print('[POLEDANCE] Creating targets with config Target =', Config.Target)
    print('[POLEDANCE] Number of poles in config:', #Config.Poles)
    DestroyTargets()
    if Config.Target == 'ox' then
        if Config.UseModels then
            local modelTarg = exports.ox_target:addModel('prop_strip_pole_01', {
                {
                    label = "Pole Dance",
                    icon = "fas fa-shoe-prints",
                    distance = 3.0,
                    offsetSize = 2.0,
                    offset = vec3(1, 1, 1),
                    onSelect = function() lib.showContext('dance_menu') end
                }
            })
            modelTargs[#modelTargs + 1] = modelTarg
        end

        for k, v in pairs(Config.Poles) do
            print('[POLEDANCE] Processing pole', k, 'at position', v.position, 'with job', v.job or 'none')
            if v.spawn then
                print('[POLEDANCE] Spawning pole prop at', v.position)
                lib.requestModel('prop_strip_pole_01')
                local pole = CreateObject(joaat('prop_strip_pole_01'), v.position.x, v.position.y, v.position.z, false,
                    false,
                    false)
                poleProps[#poleProps + 1] = pole
            end
            local params = {
                coords = v.position,
                size = vec3(1, 1, 3) or v.size,
                rotation = v.position.w,
                debug = Config.Debug,
                options = {
                    {
                        label = 'Pole Dance',
                        name = 'Pole' .. k,
                        icon = 'fas fa-shoe-prints',
                        distance = 3.0,
                        groups = v.job,
                        onSelect = function()
                            print('[POLEDANCE] Player interacted with pole, showing dance menu')
                            lib.showContext('dance_menu')
                        end
                    }
                }
            }
            local poleZone = exports.ox_target:addBoxZone(params)
            print('[POLEDANCE] Created ox_target zone for pole', k, 'at', v.position)
            polePoints[#polePoints + 1] = poleZone
        end

        -- Changing Rooms (ox_target)
        if Config.ChangingRooms and #Config.ChangingRooms > 0 then
            for i, room in ipairs(Config.ChangingRooms) do
                local center = vec3(room.position.x, room.position.y, room.position.z)
                local params = {
                    coords = center,
                    size = (room.size or vec3(2.5, 2.5, 3.0)),
                    rotation = room.position.w or 0.0,
                    debug = Config.Debug,
                    options = {
                        {
                            label = 'Changing Room',
                            name = 'ChangingRoom' .. i,
                            icon = 'fas fa-tshirt',
                            distance = 3.0,
                            groups = room.job,
                            onSelect = function()
                                OpenChangingRoom()
                            end
                        }
                    }
                }
                local zone = exports.ox_target:addBoxZone(params)
                changingZones[#changingZones + 1] = zone
                print('[POLEDANCE] Created Changing Room (ox_target) at', room.position)
            end
        end
    elseif Config.Target == 'qb' then
        if Config.UseModels then
            exports['qb-target']:AddTargetModel('prop_strip_pole_01', {
                options = {
                    {
                        icon = 'fas fa-shoe-prints',
                        label = 'Pole Dance',
                        action = function()
                            lib.showContext('dance_menu')
                        end
                    }
                },
                distance = 1.5
            })
        end
        for k, v in pairs(Config.Poles) do
            if v.spawn then
                lib.requestModel('prop_strip_pole_01')
                local pole = CreateObject(joaat('prop_strip_pole_01'), v.position.x, v.position.y, v.position.z, false,
                    false,
                    false)
                poleProps[#poleProps + 1] = pole
            end
            local poleZone = exports['qb-target']:AddBoxZone('pole' .. k, v.position.xyz, 1.5, 1.5, {
                name = "pole" .. k,
                heading = v.position.w,
                debugPoly = Config.Debug,
                minZ = v.position.z - 2.0,
                maxZ = v.position.z + 2.0
            }, {
                options = {
                    {
                        icon = 'fas fa-shoe-prints',
                        label = 'Pole Dance',
                        action = function()
                            lib.showContext('dance_menu')
                        end
                    }
                },
                distance = 2.0
            }
            )
            polePoints[#polePoints + 1] = poleZone
        end

        -- Changing Rooms (qb-target)
        if Config.ChangingRooms and #Config.ChangingRooms > 0 then
            for i, room in ipairs(Config.ChangingRooms) do
                local zone = exports['qb-target']:AddBoxZone('changingroom_' .. i, room.position.xyz, (room.size and room.size.x or 2.5), (room.size and room.size.y or 2.5), {
                    name = 'changingroom_' .. i,
                    heading = room.position.w,
                    debugPoly = Config.Debug,
                    minZ = room.position.z - 1.75,
                    maxZ = room.position.z + ((room.size and room.size.z) or 3.0)
                }, {
                    options = {
                        {
                            icon = 'fas fa-tshirt',
                            label = 'Changing Room',
                            action = OpenChangingRoom,
                            job = room.job
                        }
                    },
                    distance = 2.0
                })
                changingZones[#changingZones + 1] = zone
                print('[POLEDANCE] Created Changing Room (qb-target) at', room.position)
            end
        end
    elseif Config.Target == 'lib' then
        for k, v in pairs(Config.Poles) do
            if v.spawn then
                lib.requestModel('prop_strip_pole_01')
                local pole = CreateObject(joaat('prop_strip_pole_01'), v.position.x, v.position.y, v.position.z, false,
                    false,
                    false)
                poleProps[#poleProps + 1] = pole
            end
            local params = {
                coords = vec3(v.position.x, v.position.y, v.position.z + 1.0),
                size = vec3(1, 1, 1),
                rotation = v.position.w,
                onEnter = function()
                    lib.showTextUI('Press [E] to dance')
                end,
                inside = function()
                    if isDancing then
                        lib.showTextUI('Press [X] to stop dancing')
                        if IsControlJustPressed(0, 73) then
                            isDancing = false
                            ClearPedTasks(cache.ped)
                            lib.hideTextUI()
                            lib.showTextUI('Press [E] to dance')
                        end
                    end
                    if IsControlJustReleased(0, 38) then
                        lib.showContext('dance_menu')
                    end
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                debug = Config.Debug,
            }
            local poleZone = lib.zones.box(params)
            polePoints[#polePoints + 1] = poleZone
        end
        -- Changing Rooms (lib.zones)
        if Config.ChangingRooms and #Config.ChangingRooms > 0 then
            for i, room in ipairs(Config.ChangingRooms) do
                local params = {
                    coords = vec3(room.position.x, room.position.y, room.position.z + 0.5),
                    size = room.size or vec3(2.5, 2.5, 3.0),
                    rotation = room.position.w,
                    onEnter = function()
                        lib.showTextUI('Press [E] to change clothes')
                    end,
                    inside = function()
                        if IsControlJustReleased(0, 38) then
                            OpenChangingRoom()
                        end
                    end,
                    onExit = function()
                        lib.hideTextUI()
                    end,
                    debug = Config.Debug,
                }
                local zone = lib.zones.box(params)
                changingZones[#changingZones + 1] = zone
                print('[POLEDANCE] Created Changing Room (lib) at', room.position)
            end
        end
    end
    for _, v in ipairs(Config.Poles) do
        local polePoint = lib.points.new({
            coords = v.position,
            distance = 3.0,
        })
    end
end

local function ToConfigFormat(poleConfig)
    local formattedConfig = "{ position = vec4(" ..
        poleConfig.position.x .. "," .. poleConfig.position.y .. "," .. poleConfig.position.z .. ",0.0),"
    if poleConfig.spawn then
        formattedConfig = formattedConfig .. " spawn = true },"
    else
        formattedConfig = formattedConfig .. " },"
    end
    return formattedConfig
end

RegisterNetEvent('bm_dance:start', function(args)
    print('[POLEDANCE] Dance event triggered with args:', json.encode(args))
    local position = GetEntityCoords(cache.ped)
    local usePolePosition = false
    if not args.coords then args.coords = position end
    if args.dance then
        print('[POLEDANCE] Processing pole dance', args.dance)
        local nearbyObjects = lib.points.getClosestPoint()
        if nearbyObjects then
            print('[POLEDANCE] Found nearby point object, starting synchronized scene')
            isDancing = true
            -- Dismiss stripper NPC when player starts dancing
            DismissNPCAtPlayerPole()
            currentScene = NetworkCreateSynchronisedScene(nearbyObjects.coords.x + 0.07, nearbyObjects.coords.y + 0.3,
                nearbyObjects.coords.z + 1.15, 0.0, 0.0, 0.0, 2, false, true, 1065353216, 0, 1.3)
            NetworkAddPedToSynchronisedScene(cache.ped, currentScene, 'mini@strip_club@pole_dance@pole_dance' .. args.dance,
                'pd_dance_0' .. args.dance, 1.5, -4.0, 1, 1, 1148846080, 0)
            NetworkStartSynchronisedScene(currentScene)
            -- Start earning money from nearby NPCs
            StartEarningMoney()
        else
            print('[POLEDANCE] No nearby point object found, using pole position')
            usePolePosition = true
        end
    elseif args.lapdance then
        print('[POLEDANCE] Processing lap dance', args.lapdance)
        -- Dismiss stripper NPC when player starts dancing (for lap dances too)
        DismissNPCAtPlayerPole()
        lib.requestAnimDict(args.dict)
        TaskPlayAnim(cache.ped, args.dict, args.anim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
        isDancing = true
        currentScene = nil -- Lap dances don't use synchronized scenes
        -- Start earning money from nearby NPCs
        StartEarningMoney()
    else
        local playerCoords = GetEntityCoords(cache.ped)
        for _, pole in ipairs(Config.Poles) do
            local distance = #(pole.position.xyz - playerCoords)
            if distance <= 3.0 then
                usePolePosition = true
                break
            end
        end
    end
    if usePolePosition then
        local closestPoint = lib.points.getClosestPoint()
        if closestPoint then
            if Config.Debug then print('Close') end
            args.coords = closestPoint.coords
            isDancing = true
            -- Dismiss stripper NPC when player starts dancing
            DismissNPCAtPlayerPole()
            currentScene = NetworkCreateSynchronisedScene(args.coords.x + 0.07, args.coords.y + 0.3,
                args.coords.z + 1.15, 0.0, 0.0, 0.0, 2, false, true, 1065353216, 0, 1.3)
            NetworkAddPedToSynchronisedScene(cache.ped, currentScene, 'mini@strip_club@pole_dance@pole_dance' .. args.dance,
                'pd_dance_0' .. args.dance, 1.5, -4.0, 1, 1, 1148846080, 0)
            NetworkStartSynchronisedScene(currentScene)
            -- Start earning money from nearby NPCs
            StartEarningMoney()
        else
            if Config.Debug then print('Not close') end
        end
    end
end)

-- Handle earnings notifications from server
RegisterNetEvent('bm_dance:notifyEarnings', function(earnings, npcCount)
    if Config.NPCEarnings.enableNotifications then
        local message = string.format("Earned $%d from %d nearby NPC%s!", earnings, npcCount, npcCount == 1 and "" or "s")
        lib.notify({ 
            title = 'Tips Received', 
            description = message, 
            type = 'success',
            icon = 'fa-solid fa-dollar-sign'
        })
    end
end)

-- Handle bar menu show event
RegisterNetEvent('bm_bar:showMenu', function()
    lib.showContext('bar_main_menu')
end)

-- Handle purchase event
RegisterNetEvent('bm_bar:purchase', function(data)
    local item = data.item
    local type = data.type

    -- Ask quantity first
    local response = lib.inputDialog('Purchase ' .. item.label, {
        {
            type = 'number',
            label = 'Quantity',
            description = 'How many do you want to buy?',
            required = true,
            default = 1,
            min = 1,
            max = 50
        }
    })
    if not response then return end
    local qty = tonumber(response[1]) or 1
    if qty < 1 then qty = 1 end

    local total = item.price * qty
    local confirm = lib.alertDialog({
        header = 'Confirm Purchase',
        content = ('Buy %dx %s for $%d?'):format(qty, item.label, total),
        centered = true,
        cancel = true
    })
    if confirm ~= 'confirm' then return end

    -- Trigger server purchase with quantity
    TriggerServerEvent('bm_bar:buyItem', {
        item = item.item,
        label = item.label,
        price = item.price,
        quantity = qty,
        type = type
    })
end)

RegisterNetEvent('bm_dance:pole', function()
    local polePosition = StartRay()
    if polePosition then
        local poleConfig = {
            position = vec4(polePosition.x, polePosition.y, polePosition.z, 0.0),
            spawn = true,
        }
        Config.Poles[#Config.Poles + 1] = poleConfig
        if Config.Debug then
            print("New pole added to Config.Poles:")
            print(ToConfigFormat(poleConfig))
        end
        lib.setClipboard(ToConfigFormat(poleConfig))
        lib.notify({ title = 'Dance', description = 'New pole added to clipboard', type = 'success' })
        CreateTargets()
    else
        print("Action canceled.")
    end
end)

-- Helper to copy Changing Room position config via raycast
RegisterNetEvent('bm_dance:changing', function()
    local pos = StartRay()
    if pos then
        local roomConfig = string.format("{ position = vec4(%.2f, %.2f, %.2f, 0.0), size = vec3(1.6, 1.6, 2.0) },",
            pos.x, pos.y, pos.z)
        lib.setClipboard(roomConfig)
        lib.notify({ title = 'Changing Room', description = 'New changing room copied to clipboard', type = 'success' })
        print('[POLEDANCE] Changing Room config:', roomConfig)
    else
        print('Action canceled.')
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    print('[POLEDANCE] Resource starting, creating targets, bartender, and stripper NPCs...')
    CreateTargets()
    SpawnBartender()
    SpawnStripperNPCs()
    print('[POLEDANCE] All systems created successfully')
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    DestroyTargets()
    CleanupBartender()
    CleanupStripperNPCs()
end)

if GetResourceState('qbx_core') == 'started' then
    AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
        Wait(3000)
        CreateTargets()
        SpawnBartender()
        SpawnStripperNPCs()
    end)
    AddEventHandler('qbx_core:client:PlayerLoaded', function()
        Wait(3000)
        CreateTargets()
        SpawnBartender()
        SpawnStripperNPCs()
    end)
end
