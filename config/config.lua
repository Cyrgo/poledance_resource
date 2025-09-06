return {
    Debug = false,
    UseModels = false,                                    --UseModels true for all prop instances
    Target = 'ox',                                        --Target 'qb' or 'ox' or 'lib'
    
    -- NPC Earnings Configuration
    NPCEarnings = {
        enabled = true,                                   -- Enable/disable NPC earnings system
        checkRadius = 15.0,                               -- Radius to check for nearby NPCs
        minEarnings = 4,                                  -- Minimum cash per NPC
        maxEarnings = 12,                                 -- Maximum cash per NPC
        earningInterval = 20000,                          -- How often to give money (milliseconds)
        maxNPCsCount = 3,                                 -- Maximum NPCs that can contribute
        enableNotifications = true,                       -- Show earnings notifications
    },
    
    -- Bartender Configuration
    Bartender = {
        enabled = true,                                   -- Enable/disable bartender NPC
        position = vec4(129.50, -1284.25, 29.27, 131.64), -- Perfect bartender position
        model = 's_f_y_bartender_01',                     -- Female Vanilla Unicorn bartender
        name = 'Vanilla Unicorn Bartender',               -- NPC name
        blip = {
            enabled = true,                               -- Show blip on map
            sprite = 93,                                  -- Blip icon (bar glass)
            color = 5,                                    -- Blip color (yellow)
            scale = 0.8,                                  -- Blip size
            name = 'Vanilla Unicorn Bar'                  -- Blip label
        }
    },
    
    -- Bar Menu Items
    BarMenu = {
        drinks = {
            { name = 'beer', label = 'Beer', price = 8, item = 'beer' },
            { name = 'whiskey', label = 'Whiskey', price = 15, item = 'whiskey' },
            -- { name = 'vodka', label = 'Vodka', price = 12, item = 'vodka' },
            -- { name = 'tequila', label = 'Tequila', price = 18, item = 'tequila' },
            -- { name = 'wine', label = 'Wine', price = 20, item = 'wine' },
            -- { name = 'cocktail', label = 'House Cocktail', price = 25, item = 'cocktail' }
        },
        food = {
            -- { name = 'sandwich', label = 'Club Sandwich', price = 12, item = 'sandwich' },
            { name = 'burger', label = 'Burger', price = 15, item = 'burger' },
            -- { name = 'pizza', label = 'Pizza Slice', price = 10, item = 'pizza' },
            -- { name = 'fries', label = 'Fries', price = 8, item = 'fries' },
            -- { name = 'wings', label = 'Chicken Wings', price = 18, item = 'wings' }
        }
    },
    
    -- Stripper NPC Configuration
    StripperNPCs = {
        enabled = true,                                   -- Enable/disable stripper NPCs
        models = {                                        -- Female stripper models
            'a_f_y_topless_01',
            's_f_y_stripper_01',
            's_f_y_stripper_02'
        },
        playerDetectionRadius = 4.0,                      -- Distance to detect approaching players
        walkAwayDistance = 10.0,                          -- How far NPCs walk when dismissed
        returnDelay = 5000,                               -- Delay before NPC returns (milliseconds)
        danceInterval = 180000,                           -- Time between lap dance changes (ms)
        -- Lap dance animations for NPCs (will cycle randomly)
        lapDanceAnimations = {
            { dict = 'mp_safehouse', anim = 'lap_dance_girl' },
            { dict = 'mini@strip_club@private_dance@idle', anim = 'priv_dance_idle' },
            { dict = 'mini@strip_club@private_dance@part1', anim = 'priv_dance_p1' },
            { dict = 'mini@strip_club@private_dance@part2', anim = 'priv_dance_p2' },
            { dict = 'mini@strip_club@private_dance@part3', anim = 'priv_dance_p3' },
            { dict = 'oddjobs@assassinate@multi@yachttarget@lapdance', anim = 'yacht_ld_f' }
        }
    },
    
    Poles = {
        { position = vec4(-1388.7698974609, -674.28186035156, 27.856121063232, 0.0), spawn = true }, -- position required, job optional, spawn optional
        -- Vanilla VU Poles
        -- Add job = 'jobname' to restrict access to specific jobs (e.g., job = 'unicorn')
        -- Leave job field empty or remove it for public access
        { position = vector4(104.16384124756, -1294.2568359375, 28.26, 30) },
        { position = vector4(102.25046539307, -1290.8802490234, 28.25, 30) },
        { position = vector4(112.580322265631, -1287.0412597656, 27.46, 30) }
    },

    -- Changing Rooms (open clothing menu / outfits)
    -- Add entries here to create one or more changing areas.
    -- Each entry: { position = vec4(x, y, z, heading), size = vec3(w, l, h), job = 'optionalJob' }
    -- If job is set, only that job can use the changing room.
    -- Defaults below are near Vanilla Unicorn back rooms; adjust as desired.
    ChangingRooms = {
        { position = vec4(107.35, -1305.13, 28.77, 165.34), size = vec3(2.5, 2.5, 3.0) },
    }

}
