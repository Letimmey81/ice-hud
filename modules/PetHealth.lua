local AceOO = AceLibrary("AceOO-2.0")

local PetHealth = AceOO.Class(IceUnitBar)

-- Constructor --
function PetHealth.prototype:init()
	PetHealth.super.prototype.init(self, "PetHealth", "pet")
	
	self:SetColor("petHealth", 37, 164, 30)
end


function PetHealth.prototype:GetDefaultSettings()
	local settings = PetHealth.super.prototype.GetDefaultSettings(self)
	settings["side"] = IceCore.Side.Left
	settings["offset"] = -1
	settings["scale"] = 0.7
	return settings
end


-- OVERRIDE
function PetHealth.prototype:GetOptions()
	local opts = PetHealth.super.prototype.GetOptions(self)
	opts["scale"] = 
	{
		type = 'range',
		name = 'Scale',
		desc = 'Scale of the bar',
		min = 0.2,
		max = 1,
		step = 0.05,
		get = function()
			return self.moduleSettings.scale
		end,
		set = function(value)
			self.moduleSettings.scale = value
			self:Redraw()
		end,
		order = 31
	}
	return opts
end


-- OVERRIDE
function PetHealth.prototype:CreateFrame()
	PetHealth.super.prototype.CreateFrame(self)
	self.frame:SetScale(self.moduleSettings.scale)
	
	local point, relativeTo, relativePoint, xoff, yoff = self.frame.bottomUpperText:GetPoint()
	if (point == "TOPLEFT") then
		point = "BOTTOMLEFT"
	else
		point = "BOTTOMRIGHT"
	end
	
	self.frame.bottomUpperText:ClearAllPoints()
	self.frame.bottomUpperText:SetPoint(point, relativeTo, relativePoint, 0, 0)
end


function PetHealth.prototype:Enable()
	PetHealth.super.prototype.Enable(self)
	
	self:RegisterEvent("PET_UI_UPDATE",	 "CheckPet");
	self:RegisterEvent("PLAYER_PET_CHANGED", "CheckPet");
	self:RegisterEvent("PET_BAR_CHANGED", "CheckPet");
	self:RegisterEvent("UNIT_PET", "CheckPet");

	self:RegisterEvent("UNIT_HEALTH", "Update")
	self:RegisterEvent("UNIT_MAXHEALTH", "Update")

	self:CheckPet()
end


function PetHealth.prototype:CheckPet()
	if (UnitExists(self.unit)) then
		self.frame:Show()
		self:Update(self.unit)
	else
		self.frame:Hide()
	end
end


function PetHealth.prototype:Update(unit)
	PetHealth.super.prototype.Update(self)
	if (unit and (unit ~= self.unit)) then
		return
	end
	
	local color = "petHealth"
	if not (self.alive) then
		color = "dead"
	end


	self:UpdateBar(self.health/self.maxHealth, color)
	self:SetBottomText1(self.healthPercentage)
end



-- Load us up
PetHealth:new()
