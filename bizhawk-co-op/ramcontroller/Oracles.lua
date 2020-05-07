local addrs = nil
local seasons_addrs = {
	multiPlayerNumber = 0x3f25,
	wGameState = 0xc2ee,
	wNetCountIn = 0xc6a1,
	wNetTreasureIn = 0xcbfb,
	wNetPlayerOut = 0xcbfd,
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

-- figure out whether we're playing seasons or ages (or neither)
local game_code = string_from_byterange(memory.readbyterange(0x134, 9))
if game_code == "ZELDA DIN" then
	addrs = seasons_addrs
elseif game_code == "ZELDA NAY" then
	addrs = ages_addrs
else
	error("unknown ROM")
end

local this_player = memory.readbyte(addrs.multiPlayerNumber)
local items_in = {}
local oracles_ram = {} -- exports RAM controller interface

-- Gets a message to send to the other player of new changes
-- Returns the message as a dictionary object
-- Returns false if no message is to be sent
function oracles_ram.getMessage()
	-- return false if the player isn't in-game
	if memory.readbyte(addrs.wGameState) ~= 2 then return false end

	-- give the most recent item to the game every frame until counts match
	local count_in = memory.readbyte(addrs.wNetCountIn)
	if #items_in > count_in then
		local item = items_in[count_in + 1]
		memory.writebyte(addrs.wNetTreasureIn, item[2])
		memory.writebyte(addrs.wNetTreasureIn + 1, item[3])
	end

	local message = {}

	-- buffered treasure out? send and clear it
	local out_player = memory.readbyte(addrs.wNetPlayerOut)
	if out_player ~= 0 then
		local out_id = memory.readbyte(addrs.wNetTreasureOut)
		local out_param = memory.readbyte(addrs.wNetTreasureOut + 1)
		message["m"] = {out_player, out_id, out_param}
		memory.writebyte(addrs.wNetPlayerOut, 0)
		memory.writebyte(addrs.wNetTreasureOut, 0)
		memory.writebyte(addrs.wNetTreasureOut + 1, 0)
		console.log(string.format("sent item to P%d: {%02x, %02x}",
			out_player, out_id, out_param))
	end

	-- return the message if it has content
	for _, __ in pairs(message) do return message end
	return false
end

-- Process a message from another player and update RAM
function oracles_ram.processMessage(their_user, message)
	if message["m"] ~= nil then
		if message["m"][1] == this_player then
			table.insert(items_in, message["m"])
			console.log(string.format("received item from P%d: {%02x, %02x}",
				message["m"][1], message["m"][2], message["m"][3]))
		end
	end
end

oracles_ram.itemcount = 1 -- dummy value, must be a positive integer

return oracles_ram
