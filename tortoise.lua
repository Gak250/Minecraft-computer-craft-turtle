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
		if not turtle.up() then
			return false
		end	
		position.y = position.y + 1
		return true
	end,	
	
	moveDown = function()
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
	
	buildBlockUnder = function()
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
	
	buildLineUnder = function(a)
		for i = 1, a - 1 do
			if not action.buildBlockUnder() then
				return false
			end
			if not position.moveForward() then
				return false
			end
		end
		return action.buildBlockUnder()
	end,
	
	buildBorderUnder = function(a, b)
		if not action.buildLineUnder(a) then
			return false
		end
		if not position.turnRight() then
			return false
		end
		if not action.buildLineUnder(b) then
			return false
		end
		if not position.turnRight() then
			return false
		end
		if not action.buildLineUnder(a) then
			return false
		end
		if not position.turnRight() then
			return false
		end
		if not action.buildLineUnder(b - 1) then
			return false
		end
		return true
	end,
	
	buildFeildUnder = function(a, b)
		while a > 0 and b > 0 do
			if not action.buildBorderUnder(a, b) then
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
}

turtle.select(1)
turtle.refuel(1)

turtle.select(2)

--print(action.buildLineUnder(2))
print(action.buildFeildUnder(8, 5))
