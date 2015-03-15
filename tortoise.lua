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
		if turtle.turnLeft() then
			if position.orientation == direction.north then
				position.orientation = direction.west
			else
				position.orientation = position.orientation - 1
			end
		end
	end,
	
	turnRight = function()
		if turtle.turnRight() then
			if position.orientation == direction.west then
				position.orientation = direction.north
			else
				position.orientation = position.orientation + 1
			end
		end
	end,
	
	face = function(faceDirection)
		if (position.orientation == direction.north and faceDirection == direction.west) or position.orientation - 1 == faceDirection then
			position.turnLeft()
			print "turnLeft"
		else 
			while position.orientation ~= faceDirection do
				print "turnRight"
				position.turnRight()
			end
		end
	end,
}



