--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local rsRoot = ReplicatedStorage:WaitForChild("MusicSystem#RS@2.1")
local GuiConfig = require(rsRoot:WaitForChild("GuiConfigModule"))
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

local guiName = GuiConfig.Theme.GUI_NAME
local topIcon = Icon.new():setImage(GuiConfig.Theme.TOPBAR_ICON_IMAGE):setOrder(4):setLeft()
pcall(function() topIcon:setTheme(Icon.Themes.Dark) end)

local function getMain()
	local screen = playerGui:FindFirstChild(guiName)
	if not screen then return nil end
	return screen:FindFirstChild("MainFrame")
end

local function setOpen(state)
	local main = getMain()
	if main then
		main:SetAttribute("MusicUIOpen", state)
		main.Visible = state
	end
end

topIcon:bindEvent("selected", function() setOpen(true) end)
topIcon:bindEvent("deselected", function() setOpen(false) end)
