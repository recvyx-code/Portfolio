--!nonstrict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local rsRoot = ReplicatedStorage:WaitForChild("MusicSystem#RS@2.1")
local PlaylistModule = require(rsRoot:WaitForChild("PlaylistModule"))
local AdminModule = require(rsRoot:WaitForChild("AdminModule"))
local GuiConfig = require(rsRoot:WaitForChild("GuiConfigModule"))

local theme = GuiConfig.Theme
local uiCfg = GuiConfig.UI
local schema = GuiConfig.Schema

local remFolder = ReplicatedStorage:WaitForChild("ZeroMusicRemotes")
local RF_GetState = remFolder:WaitForChild("GetState")
local RE_Command = remFolder:WaitForChild("Command")
local RE_State = remFolder:WaitForChild("State")

local function isAdmin() return AdminModule.IsAdminPlayer(player) end
local function mk(className, props) local i = Instance.new(className) for k, v in pairs(props or {}) do i[k] = v end return i end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function formatTime(sec) if not sec or sec <= 0 then return "--:--" end local sInt = math.floor(sec + 0.5) return string.format("%d:%02d", math.floor(sInt / 60), math.floor(sInt % 60)) end
local function parseSoundId(text) if not text then return nil end local raw = tostring(text):gsub("%s+", "") if raw == "" then return nil end if raw:match("^rbxassetid://%d+$") then return raw end if raw:match("^%d+$") then return "rbxassetid://" .. raw end local num = raw:match("(%d+)") if num then return "rbxassetid://" .. num end return nil end

local function applyNeon(inst, radius, preset)
	local c = { CornerRadius = UDim.new(0, radius or 10), Padding = UDim.new(0, 0) }
	local stroke = GuiConfig.ApplyDecor(inst, c, preset)
	if stroke then
		task.spawn(function()
			TweenService:Create(stroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.82, Thickness = 2.2 }):Play()
		end)
	end
	return stroke
end

local serverState = { soundId = "", title = "", isPlaying = false, timePos = 0, timeLen = 0, volume = 0.7, speed = 1, pitch = 1, playbackSpeed = 1, reverb = false, bass = false, queue = {}, voteCount = 0, voteNeed = 6 }
local lastRecvLocal = os.clock()
local function applyState(s) if typeof(s) == "table" then serverState = s lastRecvLocal = os.clock() end end
local function estimatedTimePos() local base = tonumber(serverState.timePos) or 0 if not serverState.isPlaying then return base end return base + (os.clock() - lastRecvLocal) * math.max(0.05, tonumber(serverState.playbackSpeed) or 1) end
local function send(action, data) RE_Command:FireServer({ action = action, data = data }) end
local function sendAdmin(action, data) if not isAdmin() then return end send(action, data) end

local function buildUI()
	local screen = mk("ScreenGui", uiCfg.ScreenGui)
	screen.Parent = playerGui
	local mainProps = table.clone(uiCfg.MainFrame)
	mainProps.BackgroundColor3 = theme.C_BG
	local main = mk("Frame", mainProps)
	main.Parent = screen
	applyNeon(main, 12)
	main:SetAttribute("MusicUIOpen", false)

	local contentRoot = mk("Frame", uiCfg.ContentRoot)
	contentRoot.Parent = main

	local topInfo = mk("Frame", { Size = uiCfg.TopInfo.Size, Position = uiCfg.TopInfo.Position, BackgroundColor3 = theme.C_PANEL, ZIndex = uiCfg.TopInfo.ZIndex })
	topInfo.Parent = contentRoot
	applyNeon(topInfo, 8)
	local statusLabel = mk("TextLabel", { Text = schema.StatusLabel.Text, Position = schema.StatusLabel.Position, Size = schema.StatusLabel.Size, TextColor3 = theme.C_SILVER, Font = theme.FONT_REG, TextSize = schema.StatusLabel.TextSize, BackgroundTransparency = 1, TextXAlignment = schema.StatusLabel.TextXAlignment, Parent = topInfo, ZIndex = schema.StatusLabel.ZIndex })
	local timeLabel = mk("TextLabel", { Text = schema.TimeLabel.Text, Position = schema.TimeLabel.Position, Size = schema.TimeLabel.Size, TextColor3 = theme.C_WHITE, Font = theme.FONT_BOLD, TextSize = schema.TimeLabel.TextSize, BackgroundTransparency = 1, TextXAlignment = schema.TimeLabel.TextXAlignment, Parent = topInfo, ZIndex = schema.TimeLabel.ZIndex })

	local idBox = mk("TextBox", { PlaceholderText = isAdmin() and "Paste ID" or "Request ID (Free)", Text = "", ClearTextOnFocus = false, Position = schema.IdBox.Position, Size = schema.IdBox.Size, BackgroundColor3 = theme.C_PANEL, TextColor3 = theme.C_WHITE, Font = theme.FONT_REG, TextSize = schema.IdBox.TextSize, Parent = contentRoot, ZIndex = schema.IdBox.ZIndex })
	local idBoxStroke = applyNeon(idBox, 10)
	local addBtn = mk("TextButton", { Text = schema.AddBtn.Text, Position = schema.AddBtn.Position, Size = schema.AddBtn.Size, BackgroundColor3 = theme.C_BG, TextColor3 = theme.C_WHITE, Font = theme.FONT_BLACK, TextSize = schema.AddBtn.TextSize, Parent = contentRoot, ZIndex = schema.AddBtn.ZIndex })
	applyNeon(addBtn, 10)
	local okDot = mk("Frame", { Position = schema.OkDot.Position, Size = schema.OkDot.Size, BackgroundColor3 = theme.C_DIM, Parent = contentRoot, ZIndex = schema.OkDot.ZIndex })
	applyNeon(okDot, 8)

	local nowLabel = mk("TextLabel", { Text = schema.NowLabel.Text, Position = schema.NowLabel.Position, Size = schema.NowLabel.Size, TextColor3 = theme.C_WHITE, Font = theme.FONT_BLACK, TextSize = schema.NowLabel.TextSize, BackgroundTransparency = 1, TextXAlignment = schema.NowLabel.TextXAlignment, Parent = contentRoot, ZIndex = schema.NowLabel.ZIndex })
	local progressWrap = mk("Frame", { Size = schema.ProgressWrap.Size, Position = schema.ProgressWrap.Position, BackgroundColor3 = theme.C_DIM, Parent = contentRoot, ZIndex = schema.ProgressWrap.ZIndex })
	applyNeon(progressWrap, 6)
	local progressFill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = theme.C_WHITE, Parent = progressWrap, ZIndex = 61 })
	applyNeon(progressFill, 6, "List")

	local playBtn = mk("TextButton", { Text = schema.PlayBtn.Text, Position = schema.PlayBtn.Position, Size = schema.PlayBtn.Size, BackgroundColor3 = theme.C_BG, TextColor3 = theme.C_WHITE, Font = theme.FONT_BOLD, TextSize = schema.PlayBtn.TextSize, Parent = contentRoot, ZIndex = schema.PlayBtn.ZIndex })
	local nextBtn = mk("TextButton", { Text = schema.NextBtn.Text, Position = schema.NextBtn.Position, Size = schema.NextBtn.Size, BackgroundColor3 = theme.C_BG, TextColor3 = theme.C_WHITE, Font = theme.FONT_BOLD, TextSize = schema.NextBtn.TextSize, Parent = contentRoot, ZIndex = schema.NextBtn.ZIndex })
	local closeBtn = mk("TextButton", { Text = schema.CloseBtn.Text, Position = schema.CloseBtn.Position, Size = schema.CloseBtn.Size, BackgroundColor3 = theme.C_PANEL, TextColor3 = theme.C_WHITE, Font = theme.FONT_BLACK, TextSize = schema.CloseBtn.TextSize, Parent = contentRoot, ZIndex = schema.CloseBtn.ZIndex })
	applyNeon(playBtn, 8) applyNeon(nextBtn, 8) applyNeon(closeBtn, 8)

	return { screen = screen, main = main, statusLabel = statusLabel, timeLabel = timeLabel, idBox = idBox, idBoxStroke = idBoxStroke, addBtn = addBtn, okDot = okDot, nowLabel = nowLabel, progressFill = progressFill, playBtn = playBtn, nextBtn = nextBtn, closeBtn = closeBtn }
end

local UI = buildUI()

local function setValidVisual(valid)
	if valid then UI.okDot.BackgroundColor3 = schema.ValidOk UI.idBoxStroke.Color = schema.ValidStroke
	else UI.okDot.BackgroundColor3 = schema.InvalidOk UI.idBoxStroke.Color = schema.InvalidStroke end
end
local function setNeutralVisual() UI.okDot.BackgroundColor3 = theme.C_DIM UI.idBoxStroke.Color = theme.C_WHITE end
setNeutralVisual()

UI.idBox:GetPropertyChangedSignal("Text"):Connect(function() if parseSoundId(UI.idBox.Text) then setValidVisual(true) else setNeutralVisual() end end)

local function addOrRequest()
	local id = parseSoundId(UI.idBox.Text)
	if not id then UI.statusLabel.Text = "SYSTEM STATUS: INVALID ID" setValidVisual(false) return end
	if isAdmin() then sendAdmin("Enqueue", { id = id, title = "Sound " .. id:gsub("rbxassetid://", ""), priority = true }) UI.statusLabel.Text = "SYSTEM STATUS: ENQUEUED (PRIORITY)"
	else send("Enqueue", { id = id, title = "Requested " .. id:gsub("rbxassetid://", ""), priority = false }) UI.statusLabel.Text = "SYSTEM STATUS: REQUEST SENT" end
	UI.idBox.Text = "" setNeutralVisual()
end

UI.addBtn.MouseButton1Click:Connect(addOrRequest)
UI.playBtn.MouseButton1Click:Connect(function() if isAdmin() then sendAdmin("PlayPause") end end)
UI.nextBtn.MouseButton1Click:Connect(function() if isAdmin() then sendAdmin("Skip") else send("VoteSkip") end end)
UI.closeBtn.MouseButton1Click:Connect(function() UI.main.Visible = false UI.main:SetAttribute("MusicUIOpen", false) end)

local function applyStateToUI()
	UI.nowLabel.Text = (serverState.title and serverState.title ~= "" and string.upper(serverState.title)) or "NO TRACK"
	if serverState.isPlaying then UI.statusLabel.Text = "SYSTEM STATUS: PLAYING" UI.playBtn.Text = "PAUSE" else UI.statusLabel.Text = "SYSTEM STATUS: PAUSED" UI.playBtn.Text = "PLAY" end
	if isAdmin() then UI.nextBtn.Text = "SKIP" else UI.nextBtn.Text = string.format("VOTE SKIP %d/%d", tonumber(serverState.voteCount) or 0, tonumber(serverState.voteNeed) or 6) end
end

RE_State.OnClientEvent:Connect(function(s) applyState(s) applyStateToUI() end)
do local ok, s = pcall(function() return RF_GetState:InvokeServer() end) if ok and typeof(s) == "table" then applyState(s) end applyStateToUI() send("RequestState") end

local tracks = PlaylistModule.GetTracks()
if #tracks > 0 then UI.statusLabel.Text = "SYSTEM STATUS: READY" end

RunService.RenderStepped:Connect(function()
	local len = tonumber(serverState.timeLen) or 0
	local pos = estimatedTimePos()
	local pct = (len > 0) and clamp01(pos / len) or 0
	UI.progressFill.Size = UDim2.fromScale(pct, 1)
	UI.timeLabel.Text = string.format("%s / %s", formatTime(pos), formatTime(len))
	local open = UI.main:GetAttribute("MusicUIOpen") == true
	UI.main.Visible = open
end)
