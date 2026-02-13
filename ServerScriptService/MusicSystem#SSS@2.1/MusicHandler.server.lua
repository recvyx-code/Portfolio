--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local rsRoot = ReplicatedStorage:WaitForChild("MusicSystem#RS@2.1")
local PlaylistModule = require(rsRoot:WaitForChild("PlaylistModule"))
local AdminModule = require(rsRoot:WaitForChild("AdminModule"))
local isAdmin = AdminModule.GetCachedAdminResolver()

local rem = ReplicatedStorage:FindFirstChild("ZeroMusicRemotes") :: Folder?
if not rem then rem = Instance.new("Folder") rem.Name = "ZeroMusicRemotes" rem.Parent = ReplicatedStorage end
local RF_GetState = rem:FindFirstChild("GetState") :: RemoteFunction?
if not RF_GetState then RF_GetState = Instance.new("RemoteFunction") RF_GetState.Name = "GetState" RF_GetState.Parent = rem end
local RE_Command = rem:FindFirstChild("Command") :: RemoteEvent?
if not RE_Command then RE_Command = Instance.new("RemoteEvent") RE_Command.Name = "Command" RE_Command.Parent = rem end
local RE_State = rem:FindFirstChild("State") :: RemoteEvent?
if not RE_State then RE_State = Instance.new("RemoteEvent") RE_State.Name = "State" RE_State.Parent = rem end

local sound = SoundService:FindFirstChild("ZeroGlobalMusic") :: Sound?
if not sound then sound = Instance.new("Sound") sound.Name = "ZeroGlobalMusic" sound.Volume = 0.7 sound.Looped = false sound.Parent = SoundService end

local reverb = sound:FindFirstChild("ZeroReverb") :: ReverbSoundEffect?
if not reverb then reverb = Instance.new("ReverbSoundEffect") reverb.Name = "ZeroReverb" reverb.DecayTime = 1.4 reverb.Density = 0.35 reverb.Diffusion = 0.65 reverb.DryLevel = 0 reverb.WetLevel = -2 reverb.Enabled = false reverb.Parent = sound end
local eq = sound:FindFirstChild("ZeroBassEQ") :: EqualizerSoundEffect?
if not eq then eq = Instance.new("EqualizerSoundEffect") eq.Name = "ZeroBassEQ" eq.LowGain = 12 eq.MidGain = 2 eq.HighGain = -4 eq.Enabled = false eq.Parent = sound end
local comp = sound:FindFirstChild("ZeroCompressor") :: CompressorSoundEffect?
if not comp then comp = Instance.new("CompressorSoundEffect") comp.Name = "ZeroCompressor" comp.Attack = 0.01 comp.Release = 0.15 comp.Threshold = -22 comp.Ratio = 6 comp.GainMakeup = 3 comp.Enabled = false comp.Parent = sound end

local preloadSound = SoundService:FindFirstChild("ZeroPreloadSound") :: Sound?
if not preloadSound then preloadSound = Instance.new("Sound") preloadSound.Name = "ZeroPreloadSound" preloadSound.Volume = 0 preloadSound.Looped = false preloadSound.Parent = SoundService end
local preloaded: {[string]: number} = {}
local PRELOAD_TTL = 10 * 60

local function preloadIdAsync(soundId: string)
	soundId = tostring(soundId or "")
	if soundId == "" then return end
	local now = os.clock()
	local last = preloaded[soundId]
	if last and (now - last) < PRELOAD_TTL then return end
	preloaded[soundId] = now
	task.spawn(function() pcall(function() preloadSound.SoundId = soundId ContentProvider:PreloadAsync({ preloadSound }) end) end)
end

local function cleanupPreloadCache()
	local now = os.clock()
	for id, t in pairs(preloaded) do if (now - t) > PRELOAD_TTL then preloaded[id] = nil end end
end

type Track = { id: string, title: string }
local queue: {Track} = {}
local library: {Track} = {}
local libraryIndex = 1
local speedValue = 1.0
local pitchValue = 1.0
local reverbOn = false
local bassOn = false
local paused = false
local pausedSoundId = ""
local pausedTitle = ""
local pausedTimePos = 0.0
local playNonce = 0

local VOTE_NEED_FIXED = 6
local votedThisTrack: {[number]: boolean} = {}
local voteCount = 0
local voteNeed = VOTE_NEED_FIXED

local function resetVotesForNewTrack() votedThisTrack = {} voteCount = 0 voteNeed = VOTE_NEED_FIXED end
Players.PlayerAdded:Connect(function() voteNeed = VOTE_NEED_FIXED end)
Players.PlayerRemoving:Connect(function(plr) if votedThisTrack[plr.UserId] then votedThisTrack[plr.UserId] = nil voteCount = math.max(0, voteCount - 1) end voteNeed = VOTE_NEED_FIXED end)

local function mergedPlaybackSpeed(): number return math.clamp(((speedValue + pitchValue) * 0.5), 0.5, 2.0) end
local function applyFX() local pb = mergedPlaybackSpeed() sound.PlaybackSpeed = pb reverb.Enabled = reverbOn eq.Enabled = bassOn comp.Enabled = bassOn end
local function safeTitle(t: Track?): string if not t then return "UNTITLED" end local s = t.title if typeof(s) ~= "string" or s == "" then return "UNTITLED" end return s end
local function normalizeSoundId(id: string): string local trimmed = string.gsub(id, "%s+", "") if trimmed == "" then return "" end if string.match(trimmed, "^%d+$") then return "rbxassetid://" .. trimmed end return trimmed end

local function stateSnapshot()
	return { soundId = sound.SoundId, title = sound:GetAttribute("NowTitle") or "", isPlaying = sound.IsPlaying, timePos = sound.TimePosition, timeLen = sound.TimeLength, volume = sound.Volume, speed = speedValue, pitch = pitchValue, playbackSpeed = mergedPlaybackSpeed(), reverb = reverbOn, bass = bassOn, queue = queue, libraryCount = #library, libraryIndex = libraryIndex, serverNow = os.clock(), paused = paused, voteCount = voteCount, voteNeed = voteNeed }
end
local function broadcastState() RE_State:FireAllClients(stateSnapshot()) end

local function getLibraryTracks(): {Track}
	local ok, tracks = pcall(function() return PlaylistModule.GetTracks() end)
	if not ok or typeof(tracks) ~= "table" then return {} end
	local out: {Track} = {}
	for _, t in ipairs(tracks :: {any}) do
		if typeof(t) == "table" then
			local idAny = (t :: any).id
			local titleAny = (t :: any).title
			if typeof(idAny) == "string" then
				local nid = normalizeSoundId(idAny)
				if nid ~= "" then table.insert(out, { id = nid, title = safeTitle({ id = nid, title = (typeof(titleAny) == "string" and titleAny or "") }) }) end
			end
		end
	end
	return out
end

local function reloadLibrary() library = getLibraryTracks() if libraryIndex < 1 then libraryIndex = 1 end if libraryIndex > #library then libraryIndex = 1 end end
local function getNextLibraryTrack(): Track? if #library <= 0 then return nil end if libraryIndex < 1 or libraryIndex > #library then libraryIndex = 1 end local t = library[libraryIndex] libraryIndex += 1 if libraryIndex > #library then libraryIndex = 1 end return t end

local function playTrack(t: Track) end
local function playNext() end
local function startWatchdog(nonce: number)
	task.delay(3, function()
		if playNonce ~= nonce or paused then return end
		local len = sound.TimeLength or 0
		local pos = sound.TimePosition or 0
		if (not sound.IsPlaying) or (len <= 0 and pos <= 0.05) then task.defer(function() if playNonce ~= nonce then return end paused = false playNonce += 1 playNext() end) end
	end)
end
local function attachLengthMonitors(nonce: number)
	local loadedConn, lenConn
	local function cleanup() if loadedConn then loadedConn:Disconnect() loadedConn = nil end if lenConn then lenConn:Disconnect() lenConn = nil end end
	loadedConn = sound.Loaded:Connect(function() if playNonce ~= nonce then cleanup() return end broadcastState() end)
	lenConn = sound:GetPropertyChangedSignal("TimeLength"):Connect(function() if playNonce ~= nonce then cleanup() return end if (sound.TimeLength or 0) > 0 then broadcastState() end end)
	task.delay(10, cleanup)
end

function playTrack(t: Track)
	paused = false pausedSoundId = "" pausedTitle = "" pausedTimePos = 0
	playNonce += 1
	local nonce = playNonce
	cleanupPreloadCache()
	sound:Stop()
	sound.SoundId = normalizeSoundId(t.id)
	sound.TimePosition = 0
	sound:SetAttribute("NowTitle", safeTitle(t))
	applyFX()
	pcall(function() ContentProvider:PreloadAsync({ sound }) end)
	resetVotesForNewTrack()
	broadcastState()
	attachLengthMonitors(nonce)
	pcall(function() sound:Play() end)
	broadcastState()
	startWatchdog(nonce)
end

function playNext()
	paused = false
	if #queue > 0 then playTrack(table.remove(queue, 1)) return end
	if #library <= 0 then reloadLibrary() end
	local nextLib = getNextLibraryTrack()
	if nextLib then playTrack(nextLib) return end
	broadcastState()
end

local function ensureAutoplay()
	if paused or sound.IsPlaying then return end
	if sound.SoundId ~= "" then
		local ok = pcall(function() sound:Play() end)
		if ok then playNonce += 1 attachLengthMonitors(playNonce) startWatchdog(playNonce) broadcastState() return end
	end
	playNext()
end
sound.Ended:Connect(function() if paused then broadcastState() return end playNext() end)

local function enqueueTrack(t: any, priority: boolean?)
	if typeof(t) ~= "table" then return end
	local idAny = (t :: any).id
	if typeof(idAny) ~= "string" then return end
	local nid = normalizeSoundId(idAny)
	if nid == "" then return end
	local title = safeTitle({ id = nid, title = (typeof((t :: any).title) == "string" and (t :: any).title or "") })
	preloadIdAsync(nid)
	local track: Track = { id = nid, title = title }
	if priority == true then table.insert(queue, 1, track) else table.insert(queue, track) end
	broadcastState()
	if (not sound.IsPlaying) and (not paused) then ensureAutoplay() end
end

local function reorderQueue(fromIndex: number, toIndex: number)
	if #queue <= 1 then return end
	fromIndex = math.clamp(fromIndex, 1, #queue)
	toIndex = math.clamp(toIndex, 1, #queue)
	if fromIndex == toIndex then return end
	local moved = table.remove(queue, fromIndex)
	table.insert(queue, toIndex, moved)
	broadcastState()
end

local function doSkip() paused = false pausedSoundId = "" pausedTitle = "" pausedTimePos = 0 playNonce += 1 sound:Stop() playNext() end
local function voteSkip(plr: Player) if paused or votedThisTrack[plr.UserId] then broadcastState() return end votedThisTrack[plr.UserId] = true voteCount += 1 broadcastState() if voteCount >= VOTE_NEED_FIXED then doSkip() end end

RF_GetState.OnServerInvoke = function(_plr: Player) return stateSnapshot() end
Players.PlayerAdded:Connect(function(plr) RE_State:FireClient(plr, stateSnapshot()) end)

RE_Command.OnServerEvent:Connect(function(plr: Player, payload: any)
	if typeof(payload) ~= "table" then return end
	local action = (payload :: any).action
	local data = (payload :: any).data

	if action == "RequestState" then RE_State:FireClient(plr, stateSnapshot()) return end
	if action == "VoteSkip" then voteSkip(plr) return end
	if action == "Enqueue" then
		local priority = false
		if isAdmin(plr) and typeof(data) == "table" then priority = ((data :: any).priority == true) end
		enqueueTrack(data, priority)
		return
	end

	if not isAdmin(plr) then return end
	if action == "ReorderQueue" then if typeof(data) == "table" then reorderQueue(tonumber((data :: any).from) or 1, tonumber((data :: any).to) or 1) end return end
	if action == "RemoveQueueIndex" then local idx = tonumber(data) or 0 if idx >= 1 and idx <= #queue then table.remove(queue, idx) broadcastState() end return end
	if action == "PlayQueueIndex" then local idx = tonumber(data) or 0 if idx >= 1 and idx <= #queue then playTrack(table.remove(queue, idx)) end return end
	if action == "PlayPause" then
		if sound.IsPlaying then paused = true pausedSoundId = sound.SoundId pausedTitle = (sound:GetAttribute("NowTitle") or "") :: string pausedTimePos = sound.TimePosition playNonce += 1 sound:Stop() broadcastState() return end
		if paused and pausedSoundId ~= "" then
			paused = false playNonce += 1 local nonce = playNonce sound:Stop() sound.SoundId = pausedSoundId sound.TimePosition = math.max(0, pausedTimePos) sound:SetAttribute("NowTitle", pausedTitle) applyFX() pcall(function() ContentProvider:PreloadAsync({ sound }) end)
			pcall(function() sound:Play() end) broadcastState() attachLengthMonitors(nonce) startWatchdog(nonce) return
		end
		paused = false ensureAutoplay() broadcastState() return
	end
	if action == "Skip" then doSkip() return end
	if action == "Seek" then local target = tonumber(data) or 0 local len = sound.TimeLength or 0 if len > 0 then sound.TimePosition = math.clamp(target, 0, len) if paused then pausedTimePos = sound.TimePosition end broadcastState() end return end
	if action == "SetVolume" then local v = tonumber(data) or sound.Volume sound.Volume = math.clamp(v, 0, 1) broadcastState() return end
	if action == "SetSpeed" then local v = tonumber(data) or speedValue speedValue = math.clamp(v, 0.5, 2.0) applyFX() broadcastState() return end
	if action == "SetPitch" then local v = tonumber(data) or pitchValue pitchValue = math.clamp(v, 0.5, 2.0) applyFX() broadcastState() return end
	if action == "ToggleReverb" then reverbOn = not reverbOn applyFX() broadcastState() return end
	if action == "ToggleBass" then bassOn = not bassOn applyFX() broadcastState() return end
	if action == "ReloadLibrary" then reloadLibrary() broadcastState() ensureAutoplay() return end
	if action == "ForceAutoplay" then paused = false ensureAutoplay() return end
end)

applyFX()
reloadLibrary()
resetVotesForNewTrack()
broadcastState()
ensureAutoplay()
