local direction = {
	north = 0,
	east  = 1,
	south = 2,
	west  = 3,
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
}


