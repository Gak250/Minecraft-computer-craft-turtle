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

turtle.select(1)
turtle.refuel(1)

turtle.select(2)
builder.buildWall(5, 3)
