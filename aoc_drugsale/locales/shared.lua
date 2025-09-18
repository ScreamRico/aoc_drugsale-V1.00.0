Locales = Locales or {}

local function getDictionary(locale)
    if not locale or locale == '' then
        return nil
    end
    return Locales[locale]
end

Locale = Locale or {}

function Locale:t(key, vars)
    local primary = getDictionary(Config.Locale)
    local fallback = getDictionary(Config.LocaleFallback) or {}

    local phrase
    if primary and primary[key] then
        phrase = primary[key]
    elseif fallback[key] then
        phrase = fallback[key]
    else
        phrase = key
    end

    if vars and type(vars) == 'table' then
        for k, v in pairs(vars) do
            phrase = phrase:gsub('{' .. k .. '}', tostring(v))
        end
    end

    return phrase
end

function Locale:has(key)
    local primary = getDictionary(Config.Locale)
    if primary and primary[key] then return true end
    local fallback = getDictionary(Config.LocaleFallback)
    if fallback and fallback[key] then return true end
    return false
end

function _L(key, vars)
    return Locale:t(key, vars)
end