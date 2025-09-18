local repFile = "data/reputation.json"
local sessionFile = "data/sessions.json"

local QBCore = exports['qb-core']:GetCoreObject()
local inv = exports.ox_inventory

local function loadJson(path)
    local raw = LoadResourceFile(GetCurrentResourceName(), path)
    if not raw or raw == "" then
        return {}
    end

    local ok, data = pcall(json.decode, raw)
    if not ok then
        print(("[DrugSale] Failed to parse %s: %s"):format(path, data))
        return {}
    end

    if type(data) ~= "table" then
        return {}
    end

    return data
end

local function saveJson(path, data)
    SaveResourceFile(GetCurrentResourceName(), path, json.encode(data, { indent = true }), -1)
end

local repState = loadJson(repFile)
local sessionState = loadJson(sessionFile)
local activeSessions = {}
local sessionDirty = false

do
    local now = os.time()
    for identifier, data in pairs(sessionState) do
        if type(data) ~= "table" or not data.expiresAt or data.expiresAt <= now then
            sessionState[identifier] = nil
            sessionDirty = true
        end
    end
end

if Config.ReputationTiers then
    table.sort(Config.ReputationTiers, function(a, b)
        return (a.min or 0) < (b.min or 0)
    end)
end

local function clampChance(value)
    return math.max(0.0, math.min(100.0, value or 0))
end

local function debugLog(src, message, payload)
    if not Config.Debug then
        return
    end

    local prefix = src and tostring(src) or "server"
    local text = message

    if payload then
        text = ("%s %s"):format(text, json.encode(payload))
    end

    print(("[DrugSale][%s] %s"):format(prefix, text))

    if src and src ~= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "DrugSale Debug",
            description = text,
            type = 'inform'
        })
    end
end

local function getIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    if not identifiers or #identifiers == 0 then
        return nil
    end

    local preferred = { "license2:", "license:", "fivem:", "steam:" }

    for _, prefix in ipairs(preferred) do
        for _, identifier in ipairs(identifiers) do
            if identifier:sub(1, #prefix) == prefix then
                return identifier
            end
        end
    end

    return identifiers[1]
end

local function saveRep()
    saveJson(repFile, repState)
end

local function getRepByIdentifier(identifier)
    return tonumber(repState[identifier]) or 0
end

local function getPlayerRep(src)
    local identifier = getIdentifier(src)
    if not identifier then
        return 0, nil
    end

    return getRepByIdentifier(identifier), identifier
end

local function addRep(identifier, amount)
    local current = getRepByIdentifier(identifier)
    local newValue = math.max(0, math.floor((current + amount) * 100 + 0.5) / 100)

    repState[identifier] = newValue
    saveRep()

    return current, newValue
end

local function getTierBreakdown(rep)
    local tiers = Config.ReputationTiers or {}
    if #tiers == 0 then
        return {
            name = "Unranked",
            min = 0,
            payoutBonus = 0,
            alertModifier = 0,
            rejectModifier = 0,
            aggressionModifier = 0
        }, nil
    end

    local current = tiers[1]
    local nextTier = nil

    for i = 1, #tiers do
        local tier = tiers[i]
        if rep >= (tier.min or 0) then
            current = tier
        elseif not nextTier then
            nextTier = tier
            break
        end
    end

    return current, nextTier
end

local function summarizeTier(rep)
    local tier, nextTier = getTierBreakdown(rep)

    local summary = {
        name = tier.name or "Unranked",
        min = tier.min or 0,
        payoutBonus = tier.payoutBonus or 0,
        alertModifier = tier.alertModifier or 0,
        rejectModifier = tier.rejectModifier or 0,
        aggressionModifier = tier.aggressionModifier or 0
    }

    if nextTier then
        summary.next = {
            name = nextTier.name or "Unknown",
            min = nextTier.min or 0
        }
    end

    return tier, summary
end

local function computeChanceSet(drugConfig, tier)
    local base = {
        alert = clampChance(drugConfig.alertChance or 0),
        reject = clampChance(drugConfig.rejectChance or 0),
        aggression = clampChance(drugConfig.aggressionChance or 0)
    }

    local modifier = {
        alert = tier and (tier.alertModifier or 0) or 0,
        reject = tier and (tier.rejectModifier or 0) or 0,
        aggression = tier and (tier.aggressionModifier or 0) or 0
    }

    local final = {
        alert = clampChance(base.alert + modifier.alert),
        reject = clampChance(base.reject + modifier.reject),
        aggression = clampChance(base.aggression + modifier.aggression)
    }

    return base, final
end

local function determineOutcome(chances)
    if math.random(100) <= (chances.aggression or 0) then
        return 'aggression'
    end

    if math.random(100) <= (chances.reject or 0) then
        return 'reject'
    end

    if math.random(100) <= (chances.alert or 0) then
        return 'alert'
    end

    return 'success'
end

local function findSellableDrug(src)
    for key, data in pairs(Config.DrugData) do
        local count = inv:Search(src, 'count', data.item)
        if count and count > 0 then
            return key, data, count
        end
    end

    return nil, nil, 0
end

local function rollSale(drugConfig, inventoryCount)
    local quantityConfig = drugConfig.quantity or {}
    local priceConfig = drugConfig.price or {}

    local quantityMin = math.max(1, quantityConfig.min or 1)
    local quantityMax = math.max(quantityMin, quantityConfig.max or quantityMin)
    local availableMax = math.min(quantityMax, inventoryCount or 0)

    if availableMax <= 0 then
        return nil, nil, { error = 'not_enough_inventory' }
    end

    local saleMin = math.min(quantityMin, availableMax)
    local saleMax = availableMax

    local amount = math.random(saleMin, saleMax)
    if amount <= 0 then
        return nil, nil, { error = 'invalid_roll' }
    end

    local priceMin = priceConfig.min or 0
    local priceMax = priceConfig.max or priceMin
    if priceMax < priceMin then
        priceMax = priceMin
    end

    local unitPrice = math.random(priceMin, priceMax)
    local baseReward = math.floor(unitPrice * amount)

    return amount, baseReward, {
        unitPrice = unitPrice,
        saleMin = saleMin,
        saleMax = saleMax,
        priceMin = priceMin,
        priceMax = priceMax
    }
end

local function updateSessionState(identifier, session)
    sessionState[identifier] = {
        expiresAt = session.expiresAt,
        streak = session.streak or 0,
        saleCount = session.saleCount or 0,
        totalPayout = session.totalPayout or 0,
        bestSale = session.bestSale or 0
    }
    sessionDirty = true
end

local function buildSessionPayload(session, rep)
    local _, tierSummary = summarizeTier(rep)
    local timeRemaining = math.max(0, session.expiresAt - os.time())

    return {
        streak = session.streak or 0,
        saleCount = session.saleCount or 0,
        totalPayout = session.totalPayout or 0,
        bestSale = session.bestSale or 0,
        timeRemaining = timeRemaining,
        tier = tierSummary,
        rep = rep
    }
end

local function sendSessionUpdate(src)
    local session = activeSessions[src]
    if not session then
        return
    end

    local repValue = select(1, getPlayerRep(src))
    updateSessionState(session.identifier, session)

    TriggerClientEvent('aocdev:clientSessionUpdate', src, buildSessionPayload(session, repValue))
end

local function sendSessionStart(src, session, resumed)
    local repValue = select(1, getPlayerRep(src))
    local payload = buildSessionPayload(session, repValue)
    payload.resumed = resumed or false

    TriggerClientEvent('aocdev:clientStartSession', src, payload)
end

local function endSession(src, reason)
    local session = activeSessions[src]
    if not session then
        return
    end

    activeSessions[src] = nil
    sessionState[session.identifier] = nil
    sessionDirty = true

    TriggerClientEvent('aocdev:clientEndSession', src, { reason = reason })
end

local function suspendSession(src)
    local session = activeSessions[src]
    if not session then
        return
    end

    activeSessions[src] = nil

    updateSessionState(session.identifier, session)
end

local function startSession(src, stored, resumed)
    local identifier = getIdentifier(src)
    if not identifier then
        return nil, 'identifier_missing'
    end

    local now = os.time()
    local timeRemaining = Config.SessionDuration

    if stored and stored.expiresAt then
        timeRemaining = math.max(0, stored.expiresAt - now)
    end

    if timeRemaining <= 0 then
        sessionState[identifier] = nil
        sessionDirty = true
        return nil, 'expired'
    end

    local session = {
        identifier = identifier,
        source = src,
        started = now,
        expiresAt = now + timeRemaining,
        streak = stored and stored.streak or 0,
        saleCount = stored and stored.saleCount or 0,
        totalPayout = stored and stored.totalPayout or 0,
        bestSale = stored and stored.bestSale or 0
    }

    activeSessions[src] = session

    updateSessionState(identifier, session)
    sendSessionStart(src, session, resumed)

    return session
end

local function sendWebhook(title, description, color)
    if not Config.Webhook or not Config.Webhook.enabled then
        return
    end

    local url = Config.Webhook.url
    if not url or url == "" then
        return
    end

    PerformHttpRequest(url, function() end, 'POST', json.encode({
        embeds = {
            {
                title = title,
                description = description,
                color = color or 16753920,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }), {
        ['Content-Type'] = 'application/json'
    })
end

local function dispatchAlert(src, drugKey)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return
    end

    local coords = GetEntityCoords(ped)
    TriggerEvent('aocdev:drugsale:alert', src, coords, { drug = drugKey })
end

local function processSale(src)
    local rep, identifier = getPlayerRep(src)
    if not identifier then
        return {
            status = 'error',
            code = 'identifier_missing',
            message = _L('error_identifier')
        }
    end

    local tierTable, tierSummary = summarizeTier(rep)
    local drugKey, drugData, inventoryCount = findSellableDrug(src)

    if not drugKey then
        return {
            status = 'error',
            code = 'no_drugs',
            message = _L('session_no_drugs'),
            rep = rep,
            tier = tierSummary
        }
    end

    local baseChances, finalChances = computeChanceSet(drugData, tierTable)
    local outcome = determineOutcome(finalChances)
    local session = activeSessions[src]

    if outcome ~= 'success' then
        if session then
            session.streak = 0
            updateSessionState(session.identifier, session)
            sendSessionUpdate(src)
        end

        if outcome == 'alert' then
            dispatchAlert(src, drugKey)
        end

        debugLog(src, "Sale intercepted", {
            outcome = outcome,
            drug = drugKey,
            rep = rep,
            tier = tierSummary,
            chances = finalChances
        })

        local messageKey
        if outcome == 'alert' then
            messageKey = 'sale_alert_desc'
        elseif outcome == 'reject' then
            messageKey = 'sale_reject_desc'
        elseif outcome == 'aggression' then
            messageKey = 'sale_aggression_desc'
        end

        return {
            status = outcome,
            code = outcome,
            message = messageKey and _L(messageKey) or nil,
            label = drugData.label,
            baseChances = baseChances,
            finalChances = finalChances,
            rep = rep,
            tier = tierSummary
        }
    end

    local amount, baseReward, rollInfo = rollSale(drugData, inventoryCount)
    if not amount then
        debugLog(src, "Sale roll failed", rollInfo)
        return {
            status = 'error',
            code = rollInfo and rollInfo.error or 'invalid',
            message = _L('session_amount_error'),
            baseChances = baseChances,
            finalChances = finalChances,
            rep = rep,
            tier = tierSummary
        }
    end

    local removed = inv:RemoveItem(src, drugData.item, amount)
    if not removed then
        debugLog(src, "Inventory removal failed", { item = drugData.item, amount = amount })
        return {
            status = 'error',
            code = 'remove_failed',
            message = _L('sale_no_inventory'),
            baseChances = baseChances,
            finalChances = finalChances,
            rep = rep,
            tier = tierSummary
        }
    end

    local reward = math.floor(baseReward * (1 + (tierTable.payoutBonus or 0)))
    if reward <= 0 then
        reward = baseReward
    end

    inv:AddItem(src, "black_money", reward)

    local repGain = drugData.repGain or 0.1
    local previousRep, newRep = addRep(identifier, repGain)
    local newTierTable, newTierSummary = summarizeTier(newRep)

    local milestoneStep = Config.Webhook and Config.Webhook.milestoneStep or 0
    local milestone = false
    if milestoneStep and milestoneStep > 0 then
        local before = math.floor(previousRep / milestoneStep)
        local after = math.floor(newRep / milestoneStep)
        milestone = after > before
    end

    local sessionData = activeSessions[src]
    if sessionData then
        sessionData.streak = (sessionData.streak or 0) + 1
        sessionData.saleCount = (sessionData.saleCount or 0) + 1
        sessionData.totalPayout = (sessionData.totalPayout or 0) + reward
        if not sessionData.bestSale or reward > sessionData.bestSale then
            sessionData.bestSale = reward
        end

        updateSessionState(sessionData.identifier, sessionData)
        sendSessionUpdate(src)
    end

    if Config.Webhook and Config.Webhook.enabled then
        if Config.Webhook.bigSaleThreshold and reward >= Config.Webhook.bigSaleThreshold then
            sendWebhook("Big Sale", _L('webhook_big_sale', {
                name = GetPlayerName(src),
                label = drugData.label,
                amount = amount,
                reward = reward
            }), 65280)
        end

        if milestone then
            sendWebhook("Reputation Milestone", _L('webhook_milestone', {
                name = GetPlayerName(src),
                rep = newRep,
                tier = newTierSummary.name
            }), 255)
        end
    end

    debugLog(src, "Sale processed", {
        drug = drugKey,
        amount = amount,
        reward = reward,
        baseReward = baseReward,
        repGain = repGain,
        repBefore = previousRep,
        repAfter = newRep,
        tier = newTierSummary,
        chances = finalChances
    })

    return {
        status = 'success',
        code = 'success',
        label = drugData.label,
        amount = amount,
        reward = reward,
        repGain = repGain,
        repTotal = newRep,
        tier = newTierSummary,
        baseChances = baseChances,
        finalChances = finalChances,
        roll = rollInfo,
        milestone = milestone
    }
end

RegisterServerEvent('aocdev:attemptSale')
AddEventHandler('aocdev:attemptSale', function(requestId)
    local src = source
    local result = processSale(src)
    TriggerClientEvent('aocdev:saleOutcome', src, requestId, result)
end)

RegisterServerEvent('aocdev:requestStartSession')
AddEventHandler('aocdev:requestStartSession', function()
    local src = source
    if activeSessions[src] then
        TriggerClientEvent('aocdev:sessionDenied', src, { reason = 'already_active' })
        return
    end

    local identifier = getIdentifier(src)
    local stored = identifier and sessionState[identifier] or nil
    local session, err = startSession(src, stored, stored ~= nil)

    if not session then
        TriggerClientEvent('aocdev:sessionDenied', src, { reason = err })
    end
end)

RegisterServerEvent('aocdev:requestCancelSession')
AddEventHandler('aocdev:requestCancelSession', function()
    endSession(source, 'cancelled')
end)

RegisterServerEvent('aocdev:syncSession')
AddEventHandler('aocdev:syncSession', function()
    local src = source

    if activeSessions[src] then
        sendSessionUpdate(src)
        return
    end

    local identifier = getIdentifier(src)
    if not identifier then
        TriggerClientEvent('aocdev:clientNoSession', src)
        return
    end

    local stored = sessionState[identifier]
    if not stored then
        TriggerClientEvent('aocdev:clientNoSession', src)
        return
    end

    local session, err = startSession(src, stored, true)
    if not session then
        sessionState[identifier] = nil
        sessionDirty = true
        TriggerClientEvent('aocdev:clientNoSession', src)
    end
end)

RegisterServerEvent('aocdev:getRep')
AddEventHandler('aocdev:getRep', function()
    local src = source
    local repValue = select(1, getPlayerRep(src))
    local _, tierSummary = summarizeTier(repValue)

    TriggerClientEvent('aocdev:sendRep', src, {
        value = repValue,
        tier = tierSummary
    })
end)

RegisterCommand('drugsim', function(source)
    if source == 0 then
        print("[DrugSale] /drugsim is only available in-game.")
        return
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return
    end

    local hasPerm = QBCore.Functions.HasPermission(source, 'admin')
        or QBCore.Functions.HasPermission(source, 'god')
        or IsPlayerAceAllowed(source, 'command.drugsim')

    if not hasPerm then
        TriggerClientEvent('ox_lib:notify', source, {
            description = _L('drugsim_no_access'),
            type = 'error'
        })
        return
    end

    local repValue = select(1, getPlayerRep(source))
    local tierTable, tierSummary = summarizeTier(repValue)
    local entries = {}

    for key, data in pairs(Config.DrugData) do
        local price = data.price or {}
        local quantity = data.quantity or {}

        local minReward = (price.min or 0) * (quantity.min or 1)
        local maxReward = (price.max or price.min or 0) * (quantity.max or quantity.min or 1)

        local avgPrice = ((price.min or 0) + (price.max or price.min or 0)) / 2
        local avgQuantity = ((quantity.min or 1) + (quantity.max or quantity.min or 1)) / 2
        local avgReward = avgPrice * avgQuantity

        local finalMin = math.floor(minReward * (1 + (tierTable.payoutBonus or 0)))
        local finalMax = math.floor(maxReward * (1 + (tierTable.payoutBonus or 0)))
        local finalAvg = math.floor(avgReward * (1 + (tierTable.payoutBonus or 0)))

        local _, finalChances = computeChanceSet(data, tierTable)

        entries[#entries + 1] = {
            key = key,
            label = data.label,
            min = finalMin,
            max = finalMax,
            avg = finalAvg,
            chances = finalChances
        }
    end

    table.sort(entries, function(a, b)
        return (a.avg or 0) > (b.avg or 0)
    end)

    TriggerClientEvent('aocdev:openDrugSim', source, {
        tier = tierSummary,
        rep = repValue,
        entries = entries
    })
end)

AddEventHandler('playerDropped', function()
    suspendSession(source)
end)

CreateThread(function()
    while true do
        Wait(1000)

        local now = os.time()
        for src, session in pairs(activeSessions) do
            if session.expiresAt <= now then
                endSession(src, 'expired')
            end
        end
    end
end)

do
    local enabled = true
    local interval = 30

    if Config.SessionPersistence then
        if Config.SessionPersistence.enabled == false then
            enabled = false
        end
        if Config.SessionPersistence.saveInterval then
            interval = Config.SessionPersistence.saveInterval
        end
    end

    interval = math.max(5, math.floor(interval))

    if enabled then
        CreateThread(function()
            while true do
                Wait(interval * 1000)
                if sessionDirty then
                    saveJson(sessionFile, sessionState)
                    sessionDirty = false
                end
            end
        end)
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    saveRep()
    saveJson(sessionFile, sessionState)
end)
