local version = "6.0.0"

local defaults = {
    x = 0,
    y = -150,
    w = 200,
    h = 10,
    b = 2,
    a = 1,
    s = 1,
    vo = -2,
    ho = 0,
    move = "off",
    icons = 1,
    bg = 1,
    timers = 1,
    style = 2,
    show_oh = 1,
    show_range = 1,
    minimapPos = 225,
}

local default_bg1 = nil
local default_bg2 = nil
local default_bg3 = nil

local settings = {
    x = "Bar X position",
    y = "Bar Y position",
    w = "Bar width",
    h = "Bar height",
    b = "Border height",
    a = "Alpha between 0 and 1",
    s = "Bar scale",
    vo = "Offhand bar vertical offset",
    ho = "Offhand bar horizontal offset",
    icons = "Show weapon icons (1 = show, 0 = hide)",
    bg = "Show background (1 = show, 0 = hide)",
    timers = "Show weapon timers (1 = show, 0 = hide)",
    style = "Choose 1, 2, 3, 4, 5 or 6",
    move = "Enable bars movement",
}

local flurry = {
    WARRIOR = {10, 15, 20, 25, 30},
    SHAMAN  = { 8, 11, 14, 17, 20},
}

local armorDebuffs = {
    ["Interface\\Icons\\Ability_Warrior_Sunder"] = 450, 
    ["Interface\\Icons\\Spell_Shadow_Unholystrength"] = 640, 
    ["Interface\\Icons\\Spell_Nature_Faeriefire"] = 505, 
    ["Interface\\Icons\\Ability_Warrior_Riposte"] = 2550,
    ["Interface\\Icons\\Inv_Axe_12"] = 200
}
local combatStrings = {
    SPELLLOGSELFOTHER,
    SPELLLOGCRITSELFOTHER,
    SPELLDODGEDSELFOTHER,
    SPELLPARRIEDSELFOTHER,
    SPELLMISSSELFOTHER,
    SPELLBLOCKEDSELFOTHER,
    SPELLDEFLECTEDSELFOTHER,
    SPELLEVADEDSELFOTHER,
    SPELLIMMUNESELFOTHER,
    SPELLLOGABSORBSELFOTHER,
    SPELLREFLECTSELFOTHER,
    SPELLRESISTSELFOTHER
}
for index in combatStrings do
    for _, pattern in {"%%s", "%%d"} do
        combatStrings[index] = gsub(combatStrings[index], pattern, "(.*)")
    end
end
--------------------------------------------------------------------------------
local weapon = nil
local offhand = nil
local range = nil
local combat = false
local configmod = false
local player_guid = nil
local player_class = nil
local flurry_mult = 0
local paused_swing = nil
local paused_swingOH = nil
st_timer = 0
st_timerMax = 1
st_timerOff = 0
st_timerOffMax = 1
st_timerRange = 0
st_timerRangeMax = 1
local range_fader = 0
local ele_flurry_fresh = nil
local flurry_fresh = nil
local flurry_count = -1
local wf_swings = 0

--------------------------------------------------------------------------------
local loc = {}
loc["enUS"] = {
    hit = "You hit",
    crit = "You crit",
    glancing = "glancing",
    block = "blocked",
    Warrior = "Warrior",
    combatSpells = {
        HS = "Heroic Strike",
        Cleave = "Cleave",
        RS = "Raptor Strike",
        Maul = "Maul",
    }
}
loc["frFR"] = {
    hit = "Vous touchez",
    crit = "Vous infligez un coup critique",
    glancing = "érafle",
    block = "bloqué",
    Warrior = "Guerrier",
    combatSpells = {
        HS = "Frappe héroïque",
        Cleave = "Enchainement",
        RS = "Attaque du raptor",
        Maul = "Mutiler",
    }
}
local L = loc[GetLocale()] or loc['enUS']
--------------------------------------------------------------------------------
StaticPopupDialogs["SP_ST_Install"] = {
    text = TEXT("Thanks for installing SP_SwingTimer " ..version .. "! Use the chat command /st to change the settings."),
    button1 = TEXT(YES),
    timeout = 0,
    hideOnEscape = 1,
}
--------------------------------------------------------------------------------
function MakeMovable(frame)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local screenWidth = UIParent:GetWidth()
        local screenHeight = UIParent:GetHeight()
        local scale = SP_ST_GS["s"]
        local scaledWidth = SP_ST_GS["w"] * scale
        local scaledHeight = SP_ST_GS["h"] * scale
        local totalHeight = scaledHeight
        if SP_ST_GS["show_oh"] ~= 0 and isDualWield() then
            totalHeight = totalHeight + (SP_ST_GS["h"] * scale) + math.abs(SP_ST_GS["vo"])
        end
        if SP_ST_GS["show_range"] ~= 0 and hasRanged() then
            totalHeight = totalHeight + (SP_ST_GS["h"] * scale) + math.abs(SP_ST_GS["vo"])
        end
        local _, _, _, x, y = this:GetPoint()
        x = math.max(0, math.min(x, math.min(1000, screenWidth - scaledWidth)))
        y = math.max(math.max(-1000, -screenHeight + totalHeight), math.min(y, 0))
        this:ClearAllPoints()
        this:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
        SP_ST_GS["x"] = x
        SP_ST_GS["y"] = y
    end)
end
--------------------------------------------------------------------------------
local function print(msg)
    --DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0.5)
end
local function SplitString(s,t)
    local l = {n=0}
    local f = function(s)
        l.n = l.n + 1
        l[l.n] = s
    end
    local p = "%s*(.-)%s*"..t.."%s*"
    s = string.gsub(s,"^%s+","")
    s = string.gsub(s,"%s+$","")
    s = string.gsub(s,p,f)
    l.n = l.n + 1
    l[l.n] = string.gsub(s,"(%s%s*)$","")
    return l
end

local function has_value(tab, val)
    for value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    if tab[val] then
        return true
    end
    return false
end

local function sp_round(number, decimals)
    local power = 10^decimals
    return math.floor(number * power) / power
end

--------------------------------------------------------------------------------
local function UpdateSettings()
    if not SP_ST_GS then SP_ST_GS = {} end
    for option, value in defaults do
        if SP_ST_GS[option] == nil then
            SP_ST_GS[option] = value
        end
    end
    SP_ST_GS["x"] = math.max(0, math.min(SP_ST_GS["x"], 1000))
    SP_ST_GS["y"] = math.max(-1000, math.min(SP_ST_GS["y"], 0))
end

--------------------------------------------------------------------------------
local function UpdateHeroicStrike()
    local _, class = UnitClass("player")
    if class ~= "WARRIOR" then
        return
    end
    TrackedActionSlots = {}
    local SPActionSlot = 0
    for SPActionSlot = 1, 120 do
        local SPActionText = GetActionText(SPActionSlot)
        local SPActionTexture = GetActionTexture(SPActionSlot)
        if SPActionTexture then
            if SPActionTexture == "Interface\\Icons\\Ability_Rogue_Ambush" or SPActionTexture == "Interface\\Icons\\Ability_Warrior_Cleave" then
                tinsert(TrackedActionSlots, SPActionSlot)
            elseif SPActionText then
                SPActionText = string.lower(SPActionText)
                if SPActionText == "cleave" or SPActionText == "heroic strike" or SPActionText == "heroicstrike" or SPActionText == "hs" then
                    tinsert(TrackedActionSlots, SPActionSlot)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
local function HeroicStrikeQueued()
    if not getn(TrackedActionSlots) then
        return nil
    end
    for _, actionslotID in ipairs(TrackedActionSlots) do
        if IsCurrentAction(actionslotID) then
            return true
        end
    end
    return nil
end

--------------------------------------------------------------------------------
local function CheckFlurry()
    local c = 0
    while GetPlayerBuff(c,"HELPFUL") ~= -1 do
        local id = GetPlayerBuffID(c)
        if SpellInfo(id) == "Flurry" then
            return GetPlayerBuffApplications(c)
        end
        c = c + 1
    end
    return -1
end

--------------------------------------------------------------------------------
local function UpdateAppearance()
    SP_ST_Frame:ClearAllPoints()
    SP_ST_FrameOFF:ClearAllPoints()
    SP_ST_FrameRange:ClearAllPoints()
    
    SP_ST_Frame:SetPoint("TOPLEFT", SP_ST_GS["x"], SP_ST_GS["y"])
    SP_ST_maintimer:SetPoint("RIGHT", "SP_ST_Frame", "RIGHT", -2, 0)
    SP_ST_maintimer:SetFont("Interface\\AddOns\\SP_SwingTimer\\assets\\Expressway.ttf", SP_ST_GS["h"] + 2)
    SP_ST_maintimer:SetTextColor(1,1,1,1)
    SP_ST_maintimer:SetShadowColor(0, 0, 0, 1)
    SP_ST_maintimer:SetShadowOffset(1, -1)
    if SP_ST_GS["bg"] ~= 0 then SP_ST_Frame:SetBackdrop(default_bg1) else SP_ST_Frame:SetBackdrop(nil) end

    SP_ST_FrameOFF:SetPoint("TOPLEFT", "SP_ST_Frame", "BOTTOMLEFT", SP_ST_GS["ho"], SP_ST_GS["vo"])
    SP_ST_offtimer:SetPoint("RIGHT", "SP_ST_FrameOFF", "RIGHT", -2, 0)
    SP_ST_offtimer:SetFont("Interface\\AddOns\\SP_SwingTimer\\assets\\Expressway.ttf", SP_ST_GS["h"] + 2)
    SP_ST_offtimer:SetTextColor(1,1,1,1)
    SP_ST_offtimer:SetShadowColor(0, 0, 0, 1)
    SP_ST_offtimer:SetShadowOffset(1, -1)
    if SP_ST_GS["bg"] ~= 0 then SP_ST_FrameOFF:SetBackdrop(default_bg2) else SP_ST_FrameOFF:SetBackdrop(nil) end

    SP_ST_FrameRange:SetPoint("TOPLEFT", "SP_ST_FrameOFF", "BOTTOMLEFT", SP_ST_GS["ho"], SP_ST_GS["vo"])
    SP_ST_rangetimer:SetPoint("RIGHT", "SP_ST_FrameRange", "RIGHT", -2, 0)
    SP_ST_rangetimer:SetFont("Fonts\\FRIZQT__.TTF", SP_ST_GS["h"])
    SP_ST_rangetimer:SetTextColor(1,1,1,1)
    SP_ST_rangetimer:SetShadowColor(0, 0, 0, 1)
    SP_ST_rangetimer:SetShadowOffset(1, -1)
    if SP_ST_GS["bg"] ~= 0 then SP_ST_FrameRange:SetBackdrop(default_bg3) else SP_ST_FrameRange:SetBackdrop(nil) end

    if SP_ST_GS["icons"] ~= 0 then
        SP_ST_mainhand:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("MainHandSlot")))
        SP_ST_mainhand:SetHeight(SP_ST_GS["h"]+1)
        SP_ST_mainhand:SetWidth(SP_ST_GS["h"]+1)
        SP_ST_offhand:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("SecondaryHandSlot")))
        SP_ST_offhand:SetHeight(SP_ST_GS["h"]+1)
        SP_ST_offhand:SetWidth(SP_ST_GS["h"]+1)
        SP_ST_range:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("RangedSlot")))
        SP_ST_range:SetHeight(SP_ST_GS["h"]+1)
        SP_ST_range:SetWidth(SP_ST_GS["h"]+1)
    else 
        SP_ST_mainhand:SetTexture(nil)
        SP_ST_mainhand:SetWidth(0)
        SP_ST_offhand:SetTexture(nil)
        SP_ST_offhand:SetWidth(0)
        SP_ST_range:SetTexture(nil)
        SP_ST_range:SetWidth(0)
    end

    if SP_ST_GS["timers"] ~= 0 then
        SP_ST_maintimer:Show()
        SP_ST_offtimer:Show()
        SP_ST_rangetimer:Show()
    else
        SP_ST_maintimer:Hide()
        SP_ST_offtimer:Hide()
        SP_ST_rangetimer:Hide()
    end
    
    SP_ST_FrameTime:ClearAllPoints()
    SP_ST_FrameTime2:ClearAllPoints()
    SP_ST_FrameTime3:ClearAllPoints()

    local style = SP_ST_GS["style"]
    if style == 1 or style == 2 then
        if SP_ST_GS["icons"] ~= 0 then
            SP_ST_mainhand:SetPoint("LEFT", "SP_ST_Frame", "LEFT")
            SP_ST_offhand:SetPoint("LEFT", "SP_ST_FrameOFF", "LEFT")
            SP_ST_range:SetPoint("LEFT", "SP_ST_FrameRange", "LEFT")
            SP_ST_FrameTime:SetPoint("LEFT", "SP_ST_mainhand", "RIGHT")
            SP_ST_FrameTime2:SetPoint("LEFT", "SP_ST_offhand", "RIGHT")
            SP_ST_FrameTime3:SetPoint("LEFT", "SP_ST_range", "RIGHT")
        else
            SP_ST_FrameTime:SetPoint("LEFT", "SP_ST_Frame", "LEFT")
            SP_ST_FrameTime2:SetPoint("LEFT", "SP_ST_FrameOFF", "LEFT")
            SP_ST_FrameTime3:SetPoint("LEFT", "SP_ST_FrameRange", "LEFT")
        end
    elseif style == 3 or style == 4 then
        if SP_ST_GS["icons"] ~= 0 then
            SP_ST_mainhand:SetPoint("RIGHT", "SP_ST_Frame", "RIGHT")
            SP_ST_offhand:SetPoint("RIGHT", "SP_ST_FrameOFF", "RIGHT")
            SP_ST_range:SetPoint("RIGHT", "SP_ST_FrameRange", "RIGHT")
            SP_ST_FrameTime:SetPoint("RIGHT", "SP_ST_mainhand", "LEFT")
            SP_ST_FrameTime2:SetPoint("RIGHT", "SP_ST_offhand", "LEFT")
            SP_ST_FrameTime3:SetPoint("RIGHT", "SP_ST_range", "LEFT")
        else
            SP_ST_FrameTime:SetPoint("RIGHT", "SP_ST_Frame", "RIGHT")
            SP_ST_FrameTime2:SetPoint("RIGHT", "SP_ST_FrameOFF", "RIGHT")
            SP_ST_FrameTime3:SetPoint("RIGHT", "SP_ST_FrameRange", "RIGHT")
        end
    else
        SP_ST_mainhand:SetTexture(nil)
        SP_ST_mainhand:SetWidth(0)
        SP_ST_offhand:SetTexture(nil)
        SP_ST_offhand:SetWidth(0)
        SP_ST_range:SetTexture(nil)
        SP_ST_range:SetWidth(0)
        SP_ST_FrameTime:SetPoint("CENTER", "SP_ST_Frame", "CENTER")
        SP_ST_FrameTime2:SetPoint("CENTER", "SP_ST_FrameOFF", "CENTER")
        SP_ST_FrameTime3:SetPoint("CENTER", "SP_ST_FrameRange", "CENTER")
    end

    SP_ST_Frame:SetWidth(SP_ST_GS["w"])
    SP_ST_Frame:SetHeight(SP_ST_GS["h"])
    SP_ST_FrameOFF:SetWidth(SP_ST_GS["w"])
    SP_ST_FrameOFF:SetHeight(SP_ST_GS["h"])
    SP_ST_FrameRange:SetWidth(SP_ST_GS["w"])
    SP_ST_FrameRange:SetHeight(SP_ST_GS["h"])

    if SP_ST_GS["icons"] ~= 0 then
        SP_ST_FrameTime:SetWidth(SP_ST_GS["w"] - SP_ST_mainhand:GetWidth())
        SP_ST_FrameTime2:SetWidth(SP_ST_GS["w"] - SP_ST_offhand:GetWidth())
        SP_ST_FrameTime3:SetWidth(SP_ST_GS["w"] - SP_ST_range:GetWidth())
    else
        SP_ST_FrameTime:SetWidth(SP_ST_GS["w"])
        SP_ST_FrameTime2:SetWidth(SP_ST_GS["w"])
        SP_ST_FrameTime3:SetWidth(SP_ST_GS["w"])
    end
    
    SP_ST_FrameTime:SetHeight(SP_ST_GS["h"] - SP_ST_GS["b"])
    SP_ST_FrameTime2:SetHeight(SP_ST_GS["h"] - SP_ST_GS["b"])
    SP_ST_FrameTime3:SetHeight(SP_ST_GS["h"] - SP_ST_GS["b"])

    SP_ST_Frame:SetAlpha(SP_ST_GS["a"])
    SP_ST_Frame:SetScale(SP_ST_GS["s"])
    SP_ST_FrameOFF:SetAlpha(SP_ST_GS["a"])
    SP_ST_FrameOFF:SetScale(SP_ST_GS["s"])
    SP_ST_FrameRange:SetAlpha(SP_ST_GS["a"])
    SP_ST_FrameRange:SetScale(SP_ST_GS["s"])
    
    -- Make frames click-through when not in move mode
    if SP_ST_GS["move"] == "off" then
        SP_ST_Frame:EnableMouse(false)
        SP_ST_FrameOFF:EnableMouse(false)
        SP_ST_FrameRange:EnableMouse(false)
        -- Remove these lines since these elements don't exist as global variables
        -- SP_ST_maintimer:EnableMouse(false)
        -- SP_ST_offtimer:EnableMouse(false)
        -- SP_ST_rangetimer:EnableMouse(false)
        -- SP_ST_mainhand:EnableMouse(false)
        -- SP_ST_offhand:EnableMouse(false)
        -- SP_ST_range:EnableMouse(false)
        -- SP_ST_FrameTime:EnableMouse(false)
        -- SP_ST_FrameTime2:EnableMouse(false)
        -- SP_ST_FrameTime3:EnableMouse(false)
    else
        SP_ST_Frame:EnableMouse(true)
        SP_ST_FrameOFF:EnableMouse(true)
        SP_ST_FrameRange:EnableMouse(true)
    end
end

local function GetWeaponSpeed(off,ranged)
    local speedMH, speedOH = UnitAttackSpeed("player")
    if off and not ranged then
        return speedOH
    elseif not off and ranged then
        local rangedAttackSpeed = UnitRangedDamage("player")
        return rangedAttackSpeed
    else
        return speedMH
    end
end

local function isDualWield()
    return GetWeaponSpeed(true) ~= nil
end

local function hasRanged()
    return GetWeaponSpeed(nil,true) ~= nil
end

local function ShouldResetTimer(off)
    if not st_timerMax then st_timerMax = GetWeaponSpeed(false) end
    if not st_timerOffMax and isDualWield() then st_timerOffMax = GetWeaponSpeed(true) end
    local percentTime
    if off then
        percentTime = st_timerOff / st_timerOffMax
    else 
        percentTime = st_timer / st_timerMax
    end
    return percentTime < 0.025
end

local function ClosestSwing()
    if not st_timerMax then st_timerMax = GetWeaponSpeed(false) end
    if not st_timerOffMax then st_timerOffMax = GetWeaponSpeed(true) end
    local percentLeftMH = st_timer / st_timerMax
    local percentLeftOH = st_timerOff / st_timerOffMax
    return percentLeftMH > percentLeftOH
end

local function UpdateWeapon()
    weapon = GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
    if SP_ST_GS["icons"] ~= 0 then
        SP_ST_mainhand:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("MainHandSlot")))
    end
    if isDualWield() then
        offhand = GetInventoryItemLink("player", GetInventorySlotInfo("SecondaryHandSlot"))
        if SP_ST_GS["icons"] ~= 0 then
            SP_ST_offhand:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("SecondaryHandSlot")))
        end
    else
        SP_ST_FrameOFF:Hide()
    end
    if hasRanged() then
        range = GetInventoryItemLink("player", GetInventorySlotInfo("RangedSlot"))
        if SP_ST_GS["icons"] ~= 0 then
            SP_ST_range:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("RangedSlot")))
        end
    else
        SP_ST_FrameRange:Hide()
    end
end

local function ResetTimer(off,ranged)
    if not off and not ranged then
        st_timerMax = GetWeaponSpeed(off)
        st_timer = GetWeaponSpeed(off)
    elseif off and not ranged then
        st_timerOffMax = GetWeaponSpeed(off)
        st_timerOff = GetWeaponSpeed(off)
    else
        range_fader = GetTime()
        st_timerRangeMax = GetWeaponSpeed(false,true)
        st_timerRange = GetWeaponSpeed(false,true)
    end

    if not off and not ranged then SP_ST_Frame:Show() end
    if isDualWield() then SP_ST_FrameOFF:Show() end
    if hasRanged() then SP_ST_FrameRange:Show() end
end

local function TestShow()
    ResetTimer(false)
end

local function UpdateDisplay()
    local style = SP_ST_GS["style"]
    local show_oh = SP_ST_GS["show_oh"]
    local show_range = SP_ST_GS["show_range"]

    local classColors = {
        WARRIOR = {r = 0.78, g = 0.61, b = 0.43},
        PALADIN = {r = 0.96, g = 0.55, b = 0.73},
        HUNTER = {r = 0.67, g = 0.83, b = 0.45},
        ROGUE = {r = 1.00, g = 0.96, b = 0.41},
        PRIEST = {r = 1.00, g = 1.00, b = 1.00},
        SHAMAN = {r = 0.00, g = 0.44, b = 0.87},
        MAGE = {r = 0.41, g = 0.80, b = 0.94},
        WARLOCK = {r = 0.58, g = 0.51, b = 0.79},
        DRUID = {r = 1.00, g = 0.49, b = 0.04}
    }

    local classColor = classColors[player_class] or {r = 0.96, g = 0.55, b = 0.73}
    local outOfRangeColor = {r = classColor.r * 0.8, g = classColor.g * 0.8, b = classColor.b * 0.8}

    if SP_ST_InRange() then
        SP_ST_FrameTime:SetVertexColor(classColor.r, classColor.g, classColor.b)
        SP_ST_FrameTime2:SetVertexColor(classColor.r, classColor.g, classColor.b)
        SP_ST_Frame:SetBackdropColor(0, 0, 0, 0.8)
        SP_ST_FrameOFF:SetBackdropColor(0, 0, 0, 0.8)
    else
        SP_ST_FrameTime:SetVertexColor(outOfRangeColor.r, outOfRangeColor.g, outOfRangeColor.b)
        SP_ST_FrameTime2:SetVertexColor(outOfRangeColor.r, outOfRangeColor.g, outOfRangeColor.b)
        SP_ST_Frame:SetBackdropColor(outOfRangeColor.r, outOfRangeColor.g, outOfRangeColor.b, 0.5)
        SP_ST_FrameOFF:SetBackdropColor(outOfRangeColor.r, outOfRangeColor.g, outOfRangeColor.b, 0.5)
    end
    if CheckInteractDistance("target",4) then
        SP_ST_FrameTime3:SetVertexColor(classColor.r, classColor.g, classColor.b)
        SP_ST_FrameRange:SetBackdropColor(0, 0, 0, 0.8)
    else
        SP_ST_FrameTime3:SetVertexColor(outOfRangeColor.r, outOfRangeColor.g, outOfRangeColor.b)
        SP_ST_FrameRange:SetBackdropColor(outOfRangeColor.r, outOfRangeColor.g, outOfRangeColor.b, 0.5)
    end

    if GetTime() - 10 > range_fader then
        SP_ST_FrameRange:Hide()
    end

    if st_timer <= 0 then
        if style == 2 or style == 4 or style == 6 then
            --nothing
        else
            SP_ST_FrameTime:Hide()
        end
        if not combat and not configmod then
            SP_ST_Frame:Hide()
        end
    else
        SP_ST_FrameTime:Show()
        local width = SP_ST_GS["w"]
        local size = (st_timer / st_timerMax) * width
        if style == 2 or style == 4 or style == 6 then
            size = width - size
        end
        if size > width then
            size = width
            SP_ST_FrameTime:SetTexture(1, 0.8, 0.8, 1)
        else
            SP_ST_FrameTime:SetTexture(1, 1, 1, 1)
        end
        SP_ST_FrameTime:SetWidth(size)
        if SP_ST_GS["timers"] ~= 0 then
            local currentTime = sp_round(st_timer, 1)
            local totalTime = sp_round(st_timerMax, 1)
            if math.floor(currentTime) == currentTime then
                currentTime = currentTime..".0"
            end
            if math.floor(totalTime) == totalTime then
                totalTime = totalTime..".0"
            end
            SP_ST_maintimer:SetText(currentTime.."/"..totalTime)
        end
    end

    if hasRanged() and show_range ~= 0 then
        if st_timerRange <= 0 then
            if style == 2 or style == 4 or style == 6 then
                --nothing
            else
                SP_ST_FrameTime3:Hide()
            end
            if not combat and not configmod then
                SP_ST_FrameRange:Hide()
            end
        else
            SP_ST_FrameTime3:Show()
            local width = SP_ST_GS["w"]
            local size2 = (st_timerRange / st_timerRangeMax) * width
            if style == 2 or style == 4 or style == 6 then
                size2 = width - size2
            end
            if size2 > width then
                size2 = width
                SP_ST_FrameTime3:SetTexture(1, 0.8, 0.8, 1)
            else
                SP_ST_FrameTime3:SetTexture(1, 1, 1, 1)
            end
            SP_ST_FrameTime3:SetWidth(size2)
            if SP_ST_GS["timers"] ~= 0 then
                local currentTime = sp_round(st_timerRange, 1)
                totalTime = sp_round(st_timerRangeMax, 1)
                if math.floor(currentTime) == currentTime then
                    currentTime = currentTime..".0"
                end
                if math.floor(totalTime) == totalTime then
                    totalTime = totalTime..".0"
                end
                SP_ST_rangetimer:SetText(currentTime.."/"..totalTime)
            end
        end
    else
        SP_ST_FrameRange:Hide()
    end

    if isDualWield() and show_oh ~= 0 then
        if st_timerOff <= 0 then
            if style == 2 or style == 4 or style == 6 then
                --nothing
            else
                SP_ST_FrameTime2:Hide()
            end
            if not combat and not configmod then
                SP_ST_FrameOFF:Hide()
            end
        else
            SP_ST_FrameTime2:Show()
            local width = SP_ST_GS["w"]
            local size2 = (st_timerOff / st_timerOffMax) * width
            if style == 2 or style == 4 or style == 6 then
                size2 = width - size2
            end
            if size2 > width then
                size2 = width
                SP_ST_FrameTime2:SetTexture(1, 0.8, 0.8, 1)
            else
                SP_ST_FrameTime2:SetTexture(1, 1, 1, 1)
            end
            SP_ST_FrameTime2:SetWidth(size2)
            if SP_ST_GS["timers"] ~= 0 then
                local currentTime = sp_round(st_timerOff, 1)
                local totalTime = sp_round(st_timerOffMax, 1)
                if math.floor(currentTime) == currentTime then
                    currentTime = currentTime..".0"
                end
                if math.floor(totalTime) == totalTime then
                    totalTime = totalTime..".0"
                end
                SP_ST_offtimer:SetText(currentTime.."/"..totalTime)
            end
        end
    else
        SP_ST_FrameOFF:Hide()
    end
end

--------------------------------------------------------------------------------
local instants = {
    ["Backstab"] = 1,
    ["Sinister Strike"] = 1,
    ["Kick"] = 1,
    ["Expose Armor"] = 1,
    ["Eviscerate"] = 1,
    ["Rupture"] = 1,
    ["Kidney Shot"] = 1,
    ["Garrote"] = 1,
    ["Ambush"] = 1,
    ["Cheap Shot"] = 1,
    ["Gouge"] = 1,
    ["Feint"] = 1,
    ["Ghosly Strike"] = 1,
    ["Hemorrhage"] = 1,
    ["Hamstring"] = 1,
    ["Sunder Armor"] = 1,
    ["Bloodthirst"] = 1,
    ["Mortal Strike"] = 1,
    ["Shield Slam"] = 1,
    ["Overpower"] = 1,
    ["Revenge"] = 1,
    ["Pummel"] = 1,
    ["Shield Bash"] = 1,
    ["Disarm"] = 1,
    ["Execute"] = 1,
    ["Taunt"] = 1,
    ["Mocking Blow"] = 1,
    ["Slam"] = 1,
    ["Rend"] = 1,
    ["Crusader Strike"] = 1,
    ["Holy Strike"] = 1,
    ["Stormstrike"] = 1,
    ["Lightning Strike"] = 1,
    ["Savage Bite"] = 1,
    ["Growl"] = 1,
    ["Bash"] = 1,
    ["Swipe"] = 1,
    ["Claw"] = 1,
    ["Rip"] = 1,
    ["Ferocious Bite"] = 1,
    ["Shred"] = 1,
    ["Rake"] = 1,
    ["Cower"] = 1,
    ["Ravage"] = 1,
    ["Pounce"] = 1,
    ["Wing Clip"] = 1,
    ["Disengage"] = 1,
    ["Carve"] = 1,
}

local range_check_slot = nil
function SP_ST_Check_Actions(slot)
    if slot then
        local name,actionType,identifier = GetActionText(slot)
        if actionType and identifier and actionType == "SPELL" then
            local name,rank,texture = SpellInfo(identifier)
            if instants[name] then
                range_check_slot = slot
                return
            end
        end
    end
    for i=1,120 do
        local name,actionType,identifier = GetActionText(i)
        if actionType and identifier and actionType == "SPELL" then
            local name,rank,texture = SpellInfo(identifier)
            if instants[name] then
                range_check_slot = i
                return
            end
        end
    end
    range_check_slot = nil
end

function SP_ST_InRange()
    return range_check_slot == nil or IsActionInRange(range_check_slot) == 1
end

function rangecheck()
    print(SP_ST_InRange() and "yes" or "no")
end

function GetFlurry(class)
    flurry_mult = 1.3
    for page = 1, 3 do
        for talent = 1, 100 do
            local name, _, _, _, count = GetTalentInfo(page, talent)
            if not name then break end
            if name == "Flurry" then
                if count == 0 then
                    flurry_mult = 1
                else
                    flurry_mult = 1 + (flurry[class][count] or 0) / 100
                end
                return
            end
        end
    end
end

local configFrame = nil
local xEditBox = nil
local yEditBox = nil

local function CreateConfigFrame()
    if configFrame then return end

    configFrame = CreateFrame("Frame", "SP_ST_ConfigFrame", UIParent)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:SetScript("OnMouseDown", function() this:StartMoving() end)
    configFrame:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
    configFrame:SetWidth(400)
    configFrame:SetHeight(700)
    configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    configFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true, tileSize = 16,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    configFrame:SetBackdropColor(0, 0, 0, 1)

    local title = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("SP Swing Timer Config")

    local closeButton = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -8, -8)

    local function CreateSlider(name, parent, minVal, maxVal, step, var, editBox)
        local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        slider:SetWidth(300)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetValue(SP_ST_GS[var])
        getglobal(name .. "Low"):SetText(minVal)
        getglobal(name .. "High"):SetText(maxVal)
        getglobal(name .. "Text"):SetText(settings[var] .. ": " .. SP_ST_GS[var])
        slider:SetScript("OnValueChanged", function()
            local value = math.floor(this:GetValue() / step) * step
            SP_ST_GS[var] = value
            getglobal(name .. "Text"):SetText(settings[var] .. ": " .. value)
            if editBox then
                editBox:SetText(tostring(value))
            end
            UpdateAppearance()
        end)
        return slider
    end

    local function CreateEditBox(name, parent, var, minVal, maxVal, relatedSlider)
        local editBox = CreateFrame("EditBox", name, parent)
        editBox:SetWidth(60)
        editBox:SetHeight(20)
        editBox:SetFontObject(GameFontNormalSmall)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(6)
        editBox:SetText(tostring(SP_ST_GS[var]))
        editBox:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        editBox:SetBackdropColor(0, 0, 0, 0.8)
        editBox:SetScript("OnEnterPressed", function()
            local input = this:GetText()
            local value = tonumber(input)
            if value then
                value = math.floor(value + 0.5) -- Round to nearest integer
                local screenWidth = UIParent:GetWidth()
                local screenHeight = UIParent:GetHeight()
                local scale = SP_ST_GS["s"]
                local scaledWidth = SP_ST_GS["w"] * scale
                local scaledHeight = SP_ST_GS["h"] * scale
                local totalHeight = scaledHeight
                if SP_ST_GS["show_oh"] ~= 0 and isDualWield() then
                    totalHeight = totalHeight + (SP_ST_GS["h"] * scale) + math.abs(SP_ST_GS["vo"])
                end
                if SP_ST_GS["show_range"] ~= 0 and hasRanged() then
                    totalHeight = totalHeight + (SP_ST_GS["h"] * scale) + math.abs(SP_ST_GS["vo"])
                end
                if var == "x" then
                    value = math.max(0, math.min(value, math.min(1000, screenWidth - scaledWidth)))
                elseif var == "y" then
                    value = math.max(math.max(-1000, -screenHeight + totalHeight), math.min(value, 0))
                end
                SP_ST_GS[var] = value
                this:SetText(tostring(value))
                relatedSlider:SetValue(value)
                getglobal(relatedSlider:GetName() .. "Text"):SetText(settings[var] .. ": " .. value)
                UpdateAppearance()
            else
                this:SetText(tostring(SP_ST_GS[var]))
                print("Error: Invalid number for " .. settings[var] .. ". Please enter a number between " .. minVal .. " and " .. maxVal .. ".")
            end
            this:ClearFocus()
        end)
        editBox:SetScript("OnEscapePressed", function()
            this:SetText(tostring(SP_ST_GS[var]))
            this:ClearFocus()
        end)
        return editBox
    end

    local function CreateCheckBox(name, parent, var, text)
        local check = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate")
        getglobal(name .. "Text"):SetText(text or settings[var])
        check:SetChecked(SP_ST_GS[var] ~= 0)
        check:SetScript("OnClick", function()
            SP_ST_GS[var] = this:GetChecked() and 1 or 0
            UpdateAppearance()
        end)
        return check
    end

    local yOffset = -50

    local sliderX = CreateSlider("SP_ST_SliderX", configFrame, 0, 1000, 1, "x")
    sliderX:SetPoint("TOPLEFT", 20, yOffset)
    xEditBox = CreateEditBox("SP_ST_EditBoxX", configFrame, "x", 0, 1000, sliderX)
    xEditBox:SetPoint("LEFT", sliderX, "RIGHT", 10, 0)
    yOffset = yOffset - 40

    local sliderY = CreateSlider("SP_ST_SliderY", configFrame, -1000, 0, 1, "y")
    sliderY:SetPoint("TOPLEFT", 20, yOffset)
    yEditBox = CreateEditBox("SP_ST_EditBoxY", configFrame, "y", -1000, 0, sliderY)
    yEditBox:SetPoint("LEFT", sliderY, "RIGHT", 10, 0)
    yOffset = yOffset - 40

    local sliderW = CreateSlider("SP_ST_SliderW", configFrame, 50, 500, 1, "w")
    sliderW:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 40

    local sliderH = CreateSlider("SP_ST_SliderH", configFrame, 1, 50, 1, "h")
    sliderH:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 40

    local sliderB = CreateSlider("SP_ST_SliderB", configFrame, 0, 10, 1, "b")
    sliderB:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 40

    local sliderA = CreateSlider("SP_ST_SliderA", configFrame, 0, 1, 0.05, "a")
    sliderA:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 40

    local sliderS = CreateSlider("SP_ST_SliderS", configFrame, 0.1, 3, 0.05, "s")
    sliderS:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 40

    local sliderVO = CreateSlider("SP_ST_SliderVO", configFrame, -200, 200, 1, "vo")
    sliderVO:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 40

    local sliderHO = CreateSlider("SP_ST_SliderHO", configFrame, -200, 200, 1, "ho")
    sliderHO:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 40

    local sliderStyle = CreateSlider("SP_ST_SliderStyle", configFrame, 1, 6, 1, "style")
    sliderStyle:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 40

    local checkIcons = CreateCheckBox("SP_ST_CheckIcons", configFrame, "icons")
    checkIcons:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 30

    local checkBG = CreateCheckBox("SP_ST_CheckBG", configFrame, "bg")
    checkBG:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 30

    local checkTimers = CreateCheckBox("SP_ST_CheckTimers", configFrame, "timers")
    checkTimers:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 30

    local checkShowOH = CreateCheckBox("SP_ST_CheckShowOH", configFrame, "show_oh", "Show Offhand")
    checkShowOH:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 30

    local checkShowRange = CreateCheckBox("SP_ST_CheckShowRange", configFrame, "show_range", "Show Range")
    checkShowRange:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - 30

    local unlockButton = CreateFrame("Button", "SP_ST_UnlockButton", configFrame, "OptionsButtonTemplate")
    unlockButton:SetWidth(120)
    unlockButton:SetText("Unlock Bars")
    unlockButton:SetPoint("BOTTOMLEFT", 20, 20)
    unlockButton:SetScript("OnClick", function()
        ChatHandler("move on")
    end)

    local lockButton = CreateFrame("Button", "SP_ST_LockButton", configFrame, "OptionsButtonTemplate")
    lockButton:SetWidth(120)
    lockButton:SetText("Lock Bars")
    lockButton:SetPoint("BOTTOMRIGHT", -20, 20)
    lockButton:SetScript("OnClick", function()
        ChatHandler("move off")
    end)

    configFrame:Hide()
end

ChatHandler = function(msg)
    local vars = SplitString(msg, " ")
    for k,v in vars do
        if v == "" then
            v = nil
        end
    end
    local cmd, arg = vars[1], vars[2]
    if cmd == "reset" then
        SP_ST_GS = nil
        UpdateSettings()
        UpdateAppearance()
        if xEditBox then xEditBox:SetText(tostring(SP_ST_GS["x"])) end
        if yEditBox then yEditBox:SetText(tostring(SP_ST_GS["y"])) end
        print("Reset to defaults.")
    elseif cmd == "move" then
        if arg == "on" then
            configmod = true
            SP_ST_Frame:Show()
            SP_ST_FrameOFF:Show()
            MakeMovable(SP_ST_Frame)
        else
            SP_ST_Frame:SetMovable(false)
            local _,_,_,x,y = SP_ST_Frame:GetPoint()
            local screenWidth = UIParent:GetWidth()
            local screenHeight = UIParent:GetHeight()
            local scale = SP_ST_GS["s"]
            local scaledWidth = SP_ST_GS["w"] * scale
            local scaledHeight = SP_ST_GS["h"] * scale
            local totalHeight = scaledHeight
            if SP_ST_GS["show_oh"] ~= 0 and isDualWield() then
                totalHeight = totalHeight + (SP_ST_GS["h"] * scale) + math.abs(SP_ST_GS["vo"])
            end
            if SP_ST_GS["show_range"] ~= 0 and hasRanged() then
                totalHeight = totalHeight + (SP_ST_GS["h"] * scale) + math.abs(SP_ST_GS["vo"])
            end
            x = math.max(0, math.min(x, math.min(1000, screenWidth - scaledWidth)))
            y = math.max(math.max(-1000, -screenHeight + totalHeight), math.min(y, 0))
            SP_ST_GS["x"] = x
            SP_ST_GS["y"] = y
            SP_ST_Frame:ClearAllPoints()
            SP_ST_Frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
            if xEditBox then xEditBox:SetText(tostring(x)) end
            if yEditBox then yEditBox:SetText(tostring(y)) end
            configmod = false
            UpdateAppearance()
        end
    elseif cmd == "offhand" then
        SP_ST_GS["show_oh"] = (SP_ST_GS["show_oh"] == 0) and 1 or 0
        print("toggled showing offhand: " .. (SP_ST_GS["show_oh"] ~= 0 and "on" or "off"))
    elseif cmd == "range" then
        SP_ST_GS["show_range"] = (SP_ST_GS["show_range"] == 0) and 1 or 0
        print("toggled showing range weapon: " .. (SP_ST_GS["show_range"] ~= 0 and "on" or "off"))
    elseif cmd == "config" then
        CreateConfigFrame()
        if configFrame:IsShown() then
            configFrame:Hide()
        else
            configFrame:Show()
        end
    elseif settings[cmd] then
        if arg then
            local number = tonumber(arg)
            if number then
                if cmd == "x" then
                    local screenWidth = UIParent:GetWidth()
                    local scale = SP_ST_GS["s"]
                    local scaledWidth = SP_ST_GS["w"] * scale
                    number = math.max(0, math.min(number, math.min(1000, screenWidth - scaledWidth)))
                elseif cmd == "y" then
                    local screenHeight = UIParent:GetHeight()
                    local scale = SP_ST_GS["s"]
                    local scaledHeight = SP_ST_GS["h"] * scale
                    local totalHeight = scaledHeight
                    if SP_ST_GS["show_oh"] ~= 0 and isDualWield() then
                        totalHeight = totalHeight + (SP_ST_GS["h"] * scale) + math.abs(SP_ST_GS["vo"])
                    end
                    if SP_ST_GS["show_range"] ~= 0 and hasRanged() then
                        totalHeight = totalHeight + (SP_ST_GS["h"] * scale) + math.abs(SP_ST_GS["vo"])
                    end
                    number = math.max(math.max(-1000, -screenHeight + totalHeight), math.min(number, 0))
                end
                SP_ST_GS[cmd] = math.floor(number + 0.5)
                if cmd == "x" and xEditBox then xEditBox:SetText(tostring(SP_ST_GS[cmd])) end
                if cmd == "y" and yEditBox then yEditBox:SetText(tostring(SP_ST_GS[cmd])) end
                UpdateAppearance()
            else
                print("Error: Invalid argument")
            end
        end
        print(format("%s %s %s (%s)", SLASH_SPSWINGTIMER1, cmd, SP_ST_GS[cmd], settings[cmd]))
    else
        for k, v in settings do
            print(format("%s %s %s (%s)", SLASH_SPSWINGTIMER1, k, SP_ST_GS[k], v))
        end
        print("/st offhand (Toggle offhand display)")
        print("/st range (Toggle range wep display)")
        print("/st config (Open config window)")
    end
    TestShow()
end

local function CreateMinimapButton()
    local minimapButton = CreateFrame("Button", "SP_ST_MinimapButton", Minimap)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetWidth(33)
    minimapButton:SetHeight(33)
    minimapButton:SetFrameLevel(8)
	minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForDrag("LeftButton")

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(18)
    icon:SetHeight(18)
    icon:SetTexture("Interface\\Icons\\Ability_Warrior_Sunder")
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	
	    -- Add border texture
    local border = minimapButton:CreateTexture(nil, "BORDER")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("CENTER", 11, -12)
    border:SetWidth(54)
    border:SetHeight(54)

    local function UpdateMinimapPosition()
        local angle = math.rad(SP_ST_GS.minimapPos)
        local x = 80 * math.cos(angle)
        local y = 80 * math.sin(angle)
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    UpdateMinimapPosition()

    minimapButton:SetScript("OnDragStart", function()
        this:StartMoving()
    end)

    minimapButton:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local mx, my = Minimap:GetCenter()
        local bx, by = this:GetCenter()
        local dx = bx - mx
        local dy = by - my
        SP_ST_GS.minimapPos = math.deg(math.atan2(dy, dx))
        UpdateMinimapPosition()
    end)

    minimapButton:SetScript("OnClick", function()
        ChatHandler("config")
    end)

    minimapButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText("SP Swing Timer")
        GameTooltip:AddLine("Click to toggle configuration", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return minimapButton
end

function SP_ST_OnUpdate(delta)
    if st_timer > 0 and not paused_swing then
        st_timer = st_timer - delta
        if st_timer < 0 then
            st_timer = 0
        end
    end
    if st_timerOff > 0 and not paused_swingOH then
        st_timerOff = st_timerOff - delta
        if st_timerOff < 0 then
            st_timerOff = 0
        end
    end
    if st_timerRange > 0 then
        st_timerRange = st_timerRange - delta
        if st_timerRange < 0 then
            st_timerRange = 0
        end
    end
    UpdateDisplay()
end

function SP_ST_OnLoad()
    this:RegisterEvent("ADDON_LOADED")
    this:RegisterEvent("PLAYER_REGEN_ENABLED")
    this:RegisterEvent("PLAYER_REGEN_DISABLED")
    this:RegisterEvent("UNIT_INVENTORY_CHANGED")
    this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
    this:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
    this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES")
    this:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
    this:RegisterEvent("CHARACTER_POINTS_CHANGED")
    this:RegisterEvent("UNIT_CASTEVENT")
    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    
    --SP_ST_Frame:SetScript("OnUpdate", SP_ST_OnUpdate)
    --SP_ST_FrameOFF:SetScript("OnUpdate", SP_ST_OnUpdate)
    --SP_ST_FrameRange:SetScript("OnUpdate", SP_ST_OnUpdate)
end

function SP_ST_OnEvent()
    if event == "ADDON_LOADED" and arg1 == "SP_SwingTimer" then
        if not SP_ST_GS then
            StaticPopup_Show("SP_ST_Install")
        end
        default_bg1 = SP_ST_Frame:GetBackdrop()
        default_bg2 = SP_ST_FrameOFF:GetBackdrop()
        default_bg3 = SP_ST_FrameRange:GetBackdrop()

        if SP_ST_GS then 
            for k,v in pairs(defaults) do
                if SP_ST_GS[k] == nil then
                    SP_ST_GS[k] = v
                end
            end
        end

        UpdateSettings()
        UpdateWeapon()
        UpdateAppearance()
        if not st_timerMax then st_timerMax = GetWeaponSpeed(false) end
        if not st_timerOffMax and isDualWield() then st_timerOffMax = GetWeaponSpeed(true) end
        if not st_timerRangeMax and hasRanged() then st_timerRangeMax = GetWeaponSpeed(nil,true) end
        CreateMinimapButton()
        print("SP_SwingTimer " .. version .. " loaded. Options: /st")
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        _,player_guid = UnitExists("player")
        _,player_class = UnitClass("player")
        if UnitAffectingCombat('player') then combat = true else combat = false end

        GetFlurry(player_class)
        CheckFlurry()
        UpdateDisplay()
        SP_ST_Check_Actions()
    elseif event == "PLAYER_REGEN_DISABLED" then
        combat = true
        wf_swings = 0
        CheckFlurry()
    elseif event == "CHARACTER_POINTS_CHANGED" then
        GetFlurry(player_class)
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        SP_ST_Check_Actions(arg1)
    elseif event == "UNIT_CASTEVENT" and arg1 == player_guid then
        local spell = SpellInfo(arg4)
        if arg4 == 51368 or arg4 == 16361 then
            wf_swings = wf_swings + (arg4 == 51368 and 1 or 2)
            return
        end

        if spell == "Flurry" then
            flurry_fresh = flurry_count < 1
            flurry_count = 3
            return
        end

        if spell == "Elemental Flurry" then
            ele_flurry_fresh = true
        end

        if arg4 == 6603 then
            if arg3 == "MAINHAND" then
                ResetTimer(false)
                if ele_flurry_fresh then
                    st_timer = st_timer / 1.3
                    st_timerMax = st_timerMax / 1.3
                    ele_flurry_fresh = false
                end
                if not ele_flurry_fresh and ele_flurry_fresh ~= nil then
                    st_timer = st_timer * 1.3
                    st_timerMax = st_timerMax * 1.3
                    ele_flurry_fresh = nil
                end
                if flurry_fresh then
                    st_timer = st_timer / flurry_mult
                    st_timerMax = st_timerMax / flurry_mult
                    flurry_fresh = false
                end
                if flurry_count == 0 then
                    st_timer = st_timer * flurry_mult
                    st_timerMax = st_timerMax * flurry_mult
                end
            elseif arg3 == "OFFHAND" then
                ResetTimer(true)
                if flurry_fresh then
                    st_timerOff = st_timerOff / flurry_mult
                    st_timerOffMax = st_timerOffMax / flurry_mult
                    flurry_fresh = false
                end
                if flurry_count == 0 then
                    st_timerOff = st_timerOff * flurry_mult
                    st_timerOffMax = st_timerOffMax * flurry_mult
                end
            end
            if wf_swings > 0 then
                wf_swings = wf_swings - 1
            else
                flurry_count = flurry_count - 1
            end
            return
        elseif arg3 == "CAST" and arg4 == 5019 then
            ResetTimer(nil,true)
            return
        end

        for _,v in L['combatSpells'] do
            if spell == v and arg3 == "CAST" then
                ResetTimer(false)
                if flurry_fresh then
                    st_timer = st_timer / flurry_mult
                    st_timerMax = st_timerMax / flurry_mult
                end
                if flurry_count == 0 then
                    st_timer = st_timer * flurry_mult
                    st_timerMax = st_timerMax * flurry_mult
                end
                flurry_count = flurry_count - 1
                return
            end
        end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            local oldWep = weapon
            local oldOff = offhand
            local oldRange = range

            UpdateWeapon()
            if combat and oldWep ~= weapon then
                ResetTimer(false)
            end

            if offhand then
                local _,_,itemId = string.find(offhand,"item:(%d+)")
                local _name,_link,_,_lvl,wep_type,_subtype,_ = GetItemInfo(itemId)
                if combat and isDualWield() and oldOff ~= offhand and wep_type and wep_type == "Weapon" then
                    ResetTimer(true)
                end
            end

            if combat and oldRange ~= range then
                ResetTimer(nil,true)
            end
        end

    elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" or event == "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES" or event == "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE" then
        if string.find(arg1, ".* attacks. You parry.") or string.find(arg1, ".* was parried.") then
            if isDualWield() then
                if st_timerOff < st_timer then
                    local minimum = GetWeaponSpeed(true) * 0.20
                    local reduct = GetWeaponSpeed(true) * 0.40
                    st_timerOff = st_timerOff - reduct
                    if st_timerOff < minimum then
                        st_timerOff = minimum
                    end
                    return
                end
            end    
            local minimum = GetWeaponSpeed(false) * 0.20
            if st_timer > minimum then
                local reduct = GetWeaponSpeed(false) * 0.40
                local newTimer = st_timer - reduct
                if newTimer < minimum then
                    st_timer = minimum
                else
                    st_timer = newTimer
                end
            end
        end
    end
end

SLASH_SPSWINGTIMER1 = "/st"
SLASH_SPSWINGTIMER2 = "/swingtimer"

SlashCmdList["SPSWINGTIMER"] = ChatHandler