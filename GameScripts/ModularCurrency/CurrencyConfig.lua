local CurrencyConfig = {}

-- VISUALS
CurrencyConfig.COLORS = {
	FrameBg = Color3.fromRGB(25, 25, 30),
	FrameStroke = Color3.fromRGB(80, 80, 90),
	IconBg = Color3.fromRGB(35, 35, 42),
	TextName = Color3.fromRGB(235, 235, 235),
	TextValue = Color3.fromRGB(255, 255, 255),
	TextAlert = Color3.fromRGB(255, 80, 80), -- For max pop
	HomeButton = Color3.fromRGB(40, 40, 40),
}

CurrencyConfig.LAYOUT = {
	FramePosition = UDim2.new(1, -14, 0, 14),
	FrameSize = UDim2.new(0, 210, 0, 130),
	HomeBtnPosition = UDim2.new(1, -20, 1, -20),
}

-- DATA: What resources to track
CurrencyConfig.RESOURCES = {
	{ Key = "Gold",  Name = "Gold" },
	{ Key = "Wood",  Name = "Wood" },
	{ Key = "Stone", Name = "Stone" },
	{ Key = "Pop",   Name = "Pop", IsComputed = true },
}

return CurrencyConfig