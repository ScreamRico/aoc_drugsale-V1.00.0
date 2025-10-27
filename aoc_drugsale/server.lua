-- server.lua (Unified storage: file or SQL) for aoc_drugselling
-- Set Config.Storage = 'file' or 'sql' in config.lua
-- If using 'sql', ensure oxmysql is started and fxmanifest includes:
--   server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }
-- If using 'file', create a "data" folder inside this resource.

local QBCore = exports['qb-core']:GetCoreObject()
local inv = exports.ox_inventory

-- #########################
-- ### CONFIG REQUIRE
-- #########################
-- Expecting in config.lua:
-- Config = Config or {}
-- Config.Storage = 'file' or 'sql'
-- Config.SessionDuration, Config.ReputationTiers, Config.DrugData, Config.Webhook, Config.Debug, etc.

-- #########################
-- ### UTIL
-- #########################
-- #########################
-- ### VERSION CHECKER + EMBLEM (GitHub Releases only)
-- #########################

-- pad helper
local function _aoc_pad(s, n)
    s = tostring(s or '')
    local len = #s
    if len < n then return s .. string.rep(' ', n - len) else return s end
end

-- split helper
local function _aoc_lines(s)
    local t = {}
    for line in tostring(s or ''):gmatch("([^\n\r]*)\r?\n?") do
        if line == '' then if #t > 0 then break end else t[#t+1] = line end
    end
    return t
end

-- we’ll store the banner width so the version box matches it
local _AOC_BOX_W

local function emblem()
    -- allow Config.ShowEmblem = false to hide banner (checker still runs)
    if type(Config) == 'table' and Config.ShowEmblem == false then return end

    local art_block = [[
 ________  ________  ________  ________  _______   ___      ___ 
|\   __  \|\   __  \|\   ____\|\   ___ \|\  ___ \ |\  \    /  /|
\ \  \|\  \ \  \|\  \ \  \___|\ \  \_|\ \ \   __/|\ \  \  /  / /
 \ \   __  \ \  \\\  \ \  \    \ \  \ \\ \ \  \_|/_\ \  \/  / / 
  \ \  \ \  \ \  \\\  \ \  \____\ \  \_\\ \ \  \_|\ \ \    / /  
   \ \__\ \__\ \_______\ \_______\ \_______\ \_______\ \__/ /   
    \|__|\|__|\|_______|\|_______|\|_______|\|_______|\|__|/    
]]

    local extra = {
        "Powered by AOCdev",
        "Support: https://discord.gg/UNsfuymWCT",
    }

    local art = _aoc_lines(art_block)

    local inner = 0
    for _, line in ipairs(art)   do inner = math.max(inner, #line) end
    for _, line in ipairs(extra) do inner = math.max(inner, #line) end
    inner = math.max(inner, 64)
    _AOC_BOX_W = inner

    local top = '╔' .. string.rep('═', inner + 2) .. '╗'
    local bot = '╚' .. string.rep('═', inner + 2) .. '╝'

    local C = '^5'  -- banner color (purple). Use '^2' green or '^3' yellow if you prefer.
    local R = '^7'
    local RES_NAME = GetCurrentResourceName()
    local function tag(line) return ('[^2script:%s^7] %s%s%s'):format(RES_NAME, C, line, R) end

    print('')
    print(tag(top))
    for _, line in ipairs(art) do
        print(tag('║ ' .. _aoc_pad(line, inner) .. ' ║'))
    end
    print(tag('║ ' .. _aoc_pad('', inner) .. ' ║'))
    print(tag('║ ' .. _aoc_pad('Powered by ^3AOC_DEVELOPMENT^7', inner) .. ' ║'))
    print(tag('║ ' .. _aoc_pad('Support: https://discord.gg/UNsfuymWCT', inner) .. ' ║'))
    print(tag(bot))
end

-- pretty status box under the banner
local function version_box(current, latest, status, ok)
    local inner = _AOC_BOX_W or 64
    local top = '╔' .. string.rep('═', inner + 2) .. '╗'
    local bot = '╚' .. string.rep('═', inner + 2) .. '╝'
    local RES_NAME = GetCurrentResourceName()
    local C = ok and '^2' or '^1'  -- green if OK, red if update/error
    local R = '^7'
    local function tag(line) return ('[^2script:%s^7] %s%s%s'):format(RES_NAME, C, line, R) end

    print(tag(top))
    print(tag('║ ' .. _aoc_pad(('Current version: %s'):format(current), inner) .. ' ║'))
    if latest then
        print(tag('║ ' .. _aoc_pad(('Latest available: %s'):format(latest), inner) .. ' ║'))
    end
    print(tag('║ ' .. _aoc_pad(status, inner) .. ' ║'))
    print(tag(bot))
end

-- Version check (fxmanifest version + GitHub releases ONLY)
CreateThread(function()
    local RES_NAME = GetCurrentResourceName()
    local CURRENT  = GetResourceMetadata(RES_NAME, 'version', 0) or '0.0.0'
    local REPO_OWNER = 'ScreamRico'
    local REPO_NAME  = 'aoc_drugsale-V1.00.0'

    emblem()  -- show banner first

    local releasesURL = ('https://api.github.com/repos/%s/%s/releases/latest'):format(REPO_OWNER, REPO_NAME)
    PerformHttpRequest(releasesURL, function(code, body)
        if code ~= 200 or not body or body == '' then
            version_box(CURRENT, nil, ('Version check failed (HTTP %s)').format and ('Version check failed (HTTP %s)'):format(code) or ('Version check failed (HTTP '..tostring(code)..')'), false)
            return
        end

        local ok, data = pcall(function() return json.decode(body) end)
        if not ok or not data or not data.tag_name then
            version_box(CURRENT, nil, 'Version check parse error', false)
            return
        end

        local latest = tostring(data.tag_name):gsub('^v','')
        if CURRENT ~= latest then
            version_box(CURRENT, latest, 'Update available!', false)
            -- optional: also print a one-time info block with repo URL
            print(('^1============================================================^7'))
            print(('^1  Repo:^7 https://github.com/%s/%s'):format(REPO_OWNER, REPO_NAME))
            print(('^1============================================================^7'))
        else
            version_box(CURRENT, latest, 'You are running the latest version!', true)
        end
    end, 'GET', '', {
        ['User-Agent'] = 'FiveM-Version-Checker',
        ['Accept']     = 'application/vnd.github+json'
    })
end)
-- Simple template helper (no string.format specifiers)
local function _L(key, data)
    local map = {
        error_identifier     = 'Could not resolve your identifier.',
        session_no_drugs     = 'You have nothing to sell.',
        session_amount_error = 'Could not determine a valid sale amount.',
        sale_no_inventory    = 'No inventory to remove.',
        sale_alert_desc      = 'Your actions drew attention.',
        sale_reject_desc     = 'Buyer rejected your offer.',
        sale_aggression_desc = 'The buyer became aggressive!',
        drugsim_no_access    = 'You do not have access to /drugsim.',

        -- Webhook messages (use {placeholders}, not %d/%s)
        webhook_big_sale     = '**{name}** sold **{label} x{amount}** for **${reward}**',
        webhook_milestone    = '**{name}** reached **{rep} rep** (**{tier}**)',
    }

    local txt = map[key] or key
    if data then
        -- convert numbers to strings (and format rep to 2dp if present)
        local d = {}
        for k, v in pairs(data) do
            if k == 'rep' and type(v) == 'number' then
                d[k] = string.format('%.2f', v)
            else
                d[k] = tostring(v)
            end
        end
        for k, v in pairs(d) do
            txt = txt:gsub('{' .. k .. '}', v)
        end
    end
    return txt
end

local function clampChance(value)
    return math.max(0.0, math.min(100.0, value or 0))
end

local function debugLog(src, message, payload)
    if not Config.Debug then return end
    local prefix = src and tostring(src) or "server"
    local text = message
    if payload then text = ("%s %s"):format(text, json.encode(payload)) end
    print(("[DrugSale][%s] %s"):format(prefix, text))
    if src and src ~= 0 then
        TriggerClientEvent('ox_lib:notify', src, { title = "DrugSale Debug", description = text, type = 'inform' })
    end
end

local function getIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    if not identifiers or #identifiers == 0 then return nil end
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

-- #########################
-- ### STORAGE LAYER
-- #########################

local Storage = {}
Storage.__index = Storage

-- File backend (JSON under ./data)
local function newFileBackend()
    local self = setmetatable({}, Storage)
    local DATA_DIR = 'data'
    local REP_FILE = DATA_DIR .. '/reputation.json'
    local SES_FILE = DATA_DIR .. '/sessions.json'
    local repCache, sesCache

    local function loadJson(path)
        local raw = LoadResourceFile(GetCurrentResourceName(), path)
        if not raw or raw == '' then return {} end
        local ok, decoded = pcall(json.decode, raw)
        return ok and (decoded or {}) or {}
    end

    local function saveJson(path, tbl)
        local text = json.encode(tbl or {})
        SaveResourceFile(GetCurrentResourceName(), path, text, -1)
    end

    local function ensureLoaded()
        if not repCache then repCache = loadJson(REP_FILE) end
        if not sesCache then sesCache = loadJson(SES_FILE) end
    end

    function self.getRep(identifier)
        ensureLoaded()
        return tonumber(repCache[identifier] or 0) or 0
    end

    function self.setRep(identifier, value)
        ensureLoaded()
        repCache[identifier] = value
        saveJson(REP_FILE, repCache)
    end

    function self.addRep(identifier, amount)
        ensureLoaded()
        local before = tonumber(repCache[identifier] or 0) or 0
        local after = math.max(0, math.floor((before + amount) * 100 + 0.5) / 100)
        repCache[identifier] = after
        saveJson(REP_FILE, repCache)
        return before, after
    end

    function self.fetchSession(identifier)
        ensureLoaded()
        local row = sesCache[identifier]
        if not row then return nil end
        return {
            expiresAt = tonumber(row.expiresAt) or 0,
            streak = tonumber(row.streak or 0),
            saleCount = tonumber(row.saleCount or 0),
            totalPayout = tonumber(row.totalPayout or 0),
            bestSale = tonumber(row.bestSale or 0)
        }
    end

    function self.upsertSession(identifier, session)
        ensureLoaded()
        sesCache[identifier] = {
            expiresAt = session.expiresAt,
            streak = session.streak or 0,
            saleCount = session.saleCount or 0,
            totalPayout = session.totalPayout or 0,
            bestSale = session.bestSale or 0
        }
        saveJson(SES_FILE, sesCache)
    end

    function self.deleteSession(identifier)
        ensureLoaded()
        sesCache[identifier] = nil
        saveJson(SES_FILE, sesCache)
    end

    return self
end

-- SQL backend (oxmysql, tables aoc_drugselling_reputation / aoc_drugselling_session)
local function newSqlBackend()
    local self = setmetatable({}, Storage)

    local function sqlScalar(q,p)
        local pr = promise.new()
        MySQL.scalar(q, p, function(r) pr:resolve(r) end)
        return Citizen.Await(pr)
    end
    local function sqlQuery(q,p)
        local pr = promise.new()
        MySQL.query(q, p, function(r) pr:resolve(r or {}) end)
        return Citizen.Await(pr)
    end
    local function sqlExec(q,p)
        local pr = promise.new()
        MySQL.update(q, p, function(a) pr:resolve(a) end)
        return Citizen.Await(pr)
    end

    function self.getRep(identifier)
        local rep = sqlScalar('SELECT rep FROM aoc_drugselling_reputation WHERE identifier = ?', { identifier })
        return tonumber(rep) or 0
    end
    function self.setRep(identifier, value)
        sqlExec([[
            INSERT INTO aoc_drugselling_reputation(identifier, rep)
            VALUES(?, ?)
            ON DUPLICATE KEY UPDATE rep = VALUES(rep)
        ]], { identifier, value })
    end
    function self.addRep(identifier, amount)
        local before = self.getRep(identifier)
        local after = math.max(0, math.floor((before + amount) * 100 + 0.5) / 100)
        self.setRep(identifier, after)
        return before, after
    end
    function self.fetchSession(identifier)
        local row = sqlQuery('SELECT * FROM aoc_drugselling_session WHERE identifier = ? LIMIT 1', { identifier })[1]
        if not row then return nil end
        return {
            expiresAt = tonumber(row.expires_at) or 0,
            streak = tonumber(row.streak or 0),
            saleCount = tonumber(row.sale_count or 0),
            totalPayout = tonumber(row.total_payout or 0),
            bestSale = tonumber(row.best_sale or 0)
        }
    end
    function self.upsertSession(identifier, session)
        sqlExec([[
            INSERT INTO aoc_drugselling_session
                (identifier, expires_at, streak, sale_count, total_payout, best_sale, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, NOW())
            ON DUPLICATE KEY UPDATE
                expires_at = VALUES(expires_at),
                streak = VALUES(streak),
                sale_count = VALUES(sale_count),
                total_payout = VALUES(total_payout),
                best_sale = VALUES(best_sale),
                updated_at = NOW()
        ]], {
            identifier, session.expiresAt, session.streak or 0,
            session.saleCount or 0, session.totalPayout or 0, session.bestSale or 0
        })
    end
    function self.deleteSession(identifier)
        sqlExec('DELETE FROM aoc_drugselling_session WHERE identifier = ?', { identifier })
    end

    return self
end

local backend = (Config.Storage == 'sql') and newSqlBackend() or newFileBackend()

-- #########################
-- ### TIERS/CHANCES
-- #########################

local function getTierBreakdown(rep)
    local tiers = Config.ReputationTiers or {}
    if #tiers == 0 then
        return {
            name = "Unranked", min = 0, payoutBonus = 0, alertModifier = 0, rejectModifier = 0, aggressionModifier = 0
        }, nil
    end
    table.sort(tiers, function(a,b) return (a.min or 0) < (b.min or 0) end)
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
        summary.next = { name = nextTier.name or "Unknown", min = nextTier.min or 0 }
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
    if math.random(100) <= (chances.aggression or 0) then return 'aggression' end
    if math.random(100) <= (chances.reject or 0) then return 'reject' end
    if math.random(100) <= (chances.alert or 0) then return 'alert' end
    return 'success'
end

-- #########################
-- ### INVENTORY / ROLLS
-- #########################

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
    if priceMax < priceMin then priceMax = priceMin end

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

-- #########################
-- ### SESSION / REP API
-- #########################

local activeSessions = {}

local function getPlayerRep(src)
    local identifier = getIdentifier(src)
    if not identifier then return 0, nil end
    return backend.getRep(identifier), identifier
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
    if not session then return end
    local repValue = select(1, getPlayerRep(src))
    backend.upsertSession(session.identifier, session)
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
    if not session then return end
    activeSessions[src] = nil
    backend.deleteSession(session.identifier)
    TriggerClientEvent('aocdev:clientEndSession', src, { reason = reason })
end

local function suspendSession(src)
    local session = activeSessions[src]
    if not session then return end
    activeSessions[src] = nil
    backend.upsertSession(session.identifier, session)
end

local function startSession(src, stored, resumed)
    local identifier = getIdentifier(src)
    if not identifier then return nil, 'identifier_missing' end

    local now = os.time()
    local timeRemaining = Config.SessionDuration
    if stored and stored.expiresAt then
        timeRemaining = math.max(0, stored.expiresAt - now)
    end
    if timeRemaining <= 0 then
        backend.deleteSession(identifier)
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
    backend.upsertSession(identifier, session)
    sendSessionStart(src, session, resumed)
    return session
end

-- #########################
-- ### WEBHOOKS / ALERTS
-- #########################

local function sendWebhook(title, description, color)
    if not Config.Webhook or not Config.Webhook.enabled then return end
    local url = Config.Webhook.url
    if not url or url == "" then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        embeds = { { title = title, description = description, color = color or 16753920, timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ") } }
    }), { ['Content-Type'] = 'application/json' })
end

local function dispatchAlert(src, drugKey)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    TriggerEvent('aocdev:drugsale:alert', src, coords, { drug = drugKey })
end

-- #########################
-- ### SALE PIPELINE
-- #########################

local function processSale(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return { status = 'error', code = 'player_invalid', message = _L('sale_player_incapacitated') }
    end

    if IsEntityDead(ped) or IsPedFatallyInjured(ped) or IsPedDeadOrDying(ped, true) then
        return { status = 'error', code = 'player_dead', message = _L('sale_player_incapacitated') }
    end

    local player = Player(src)
    if player and player.state then
        local state = player.state
        if state.isDead or state.dead or state.isIncapacitated or state.incapacitated
            or state.isDown or state.isDowned or state.downed
            or state.isLastStand or state.laststand or state.lastStand
            or state.isUnconscious or state.unconscious or state.bleedingOut or state.bleedingout then
            return { status = 'error', code = 'player_dead', message = _L('sale_player_incapacitated') }
        end
    end

    if IsPedInWrithe(ped) then
        return { status = 'error', code = 'player_dead', message = _L('sale_player_incapacitated') }
    end

    local rep, identifier = getPlayerRep(src)
    if not identifier then
        return { status = 'error', code = 'identifier_missing', message = _L('error_identifier') }
    end

    local tierTable, tierSummary = summarizeTier(rep)
    local drugKey, drugData, inventoryCount = findSellableDrug(src)

    if not drugKey then
        return { status = 'error', code = 'no_drugs', message = _L('session_no_drugs'), rep = rep, tier = tierSummary }
    end

    local baseChances, finalChances = computeChanceSet(drugData, tierTable)
    local outcome = determineOutcome(finalChances)
    local session = activeSessions[src]

    if outcome ~= 'success' then
        if session then
            session.streak = 0
            backend.upsertSession(session.identifier, session)
            sendSessionUpdate(src)
        end

        if outcome == 'alert' then
            dispatchAlert(src, drugKey)
        end

        debugLog(src, "Sale intercepted", { outcome = outcome, drug = drugKey, rep = rep, tier = tierSummary, chances = finalChances })

        local messageKey
        if outcome == 'alert' then messageKey = 'sale_alert_desc'
        elseif outcome == 'reject' then messageKey = 'sale_reject_desc'
        elseif outcome == 'aggression' then messageKey = 'sale_aggression_desc' end

        return {
            status = outcome, code = outcome,
            message = messageKey and _L(messageKey) or nil,
            label = drugData.label, baseChances = baseChances, finalChances = finalChances, rep = rep, tier = tierSummary
        }
    end

    local amount, baseReward, rollInfo = rollSale(drugData, inventoryCount)
    if not amount then
        debugLog(src, "Sale roll failed", rollInfo)
        return { status = 'error', code = rollInfo and rollInfo.error or 'invalid', message = _L('session_amount_error'), baseChances = baseChances, finalChances = finalChances, rep = rep, tier = tierSummary }
    end

    local removed = inv:RemoveItem(src, drugData.item, amount)
    if not removed then
        debugLog(src, "Inventory removal failed", { item = drugData.item, amount = amount })
        return { status = 'error', code = 'remove_failed', message = _L('sale_no_inventory'), baseChances = baseChances, finalChances = finalChances, rep = rep, tier = tierSummary }
    end

    local reward = math.floor(baseReward * (1 + (tierTable.payoutBonus or 0)))
    if reward <= 0 then reward = baseReward end

    inv:AddItem(src, "black_money", reward)

    local repGain = drugData.repGain or 0.1
    local previousRep, newRep = backend.addRep(identifier, repGain)
    local _, newTierSummary = summarizeTier(newRep)

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
        backend.upsertSession(sessionData.identifier, sessionData)
        sendSessionUpdate(src)
    end

    if Config.Webhook and Config.Webhook.enabled then
        if Config.Webhook.bigSaleThreshold and reward >= Config.Webhook.bigSaleThreshold then
            sendWebhook("Big Sale", _L('webhook_big_sale', { name = GetPlayerName(src), label = drugData.label, amount = amount, reward = reward }), 65280)
        end
        if milestone then
            sendWebhook("Reputation Milestone", _L('webhook_milestone', { name = GetPlayerName(src), rep = newRep, tier = newTierSummary.name }), 255)
        end
    end

    debugLog(src, "Sale processed", {
        drug = drugKey, amount = amount, reward = reward, baseReward = baseReward,
        repGain = repGain, repBefore = previousRep, repAfter = newRep, tier = newTierSummary, chances = finalChances
    })

    return {
        status = 'success', code = 'success', label = drugData.label, amount = amount, reward = reward,
        repGain = repGain, repTotal = newRep, tier = newTierSummary, baseChances = baseChances, finalChances = finalChances,
        roll = rollInfo, milestone = milestone
    }
end

-- #########################
-- ### EVENTS / COMMANDS
-- #########################

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
    local stored = identifier and backend.fetchSession(identifier) or nil
    local now = os.time()
    if stored and stored.expiresAt and stored.expiresAt <= now then
        stored = nil
        backend.deleteSession(identifier)
    end

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

    local stored = backend.fetchSession(identifier)
    if not stored then
        TriggerClientEvent('aocdev:clientNoSession', src)
        return
    end

    local session, err = startSession(src, stored, true)
    if not session then
        backend.deleteSession(identifier)
        TriggerClientEvent('aocdev:clientNoSession', src)
    end
end)

RegisterServerEvent('aocdev:getRep')
AddEventHandler('aocdev:getRep', function()
    local src = source
    local repValue = select(1, getPlayerRep(src))
    local _, tierSummary = summarizeTier(repValue)
    TriggerClientEvent('aocdev:sendRep', src, { value = repValue, tier = tierSummary })
end)

RegisterCommand('drugsim', function(source)
    if source == 0 then
        print("[DrugSale] /drugsim is only available in-game.")
        return
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local hasPerm = QBCore.Functions.HasPermission(source, 'admin')
        or QBCore.Functions.HasPermission(source, 'god')
        or IsPlayerAceAllowed(source, 'command.drugsim')
    if not hasPerm then
        TriggerClientEvent('ox_lib:notify', source, { description = _L('drugsim_no_access'), type = 'error' })
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

    table.sort(entries, function(a, b) return (a.avg or 0) > (b.avg or 0) end)
    TriggerClientEvent('aocdev:openDrugSim', source, { tier = tierSummary, rep = repValue, entries = entries })
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
