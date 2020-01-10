-- GBA Shaman King - Master of Spirits, TASing script
-- Ram watch, Yoh and enemy information

local max_entities= 23
local color= {
	opaque= {
		[0]=0xFF00FF00, -- Green
		0xFFFFFF00, -- Yellow
		0xFFFF0000, -- Red
		0xFFBA8E7D, -- Brown
		0xFF0000FF, -- Blue
		0xFF665046  -- Dark brown
	};
	trans= {
		[0]=0x7700FF00, -- Green
		0x77FFFF00, -- Yellow
		0x77FF0000, -- Red
		0x77BA8E7D, -- Brown
		0x770000FF, -- Blue
		0x44665046  -- Dark brown
	}
}

client.SetGameExtraPadding(0,0,40,0)
local Queue = {head = 0, tail = 0, full = false}

-- Circular buffer implementation in Lua
function Queue:new (o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Queue:empty ()
	return (not self.full) and self.head == self.tail
end

function Queue:_advance ()
	-- If the buffer is full, the start point "rotates",
	-- so we advance both head and tail
	if self.full then
		self.tail = (self.tail + 1) % self.size 
	end
	
	self.head = (self.head + 1) % self.size
	-- Has the queue become full?
	self.full = self.head == self.tail
end

function Queue:enqueue (value)
	-- Will overwrite values when the buffer is full.
	self[self.head] = value
	self:_advance()
end

-- Returns the first element in the queue (the oldest).
function Queue:get ()
	if self:empty() then error("get: queue is empty") end
	return self[self.tail]
end

-- Returns the last element in the queue (the newest).
-- If the queue is full, head == tail,
-- so we must go backwards to get the last element of the queue.
function Queue:get_head ()
	if self:empty() then error("get_head: queue is empty") end
	head = (self.head - 1) % self.size
	return self[head]
end

-- Returns first element and advances the tail pointer.
-- Useful for getting all values of the list in constant space.
-- At the end, tail returns to its original value.
function Queue:get_advance (list)
	value = self[self.tail]
	self.tail = (self.tail + 1) % self.size
	return value
end
	
-- General RAM watch, and value display on screen
local function DisplayHud(x,y)

	-- Furyoku
	local furyoku     = memory.read_u16_le(0x22BE, "IWRAM")
	gui.pixelText (x+0,y+0, string.format("%4d", furyoku), 0xFFFFFFFF, color.trans[4])

	-- Furyoku refill
	local frefill     = memory.read_u16_le(0x22CA, "IWRAM")
	if refill == 0 then
	gui.pixelText(x+0,y+7, string.format("%4d", frefill), 0xFFFFFFFF, color.trans[0]) 
	else
	gui.pixelText(x+0,y+7, string.format("%4d", frefill), 0xFFFFFFFF, color.trans[2])
	end

-- In-game time (current segment)
	local igtframeseg = memory.read_u32_le(0x36DD, "IWRAM")
	gui.pixelText(x+180,y+0, string.format("%8d", igtframeseg), 0xFFFFFFFF, color.trans[0])
-- In-game time (current area)
	local igtframearea= memory.read_u32_le(0x3629, "IWRAM")
	gui.pixelText(x+180,y+7, string.format("%8d", igtframearea), 0xFFFFFFFF, color.trans[3])    
-- In-game time (global)
	local igtframe    = memory.read_u32_le(0x1DD8, "IWRAM")
	gui.pixelText(x+180,y+14, string.format("%8d", igtframe), 0xFFFFFFFF, color.trans[5])
	-- Global timer
	local globalframe = memory.read_u32_le(0x1DD4, "IWRAM")
	gui.pixelText(x+180,y+21, string.format("%8d", globalframe))

	-- Speed
	local xspeed      = memory.read_s32_le(0x3650, "IWRAM")
	local yspeed      = memory.read_s32_le(0x3654, "IWRAM")
	gui.pixelText(x+215,y, string.format("%6d", xspeed))
	gui.pixelText(x+215,y+7, string.format("%6d", yspeed))


	-- Ground/air? Displays G on ground, A on air
	local groair      = memory.read_u8(    0x3614, "IWRAM")
	if groair == 1 then
		gui.pixelText(x+215,y+14, "G", 0xFFFFFFFF, color.trans[4])
	else
		gui.pixelText(x+215,y+14, "A", 0xFFFFFFFF, color.trans[1])
	end

	-- Buffered down input timer to backdash
	local downbuffer  = memory.read_u8(    0x25C3, "IWRAM")
	if downbuffer >= 1 then
		gui.pixelText(x+219,y+14, "V" .. string.format("%4d", downbuffer), 0xFFFFFFFF, color.trans[0])
	else
		gui.pixelText(x+219,y+14, string.format("%5d", downbuffer), 0xFFFFFFFF, color.trans[5])
	end

	-- X and Y position
	local xposition   = memory.read_u32_le(0x3648, "IWRAM")
	local yposition   = memory.read_u32_le(0x364C, "IWRAM")
	gui.pixelText(x+203,y+35, string.format("%9d", xposition), 0xFFFFFFFF, color.trans[5])
	gui.pixelText(x+203,y+42, string.format("%9d", yposition), 0xFFFFFFFF, color.trans[5])

end

-- A visual separator for the sidebar
--#############################################################################
local function Separator(x,y, length)
--#############################################################################

	gui.drawLine(x+14,y, x+length,y)

	for i=0,6 do
		gui.drawPixel(x+i*2,y)
	end

end

-- General movie information
--#############################################################################
local function MovieInfo(x,y)
--#############################################################################

	local frame= emu.framecount()
	if emu.islagged() == true then
		gui.pixelText(x,y, frame, 0xFFFFFFFF, color.opaque[2])
	else
		gui.pixelText(x,y, frame)
	end

	local lagcount= emu.lagcount()
	gui.pixelText(x,y+7, lagcount, color.opaque[2])

	-- Shoutouts to Masterjun
	local buttons = {["Up"]="^", ["Down"]="v", ["Left"]="<", ["Right"]=">", ["Select"]="s", ["Start"]="S", ["A"]="A", ["B"]="B", ["L"]="L", ["R"]="R"}
	local s = ""
	for k,v in pairs(movie.getinput(frame-1)) do
		if v == true then
			s= s..buttons[k]
		end
	end
	
	gui.pixelText(x,y+14 ,s)

end

-- Displays information about Yoh's animations on the sidebar
--#############################################################################
local function GetYohState(x,y)
--#############################################################################

	local stateText= {
		[0]=  { "Standing","",""                   } ,
			{ "Walking","",""                    } ,
			{ "Neutral","",""                    } ,
			{ "Crouching","",""                  } ,
			{ "Crouched","",""                   } ,
			{ "Standing","up",""                 } ,
			{ "Pre-","jumping",""                } ,
			{ "Jumping","",""                    } ,
			{ "Falling,","initial",""            } ,
			{ "Falling","",""                    } ,
			{ "Landing","",""                    } ,
			{ "Back","dashing",""                } ,
			{ "Entering","door",""               } ,
			{ "Exiting","door",""                } ,
			{ "Taking","damage",""               } ,
			{ "Taking","damage,","crouched"      } ,
			{ "Taking","damage,","air"           } ,
			{ "Knockback","damage",""            } ,
			{ "Knockback","upwards",""           } ,
			{ "Knockback","hitting","ground"     } ,
			{ "Knockback","fall",""              } ,
			{ "Knockback","ground",""            } ,
			{ "Knockback","getting up",""        } ,
			{ "Electro-","cuted",""              } ,
			{ "Electro-","cuted","2"             } ,
			{ "Taking","damage?",""              } ,
			{ "Taking","damage?",""              } ,
			{ "1st slash,","wooden,","ground"    } ,
			{ "2nd slash,","wooden,","ground"    } ,
			{ "3rd slash,","wooden,","ground"    } ,
			{ "1st slash,","light,","ground"     } ,
			{ "2nd slash,","light,","ground"     } ,
			{ "3rd slash,","light,","ground"     } ,
			{ "1st slash,","antiquity,","ground" } ,
			{ "2nd slash,","antiquity,","ground" } ,
			{ "3rd slash,","antiquity,","ground" } ,
			{ "Crouch","slash,","wooden"         } ,
			{ "Crouch","slash,","light"          } ,
			{ "Crouch","slash,","antiquity"      } ,
			{ "1st slash,","wooden,","air"       } ,
			{ "2nd slash,","wooden,","air"       } ,
			{ "3rd slash,","wooden,","air"       } ,
			{ "1st slash,","light,","air"        } ,
			{ "2nd slash,","light,","air"        } ,
			{ "3rd slash,","light,","air"        } ,
			{ "1st slash,","antiquity,","air"    } ,
			{ "2nd slash,","antiquity,","air"    } ,
			{ "3rd slash,","antiquity,","air"    } ,
			{ "Halo","Bump,","ground"            } ,
			{ "Halo","Bump,","air"               } ,
			{ "Nipopo","Punch", "ground"         } ,
			{ "Nipopo","Punch", "air"            } ,
			{ "Daodondo","",""                   } ,
			{ "Gussy", "Kenji", "ground"         } ,
			{ "Gussy", "Kenji", "air"            } ,
			{ "Jaguar","Swipe",""                } ,
			{ "Footballer","",""                 } ,
			{ "Footballer,","sparks",""          } ,
			{ "Big", "Thumb",""                  } ,
			{ "Big", "Thumb,","smoke"            } ,
			{ "Big", "Thumb,","Tokageroh"        } ,
			{ "Celestial","Slash,","ground"      } ,
			{ "Celestial","Slash,","air"         } ,
			{ "Celestial","Slash,","blade"       } ,
		[82]= { "Shikigami,","ground",""           } ,
		[83]= { "Shikigami,","air",""              } ,
		[259]={ "Totem","Attack,","summoning"      } ,
		[260]={ "Totem","Attack,","charge"         } ,
		[261]={ "Totem","Attack,","sparks"         } ,
		[262]={ "Totem","Attack,","fire"           } ,
		[263]={ "Totem","Attack,","withdraw"       } ,
	}

		local state      = memory.read_u16_le(0x35E0, "IWRAM")
		local duration   = memory.read_u8(    0x35E9, "IWRAM")
		local statetimer = memory.read_u8(    0x35DF, "IWRAM")
		local delay      = memory.read_u16_le(0x362D, "IWRAM")

		local t          = stateText[state]
		if t then
				gui.pixelText(x,y, state .. ":" .. statetimer)
				gui.pixelText(x,y+ 7,t[1],color.opaque[1])
				gui.pixelText(x,y+14,t[2],color.opaque[1])
				gui.pixelText(x,y+21,t[3],color.opaque[1])
				gui.pixelText(x,y+28, duration .. ":" .. delay, 0xFFFFFFFF, color.trans[2])
	else
				gui.pixelText(x,y, state .. ":" .. statetimer)
				gui.pixelText(x,y+ 7,"NULL!!!",0xFFC0C0C0)
				gui.pixelText(x,y+28, duration .. ":" .. delay, 0xFFFFFFFF, color.trans[2])
	end

end

-- Information about our inventory (mediums, souls)
--#############################################################################
local function InventoryInfo(x,y)
--#############################################################################

	local leafcount = memory.read_u8(0x2358, "IWRAM")
	local rockcount = memory.read_u8(0x2359, "IWRAM")
	local dollcount = memory.read_u8(0x235A, "IWRAM")

	gui.pixelText(x,y, leafcount, color.opaque[0])
	gui.pixelText(x+11,y, rockcount, color.opaque[3])
	gui.pixelText(x+22,y, dollcount, color.opaque[5])

end

-- SK2 rng re-implementation in Lua
local function RngLua(value)
	local high = (value * 0x41C6) % 0x10000
	local low  = (value * 0x4E6D) % 0x100000000
	return ((low + high * 0x10000) % 0x100000000) + 0x3039
end

-- Hash table with two fields:
-- first color of background, then color of text
local fancy_color_table =
	{
		{0xAAFF0000, 0xFFFFFFFF}, --red
		{0xAAFF7F00, 0xFF000000}, --orange
		{0xAAFFFF00, 0xFF000000}, --yellow
		{0xAA00FF00, 0xFF000000}, --green
		{0xAA0000FF, 0xFFFFFFFF}, --blue
		{0xAA4B0082, 0xFFFFFFFF}, --darkpurple
		{0xAA9400D3, 0xFFFFFFFF}  --purple
	}

local function fancy_colors(value)
	return fancy_color_table[ (value % 6) + 1 ]
end

-- Displays a table of the next X rng values, based on current 
-- This function will be called each frame, so globals persist between frames
pastRNG = memory.read_u32_le(0x1DC8, "IWRAM") -- Seed with the initial value from RAM
taken = 0

-- Populate a queue with new RNG values
local function populate(queue, n)
	-- At the start, the queue contains a single value: the current RNG.
	-- That is the 'previous' element, memoized.
	local previous = queue:get()
	
	-- Fill the rest of the queue:
	-- slot 0 is already filled, so slots 1 to n.
	for i=1,n do
		-- Compute the current element with the help of the previous one.
		local current = RngLua(previous)
		queue:enqueue(current) 
		-- Before we loop, the current element is the previous one.
		previous = current
	end
end

--[[ Our update pattern:
1. Look at the element in the tail of the queue.
2. Add an element, updating both the head and tail, since the queue is always full.
3. Look again and repeat.

The queue is always full this way, so we can deal with this in a very fast way. 
It will always loop around.
]]--
local function consume(queue)
	oldest = queue:get() -- Get the oldest value (if zero consumes, the current RNG, if not, the RNG advanced N times)
	newest = queue:get_head() -- and the newest value (RNG advanced n times.)
	-- Advance the queue:
	-- overwrite the oldest value with the advanced new value.
	queue:enqueue(RngLua(newest))
	return oldest -- Relevant RNG.
end

local function RngPredict(ctx, x, y)
	local RNG = memory.read_u32_le(0x1DC8, "IWRAM")
	local queue = ctx.queue
	local size = queue.size
	
	-- If the queue is empty, populate it
	if queue:empty() then
		queue:enqueue(RNG)
		populate(queue, (size - 1)) -- We already queued one element, the current RNG
	end
	
	-- Has the RNG advanced?
	if ctx.pastRNG ~= RNG then
		local found = false
		local taken = 0
		
		-- Take values from the queue, until we find the one matching the new RNG 
		-- in this frame.
		while not found and taken < 5 do
			compared_RNG = consume(queue)
			taken = taken + 1
			if compared_RNG == RNG then -- Have we found the RNG yet?
				found = true
			end
		end
		
		ctx.taken = taken
		-- Update pastRNG
		ctx.pastRNG = RNG
	end
	
	-- Display on-screen how much the RNG has advanced
	local taken = ctx.taken
	if taken ~= 0 then
		gui.pixelText(x+33, y, taken, 0xFFFFFFFF, color.trans[6])
		gui.pixelText(x+33, y + taken*7 , "!", 0xFFFFFFFF, color.trans[2])
	end
	
	-- Show the queue of RNG values
	for i=0, (size - 1) do
		value = queue:get_advance() -- Loop through each of the RNG values
		gui.pixelText(x,
					y+i*7,
					string.format("%8x", value), 
					fancy_colors(value)[2], -- Returns fancy rainbow colors
					fancy_colors(value)[1]) -- More rainbows!
	end

end

-- Draws hitboxes
-- Object size: B4 (180)
--#############################################################################
local function DrawHitbox(x,y, offset, id)
--#############################################################################

	local cameraX = memory.read_s32_le(0x1E50, "IWRAM")/256
	local cameraY = memory.read_s32_le(0x1E54, "IWRAM")/256

-- Figure out appropriate pixel values (somewhat hacky)
	local X1, X2= memory.read_s32_le(0x3664 + offset, "IWRAM")/256, memory.read_s32_le(0x3668 + offset, "IWRAM")/256
	local Y1, Y2= memory.read_s32_le(0x366C + offset, "IWRAM")/256, memory.read_s32_le(0x3670 + offset, "IWRAM")/256

	local pixelX1, pixelX2 = X1-cameraX+120, X2-cameraX+120
	local pixelY1, pixelY2 = cameraY-Y1+71, cameraY-Y2+71

	local invicibility = memory.read_u16_le(0x3630 + offset, "IWRAM")
	-- Add invicibility counter if invicible
	if invicibility >= 1 then
				gui.drawBox (x+pixelX1, y+pixelY1, x+pixelX2, y+pixelY2, color.opaque[1], color.trans[5])
				gui.pixelText (x+pixelX1, y+pixelY1, invicibility, 0xFFFFFFFF, color.trans[1])
	else
				gui.drawBox (x+pixelX1, y+pixelY1, x+pixelX2, y+pixelY2, color.opaque[5], color.trans[5])
	end

	-- Facing direction
	local fdirection = memory.read_u8(0x3634 + offset, "IWRAM")
	if fdirection    == 1 then
				gui.pixelText (x+pixelX1, y+pixelY2 - 7, "<")
	elseif fdirection == 0 then
				gui.pixelText (x+pixelX1, y+pixelY2 - 7, ">")
	else
				gui.pixelText (x+pixelX1, y+pixelY2 - 7, "?")
	end

	-- Raw damage output
	local rawdmg = memory.read_u8(0x3638 + offset, "IWRAM")
		gui.pixelText (x+pixelX1 + 8, y+pixelY2 - 7, rawdmg, 0xFFFFFFFF, color.trans[2])

	-- Health
	local health= memory.read_u16_le(0x3636 + offset, "IWRAM")
		gui.pixelText(x+pixelX1 + 10,y+pixelY1 + 1, health, color.opaque[1])

	-- State, animation and timer information
	if id ~= 0 then
				local state      = memory.read_u16_le(0x35E0 + offset, "IWRAM")
				local statetimer = memory.read_u8(0x35DF + offset, "IWRAM")
				local duration   = memory.read_u8(0x35E9 + offset, "IWRAM")
				local delay      = memory.read_u16_le(0x362D + offset, "IWRAM")
				gui.pixelText (x+pixelX1 + 24, y+pixelY2, state .. ":" .. statetimer)
				gui.pixelText (x+pixelX1 + 24, y+pixelY2 - 7, duration .. ":" .. delay, 0xFFFFFFFF, color.trans[2])
	end

end

local function CamHack()
	local cameraX = memory.read_s32_le(0x1E50, "IWRAM")
	local X1, X2= memory.read_s32_le(0x3664, "IWRAM")/256, 
			memory.read_s32_le(0x3668, "IWRAM")/256
	local x = x1+x2/2
	memory.write_s32_le(0x1E50, x)
end

local ctx = {}
ctx.size = 18
ctx.queue = Queue:new{size=ctx.size}
ctx.pastRNG = 0
ctx.taken = 0

-- When we load a state, we will not find a RNG value
-- So emptying the queue and loading it with the new RNG value from the loaded
-- state is needed
-- We also need to make sure 
local function resetQueue() 
	print('callback: queue reset!')
	ctx.queue = Queue:new{size=ctx.size}
	ctx.pastRNG = memory.read_u32_le(0x1DC8, "IWRAM")
	taken = 0
end
event.onloadstate(resetQueue, "empty queue")

while true do

	DisplayHud(0,0)
	RngPredict(ctx, 241,74,10)
	MovieInfo(241,0)
	Separator(241,22, 38)
	GetYohState(241,24)
	Separator(241,61, 38)
	InventoryInfo(241,63)

	for i=0,max_entities do
		if memory.read_u16_le(0x3636 + i*180, "IWRAM") ~= 0 then
			DrawHitbox(0,8, 0 + i*180, i) -- 0xB4
		end
	end

	emu.frameadvance()
end
