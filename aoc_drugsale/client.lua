local session = {
    active = false,
    expiresAt = 0,
    streak = 0,
    saleCount = 0,
    totalPayout = 0,
    bestSale = 0,
    tier = nil,
    rep = 0,
    origin = nil,
    nextBuyerSpawn = 0,
    timerThread = nil,
    spawnThread = nil,
    guardThread = nil,
    resumed = false
}

local peds = {}
local soldTo = {}
local pendingSales = {}
local phoneScenarioActive = false
local callInProgress = false
local pendingMoveCancel = false

local function formatSessionTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format('%02d:%02d', minutes, secs)
end

local function formatCurrency(amount)
    local formatted = tostring(math.floor((amount or 0) + 0.5))
    local k
    while true do
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

local function formatRep(value)
    return string.format('%.1f', value or 0)
end

local function loadAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(10)
        end
    end
end

local function stopPhoneAnimation()
    if not phoneScenarioActive then return end
    phoneScenarioActive = false

    local playerPed = PlayerPedId()
    if IsPedUsingAnyScenario(playerPed) or IsPedActiveInScenario(playerPed) then
        ClearPedTasksImmediately(playerPed)
    else
        ClearPedSecondaryTask(playerPed)
    end

    TaskUseMobilePhone(playerPed, false)
end

local function startPhoneAnimation()
    if phoneScenarioActive then return end

    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then return end

    if not IsPedUsingAnyScenario(playerPed) and not IsPedActiveInScenario(playerPed) then
        TaskStartScenarioInPlace(playerPed, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
        TaskUseMobilePhone(playerPed, true)
        phoneScenarioActive = true
    end
end

local function cleanupPeds()
    for ped in pairs(peds) do
        if DoesEntityExist(ped) then
            ClearPedTasks(ped)
            DeleteEntity(ped)
        end
    end

    peds = {}
    soldTo = {}
end

local function updateSessionCard()
    if not session.active then
        exports.ox_lib:hideTextUI()
        return
    end

    local timeLeft = math.max(0, math.floor((session.expiresAt - GetGameTimer()) / 1000))
    local text = _L('session_ui_template', {
        streak = session.streak or 0,
        time = formatSessionTime(timeLeft)
    })

    exports.ox_lib:showTextUI(text, {
        position = 'top-center'
    })
end

local function startTimerThread()
    if session.timerThread then return end

    session.timerThread = CreateThread(function()
        while session.active do
            updateSessionCard()
            Wait(1000)
        end

        exports.ox_lib:hideTextUI()
        session.timerThread = nil
    end)
end

local function rollBuyerSpawnInterval()
    local min = Config.BuyerSpawnInterval and Config.BuyerSpawnInterval.min or 10
    local max = Config.BuyerSpawnInterval and Config.BuyerSpawnInterval.max or min
    if max < min then max = min end
    return math.random(min, max)
end

local function getBuyerSpawnPosition()
    local playerPed = PlayerPedId()
    local origin = session.origin or GetEntityCoords(playerPed)
    local attempts = Config.BuyerSpawnAttempts or 6
    local fallback

    for _ = 1, attempts do
        local distance = math.random(Config.BuyerSpawnDistance.min, Config.BuyerSpawnDistance.max)
        local angle = math.random() * 2.0 * math.pi
        local offset = vector3(math.cos(angle) * distance, math.sin(angle) * distance, 0.0)
        local candidate = vector3(origin.x + offset.x, origin.y + offset.y, origin.z + 1.0)

        local foundGround, groundZ = GetGroundZFor_3dCoord(candidate.x, candidate.y, candidate.z, false)
        if foundGround then
            candidate = vector3(candidate.x, candidate.y, groundZ)
        end

        fallback = candidate

        if not IsSphereVisible(candidate.x, candidate.y, candidate.z + 1.0, 1.5) then
            return candidate
        end
    end

    return fallback
end

local function getActiveBuyerCount()
    local count = 0
    for ped in pairs(peds) do
        if DoesEntityExist(ped) then
            count = count + 1
        end
    end
    return count
end

local function endSessionLocal(reasonKey)
    session.active = false
    session.expiresAt = 0
    session.origin = nil
    session.nextBuyerSpawn = 0
    session.resumed = false
    pendingMoveCancel = false
    session.streak = 0
    session.saleCount = 0
    session.totalPayout = 0
    session.bestSale = 0

    stopPhoneAnimation()
    cleanupPeds()
    exports.ox_lib:hideTextUI()

    if reasonKey then
        exports.ox_lib:notify({
            description = _L(reasonKey),
            type = 'error'
        })
    end
end

local function startGuardThread()
    if session.guardThread then return end

    session.guardThread = CreateThread(function()
        local moveRadius = tonumber(Config.SessionMoveRadius) or 35.0
        while session.active do
            Wait(500)
            if not session.origin then break end

            local playerPed = PlayerPedId()
            local dist = #(GetEntityCoords(playerPed) - session.origin)
            if dist > moveRadius then
                if not pendingMoveCancel then
                    pendingMoveCancel = true
                    exports.ox_lib:notify({ description = _L('session_move_too_far'), type = 'error' })
                    TriggerServerEvent('aocdev:requestCancelSession')
                end
                break
            end
        end
        session.guardThread = nil
    end)
end

local function spawnLoopTick()
    if session.nextBuyerSpawn > 0 then
        session.nextBuyerSpawn = session.nextBuyerSpawn - 1
        return
    end

    if Config.MaxConcurrentBuyers and getActiveBuyerCount() >= Config.MaxConcurrentBuyers then
        session.nextBuyerSpawn = math.max(2, math.floor(rollBuyerSpawnInterval() / 2))
        return
    end

    local spawned = spawnBuyer()
    if spawned then
        session.nextBuyerSpawn = rollBuyerSpawnInterval()
    else
        session.nextBuyerSpawn = math.max(2, math.floor(rollBuyerSpawnInterval() / 2))
    end
end

local function startSpawnThread()
    if session.spawnThread then return end

    session.spawnThread = CreateThread(function()
        while session.active do
            spawnLoopTick()
            Wait(1000)
        end
        session.spawnThread = nil
    end)
end

local function makeRequestId()
    return ('sale:%s:%s'):format(GetPlayerServerId(PlayerId()), GetGameTimer())
end

local function awaitSaleResult(requestId)
    local p = promise.new()
    pendingSales[requestId] = p

    SetTimeout(5000, function()
        if pendingSales[requestId] then
            pendingSales[requestId] = nil
            p:resolve({ status = 'error', code = 'timeout', message = _L('sale_timeout') })
        end
    end)

    return Citizen.Await(p)
end

RegisterNetEvent('aocdev:saleOutcome', function(requestId, result)
    local p = pendingSales[requestId]
    if not p then return end

    pendingSales[requestId] = nil
    p:resolve(result or { status = 'error', code = 'unknown' })
end)

local function DrawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(x, y)
end

function spawnBuyer()
    if not session.active then return false end

    if Config.MaxConcurrentBuyers and getActiveBuyerCount() >= Config.MaxConcurrentBuyers then
        return false
    end

    local spawnCoords = getBuyerSpawnPosition()
    if not spawnCoords then return false end

    local model = Config.CustomPeds[math.random(#Config.CustomPeds)]
    RequestModel(model)
    local waited = 0
    while not HasModelLoaded(model) do
        Wait(10)
        waited = waited + 1
        if waited >= 500 then
            return false
        end
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local heading = GetHeadingFromVector_2d(playerCoords.x - spawnCoords.x, playerCoords.y - spawnCoords.y)
    local ped = CreatePed(4, model, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false)

    if not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(model)
        return false
    end

    SetModelAsNoLongerNeeded(model)

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    TaskGoToEntity(ped, PlayerPedId(), -1, 2.0, 1.2, 1073741824, 0)

    peds[ped] = true

    CreateThread(function()
        while session.active and DoesEntityExist(ped) do
            local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped))
            if dist < 2.5 and not soldTo[ped] then
                DrawText3D(GetEntityCoords(ped), _L('sale_prompt'))
                if IsControlJustReleased(0, 38) then
                    if handleSale(ped) then
                        soldTo[ped] = true
                        break
                    end
                end
            end
            Wait(0)
        end

        local pedExists = DoesEntityExist(ped)
        local wasSold = soldTo[ped]

        if pedExists and not wasSold then
            TaskWanderStandard(ped, 10.0, 10)
            SetTimeout(5000, function()
                if DoesEntityExist(ped) then
                    DeleteEntity(ped)
                end
            end)
        end

        peds[ped] = nil
        soldTo[ped] = nil
    end)

    return true
end

function handleSale(ped)
    if not session.active or not DoesEntityExist(ped) then return false end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local pedCoords = GetEntityCoords(ped)
    if #(playerCoords - pedCoords) > 3.0 then
        exports.ox_lib:notify({ description = _L('sale_get_closer'), type = 'error' })
        return false
    end

    exports.ox_lib:progressBar({
        duration = 2500,
        label = _L('sale_offer_label'),
        useWhileDead = false,
        canCancel = false,
        disable = { move = true, car = true, combat = true }
    })

    if not session.active or not DoesEntityExist(ped) then return false end

    ClearPedTasks(ped)
    TaskStandStill(ped, 4000)
    TaskTurnPedToFaceEntity(ped, playerPed, 1000)
    TaskTurnPedToFaceEntity(playerPed, ped, 1000)
    Wait(600)

    loadAnimDict('mp_common')
    TaskPlayAnim(playerPed, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 0, 0, false, false, false)
    TaskPlayAnim(ped, 'mp_common', 'givetake1_b', 8.0, -8.0, 1500, 0, 0, false, false, false)
    Wait(1500)

    if #(GetEntityCoords(playerPed) - GetEntityCoords(ped)) > 3.0 then
        exports.ox_lib:notify({ description = _L('sale_buyer_moved'), type = 'error' })
        return false
    end

    local requestId = makeRequestId()
    TriggerServerEvent('aocdev:attemptSale', requestId)
    local result = awaitSaleResult(requestId)

    if not result then
        exports.ox_lib:notify({ description = _L('sale_timeout'), type = 'error' })
        return false
    end

    if result.status == 'success' then
        exports.ox_lib:notify({
            title = _L('sale_success_title'),
            description = _L('sale_success_desc', {
                label = result.label or _L('sale_unknown_product'),
                amount = result.amount or 0,
                reward = formatCurrency(result.reward or 0)
            }),
            type = 'success'
        })

        ClearPedTasks(ped)
        TaskWanderStandard(ped, 10.0, 10)
        SetTimeout(7000, function()
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
            peds[ped] = nil
            soldTo[ped] = nil
        end)

        if result.tier then
            session.tier = result.tier
        end
        if result.repTotal then
            session.rep = result.repTotal
        end
        if result.milestone then
            exports.ox_lib:notify({ description = _L('sale_milestone_notify', { rep = formatRep(result.repTotal or 0) }), type = 'inform' })
        end

        return true
    end

    if result.status == 'reject' then
        exports.ox_lib:notify({ description = _L('sale_reject_notify'), type = 'error' })
        TaskTurnPedToFaceEntity(ped, playerPed, 1000)
        TaskSmartFleePed(ped, playerPed, 25.0, -1)
        soldTo[ped] = true
        return false
    end

    if result.status == 'alert' then
    exports['ps-dispatch']:DrugSale()  -- 🚔 send dispatch alert (ps-dispatch)
    exports.ox_lib:notify({ description = _L('sale_alert_notify'), type = 'error' })
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', 0, false)
    SetTimeout(4000, function()
        if DoesEntityExist(ped) then
            ClearPedTasks(ped)
            TaskSmartFleePed(ped, playerPed, 80.0, -1)
        end
    end)
    soldTo[ped] = true
    return false
end


    if result.status == 'aggression' then
        exports.ox_lib:notify({ description = _L('sale_aggression_notify'), type = 'error' })
        GiveWeaponToPed(ped, `WEAPON_KNIFE`, 1, false, true)
        SetPedCombatAttributes(ped, 46, true)
        TaskCombatPed(ped, playerPed, 0, 16)
        soldTo[ped] = true
        return false
    end

    if result.message then
        exports.ox_lib:notify({ description = result.message, type = 'error' })
    end

    return false
end

local function applySessionData(data)
    if not data then return end

    session.streak = data.streak or session.streak or 0
    session.saleCount = data.saleCount or session.saleCount or 0
    session.totalPayout = data.totalPayout or session.totalPayout or 0
    session.bestSale = data.bestSale or session.bestSale or 0
    session.tier = data.tier or session.tier
    session.rep = data.rep or session.rep or 0

    if data.timeRemaining then
        session.expiresAt = GetGameTimer() + math.max(0, data.timeRemaining) * 1000
    end

    updateSessionCard()
end

local function activateSession(data)
    session.active = true
    session.origin = GetEntityCoords(PlayerPedId())
    session.nextBuyerSpawn = rollBuyerSpawnInterval()
    session.resumed = data and data.resumed or false
    pendingMoveCancel = false

    applySessionData(data)

    if session.resumed then
        exports.ox_lib:notify({ description = _L('session_resumed'), type = 'inform' })
    else
        exports.ox_lib:notify({ description = _L('session_start'), type = 'success' })
    end

    startTimerThread()
    startSpawnThread()
    startGuardThread()
end

RegisterNetEvent('aocdev:clientStartSession', function(data)
    activateSession(data)
end)

RegisterNetEvent('aocdev:clientSessionUpdate', function(data)
    if not session.active then
        applySessionData(data)
        return
    end

    applySessionData(data)
end)

RegisterNetEvent('aocdev:clientEndSession', function(payload)
    local reason = payload and payload.reason
    local reasonKey

    if reason == 'expired' then
        reasonKey = 'session_ui_expired'
    elseif reason == 'cancelled' then
        reasonKey = 'session_cancelled'
    elseif reason == 'identifier_missing' then
        reasonKey = 'error_identifier'
    end

    endSessionLocal(reasonKey)
end)

RegisterNetEvent('aocdev:sessionDenied', function(data)
    local reason = data and data.reason or 'unknown'
    local reasonMap = {
        already_active = 'session_already_active',
        identifier_missing = 'error_identifier',
        expired = 'session_ui_expired'
    }

    local key = reasonMap[reason] or 'session_denied'
    exports.ox_lib:notify({ description = _L(key), type = 'error' })
end)

RegisterNetEvent('aocdev:clientNoSession', function()
    -- No-op; ensures sync completes quietly
end)

RegisterNetEvent('aocdev:openDrugSim', function(data)
    if not data or not data.entries then return end

    local options = {}
    for _, entry in ipairs(data.entries) do
        local risk = entry.chances or {}
        options[#options + 1] = {
            title = string.format("%s | $%s / $%s / $%s", entry.label, formatCurrency(entry.min), formatCurrency(entry.avg), formatCurrency(entry.max)),
            description = _L('drugsim_header_risk') .. string.format(": %d%% / %d%% / %d%%", risk.alert or 0, risk.reject or 0, risk.aggression or 0)
        }
    end

    exports.ox_lib:registerContext({
        id = 'aocdev_drugsim',
        title = _L('drugsim_title', { rep = formatRep(data.rep or 0) }),
        options = options
    })
    exports.ox_lib:showContext('aocdev_drugsim')
end)

RegisterNetEvent('aocdev:sendRep', function(data)
    data = data or {}
    local tier = data.tier or {}

    local options = {
        { title = _L('rep_menu_value'), description = formatRep(data.value or 0) },
        { title = _L('rep_tier_label'), description = tier.name or '�' }
    }

    if tier.payoutBonus then
        options[#options + 1] = {
            title = _L('rep_bonus_payout'),
            description = string.format("%d%%", math.floor((tier.payoutBonus or 0) * 100))
        }
    end

    options[#options + 1] = {
        title = _L('rep_bonus_risk'),
        description = string.format("Alert %d%% | Reject %d%% | Aggro %d%%", tier.alertModifier or 0, tier.rejectModifier or 0, tier.aggressionModifier or 0)
    }

    if tier.next then
        options[#options + 1] = {
            title = _L('rep_next_tier'),
            description = string.format("%s @ %s", tier.next.name or '�', formatRep(tier.next.min or 0))
        }
    end

    exports.ox_lib:registerContext({
        id = 'rep_menu',
        title = _L('rep_menu_title'),
        options = options
    })
    exports.ox_lib:showContext('rep_menu')
end)

RegisterCommand('selldrugs', function()
    if callInProgress then return end

    if session.active then
        TriggerServerEvent('aocdev:requestCancelSession')
        return
    end

    callInProgress = true
    startPhoneAnimation()
    local success = exports.ox_lib:progressBar({
        duration = 3000,
        label = _L('command_sell_starting'),
        useWhileDead = false,
        canCancel = false,
        disable = { move = true, car = true, combat = true }
    })
    stopPhoneAnimation()

    if success then
        TriggerServerEvent('aocdev:requestStartSession')
    else
        exports.ox_lib:notify({ description = _L('session_call_cancelled'), type = 'error' })
    end

    callInProgress = false
end)

RegisterCommand('drugdash', function()
    if not session.active then
        exports.ox_lib:notify({ description = _L('dashboard_no_session'), type = 'error' })
        return
    end

    local options = {
        { title = _L('dashboard_total_cash'), description = ('$%s'):format(formatCurrency(session.totalPayout or 0)) },
        { title = _L('dashboard_best_sale'), description = ('$%s'):format(formatCurrency(session.bestSale or 0)) },
        { title = _L('dashboard_sales'), description = tostring(session.saleCount or 0) },
        { title = _L('dashboard_current_tier'), description = session.tier and session.tier.name or '�' }
    }

    exports.ox_lib:registerContext({
        id = 'aocdev_drugdash',
        title = _L('dashboard_title'),
        options = options
    })
    exports.ox_lib:showContext('aocdev_drugdash')
end)

RegisterCommand('rep', function()
    TriggerServerEvent('aocdev:getRep')
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end

    TriggerServerEvent('aocdev:syncSession')
end)
