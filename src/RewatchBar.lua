RewatchBar = {}
RewatchBar.__index = RewatchBar

local colors =
{
	{ r=0.00, g=0.70, b=0.0, a=1 },
	{ r=0.85, g=0.15, b=0.8, a=1 },
	{ r=0.05, g=0.30, b=0.1, a=1 },
	{ r=0.50, g=0.80, b=0.3, a=1 },
	{ r=0.00, g=0.10, b=0.8, a=1 }
}

function RewatchBar:new(spell, parent, anchor, i, isSidebar)

	local self =
	{
		bar = CreateFrame("STATUSBAR", nil, parent.frame, "TextStatusBar"),
		button = nil,
		parent = parent,
		sidebar = nil,

		expirationTime = 0,
		stacks = 0,
		spell = spell,
		spellId = nil,
		color = colors[((i-1)%#colors)+1],
		isSidebar = isSidebar,
		update = nil,
	}

	rewatch:Debug("RewatchBar:new")

	setmetatable(self, RewatchBar)

	-- bar
	self.bar:SetStatusBarTexture(rewatch.options.profile.bar)
	self.bar:GetStatusBarTexture():SetHorizTile(false)
	self.bar:GetStatusBarTexture():SetVertTile(false)
	self.bar:SetStatusBarColor(self.color.r, self.color.g, self.color.b, 0.2)
	self.bar:SetMinMaxValues(0, 1)
	self.bar:SetValue(self.isSidebar and 0 or 1)
	self.bar:SetFrameLevel(self.isSidebar and 30 or 20)

	if(rewatch.options.profile.layout == "horizontal") then
		self.bar:SetWidth(rewatch:Scale(rewatch.options.profile.spellBarWidth))
		self.bar:SetHeight(rewatch:Scale(rewatch.options.profile.spellBarHeight / (self.isSidebar and 3 or 1)))
		self.bar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
		self.bar:SetOrientation("horizontal")
	else
		self.bar:SetWidth(rewatch:Scale(rewatch.options.profile.spellBarHeight / (self.isSidebar and 3 or 1)))
		self.bar:SetHeight(rewatch:Scale(rewatch.options.profile.spellBarWidth))
		self.bar:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
		self.bar:SetOrientation("vertical")
	end

	if(self.isSidebar) then

		-- sidebar overrides
		self.color = { r = 1-self.color.r, g = 1-self.color.g, b = 1-self.color.b }
		self.bar:SetStatusBarColor(self.color.r, self.color.g, self.color.b, 0.2)

	else

		-- overlay cast button
		self.button = CreateFrame("BUTTON", nil, self.bar, "SecureActionButtonTemplate")
		self.button:SetWidth(self.bar:GetWidth())
		self.button:SetHeight(self.bar:GetHeight())
		self.button:SetPoint("TOPLEFT", self.bar, "TOPLEFT", 0, 0)
		self.button:RegisterForClicks("LeftButtonDown", "RightButtonDown")
		self.button:SetAttribute("type1", "spell")
		self.button:SetAttribute("unit", parent.name)
		self.button:SetAttribute("spell1", spell)
		self.button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8.blp")
		self.button:SetFrameLevel(40)

		-- text
		self.bar.text = self.button:CreateFontString("$parentText", "ARTWORK", "GameFontHighlightSmall")
		self.bar.text:SetPoint("RIGHT", self.button)
		self.bar.text:SetAllPoints()
		self.bar.text:SetAlpha(1)
		self.bar.text:SetText("")

		-- apply tooltip support
		self.button:SetScript("OnEnter", function() self.button:SetAlpha(0.2); rewatch:SetSpellTooltip(spell) end)
		self.button:SetScript("OnLeave", function() self.button:SetAlpha(1); GameTooltip:Hide() end)

		-- germination sidebar
		if(spell == rewatch.locale["rejuvenation"]) then

			self.sidebar = RewatchBar:new(rewatch.locale["rejuvenationgermination"], parent, anchor, i, true)

		end

		-- cenarion ward sidebar
		if(spell == rewatch.locale["cenarionward"]) then

			self.sidebar = RewatchBar:new(rewatch.locale["cenarionward"], parent, anchor, i, true)
			self.sidebar.spellId = 102351
			self.spellId = 102352

		end

	end

	-- events
	local lastUpdate, interval = 0, 1/20

	self.bar:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

	self.bar:SetScript("OnEvent", function(_, event) self:OnEvent(event) end)
	self.bar:SetScript("OnUpdate", function(_, elapsed)

		lastUpdate = lastUpdate + elapsed

		if lastUpdate > interval then
			self:OnUpdate()
			lastUpdate = 0
		end

	end)

	return self

end

-- event handler
function RewatchBar:OnEvent(event)

	local _, effect, _, sourceGUID, _, _, _, targetGUID, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()

	if(not spellName) then return end
	if(not sourceGUID) then return end
	if(not targetGUID) then return end
	if(sourceGUID ~= rewatch.guid) then return end
	if(self.spellId and spellId ~= self.spellId) then return end

	-- normal hot updates
	if(spellName == self.spell and targetGUID == self.parent.guid) then

		if(effect == "SPELL_AURA_APPLIED_DOSE" or effect == "SPELL_AURA_APPLIED" or effect == "SPELL_AURA_REFRESH") then
			
			self:Up()

		elseif(effect == "SPELL_AURA_REMOVED" or effect == "SPELL_AURA_DISPELLED" or effect == "SPELL_AURA_REMOVED_DOSE") then
			
			self:Down()
			self:Cooldown()

		-- commented for now to rule out a potential cause for the random cooldown runup triggers...
		-- elseif(effect == "SPELL_CAST_SUCCESS" and self.expirationTime == 0 and not self.cooldown) then
		-- 	self:Cooldown()

		end

	end

	-- catch global extensions
	if(effect == "SPELL_CAST_SUCCESS" and self.expirationTime > 0 and not self.cooldown) then

		if(spellName == rewatch.locale["flourish"]) then
			
			self.update = GetTime()

		elseif(spellName == rewatch.locale["swiftmend"] and targetGUID == self.parent.guid) then
			
			self.update = GetTime() + 0.1

		end

	end

end

-- update handler
function RewatchBar:OnUpdate()

	local currentTime = GetTime()

	-- handle updates async
	if(self.update and currentTime > self.update) then

		self:Up()
		self.update = nil

	end

	-- update bar
	if(self.expirationTime > 0) then

		local left = self.expirationTime - currentTime

		if(left <= 0) then

			self:Down()

			-- commented for now to rule out a potential cause for the random cooldown runup triggers...
			--self:Cooldown()

		else

			-- value
			if(self.cooldown) then
				self.bar:SetValue(select(2, self.bar:GetMinMaxValues()) - left)
			else
				self.bar:SetValue(left)
			end

			-- color
			if(not self.cooldown and math.abs(left-2)<0.1) then
				self.bar:SetStatusBarColor(0.6, 0.0, 0.0, 1)
			end

			-- text
			if(not self.isSidebar and self.stacks <= 1) then

				self.bar.text:SetText(left > 99 and "" or string.format("%.00f", left))

			elseif(not self.isSidebar) then

				local s = left > 99 and "" or string.format("%.00f", left)

				s = s..(rewatch.options.profile.layout == "horizontal" and " - " or "\n\n")

				if(self.stacks == 2) then s = s.."II"
				elseif(self.stacks == 3) then s = s.."III"
				elseif(self.stacks == 4) then s = s.."IV"
				elseif(self.stacks == 5) then s = s.."V"
				elseif(self.stacks == 6) then s = s.."VI"
				elseif(self.stacks == 7) then s = s.."VII"
				elseif(self.stacks == 8) then s = s.."IIX"
				elseif(self.stacks == 9) then s = s.."IX"
				elseif(self.stacks == 10) then s = s.."X"
				else s = s..self.stacks end

				self.bar.text:SetText(s)

			end
		end
	end

end

-- put it up
function RewatchBar:Up()

	rewatch:Debug("RewatchBar:Up")

	local name, stacks, expirationTime, spellId
	local found = false

	for i=1,40 do

		name, _, stacks, _, _, expirationTime, _, _, _, spellId = UnitBuff(self.parent.name, i, "PLAYER")

		if(name == nil) then break end
		if(not self.spellId and name == self.spell) then found = true end
		if(spellId == self.spellId) then found = true end
		if(found) then break end

	end

	if(not found or not expirationTime) then
		
		self.stacks = 0

	else

		local duration = expirationTime - GetTime()

		if(select(2, self.bar:GetMinMaxValues()) <= duration) then self.bar:SetMinMaxValues(0, duration) end

		self.expirationTime = expirationTime
		self.stacks = stacks
		self.cooldown = false
		self.bar:SetStatusBarColor(self.color.r, self.color.g, self.color.b, self.color.a)
		self.bar:SetValue(duration)

		if(not self.isSidebar) then self.bar.text:SetText(string.format("%.00f", duration)) end

	end

end

-- take it down
function RewatchBar:Down()

	rewatch:Debug("RewatchBar:Down")

	if(not self.parent.dead and self.stacks > 1) then self:Up() end
	if(not self.parent.dead and self.stacks > 1) then return end

	self.expirationTime = 0
	self.cooldown = false
	self.bar:SetStatusBarColor(self.color.r, self.color.g, self.color.b, 0.2)
	self.bar:SetMinMaxValues(0, 1)
	self.bar:SetValue(self.isSidebar and 0 or 1)

	if(not self.isSidebar) then self.bar.text:SetText("") end

end

-- count up for cooldown
function RewatchBar:Cooldown()

	rewatch:Debug("RewatchBar:Cooldown")

	if(self.parent.dead) then return end

	local start, duration, enabled = GetSpellCooldown(self.spell)

	if(start > 0 and duration > 0 and enabled > 0) then

		self.expirationTime = start + duration
		self.cooldown = true
		self.bar:SetStatusBarColor(0, 0, 0, 0.8)
		self.bar:SetMinMaxValues(0, self.expirationTime - GetTime())

	end

end

-- dispose
function RewatchBar:Dispose()

	rewatch:Debug("RewatchBar:Dispose")

	self.bar:UnregisterAllEvents()
	self.bar:Hide()

	if(self.sidebar) then self.sidebar:Dispose() end

	self.bar = nil
	self.parent = nil
	self.button = nil
	self.sidebar = nil

end