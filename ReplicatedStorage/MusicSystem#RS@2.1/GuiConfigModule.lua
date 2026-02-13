--!strict

local M = {}

M.Theme = {
	GUI_NAME = "MusicSystem_Zero_Global_Full",
	KASET_IMAGE_ID = "rbxassetid://91300334986019",
	MAIN_BG_IMAGE_ID = "rbxassetid://91300334986019",
	TOPBAR_ICON_IMAGE = "rbxassetid://117380457425054",

	C_BG = Color3.fromRGB(15, 15, 15),
	C_PANEL = Color3.fromRGB(15, 15, 15),
	C_WHITE = Color3.fromRGB(255, 255, 255),
	C_SILVER = Color3.fromRGB(160, 160, 160),
	C_DIM = Color3.fromRGB(35, 35, 35),

	FONT_BOLD = Enum.Font.GothamBold,
	FONT_BLACK = Enum.Font.GothamBlack,
	FONT_REG = Enum.Font.Gotham,
	LIST_FONT = Enum.Font.GothamBlack,

	MAIN_BG_TRANSPARENCY = 0.05,
	MAIN_BG_TINT = Color3.fromRGB(255, 255, 255),
	VIGNETTE_ALPHA = 0.22,
}

M.Strokes = {
	Default = {
		Thickness = 2.5,
		Color = Color3.fromRGB(255, 255, 255),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Transparency = 0.6,
	},
	List = {
		Thickness = 2,
		Color = Color3.fromRGB(255, 255, 255),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Transparency = 0.68,
	},
}

M.Gradients = {
	Neon = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(30, 100, 200)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 50)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(30, 100, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
	}),
}

M.UI = {
	ScreenGui = { Name = M.Theme.GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = true },
	MainFrame = { Name = "MainFrame", Size = UDim2.fromOffset(980, 540), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0.06, ZIndex = 10, Visible = false, CornerRadius = UDim.new(0, 12) },
	ContentRoot = { Name = "ContentRoot", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50 },
	TopInfo = { Size = UDim2.new(0.42, 0, 0, 85), Position = UDim2.fromOffset(20, 20), CornerRadius = UDim.new(0, 8), Padding = UDim.new(0, 8), ZIndex = 60 },
	OptionBox = { Size = UDim2.fromOffset(120, 85), CornerRadius = UDim.new(0, 8), Padding = UDim.new(0, 8), ZIndex = 60 },
	Playlist = { Size = UDim2.new(0.23, 0, 1, 0), CornerRadius = UDim.new(0, 10), Padding = UDim.new(0, 8), ZIndex = 56 },
	Center = { Size = UDim2.new(0.48, 0, 1, 0), CornerRadius = UDim.new(0, 10), Padding = UDim.new(0, 8), ZIndex = 56 },
	Queue = { Size = UDim2.new(0.24, 0, 1, 0), CornerRadius = UDim.new(0, 10), Padding = UDim.new(0, 8), ZIndex = 56 },
	ListRow = { Size = UDim2.new(1, 0, 0, 42), CornerRadius = UDim.new(0, 10), Padding = UDim.new(0, 6), ZIndex = 70 },
	ListButton = { Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -40, 0.5, 0), CornerRadius = UDim.new(0, 10), ZIndex = 72 },
	TextBox = { CornerRadius = UDim.new(0, 10), Padding = UDim.new(0, 8) },
	TextButton = { CornerRadius = UDim.new(0, 8), Padding = UDim.new(0, 6) },
	SliderBar = { CornerRadius = UDim.new(0, 8) },
	RoundKnob = { CornerRadius = UDim.new(1, 0) },
}

function M.ApplyDecor(target: Instance, cfg: {[string]: any}?, strokePreset: string?)
	if not cfg then return nil end
	if cfg.CornerRadius then
		local c = Instance.new("UICorner")
		c.CornerRadius = cfg.CornerRadius
		c.Parent = target
	end
	if cfg.Padding then
		local p = Instance.new("UIPadding")
		p.PaddingTop = cfg.Padding
		p.PaddingBottom = cfg.Padding
		p.PaddingLeft = cfg.Padding
		p.PaddingRight = cfg.Padding
		p.Parent = target
	end
	local strokeCfg = M.Strokes[strokePreset or "Default"]
	if strokeCfg then
		local s = Instance.new("UIStroke")
		for k, v in pairs(strokeCfg) do
			(s :: any)[k] = v
		end
		s.Parent = target
		local g = Instance.new("UIGradient")
		g.Color = M.Gradients.Neon
		g.Parent = s
		return s
	end
	return nil
end


M.Schema = {
	StatusLabel = { Text = "SYSTEM STATUS: IDLE", Position = UDim2.fromOffset(15, 40), Size = UDim2.fromOffset(300, 20), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 61 },
	TimeLabel = { Text = "--:-- / --:--", Position = UDim2.new(1, -110, 0, 40), Size = UDim2.fromOffset(100, 20), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 61 },
	IdBox = { Position = UDim2.fromOffset(20, 120), Size = UDim2.fromOffset(300, 34), TextSize = 12, ZIndex = 60 },
	AddBtn = { Text = "+", Position = UDim2.fromOffset(330, 120), Size = UDim2.fromOffset(34, 34), TextSize = 18, ZIndex = 60 },
	OkDot = { Position = UDim2.fromOffset(370, 132), Size = UDim2.fromOffset(12, 12), ZIndex = 60 },
	NowLabel = { Text = "NO TRACK", Position = UDim2.fromOffset(20, 180), Size = UDim2.fromOffset(720, 30), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 60 },
	ProgressWrap = { Size = UDim2.fromOffset(720, 10), Position = UDim2.fromOffset(20, 230), ZIndex = 60 },
	PlayBtn = { Text = "PLAY", Position = UDim2.fromOffset(20, 260), Size = UDim2.fromOffset(120, 38), TextSize = 12, ZIndex = 60 },
	NextBtn = { Text = "SKIP", Position = UDim2.fromOffset(150, 260), Size = UDim2.fromOffset(120, 38), TextSize = 12, ZIndex = 60 },
	CloseBtn = { Text = "X", Position = UDim2.new(1, -50, 0, 15), Size = UDim2.fromOffset(35, 35), TextSize = 16, ZIndex = 999 },
	ValidOk = Color3.fromRGB(170, 255, 200),
	ValidStroke = Color3.fromRGB(200, 255, 220),
	InvalidOk = Color3.fromRGB(255, 170, 170),
	InvalidStroke = Color3.fromRGB(255, 210, 210),
}

return M
