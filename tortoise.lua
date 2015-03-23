--[[ DataDumper.lua
Copyright (c) 2007 Olivetti-Engineering SA

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

local dumplua_closure = [[
local closures = {}
local function closure(t) 
  closures[#closures+1] = t
  t[1] = assert(loadstring(t[1]))
  return t[1]
end

for _,t in pairs(closures) do
  for i = 2,#t do 
    debug.setupvalue(t[1], i-1, t[i]) 
  end 
end
]]

local lua_reserved_keywords = {
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 
  'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 
  'return', 'then', 'true', 'until', 'while' }

local function keys(t)
  local res = {}
  local oktypes = { stringstring = true, numbernumber = true }
  local function cmpfct(a,b)
    if oktypes[type(a)..type(b)] then
      return a < b
    else
      return type(a) < type(b)
    end
  end
  for k in pairs(t) do
    res[#res+1] = k
  end
  table.sort(res, cmpfct)
  return res
end

local c_functions = {}
for _,lib in pairs{'_G', 'string', 'table', 'math', 
    'io', 'os', 'coroutine', 'package', 'debug'} do
  local t = _G[lib] or {}
  lib = lib .. "."
  if lib == "_G." then lib = "" end
  for k,v in pairs(t) do
    if type(v) == 'function' and not pcall(string.dump, v) then
      c_functions[v] = lib..k
    end
  end
end

function DataDumper(value, varname, fastmode, ident)
  local defined, dumplua = {}
  -- Local variables for speed optimization
  local string_format, type, string_dump, string_rep = 
        string.format, type, string.dump, string.rep
  local tostring, pairs, table_concat = 
        tostring, pairs, table.concat
  local keycache, strvalcache, out, closure_cnt = {}, {}, {}, 0
  setmetatable(strvalcache, {__index = function(t,value)
    local res = string_format('%q', value)
    t[value] = res
    return res
  end})
  local fcts = {
    string = function(value) return strvalcache[value] end,
    number = function(value) return value end,
    boolean = function(value) return tostring(value) end,
    ['nil'] = function(value) return 'nil' end,
    ['function'] = function(value) 
      return string_format("loadstring(%q)", string_dump(value)) 
    end,
    userdata = function() error("Cannot dump userdata") end,
    thread = function() error("Cannot dump threads") end,
  }
  local function test_defined(value, path)
    if defined[value] then
      if path:match("^getmetatable.*%)$") then
        out[#out+1] = string_format("s%s, %s)\n", path:sub(2,-2), defined[value])
      else
        out[#out+1] = path .. " = " .. defined[value] .. "\n"
      end
      return true
    end
    defined[value] = path
  end
  local function make_key(t, key)
    local s
    if type(key) == 'string' and key:match('^[_%a][_%w]*$') then
      s = key .. "="
    else
      s = "[" .. dumplua(key, 0) .. "]="
    end
    t[key] = s
    return s
  end
  for _,k in ipairs(lua_reserved_keywords) do
    keycache[k] = '["'..k..'"] = '
  end
  if fastmode then 
    fcts.table = function (value)
      -- Table value
      local numidx = 1
      out[#out+1] = "{"
      for key,val in pairs(value) do
        if key == numidx then
          numidx = numidx + 1
        else
          out[#out+1] = keycache[key]
        end
        local str = dumplua(val)
        out[#out+1] = str..","
      end
      if string.sub(out[#out], -1) == "," then
        out[#out] = string.sub(out[#out], 1, -2);
      end
      out[#out+1] = "}"
      return "" 
    end
  else 
    fcts.table = function (value, ident, path)
      if test_defined(value, path) then return "nil" end
      -- Table value
      local sep, str, numidx, totallen = " ", {}, 1, 0
      local meta, metastr = (debug or getfenv()).getmetatable(value)
      if meta then
        ident = ident + 1
        metastr = dumplua(meta, ident, "getmetatable("..path..")")
        totallen = totallen + #metastr + 16
      end
      for _,key in pairs(keys(value)) do
        local val = value[key]
        local s = ""
        local subpath = path
        if key == numidx then
          subpath = subpath .. "[" .. numidx .. "]"
          numidx = numidx + 1
        else
          s = keycache[key]
          if not s:match "^%[" then subpath = subpath .. "." end
          subpath = subpath .. s:gsub("%s*=%s*$","")
        end
        s = s .. dumplua(val, ident+1, subpath)
        str[#str+1] = s
        totallen = totallen + #s + 2
      end
      if totallen > 80 then
        sep = "\n" .. string_rep("  ", ident+1)
      end
      str = "{"..sep..table_concat(str, ","..sep).." "..sep:sub(1,-3).."}" 
      if meta then
        sep = sep:sub(1,-3)
        return "setmetatable("..sep..str..","..sep..metastr..sep:sub(1,-3)..")"
      end
      return str
    end
    fcts['function'] = function (value, ident, path)
      if test_defined(value, path) then return "nil" end
      if c_functions[value] then
        return c_functions[value]
      elseif debug == nil or debug.getupvalue(value, 1) == nil then
        return string_format("loadstring(%q)", string_dump(value))
      end
      closure_cnt = closure_cnt + 1
      local res = {string.dump(value)}
      for i = 1,math.huge do
        local name, v = debug.getupvalue(value,i)
        if name == nil then break end
        res[i+1] = v
      end
      return "closure " .. dumplua(res, ident, "closures["..closure_cnt.."]")
    end
  end
  function dumplua(value, ident, path)
    return fcts[type(value)](value, ident, path)
  end
  if varname == nil then
    varname = "return "
  elseif varname:match("^[%a_][%w_]*$") then
    varname = varname .. " = "
  end
  if fastmode then
    setmetatable(keycache, {__index = make_key })
    out[1] = varname
    table.insert(out,dumplua(value, 0))
    return table.concat(out)
  else
    setmetatable(keycache, {__index = make_key })
    local items = {}
    for i=1,10 do items[i] = '' end
    items[3] = dumplua(value, ident or 0, "t")
    if closure_cnt > 0 then
      items[1], items[6] = dumplua_closure:match("(.*\n)\n(.*)")
      out[#out+1] = ""
    end
    if #out > 0 then
      items[2], items[4] = "local t = ", "\n"
      items[5] = table.concat(out)
      items[7] = varname .. "t"
    else
      items[2] = varname
    end
    return table.concat(items)
  end
end

function math.sign(x)
   if x < 0 then
     return -1
   elseif x > 0 then
     return 1
   else
     return 0
   end
end

local direction = {
	north = 0,
	east  = 1,
	south = 2,
	west  = 3,
	up    = 4,
	down  = 5,
}

local relativeDirection = {
	forward = 0,
	backward  = 1,
}

local position = {}
position = {
	x = 0,
	y = 0,
	z = 0,
   
	orientation = direction.south,
   
	turnLeft = function()
		if not turtle.turnLeft() then
			return false
		end
		
		if position.orientation == direction.north then
			position.orientation = direction.west
		else
			position.orientation = position.orientation - 1
		end
		return true
	end,
	
	turnRight = function()
		if not turtle.turnRight() then
			return false
		end
		
		if position.orientation == direction.west then
			position.orientation = direction.north
		else
			position.orientation = position.orientation + 1
		end
		return true
	end,
	
	turnBack = function()
		if not position.turnRight() then
			return false
		end
		if not position.turnRight() then
			return false
		end
		return true
	end,
	
	faceLeft = function(faceDirection)
		while position.orientation ~= faceDirection do
			if not position.turnLeft() then
				return false
			end
		end
		return true
	end,
	
	faceRight = function(faceDirection)
		while position.orientation ~= faceDirection do
			if not position.turnRight() then
				return false
			end
		end
		return true
	end,
	
	face = function(faceDirection)
		if (position.orientation == direction.north and faceDirection == direction.west) or 
				position.orientation - 1 == faceDirection then
				
			if position.faceLeft(faceDirection) then
				return true
			end
			return position.faceRight(faceDirection)
		end
		
		if position.faceRight(faceDirection) then
			return true
		end
		return position.faceLeft(faceDirection)			
	end,
	
	moveUpdates = 
	{
		[direction.north] = { axis = 'z', change =  1 },
		[direction.south] = { axis = 'z', change = -1 },
		[direction.east ] = { axis = 'x', change =  1 },
		[direction.west ] = { axis = 'x', change = -1 },		
	},
	
	moveUpdate = function(dir)
		update = position.moveUpdates[position.orientation]
		if dir == relativeDirection.forward then
			change = update.change
		else
			change = - update.change
		end
		position[update.axis] = position[update.axis] + change
	end,
	
	moveForward = function()		
		if turtle.detect() then
			if not turtle.dig() then
				return false
			end
		end
		if not turtle.forward() then
			return false
		end
		position.moveUpdate(relativeDirection.forward)
		return true
	end,

	moveBackward = function()
		if not turtle.back() then
			return false
		end
		position.moveUpdate(relativeDirection.backward)
		return true
	end,	
	
	moveUp = function()
		if turtle.detectUp() then
			if not turtle.digUp() then
				return false
			end
		end
		if not turtle.up() then
			return false
		end	
		position.y = position.y + 1
		return true
	end,	
	
	moveDown = function()
		if turtle.detectDown() then
			if not turtle.digDown() then
				return false
			end
		end
		if not turtle.down() then
			return false
		end
		position.y = position.y - 1
		return true
	end,
	
	move = function(dir)
		if dir == direction.up then
			return position.moveUp() 
		end
		if dir == direction.down then
			return position.moveDown()
		end
		if not position.face(dir) then
			return false
		end
		return position.moveForward() 
	end,
	
	moveTo = function(coord, action)
		while coord.y < position.y do
			position.moveDown()
			if action then
				action()
			end
		end
		while coord.y > position.y do
			position.moveUp()
			if action then
				action()
			end
		end

		for dir, value in pairs(position.moveUpdates) do
			while math.sign(coord[value.axis] - position[value.axis]) == value.change do
				position.move(dir)
				if action then
					action()
				end
			end
		end
	end,
	
	onTop = function(coord)
		return position.x == coord.x and position.y - 1 == coord.y and position.z == coord.z
	end,
	
	under = function(coord)
		return position.x == coord.x and position.y + 1 == coord.y and position.z == coord.z
	end,
	
}

local action = {}
action = {

	inspect = function(dir)
		if dir == direction.up then
			return turtle.inspectUp() 
		end
		if dir == direction.down then
			return turtle.inspectDown()
		end
		if not position.face(dir) then
			return false
		end
		return turtle.inspect() 
	end,

	inspectBlock = function(dir)
		local success, data = action.inspect(dir)
		if not success then
			return "n/a"
		end
		return data.name
	end,
	
}
	
local builder = {}
builder = {
 
	buildBlockUnder = function(pattern)
		if pattern then
			material = pattern.selectMaterial(position.x, position.y, position.z)
			if not turtle.select(material) then
				return false
			end
		end

		if turtle.detectDown() then
			if turtle.compareDown() then
				return true
			end
			if not turtle.digDown() then
				return false
			end
		end
		
		return turtle.placeDown()
	end,
	
	buildLineUnder = function(a, pattern)
		for i = 1, a - 1 do
			if not builder.buildBlockUnder(pattern) then
				return false
			end
			if not position.moveForward() then
				return false
			end
		end
		return builder.buildBlockUnder(pattern)
	end,
	
	buildBorderUnder = function(a, b, pattern)
		if not builder.buildLineUnder(a, pattern) then
			return false
		end
		if not position.turnRight() then
			return false
		end
		if not builder.buildLineUnder(b, pattern) then
			return false
		end
		if not position.turnRight() then
			return false
		end
		if not builder.buildLineUnder(a, pattern) then
			return false
		end
		if not position.turnRight() then
			return false
		end
		if not builder.buildLineUnder(b - 1, pattern) then
			return false
		end
		return true
	end,
	
	buildFeildUnder = function(a, b, pattern)
		while a > 0 and b > 0 do
			if not builder.buildBorderUnder(a, b, pattern) then
				return false
			end
			a = a - 2
			b = b - 2
			if not position.turnRight() then
				return false
			end
			if not position.moveForward() then
				return false
			end
		end
	end,
	
	buildWall = function(width, height, pattern)
		for h = 1, height do 
			if not position.moveUp() then
				return false
			end
			if not builder.buildLineUnder(width, pattern) then
				return false
			end
			if not position.turnBack() then
				return false
			end
		end
		return true
	end,
}

chessPattern = {}
chessPattern = {
	material1 = 2,
	material2 = 3,
	
	selectMaterial = function(x, y, z)
		local hash = (math.abs(x) + math.abs(y) + math.abs(z)) % 2
		if hash == 0 then
			return chessPattern.material1
		end
		return chessPattern.material2
	end,
}

circlePattern = {}
circlePattern = {
	material1 = 2,
	material2 = 3,
	
	selectMaterial = function(x, y, z)
		local hash = math.floor(math.sqrt(x * x + z * z) + .5) % 2
		if hash == 0 then
			return circlePattern.material1
		end
		return circlePattern.material2
	end,
}

scavenger = {}
scavenger = {	
	noted = {},
	
	addNote = function(material, metadata, x, y, z)
		if not scavenger.noted[material] then
			scavenger.noted[material] = {}
		end
		
		if not metadata then
			metadata = 0
		end
		
		if not scavenger.noted[material][metadata] then
			scavenger.noted[material][metadata] = {}
		end
		
		local pos = { x = x, y = y, z = z }
		table.insert(scavenger.noted[material][metadata], pos)
	end,
	
	inspectForward = function()
		local success, data = turtle.inspect()
		if success then
			local update = position.moveUpdates[position.orientation]
			local x = position.x
			if update.axis == "x" then
				x = x + update.change
			end
			local z = position.z
			if update.axis == "z" then
				z = z + update.change
			end
			scavenger.addNote(data.name, data.metadata, x, position.y, z)
		end
	end,
	
	inspectUp = function()
		local success, data = turtle.inspectUp()
		if success then
			scavenger.addNote(data.name, data.metadata, position.x, position.y + 1, position.z)
		end
	end,
	
	inspectDown = function()
		local success, data = turtle.inspectDown()
		if success then
			scavenger.addNote(data.name, data.metadata, position.x, position.y - 1, position.z)
		end
	end,
	
	inspectFast = function()
		scavenger.inspectDown()
		scavenger.inspectUp()
		scavenger.inspectForward()
	end,

	inspectAround = function()
		for i = 1, 3 do
			scavenger.inspectForward()
			position.turnRight()
		end
		scavenger.inspectForward()
	end,
	
	inspectAll = function()
		scavenger.inspectDown()
		scavenger.inspectUp()
		scavenger.inspectAround()
	end,
	
	sqrtDistance = function(pos1, pos2)
		return (pos1.x - pos2.x)^2 + (pos1.y - pos2.y)^2 + (pos1.z - pos2.z)^2 
	end,
	
	findClosestNoted = function(materials)
		
		local closestDistance = 10000
		local closest = nil
	
		for i, material in ipairs(materials) do
			local types = scavenger.noted[material]
			if types then
				for j, coords in pairs(types) do
					for k, coord in ipairs(coords) do
						distsq = scavenger.sqrtDistance(position, coord)
						
						if distsq < closestDistance then
							closestDistance = distsq
							closest = coord
						end
					end
				end
			end
		end
		
		return closest
	end,
	
	removeCoord = function(item)
		removes = {}
		for material, types in pairs(scavenger.noted) do
			for j, coords in pairs(types) do
				for k, coord in ipairs(coords) do
					if item.x == coord.x and item.y == coord.y and item.z == coord.z then
						table.insert(removes, {material = material, j = j, k = k})
					end
				end
			end
		end
		
		for i, item in ipairs(removes) do
			table.remove(scavenger.noted[item.material][item.j], item.k)
		end
	end,
	
	fromWhereToEat = function(coord)
		local eatPositions = {
			{x = coord.x + 1, y = coord.y, z = coord.z},
			{x = coord.x - 1, y = coord.y, z = coord.z},
			{x = coord.x, y = coord.y + 1, z = coord.z},
			{x = coord.x, y = coord.y - 1, z = coord.z},
			{x = coord.x, y = coord.y, z = coord.z + 1},
			{x = coord.x, y = coord.y, z = coord.z - 1},
		}
		
		local closestDistance = 10000
		local closest = nil
		
		for i, coord in ipairs(eatPositions) do
			distsq = scavenger.sqrtDistance(position, coord)
			
			if distsq < closestDistance then
				closestDistance = distsq
				closest = coord
			end
		end
		
		return closest
	end,
	
	eat = function(coord)
		if position.onTop(coord) then
			turtle.digDown()
		elseif position.under(coord) then
			turtle.digUp()
		else
			for dir, value in pairs(position.moveUpdates) do
				if math.sign(coord[value.axis] - position[value.axis]) == value.change then
					position.face(dir)
				end
			end
		end
		turtle.dig()
		scavenger.removeCoord(coord)
	end,
	
	eatTree = function()
		scavenger.inspectAll()
		
		for i = 1, 100 do
			scavenger.inspectAll()
			item = scavenger.findClosestNoted({"minecraft:log", "minecraft:leaves"})
			if item then
				print (item.x, ", ", item.y, ", ", item.z)
				position.moveTo(scavenger.fromWhereToEat(item), scavenger.inspectFast)
				scavenger.eat(item)
				position.moveTo(item)
			end
		end
	end,
	
	
}

turtle.select(1)
turtle.refuel(1)

scavenger.eatTree()
