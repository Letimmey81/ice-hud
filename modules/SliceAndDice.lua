local AceOO = AceLibrary("AceOO-2.0")

local SliceAndDice = AceOO.Class(IceUnitBar)

local NetherbladeItemIdList = {29044, 29045, 29046, 29047, 29048}
local NetherbladeEquipLocList = {"HeadSlot", "ShoulderSlot", "ChestSlot", "LegsSlot", "HandsSlot"}

local baseTime = 9
local gapPerComboPoint = 3
local netherbladeBonus = 3
local impSndTalentPage = 2
local impSndTalentIdx = 4
local impSndBonusPerRank = 0.15
local maxComboPoints = 5

local CurrMaxSnDDuration = 0

-- Constructor --
function SliceAndDice.prototype:init()
	SliceAndDice.super.prototype.init(self, "SliceAndDice", "player")

	self.moduleSettings = {}
	self.moduleSettings.desiredLerpTime = 0
	self.moduleSettings.shouldAnimate = false

	self:SetDefaultColor("SliceAndDice", 0.75, 1, 0.2)
end

-- 'Public' methods -----------------------------------------------------------

-- OVERRIDE
function SliceAndDice.prototype:Enable(core)
	SliceAndDice.super.prototype.Enable(self, core)
	
	self:RegisterEvent("PLAYER_AURAS_CHANGED", "UpdateSliceAndDice")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateDurationBar")
	self:RegisterEvent("PLAYER_COMBO_POINTS", "UpdateDurationBar")

	self:ScheduleRepeatingEvent(self.elementName, self.UpdateSliceAndDice, 0.1, self)

	self:Show(false)

	self:SetBottomText1("")
end

function SliceAndDice.prototype:Disable(core)
	SliceAndDice.super.prototype.Disable(self, core)

	self:CancelScheduledEvent(self.elementName)
end

-- OVERRIDE
function SliceAndDice.prototype:GetDefaultSettings()
    local settings = SliceAndDice.super.prototype.GetDefaultSettings(self)

    settings["enabled"] = false
    settings["shouldAnimate"] = false
    settings["desiredLerpTime"] = nil
    settings["lowThreshold"] = 0
    settings["side"] = IceCore.Side.Right
    settings["offset"] = 4
    settings["upperText"]="SnD:#"
    settings["showAsPercentOfMax"] = true
    settings["durationAlpha"] = 0.6

    return settings
end

-- OVERRIDE
function SliceAndDice.prototype:GetOptions()
    local opts = SliceAndDice.super.prototype.GetOptions(self)
	
    opts["shouldAnimate"] = nil
    opts["desiredLerpTime"] = nil
    opts["lowThreshold"] = nil
    opts["textSettings"].args["lowerTextString"] = nil
    opts["textSettings"].args["lowerTextVisible"] = nil
    opts["textSettings"].args["upperTextString"]["desc"] = "The text to display under this bar. # will be replaced with the number of Slice and Dice seconds remaining."
    opts["textSettings"].args["lockLowerFontAlpha"] = nil

    opts["showAsPercentOfMax"] =
    {
        type = 'toggle',
        name = 'Show bar as % of maximum',
        desc = 'If this is checked, then the SnD buff time shows as a percent of the maximum attainable (taking set bonuses and talents into account). Otherwise, the bar always goes from full to empty when applying SnD no matter the duration.',
        get = function()
            return self.moduleSettings.showAsPercentOfMax
        end,
        set = function(v)
            self.moduleSettings.showAsPercentOfMax = v
        end,
        disabled = function()
            return not self.moduleSettings.enabled
        end
    }

    opts["durationAlpha"] =
    {
        type = "range",
        name = "Potential SnD time bar alpha",
        desc = "What alpha value to use for the bar that displays how long your SnD will last if you activate it. (This gets multiplied by the bar's current alpha to stay in line with the bar on top of it)",
        min = 0,
        max = 100,
        step = 5,
        get = function()
            return self.moduleSettings.durationAlpha * 100
        end,
        set = function(v)
            self.moduleSettings.durationAlpha = v / 100.0
            self:Redraw()
        end,
        disabled = function()
            return not self.moduleSettings.enabled
        end
    }
    
    return opts
end

function SliceAndDice.prototype:CreateFrame()
	SliceAndDice.super.prototype.CreateFrame(self)

	self:CreateDurationBar()
end

function SliceAndDice.prototype:CreateDurationBar()
	if not self.durationFrame then
		self.durationFrame = CreateFrame("Statusbar", nil, self.frame)
		self.CurrScale = 0
	end

	self.durationFrame:SetFrameStrata("LOW")
	self.durationFrame:SetWidth(self.settings.barWidth + (self.moduleSettings.widthModifier or 0))
	self.durationFrame:SetHeight(self.settings.barHeight)

	if not self.durationFrame.bar then
		self.durationFrame.bar = self.frame:CreateTexture(nil, "BACKGROUND")
	end

	self.durationFrame.bar:SetTexture(IceElement.TexturePath .. self.settings.barTexture)
	self.durationFrame.bar:SetAllPoints(self.frame)

	self.durationFrame:SetStatusBarTexture(self.durationFrame.bar)

	self:UpdateBar(1, "undef")

	self.durationFrame:ClearAllPoints()
	self.durationFrame:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 0)

	self.durationFrame:SetAlpha(self.alpha * self.moduleSettings.durationAlpha)

	-- force update the bar...if we're in here, then either the UI was just loaded or the player is jacking with the options.
	-- either way, make sure the duration bar matches accordingly
	self:UpdateDurationBar()
end

-- 'Protected' methods --------------------------------------------------------

function _GetBuffDuration(unitName, buffName)
    local i = 1
    local buff, rank, texture, count, duration, remaining = UnitBuff(unitName, i)

    while buff do
        if (texture and string.match(texture, buffName)) then
            return duration, remaining
        end

        i = i + 1;

        buff, rank, texture, count, duration, remaining = UnitBuff(unitName, i)
    end

    return nil, nil
end

function SliceAndDice.prototype:UpdateSliceAndDice()
    local duration, remaining = _GetBuffDuration("player", "Ability_Rogue_SliceDice")

    if duration ~= nil and remaining ~= nil then
        self:Show(true)
        self:UpdateBar(remaining / (self.moduleSettings.showAsPercentOfMax and CurrMaxSnDDuration or duration), "SliceAndDice")

        formatString = self.moduleSettings.upperText or ''
        self:SetBottomText1(string.gsub(formatString, "#", tostring(floor(remaining))))
    else
	self:UpdateBar(0, "SliceAndDice")
	self:SetBottomText1("")

	if GetComboPoints("target") == 0 or not UnitExists("target") then
	        self:Show(false)
	end
    end
end

function SliceAndDice.prototype:UpdateDurationBar()
	local points = GetComboPoints("target")
	local scale

	-- first, set the cached upper limit of SnD duration
	CurrMaxSnDDuration = self:GetMaxBuffTime(maxComboPoints)

	-- player doesn't want to show the percent of max or the alpha is zeroed out, so don't bother with the duration bar
	if not self.moduleSettings.showAsPercentOfMax or self.moduleSettings.durationAlpha == 0 then
		return
	end

	-- if we have combo points and a target selected, go ahead and show the bar so the duration bar can be seen
	if points > 0 and UnitExists("target") then
		self:Show(true)
	end

	-- compute the scale from the current number of combo points
	scale = self:GetMaxBuffTime(points) / CurrMaxSnDDuration

	-- sadly, animation uses bar-local variables so we can't use the animation for 2 bar textures on the same bar element
	if (self.moduleSettings.side == IceCore.Side.Left) then
		self.durationFrame.bar:SetTexCoord(1, 0, 1-scale, 1)
	else
		self.durationFrame.bar:SetTexCoord(0, 1, 1-scale, 1)
	end
end

function SliceAndDice.prototype:GetMaxBuffTime(numComboPoints)
    local maxduration

    if numComboPoints == 0 then
        return 0
    end

    maxduration = baseTime + ((numComboPoints - 1) * gapPerComboPoint)

    if self:HasNetherbladeBonus() then
        maxduration = maxduration + netherbladeBonus
    end

    _, _, _, _, rank = GetTalentInfo(impSndTalentPage, impSndTalentIdx)

    maxduration = maxduration * (1 + (rank * impSndBonusPerRank))

    return maxduration
end

function SliceAndDice.prototype:HasNetherbladeBonus()
	local numPieces
	local linkStr, itemId

	numPieces = 0

	-- run through all the possible equip locations of a netherblade piece
	for i=1,#NetherbladeEquipLocList do
		-- pull the link string for the item in this equip loc
		linkStr = GetInventoryItemLink(self.unit, GetInventorySlotInfo(NetherbladeEquipLocList[i]))
		-- get the item id out of that link string
		itemId = self:GetItemIdFromItemLink(linkStr)

		-- check if the item id in that slot is part of the netherblade item id list
		if self:IsItemIdInList(itemId, NetherbladeItemIdList) then
			-- increment the fact that we have this piece of netherblade
			numPieces = numPieces + 1

			-- check if we've met the set bonus for slice and dice
			if numPieces >= 2 then
				return true
			end
		end
	end
end

function SliceAndDice.prototype:GetItemIdFromItemLink(linkStr)
	local itemId

	_, itemId, _, _, _, _, _, _, _ = strsplit(":", linkStr)

	return itemId
end

function SliceAndDice.prototype:IsItemIdInList(itemId, list)
	for i=1,#list do
		if string.match(itemId, list[i]) then
			return true
		end
	end

	return false
end

local _, unitClass = UnitClass("player")
-- Load us up
if unitClass == "ROGUE" then
    IceHUD.SliceAndDice = SliceAndDice:new()
end