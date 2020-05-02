local addrs = nil
local seasons_addrs = {
	wNetCountIn = 0xc6a1,
	wNetTreasureIn = 0xcbfc,
	wNetTreasureOut = 0xcbfe,
}
local ages_addrs = {
}

-- converts a return value from memory.readbyterange to a string
local function string_from_byterange(br)
	local t = {}
	for k, v in pairs(br) do
		t[tonumber(k) + 1] = tonumber(v)
	end
	return string.char(unpack(t))
end

-- returns relevant variables for sync. only works if player is in-game!
local function get_ram()
	return {
		hp = memory.readbyte(addrs.wLinkHealth),
		max_hp = memory.readbyte(addrs.wLinkMaxHealth),
	}
end

-- figure out whether we're playing seasons or ages (or neither)
local game_code = string_from_byterange(memory.readbyterange(0x134, 9))
if game_code == "ZELDA DIN" then
	addrs = seasons_addrs
elseif game_code == "ZELDA NAY" then
	addrs = ages_addrs
else
	error("unknown ROM")
end

local items_in = {}
local oracles_ram = {} -- exports RAM controller interface

-- debug text in case items_in starts with stuff
for _, v in ipairs(items_in) do
	console.log(string.format("starting item: {%02x, %02x}", v[1], v[2]))
end

-- Gets a message to send to the other player of new changes
-- Returns the message as a dictionary object
-- Returns false if no message is to be sent
function oracles_ram.getMessage()
	-- return false if the player isn't in-game
	local wGameState = memory.readbyte(0xc2ee)
	if wGameState ~= 2 then return false end

	-- give the most recent item to the game every frame until counts match
	local count_in = memory.readbyte(addrs.wNetCountIn)
	if #items_in > count_in then
		local item = items_in[count_in + 1]
		memory.writebyte(addrs.wNetTreasureIn, item[1])
		memory.writebyte(addrs.wNetTreasureIn + 1, item[2])
	end

	local message = {}

	-- buffered treasure out? send and clear it
	local out_id = memory.readbyte(addrs.wNetTreasureOut) 
	if out_id ~= 0 then
		local out_subid = memory.readbyte(addrs.wNetTreasureOut + 1)
		message["m"] = {out_id, out_subid}
		memory.writebyte(addrs.wNetTreasureOut, 0)
		memory.writebyte(addrs.wNetTreasureOut + 1, 0)
		console.log(string.format("sent item: {%02x, %02x}", out_id, out_subid))
	end

	-- return the message if it has content
	for _, __ in pairs(message) do return message end
	return false
end

-- Process a message from another player and update RAM
function oracles_ram.processMessage(their_user, message)
	if message["m"] ~= nil then
		table.insert(items_in, message["m"])
		console.log(string.format("received item: {%02x, %02x}", message["m"][1], message["m"][2]))
	end
end

oracles_ram.itemcount = 1

return oracles_ram
