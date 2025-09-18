Config = {}

Config.Locale = 'en'
Config.LocaleFallback = 'en'

Config.Debug = false

Config.SessionDuration = 480
Config.SellCooldown = 6

Config.SessionMoveRadius = 35.0

Config.SessionPersistence = {
    enabled = true,
    saveInterval = 30 -- seconds between automatic session state saves
}

Config.BuyerSpawnInterval = { min = 8, max = 14 }
Config.BuyerSpawnDistance = { min = 35, max = 55 }
Config.BuyerSpawnAttempts = 8
Config.MaxConcurrentBuyers = 3

Config.Webhook = {
    enabled = false,
    url = "",
    bigSaleThreshold = 5000, -- triggers a webhook when a single sale meets or exceeds this amount
    milestoneStep = 25 -- fires when reputation hits multiples of this value
}

Config.ReputationTiers = {
    {
        name = "Rookie",
        min = 0,
        payoutBonus = 0.0,
        alertModifier = 0,
        rejectModifier = 0,
        aggressionModifier = 0
    },
    {
        name = "Hustler",
        min = 15,
        payoutBonus = 0.1,
        alertModifier = -2,
        rejectModifier = -3,
        aggressionModifier = -1
    },
    {
        name = "Supplier",
        min = 35,
        payoutBonus = 0.2,
        alertModifier = -4,
        rejectModifier = -5,
        aggressionModifier = -2
    },
    {
        name = "Kingpin",
        min = 60,
        payoutBonus = 0.35,
        alertModifier = -6,
        rejectModifier = -8,
        aggressionModifier = -3
    }
}

Config.DrugData = {
    coke_pure = {
        item = "coke_pure",
        label = "Pure Coke",
        price = { min = 275, max = 425 },
        quantity = { min = 1, max = 2 },
        alertChance = 12,
        rejectChance = 10,
        aggressionChance = 6,
        repGain = 0.35
    },
    coke_figure = {
        item = "coke_figure",
        label = "Action Figure Coke",
        price = { min = 210, max = 330 },
        quantity = { min = 1, max = 2 },
        alertChance = 8,
        rejectChance = 14,
        aggressionChance = 4,
        repGain = 0.25
    },
    meth_bag = {
        item = "meth_bag",
        label = "Meth Bag",
        price = { min = 240, max = 360 },
        quantity = { min = 1, max = 2 },
        alertChance = 11,
        rejectChance = 12,
        aggressionChance = 7,
        repGain = 0.3
    },
    weed = {
        item = "weed",
        label = "Weed",
        price = { min = 75, max = 150 },
        quantity = { min = 1, max = 4 },
        alertChance = 6,
        rejectChance = 18,
        aggressionChance = 2,
        repGain = 0.1
    },
    weed_package = {
        item = "weed_package",
        label = "Weed Package",
        price = { min = 90, max = 160 },
        quantity = { min = 1, max = 4 },
        alertChance = 6,
        rejectChance = 18,
        aggressionChance = 2,
        repGain = 0.12
    },
    ecstasy1 = {
        item = "ecstasy1",
        label = "Ecstasy (Blue)",
        price = { min = 65, max = 125 },
        quantity = { min = 1, max = 5 },
        alertChance = 5,
        rejectChance = 20,
        aggressionChance = 3,
        repGain = 0.11
    },
    ecstasy2 = {
        item = "ecstasy2",
        label = "Ecstasy (Green)",
        price = { min = 65, max = 125 },
        quantity = { min = 1, max = 5 },
        alertChance = 5,
        rejectChance = 20,
        aggressionChance = 3,
        repGain = 0.11
    },
    ecstasy3 = {
        item = "ecstasy3",
        label = "Ecstasy (Orange)",
        price = { min = 65, max = 125 },
        quantity = { min = 1, max = 5 },
        alertChance = 5,
        rejectChance = 20,
        aggressionChance = 3,
        repGain = 0.11
    },
    ecstasy4 = {
        item = "ecstasy4",
        label = "Ecstasy (Pink)",
        price = { min = 65, max = 125 },
        quantity = { min = 1, max = 5 },
        alertChance = 5,
        rejectChance = 20,
        aggressionChance = 3,
        repGain = 0.11
    },
    ecstasy5 = {
        item = "ecstasy5",
        label = "Ecstasy (Yellow)",
        price = { min = 65, max = 125 },
        quantity = { min = 1, max = 5 },
        alertChance = 5,
        rejectChance = 20,
        aggressionChance = 3,
        repGain = 0.11
    },
    lsd1 = {
        item = "lsd1",
        label = "LSD (Blotter 1)",
        price = { min = 75, max = 140 },
        quantity = { min = 1, max = 4 },
        alertChance = 6,
        rejectChance = 18,
        aggressionChance = 4,
        repGain = 0.14
    },
    lsd2 = {
        item = "lsd2",
        label = "LSD (Blotter 2)",
        price = { min = 75, max = 140 },
        quantity = { min = 1, max = 4 },
        alertChance = 6,
        rejectChance = 18,
        aggressionChance = 4,
        repGain = 0.14
    },
    lsd3 = {
        item = "lsd3",
        label = "LSD (Blotter 3)",
        price = { min = 75, max = 140 },
        quantity = { min = 1, max = 4 },
        alertChance = 6,
        rejectChance = 18,
        aggressionChance = 4,
        repGain = 0.14
    },
    lsd4 = {
        item = "lsd4",
        label = "LSD (Blotter 4)",
        price = { min = 75, max = 140 },
        quantity = { min = 1, max = 4 },
        alertChance = 6,
        rejectChance = 18,
        aggressionChance = 4,
        repGain = 0.14
    },
    lsd5 = {
        item = "lsd5",
        label = "LSD (Blotter 5)",
        price = { min = 75, max = 140 },
        quantity = { min = 1, max = 4 },
        alertChance = 6,
        rejectChance = 18,
        aggressionChance = 4,
        repGain = 0.14
    },
    magicmushroom = {
        item = "magicmushroom",
        label = "Magic Mushroom",
        price = { min = 95, max = 160 },
        quantity = { min = 1, max = 3 },
        alertChance = 7,
        rejectChance = 16,
        aggressionChance = 4,
        repGain = 0.18
    },
    peyote = {
        item = "peyote",
        label = "Peyote",
        price = { min = 110, max = 180 },
        quantity = { min = 1, max = 3 },
        alertChance = 6,
        rejectChance = 15,
        aggressionChance = 5,
        repGain = 0.2
    },
    xanaxpack = {
        item = "xanaxpack",
        label = "Pack of Xanax",
        price = { min = 150, max = 260 },
        quantity = { min = 1, max = 2 },
        alertChance = 8,
        rejectChance = 14,
        aggressionChance = 3,
        repGain = 0.22
    },
    xanaxpill = {
        item = "xanaxpill",
        label = "Xanax Pill",
        price = { min = 35, max = 60 },
        quantity = { min = 2, max = 6 },
        alertChance = 5,
        rejectChance = 18,
        aggressionChance = 2,
        repGain = 0.12
    },
    heroin = {
        item = "heroin",
        label = "Heroin",
        price = { min = 240, max = 380 },
        quantity = { min = 1, max = 2 },
        alertChance = 12,
        rejectChance = 12,
        aggressionChance = 8,
        repGain = 0.32
    },
    crack = {
        item = "crack",
        label = "Crack",
        price = { min = 180, max = 320 },
        quantity = { min = 1, max = 3 },
        alertChance = 11,
        rejectChance = 14,
        aggressionChance = 7,
        repGain = 0.28
    }
}

Config.CustomPeds = {
    `a_m_m_skater_01`,
    `a_m_y_stbla_02`,
    `a_m_y_hipster_01`
}