-- json is global is it is accessed by a number of modules
json = require "dkjson"

-- local modules
local level = require "Level"
local camera = require "Camera"

--test light shader code
local lightshadercode = [[

extern vec3 light;
extern Image lightmask;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // get the pixel colour
    vec4 texcolor = Texel(texture, texture_coords);

    //calculate ambient
    vec4 ambient = texcolor * vec4(0.1,0.1,0.1,1.0);

    // determines distance of pixel to light position
    number Distance = distance(screen_coords, light.xy);
    
    // make it gradient 
    number Mult = 1.0 - (Distance / light.z);

    // set the color clamped to ambient
    texcolor = texcolor * color * Mult;

    // get the marking colour
    vec4 maskcolor = Texel(lightmask, texture_coords);

    // return the colour multiplied by the mask
    return clamp(texcolor * maskcolor, ambient, vec4(1.0, 1.0, 1.0, 1.0));
}
]]

function clamp(v, min, max)
    -- clamps v between min and max
    if v < min then
        return min
    elseif v > max then
        return max
    else
        return v
    end
end

function love.load()    
    -- physics test
    love.physics.setMeter(30)
    w = love.physics.newWorld(0,0,true)  -- no gravity really because it is a top down view

    love.graphics.setBackgroundColor(0,0,0,255)

    -- load the level data
    levelconfig = json.opendecode("Assets/Levels/LevelConfig.json")

    -- main load for the game!!
--    l = Level.new(levelconfig.Size[1].Width,levelconfig.Size[1].Height,nil, levelconfig)
    l = Level.new(1, nil, levelconfig)

    -- create a camera
    c = camera.new(0, 0, levelconfig.Size[l.Difficulty].Width * levelconfig.CellSize, levelconfig.Size[l.Difficulty].Width * levelconfig.CellSize)

    DiffuseCanvas = love.graphics.newCanvas(c.size.vw,c.size.vh)
    LightMaskCanvas = love.graphics.newCanvas(c.size.vw,c.size.vh)

    lightshader = love.graphics.newShader(lightshadercode)

    --print(c.scale.x .. "," .. c.scale.y)

    playerlight = {}
    playerlight = {x=0,y=0,z=512}

    -- temp player info
    p = {}
    p.x = (l.StartCell.x - 1) * levelconfig.CellSize + levelconfig.CellSize/2
    p.y = (l.StartCell.y - 1) * levelconfig.CellSize + levelconfig.CellSize/2
    p.sp = 40000
    p.sz = 16 * c.scale.x

    -- test objects
    objects = {}
    objects.player = {}
    objects.player.body = love.physics.newBody(w, p.x, p.y, "dynamic")
    objects.player.shape = love.physics.newCircleShape(p.sz)
    objects.player.fixture = love.physics.newFixture(objects.player.body, objects.player.shape)
    objects.player.fixture:setGroupIndex(1)

    objects.clutter = {}

    drawclutter = true

    for i=1,l.Width do
        for j=1,l.Height do
            local o = {}
            if not(i == l.StartCell.x and j == l.StartCell.y) then
                o.body = love.physics.newBody(w, (i-1) * l.CellSize + l.CellSize/2, (j-1) * l.CellSize + l.CellSize/2, "dynamic")
                o.shape = love.physics.newPolygonShape(0,0,16,0,16,16,0,16)
                o.fixture = love.physics.newFixture(o.body, o.shape)
                o.fixture:setGroupIndex(2)

                table.insert(objects.clutter, o)
            end
        end
    end

    keypath = {}

    --love.graphics.setDefaultFilter("nearest","nearest")
end

function levelraycallback(fixture, x, y, xn, yn, fraction)
	local hit = {}
	hit.fixture = fixture
	hit.x, hit.y = x, y
	hit.xn, hit.yn = xn, yn
	hit.fraction = fraction

    -- only add if the collision is with a level wall...
    if hit.fixture:getGroupIndex() == 1 then
        --print("ray ".. l.rayindex .. ": added")
        table.insert(l.rays[l.rayindex].hits, hit)
    end
    -- end the ray... after first hit
    return 1
end

function love.update(dt)

    -- physics test!!!
    w:update(dt)
    --reset in case we aren't acutally moving
    objects.player.body:setLinearVelocity(0,0)

    -- reset clutter
    for i=1, #objects.clutter do
        objects.clutter[i].body:setLinearVelocity(0,0)
        objects.clutter[i].body:setAngularVelocity(0,0)        
    end

    -- main update for the game!!
    local x = 0
    local y = 0
    if love.keyboard.isDown("left") then
        x = -500
        --p.x = p.x - p.sp * dt
    end
    if love.keyboard.isDown("right") then 
        x = 500
        --p.x = p.x + p.sp * dt
    end
    if love.keyboard.isDown("up") then 
        y = -500
        --p.y = p.y - p.sp * dt 
    end
    if love.keyboard.isDown("down") then 
        y = 500
        --p.y = p.y + p.sp * dt 
    end

    objects.player.body:setLinearVelocity(x,y)

    -- adjust the position of the camera to be centred on the player
    local sz = {}
    sz.w, sz.h, sz.vw, sz.vh = c:getCamera()

    c:setPosition(objects.player.body:getX() - sz.vw/2, objects.player.body:getY() - sz.vh/2)

    --update the shader variables
    local cx, cy = c:getPosition()
    playerlight.x = (objects.player.body:getX() - cx) * c.scale.x
    playerlight.y = (objects.player.body:getY() - cy) * c.scale.y
    lightshader:send("light", {playerlight.x, playerlight.y, playerlight.z})
    

    -- temp ray stuff
    --sendrays()
    -- testing the cell visibility
    local px = objects.player.body:getX()
    local py = objects.player.body:getY()
    local wx, wy, ww, wh = c:getWorld();
    --l:update(px, py, ww, wh, dt)
    local cx, cy, cx2, cy2 = c:getVisible()
    l:buildvisible2(px, py, cx, cy, cx2, cy2)

end

function love.keyreleased(key)
    if (key == "escape") then
        love.event.quit()
    end

    if (key == "g") then
        w:destroy()
        w = love.physics.newWorld(0,0,true)  -- no gravity really because it is a top down view
        l = nil
        l = Level.new(1, nil, levelconfig)
        c = camera.new(0, 0, levelconfig.Size[l.Difficulty].Width * levelconfig.CellSize, levelconfig.Size[l.Difficulty].Width * levelconfig.CellSize)
        p.x = (l.StartCell.x - 1) * l.CellSize + l.CellSize/2
        p.y = (l.StartCell.y - 1) * l.CellSize + l.CellSize/2
        objects = {}
        objects.player = {}
        objects.player.body = love.physics.newBody(w, p.x, p.y, "dynamic")
        objects.player.shape = love.physics.newCircleShape(p.sz)
        objects.player.fixture = love.physics.newFixture(objects.player.body, objects.player.shape)
    end

    if (key == "b") then
        c:setBounds(not(c:getBounds()))
    end

    if (key == "t") then
        l.drawtiles = not(l.drawtiles)
    end

    if (key == "l") then
        l.drawlines = not(l.drawlines)
    end

    if (key == "v") then
        l.testforvisible = not(l.testforvisible)
    end

    if (key == "p") then
        l.drawpaths = not(l.drawpaths)
    end

    if (key == "d") then
        l.drawdoors = not(l.drawdoors)
    end

    if (key == "k") then
        l.drawkeys = not(l.drawkeys)
    end

    if (key == "c") then
        drawclutter = not(drawclutter)
    end
    
    if (key == "q") then
        keypath = l:getClosestKey(l:getCellFromWorldPosition(objects.player.body:getX(), objects.player.body:getY()))
    end

end


function love.draw()
    -- main draw for the game!!
    love.graphics.push()
    -- setup the resolution independant drawing
    love.graphics.scale(c.scale.x, c.scale.y)
    -- move the screen to the camera
    love.graphics.translate(-c.pos.x, -c.pos.y)

    love.graphics.setCanvas(DiffuseCanvas)
    love.graphics.clear(0,0,0,255)
    
    -- draw stuff

    l:draw()


    love.graphics.setColor(255,0,255,255)
    love.graphics.circle("fill",objects.player.body:getX(), objects.player.body:getY(), p.sz)

    if drawclutter then
        love.graphics.setColor(255,255,0,255)
        for i=1, #objects.clutter do
            local x, y = l:getCellFromWorldPosition(objects.clutter[i].body:getX(), objects.clutter[i].body:getY())
            if (l.testforvisible and l.Cells[x][y].Visible) or not(l.testforvisible) then
                love.graphics.polygon("fill",objects.clutter[i].body:getWorldPoints(objects.clutter[i].shape:getPoints()))
            end
        end
    end

    -- draw debing info
    l:debugdraw()

    if l.drawkeys and #keypath > 0 then
        love.graphics.setColor(255,255,0,255)
        for i=1, #keypath do
            if (l.testforvisible and l.Cells[keypath[i].x][keypath[i].y].Visible) or not(l.testforvisible) then
                love.graphics.circle("line", (keypath[i].x-1) * l.CellSize + l.CellSize / 2, (keypath[i].y-1) * l.CellSize + l.CellSize / 2, 32)
            end
        end
    end

    -- ray colour (red)
--[[
    for i=1, #l.rays do
        love.graphics.setColor(255,0,0,255)
        love.graphics.line(l.rays[i].x1, l.rays[i].y1, l.rays[i].x2, l.rays[i].y2)
        love.graphics.setColor(255,255,0,255)
        for j=1, #l.rays[i].hits do
            local r = 1
            if j == 1 then
                r = 2
            end
            love.graphics.circle("fill", l.rays[i].hits[j].x, l.rays[i].hits[j].y, r)
        end
    end
]]
    -- draw the light mask
    love.graphics.setCanvas(LightMaskCanvas)
    love.graphics.clear(0,0,0,255)
    love.graphics.setColor(0,0,0,255)
    love.graphics.rectangle("fill",0,0,c.size.vw, c.size.vh)
    love.graphics.setColor(255,255,255,255)
    for i=1, #l.lightmask do
        love.graphics.polygon("fill", l.lightmask[i])
    end

    -- unset the canvas
    love.graphics.setCanvas()

    -- reset the colour
    love.graphics.setColor(255,255,255,255)

    love.graphics.pop()


    -- setup the resolution independant drawing
    --love.graphics.push()
    --love.graphics.scale(c.scale.x, c.scale.y)

    -- send the lightmask to the shader
    lightshader:send("lightmask", LightMaskCanvas)
    -- send the lightmask to the shader
    love.graphics.setShader(lightshader)
    -- draw the diffuse canvas
    love.graphics.draw(DiffuseCanvas, 0, 0)
    -- unset the shaders
    love.graphics.setShader()

    --love.graphics.pop()

    love.graphics.setColor(255,255,0,255)
    love.graphics.print("Current FPS: " .. love.timer.getFPS(), 50, 50)    

end
