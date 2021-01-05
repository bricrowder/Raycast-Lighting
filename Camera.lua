Camera = {}
Camera.__index = Camera

-- Clamps v between min and max
local function clamp(v, min, max)
    if v < min then
        return min
    elseif v > max then
        return max
    else
        return v
    end
end

function Camera.new(x, y, w, h)
    -- Create the camera object
    local c = {}
    setmetatable(c, Camera)

    -- Assign the camera position
    c.pos = {}
    c.pos.x = 0
    c.pos.y = 0

    -- Set world bounds
    c.world = {}
    c.world.bounds = true
    c.world.x = x
    c.world.y = y
    c.world.w = w
    c.world.h = h

    -- Virtual resolution is the resolution that the game will be drawn at 
    local virtualresolution = {w=960,h=540}

    -- this is he actual resolution of the window
    local actualresolution = {w=love.graphics.getWidth(),h=love.graphics.getHeight()}

    -- assign the camera size - captures both the actual size (the size of the window) and the virtual size to be used with game calculations
    c.size = {}
    c.size.w = actualresolution.w
    c.size.h = actualresolution.h
    c.size.vw = virtualresolution.w
    c.size.vh = virtualresolution.h

    -- Scale of the drawing, makes the game resolution idependant
    c.scale = {}
    c.scale.x = c.size.w / c.size.vw
    c.scale.y = c.size.h / c.size.vh

    return c
end

-- Must be run BEFORE any resolution independant draw calls
-- Sets up the scale (for resolution) and translation (for camera position)
function Camera:set()
    love.graphics.push()
    -- setup the resolution independant drawing
    love.graphics.scale(self.scale.x, self.scale.y)
    -- move the screen to the camera
    love.graphics.translate(-self.pos.x, -self.pos.y)
end

-- Must be run AFTER any resolution independant draw calls
function Camera:unset()
    love.graphics.pop()
end

-- move the camera to x,y position
-- reads the bounds flag to see if the camera should be bound to the world or not
function Camera:setPosition(x, y)
    if self.world.bounds then
        -- uses the virtual resolution for the evaluation because the game uses
        self.pos.x = clamp(x, self.world.x, self.world.w-self.size.vw)
        self.pos.y = clamp(y, self.world.y, self.world.h-self.size.vh)
    else
        self.pos.x = x
        self.pos.y = y
    end    
end

-- get the camera x,y position
function Camera:getPosition()
    return self.pos.x, self.pos.y
end

-- set the world x, y, width, height
function Camera:setWorld(x,y,w,h)
    self.world.x = x
    self.world.y = y
    self.world.w = w
    self.world.h = h
end

-- return the world x, y, width, height
function Camera:getWorld()
    return self.world.x, self.world.y, self.world.w, self.world.h
end

-- set if the bounds are active or not
function Camera:setBounds(v)
    self.world.bounds = v
end

-- return the status of the bounds
function Camera:getBounds()
    return self.world.bounds
end

-- returns the size of the camera
function Camera:getCamera()
    return self.size.w, self.size.h, self.size.vw, self.size.vh
end

-- Returns the boundaries of what is visible in the camera
function Camera:getVisible()
    local x, y = self:getPosition()
    local w, h, vw, vh = self:getCamera()
    return x, y, x + vw, y + vh
end

return Camera
