math.randomseed(os.time())
dofile('data/lib/lib.lua')

NOT_MOVEABLE_ACTION = 8000
PARTY_PROTECTION = 1 -- Set to 0 to disable.
ADVANCED_SECURE_MODE = 1 -- Set to 0 to disable.

STORAGEVALUE_PROMOTION = 30018

ropeSpots = {384, 418, 8278, 8592, 13189, 14435, 14436, 15635, 19518, 26019, 24621, 24622, 24623, 24624}

--[ Impact Analyser ]--
updateInterval = 2 --every 2 seconds
-- Healing
healingImpact = {} -- global table to insert data
-- Damage
damageImpact = {} -- global table to insert data

-- New prey => preyTimeLeft
nextPreyTime = {}

-- From here down are the functions of TFS

function getDistanceBetween(firstPosition, secondPosition)
	local xDif = math.abs(firstPosition.x - secondPosition.x)
	local yDif = math.abs(firstPosition.y - secondPosition.y)
	local posDif = math.max(xDif, yDif)
	if firstPosition.z ~= secondPosition.z then
		posDif = posDif + 15
	end
	return posDif
end

function getFormattedWorldTime()
	local worldTime = getWorldTime()
	local hours = math.floor(worldTime / 60)

	local minutes = worldTime % 60
	if minutes < 10 then
		minutes = '0' .. minutes
	end
	return hours .. ':' .. minutes
end

function getLootRandom()
	return math.random(0, MAX_LOOTCHANCE) / configManager.getNumber(configKeys.RATE_LOOT)
end

table.contains = function(array, value)
	for _, targetColumn in pairs(array) do
		if targetColumn == value then
			return true
		end
	end
	return false
end

string.split = function(str, sep)
	local res = {}
	for v in str:gmatch("([^" .. sep .. "]+)") do
		res[#res + 1] = v
	end
	return res
end

string.splitTrimmed = function(str, sep)
	local res = {}
	for v in str:gmatch("([^" .. sep .. "]+)") do
		res[#res + 1] = v:trim()
	end
	return res
end

string.trim = function(str)
	return str:match'^()%s*$' and '' or str:match'^%s*(.*%S)'
end

-- From here down are the custom functions

local start = os.time()
local linecount = 0
debug.sethook(function(event, line)
    linecount = linecount + 1
    if os.mtime() - start >= 1 then
        if linecount >= 30000 then
            print(string.format("possible infinite loop in file %s near line %s", debug.getinfo(2).source, line))
            debug.sethook()
        end
        linecount = 0
        start = os.time()
    end
end, "l")

function doCreatureSayWithRadius(cid, text, type, radiusx, radiusy, position)
	if not position then
		position = Creature(cid):getPosition()
	end

	local spectators, spectator = Game.getSpectators(position, false, true, radiusx, radiusx, radiusy, radiusy)
	for i = 1, #spectators do
		spectator = spectators[i]
		spectator:say(text, type, false, spectator, position)
	end
end

function getBlessingsCost(level)
	if level <= 30 then
		return 2000
	elseif level >= 120 then
		return 20000
	else
		return (level - 20) * 200
	end
end

function getPvpBlessingCost(level)
	if level <= 30 then
		return 2000
	elseif level >= 270 then
		return 50000
	else
		return (level - 20) * 200
	end
end

function isInRange(pos, fromPos, toPos)
	return pos.x >= fromPos.x and pos.y >= fromPos.y and pos.z >= fromPos.z and pos.x <= toPos.x and pos.y <= toPos.y and pos.z <= toPos.z
end

function isNumber(str)
	return tonumber(str) ~= nil
end

function Creature.getMonster(self)
return self:isMonster() and self or nil
end

-- Stamina
if nextUseStaminaTime == nil then
    nextUseStaminaTime = {}
end

if nextUseStaminaPrey == nil then
    nextUseStaminaPrey = {}
end

if nextUseXpStamina == nil then
    nextUseXpStamina = {}
end

if lastItemImbuing == nil then
    lastItemImbuing = {}
end

if nextDelayPreyReroll == nil then
	nextDelayPreyReroll = {}
end

--Boss entry
if not bosssPlayers then
	bosssPlayers = {
		addPlayers = function (self, cid)
			local player = Player(cid)
			if not player then return false end
			if not self.players then
				self.players = {}
			end
			self.players[player:getId()] = 1
		end,
		removePlayer = function (self, cid)
			local player = Player(cid)
			if not player then  return false end
			if not self.players then return false end
			self.players[player:getId()] = nil
		end,
		getPlayersCount = function (self)
			if not self.players then return 0 end
			local c = 0
			for _ in pairs(self.players) do  c = c + 1 end
			return c
		end
	}
end

-- function for the reload talkaction
local logFormat = "[%s] %s %s"

function logCommand(player, words, param)
	local file = io.open("data/logs/" .. player:getName() .. " commands.log", "a")
	if not file then
		return
	end

	io.output(file)
	io.write(logFormat:format(os.date("%d/%m/%Y %H:%M"), words, param):trim() .. "\n")
	io.close(file)
end

-- MARRY
PROPOSED_STATUS = 1
MARRIED_STATUS = 2
PROPACCEPT_STATUS = 3
LOOK_MARRIAGE_DESCR = TRUE
ITEM_WEDDING_RING = 2121
ITEM_ENGRAVED_WEDDING_RING = 10502

function getPlayerSpouse(id)
    local resultQuery = db.storeQuery("SELECT `marriage_spouse` FROM `players` WHERE `id` = " .. db.escapeString(id))
    if resultQuery ~= false then
        local ret = result.getDataInt(resultQuery, "marriage_spouse")
        result.free(resultQuery)
        return ret
    end
    return -1
end

function setPlayerSpouse(id, val)
    db.query("UPDATE `players` SET `marriage_spouse` = " .. val .. " WHERE `id` = " .. id)
end

function getPlayerMarriageStatus(id)
    local resultQuery = db.storeQuery("SELECT `marriage_status` FROM `players` WHERE `id` = " .. db.escapeString(id))
    if resultQuery ~= false then
        local ret = result.getDataInt(resultQuery, "marriage_status")
        result.free(resultQuery)
        return ret
    end
    return -1
end

function setPlayerMarriageStatus(id, val)
    db.query("UPDATE `players` SET `marriage_status` = " .. val .. " WHERE `id` = " .. id)
end

function Player:getMarriageDescription(thing)
    local descr = ""
    if getPlayerMarriageStatus(thing:getGuid()) == MARRIED_STATUS then
        playerSpouse = getPlayerSpouse(thing:getGuid())
        if self == thing then
            descr = descr .. " You are "
        elseif thing:getSex() == PLAYERSEX_FEMALE then
            descr = descr .. " She is "
        else
            descr = descr .. " He is "
        end
        descr = descr .. "married to " .. getPlayerNameById(playerSpouse) .. '.'
    end
    return descr
end

-- The following 2 functions can be used for delayed shouted text
function say(param)
selfSay(text)
doCreatureSay(param.cid, param.text, 1)
end

function delayedSay(text, delay)
local delay = delay or 0
local cid = getNpcCid()
addEvent(say, delay, {cid = cid, text = text})
end

