return {
    Debug = false,
    UseModels = false,                                    --UseModels true for all prop instances
    Target = 'ox',                                        --Target 'qb' or 'ox' or 'lib'
    
    -- NPC Earnings Configuration
    NPCEarnings = {
        enabled = true,                                   -- Enable/disable NPC earnings system
        checkRadius = 15.0,                               -- Radius to check for nearby NPCs
        minEarnings = 1,                                  -- Minimum cash per NPC
        maxEarnings = 5,                                  -- Maximum cash per NPC
        earningInterval = 15000,                          -- How often to give money (milliseconds)
        maxNPCsCount = 3,                                 -- Maximum NPCs that can contribute
        enableNotifications = true,                       -- Show earnings notifications
    },
    
    Poles = {
        { position = vec4(-1388.7698974609, -674.28186035156, 27.856121063232, 0.0), spawn = true }, -- position required, job optional, spawn optional
        -- Vanilla VU Poles
        -- Add job = 'jobname' to restrict access to specific jobs (e.g., job = 'unicorn')
        -- Leave job field empty or remove it for public access
        { position = vector4(104.16384124756, -1294.2568359375, 28.26, 30) },
        { position = vector4(102.25046539307, -1290.8802490234, 28.25, 30) },
        { position = vector4(112.580322265631, -1287.0412597656, 27.46, 30) }
    }

}
