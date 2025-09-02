local polePoints = {}
local poleProps = {}
local modelTargs = {}
local isDancing = false
local currentScene = nil
local earningThread = nil
local bartenderNPC = nil
local bartenderBlip = nil
local Config = require 'config.config'

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
    
    -- Show confirmation with loading indicator
    local alert = lib.alertDialog({
        header = 'Purchase ' .. item.label,
        content = 'Are you sure you want to buy ' .. item.label .. ' for $' .. item.price .. '?',
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        -- Trigger server purchase
        TriggerServerEvent('bm_bar:buyItem', {
            item = item.item,
            label = item.label,
            price = item.price,
            type = type
        })
    end
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

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    print('[POLEDANCE] Resource starting, creating targets and bartender...')
    CreateTargets()
    SpawnBartender()
    print('[POLEDANCE] Targets and bartender created successfully')
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    DestroyTargets()
    CleanupBartender()
end)

if GetResourceState('qbx_core') == 'started' then
    AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
        Wait(3000)
        CreateTargets()
        SpawnBartender()
    end)
    AddEventHandler('qbx_core:client:PlayerLoaded', function()
        Wait(3000)
        CreateTargets()
        SpawnBartender()
    end)
end
