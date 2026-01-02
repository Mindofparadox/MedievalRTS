local AdminConfig = {}

-- [[ SECURITY ]]
AdminConfig.OWNER_ID = 1962138076 -- REPLACE WITH YOUR USER ID

-- [[ VISUALS ]]
AdminConfig.COLORS = {
	FrameBg = Color3.fromRGB(25, 25, 30),
	FrameBorder = Color3.fromRGB(255, 0, 255),
	HeaderBg = Color3.fromRGB(40, 40, 50),
	TabContainerBg = Color3.fromRGB(35, 35, 40),
	ButtonDefault = Color3.fromRGB(60, 60, 70),
	Text = Color3.new(1, 1, 1),
}

-- [[ TABS & TOOLS DATA ]]
AdminConfig.TABS = {
	{
		Name = "Units",
		Buttons = {
			{ Text = "My Builder", Color = Color3.fromRGB(50, 150, 50), Tool = "SpawnUnit", Data = { UnitType = "Builder", IsEnemy = false } },
			{ Text = "My Peasant", Color = Color3.fromRGB(50, 150, 50), Tool = "SpawnUnit", Data = { UnitType = "WarPeasant", IsEnemy = false } },
			{ Text = "My Archer",  Color = Color3.fromRGB(50, 150, 50), Tool = "SpawnUnit", Data = { UnitType = "Archer", IsEnemy = false } },
			{ Text = "Enemy Builder", Color = Color3.fromRGB(180, 50, 50), Tool = "SpawnUnit", Data = { UnitType = "Builder", IsEnemy = true } },
			{ Text = "Enemy Peasant", Color = Color3.fromRGB(180, 50, 50), Tool = "SpawnUnit", Data = { UnitType = "WarPeasant", IsEnemy = true } },
			{ Text = "Enemy Archer",  Color = Color3.fromRGB(180, 50, 50), Tool = "SpawnUnit", Data = { UnitType = "Archer", IsEnemy = true } },
		}
	},
	{
		Name = "Buildings",
		Buttons = {
			{ Text = "Barracks", Color = Color3.fromRGB(100, 100, 200), Tool = "PlaceBuild", Data = { BuildName = "RTSBarracks" } },
			{ Text = "Archer Tower", Color = Color3.fromRGB(100, 100, 200), Tool = "PlaceBuild", Data = { BuildName = "ArcherTower" } },
			{ Text = "Palisade", Color = Color3.fromRGB(120, 120, 160), Tool = "PlaceBuild", Data = { BuildName = "Palisade" } },
			{ Text = "Palisade II", Color = Color3.fromRGB(120, 120, 160), Tool = "PlaceBuild", Data = { BuildName = "Palisade2" } },
			{ Text = "House", Color = Color3.fromRGB(70, 140, 70), Tool = "PlaceBuild", Data = { BuildName = "House" } },
			{ Text = "Farm", Color = Color3.fromRGB(70, 140, 70), Tool = "PlaceBuild", Data = { BuildName = "Farm" } },
			{ Text = "Sawmill", Color = Color3.fromRGB(70, 140, 70), Tool = "PlaceBuild", Data = { BuildName = "RTSSawmill" } },
		}
	},
	{
		Name = "Map",
		Buttons = {
			{ Text = "GrassTile", Color = Color3.fromRGB(80, 80, 100), Tool = "PaintTile", Data = { TileName = "GrassTile" } },
			{ Text = "DirtTile", Color = Color3.fromRGB(80, 80, 100), Tool = "PaintTile", Data = { TileName = "DirtTile" } },
			{ Text = "StoneTile", Color = Color3.fromRGB(80, 80, 100), Tool = "PaintTile", Data = { TileName = "StoneTile" } },
			{ Text = "WaterTile", Color = Color3.fromRGB(80, 80, 100), Tool = "PaintTile", Data = { TileName = "WaterTile" } },
			{ Text = "SandTile", Color = Color3.fromRGB(80, 80, 100), Tool = "PaintTile", Data = { TileName = "SandTile" } },
		}
	},
	{
		Name = "Resources",
		Buttons = {
			{ Text = "+1000 Gold", Color = Color3.fromRGB(255, 200, 50), Action = "Resources", Data = { Gold = 1000 } },
			{ Text = "+1000 Wood", Color = Color3.fromRGB(160, 100, 50), Action = "Resources", Data = { Wood = 1000 } },
			{ Text = "+1000 Stone", Color = Color3.fromRGB(140, 140, 140), Action = "Resources", Data = { Stone = 1000 } },
			{ Text = "+10 PopCap", Color = Color3.fromRGB(80, 200, 255), Action = "Population", Data = { Delta = 10 } },
			{ Text = "-10 PopCap", Color = Color3.fromRGB(80, 200, 255), Action = "Population", Data = { Delta = -10 } },
			{ Text = "Reset Res", Color = Color3.fromRGB(200, 50, 50), Action = "Resources", Data = { Gold = -999999, Wood = -999999 } },
		}
	},
	{
		Name = "Tools",
		Buttons = {
			{ Text = "DESTROYER", Color = Color3.fromRGB(255, 0, 0), Tool = "Destroy" },
			{ Text = "Force Barracks", Color = Color3.fromRGB(100, 100, 200), Tool = "PlaceBuild", Data = { BuildName = "RTSBarracks" } },
		}
	}
}

return AdminConfig