-- Init the level object (i.e. the table)
Level = {}
-- Make it searchable when calling functions... 
Level.__index = Level

-- Clears the washere array to be reused
local function ResetWasHere(self)
    -- Clear the array
    self.WasHere = {}

    -- reset the values to false
    for i=1, self.Width do
        self.WasHere[i] = {}
        for j=1, self.Height do
            self.WasHere[i][j] = false
        end
    end
end

-- returns the number of walls for a specific cell
local function CountWalls(self, xt, yt)
    local w = 0

    if self.Cells[xt][yt].North == true then w = w + 1 end
    if self.Cells[xt][yt].South == true then w = w + 1 end
    if self.Cells[xt][yt].East == true then w = w + 1 end
    if self.Cells[xt][yt].West == true then w = w + 1 end
    
    return w
end

-- Recursive Path Determination
local function SolvePath(self, xt, yt)

    -- 1. Check to see if we are at the end, there could be multiple ones to check...
    for i=1, #self.TempEnd do
        if xt == self.TempEnd[i].x and yt == self.TempEnd[i].y then 
            table.insert(self.TempPath, {x=xt, y=yt})
            return true 
        end
    end

    -- 2. Check to see if we have already been here
    if self.WasHere[xt][yt] == true then
        return false
    end

    -- 3. Set the washere flag
    self.WasHere[xt][yt] = true

    -- 4. Recursively check the different directions
    --check left
    if self.Cells[xt][yt].West == false and SolvePath(self, xt-1, yt) == true then
        table.insert(self.TempPath, {x=xt, y=yt})
        return true
    end
    --check right
    if self.Cells[xt][yt].East == false and SolvePath(self, xt+1, yt) == true then
        table.insert(self.TempPath, {x=xt, y=yt})
        return true
    end
    --check up
    if self.Cells[xt][yt].North == false and SolvePath(self, xt, yt-1) == true then
        table.insert(self.TempPath, {x=xt, y=yt})        
        return true
    end
    --check down
    if self.Cells[xt][yt].South == false and SolvePath(self, xt, yt+1) == true then
        table.insert(self.TempPath, {x=xt, y=yt})
        return true
    end

    -- 5. if all else fails, return false
    return false
end

local function SetDoors(self)
    -- Determine the number of doors
    local NumberOfDoors = math.floor(#self.TempPath * self.DoorRules.Rate)
    -- Door counter for while loop
    local DoorCount = 0
    -- Reset the error flag
    local ErrorCount = 0
    -- make sure we can actually put some doors in based on the length of the path, number of doors and spacing, if we cant then cancel
    if #self.TempPath - self.DoorRules.Spacing*2 < NumberOfDoors*(self.DoorRules.Spacing+1) then
        return
    end
    -- Randomly choose locations on the path and put a door
    while DoorCount < NumberOfDoors do
        -- select a random cell in the path
        local SelectedIndex = math.random(1,#self.TempPath)
        -- Duplicate selection flag, also used to see if we need to bother with next validity check
        local Duplicate = false
        -- Check rules for placement
        --  Do not put a door within the start and end of the path within the spacing rule
        if SelectedIndex < self.DoorRules.Spacing or SelectedIndex > #self.TempPath - self.DoorRules.Spacing then
            Duplicate = true
        end
        -- Check for spacing against other doors
        if Duplicate == false then
            for i=1, #self.Doors do
                local DoorIndex = 0
                -- find the current door's index on the path
                for j=1, #self.TempPath do
                    if self.Doors[i].x == self.TempPath[j].x and self.Doors[i].y == self.TempPath[j].y then
                        DoorIndex = j
                        break
                    end
                end
                -- Compare the distance between the two
                -- Calculate the difference and convert any negative values to positive
                -- Also use this check to count for errors, if we hit too many then just cancel... 
                local SpacingDifference = DoorIndex - SelectedIndex
                if SpacingDifference < 0 then 
                    SpacingDifference = SpacingDifference * -1 
                end
                if SpacingDifference <= self.DoorRules.Spacing then
                    ErrorCount = ErrorCount + 1
                    Duplicate = true
                    break
                end
            end
        end
        -- Check for duplicates
        if Duplicate == false then
            for i=1, #self.Doors do
                if self.TempPath[SelectedIndex].x == self.Doors[i].x and self.TempPath[SelectedIndex].y == self.Doors[i].y then
                    Duplicate = true
                    break
                end
            end
        end
        -- if it isn't a duplicate or on the first/last index then add the door
        if Duplicate == false then
            local door = {}
            -- Set the door cell coordinates
            door.x = self.TempPath[SelectedIndex].x
            door.y = self.TempPath[SelectedIndex].y
            -- determine where the door should be, it should always be on the way OUT of the cell
            if self.TempPath[SelectedIndex+1].x > self.TempPath[SelectedIndex].x then
                -- the next cell is to the right so it should be an EAST door
                door.wall = "E"
            elseif self.TempPath[SelectedIndex+1].x < self.TempPath[SelectedIndex].x then
                -- the next cell is to the left so it should be an WEST door
                door.wall = "W"
            elseif self.TempPath[SelectedIndex+1].y < self.TempPath[SelectedIndex].y then
                -- the next cell is to the above so it should be an NORTH door
                door.wall = "N"
            elseif self.TempPath[SelectedIndex+1].y > self.TempPath[SelectedIndex].y then
                -- the next cell is to the below so it should be an SOUTH door
                door.wall = "S"
            end
            -- Set the default locked value to false and the matching key index to 0
            door.locked = false
            door.keyindex = 0

            -- Add the door to the doors table
            table.insert(self.Doors, door)

            -- Add the door to the cell table
            self.Cells[door.x][door.y].Door = door

            -- Add the door to the path table
            self.TempPath[SelectedIndex].Door = door

            -- increment the door counter to count the door...
           DoorCount = DoorCount + 1 
        end

        -- Check the error count, if we have it it then break the while loop (by triggering its condition)
        if ErrorCount >= self.DoorRules.PlacementErrors then
            DoorCount = NumberOfDoors
        end
    end
end

local function addTileToCell(self, xt, yt, rt, Tile, it, jt)
    local t = {}
    t.x = xt
    t.y = yt
    t.rotation = rt
    t.Tag = Tile.Tag
    t.Type = Tile.Type
    t.Quad = Tile.Quad
    -- assign the door tile
    table.insert(self.TileTemp, t)
    -- loop through all the collision data associated with the tile
    if Tile.Collision and Tile.Collision.Points then
        for k=1,#Tile.Collision.Points do
            -- create a table
            local ctemp = {}
            -- create the body based on the positioning of the tile
            local x = (it-1) * self.CellSize + t.x
            local y = (jt-1) * self.CellSize + t.y
            ctemp.Body = love.physics.newBody(w, x, y, "static")
            -- create the shape based on the collision data
            ctemp.Shape = love.physics.newPolygonShape(Tile.Collision.Points[k])
            ctemp.Fixture = love.physics.newFixture(ctemp.Body, ctemp.Shape)
            ctemp.Fixture:setGroupIndex(1)
            -- rotate the body based on the tile rotation
            ctemp.Body:setAngle(t.rotation)
            table.insert(self.Cells[it][jt].Collision,ctemp)
        end  
    end
end

local function setTiles(self, ts)
    -- Define the paths to the image and json config
    local imgfile = "Assets/Levels/TilesetTexture_" .. ts .. ".png"
    local jsonfile = "Assets/Levels/TilesetConfig_" .. ts .. ".json"
    
    -- load the json data
    local jsondata = json.opendecode(jsonfile)

    -- open the image
    local idx = #self.Tileset + 1
    self.Tileset[idx] = love.graphics.newImage(imgfile)

    -- Init the quad table
    self.Tiles[idx] = {}
    self.Tiles[idx].Scale = self.CellSize / jsondata.CellSize    -- put the scale in for calculations later
    self.Tiles[idx].Floors = {}
    self.Tiles[idx].Walls = {}
    self.Tiles[idx].DoorFrames = {}    
    self.Tiles[idx].Decals = {}
    self.Tiles[idx].Exteriors = {}
    self.Tiles[idx].OutsideCorners = {}
    self.Tiles[idx].InsideCorners = {}
    
    -- load the image tile quads and meta info
    for i=1,#jsondata.Tile do
        local tag = jsondata.Tile[i].Tag
        local t = jsondata.Tile[i].Type
        local x = jsondata.Tile[i].x
        local y = jsondata.Tile[i].y
        local w = jsondata.Tile[i].w
        local h = jsondata.Tile[i].h
        local c = {}
        -- Find the associated collision info
        for j=1,#jsondata.Collision do
            if jsondata.Collision[j].Tag == tag then
                c = jsondata.Collision[j]
                --scale the collision data, only if you need to though
                --if not(self.Tiles[idx].Scale == 1)
                    for k=1, #c.Points do
                        for h=1, #c.Points[k] do
                            c.Points[k][h] = c.Points[k][h] * self.Tiles[idx].Scale
                        end
                    end
                --end
                break
            end
        end

        if t == "floor" then
            table.insert(self.Tiles[idx].Floors, {Tag=tag, Type=t, Quad=love.graphics.newQuad(x, y, w, h, self.Tileset[idx]:getDimensions()), Collision=nil})
        elseif t == "wall" then
            table.insert(self.Tiles[idx].Walls, {Tag=tag, Type=t, Quad=love.graphics.newQuad(x, y, w, h, self.Tileset[idx]:getDimensions()), Collision=c})
        elseif t == "door" then
            table.insert(self.Tiles[idx].DoorFrames, {Tag=tag, Type=t, Quad=love.graphics.newQuad(x, y, w, h, self.Tileset[idx]:getDimensions()), Collision=c})
        elseif t == "exterior" then
            table.insert(self.Tiles[idx].Exteriors, {Tag=tag, Type=t, Quad=love.graphics.newQuad(x, y, w, h, self.Tileset[idx]:getDimensions()), Collision=c})
        elseif t == "outsidecorner" then
            table.insert(self.Tiles[idx].OutsideCorners, {Tag=tag, Type=t, Quad=love.graphics.newQuad(x, y, w, h, self.Tileset[idx]:getDimensions()), Collision=c})
        elseif t == "insidecorner" then
            table.insert(self.Tiles[idx].InsideCorners, {Tag=tag, Type=t, Quad=love.graphics.newQuad(x, y, w, h, self.Tileset[idx]:getDimensions()), Collision=c})
        else    -- decals or whatever
            table.insert(self.Tiles[idx].Decals, {Tag=tag, Type=t, Quad=love.graphics.newQuad(x, y, w, h, self.Tileset[idx]:getDimensions()), Collision=c})
        end
        
    end
end

function Level.new(d, s, config)
    -- Lua object stuff
    local l = {}
    setmetatable(l, Level)

    -- Width and Height of the level
    l.Difficulty = d
    l.Width = config.Size[l.Difficulty].Width
    l.Height = config.Size[l.Difficulty].Height

    -- level seed
    l.Seed = s

    if type(l.Seed) == "string" then
        -- convert string to byte ascii values added together
        local tempseed = 0
        for i=1, string.len(l.Seed) do
            tempseed = tempseed + string.byte(l.Seed,i)
        end
        l.Seed = tempseed
    elseif type(l.Seed) == "number" then
        -- do nothing really, it is just a number, pass it directly
    else
        l.Seed = os.time()
    end    
    
    -- Table of Cells
    l.Cells = {}

    -- Start and End cell coordinates
    l.StartCell = {x=1, y=1}
    l.EndCell = {x=1, y=1}

    -- Critical path coordinate table
    l.CriticalPath = {}

    -- Deadend path coordinate table
    l.DeadEndPath = {}

    -- Door Data Table, holds stuff like the door rate on a path, the spacing rules
    l.DoorRules = config.DoorRules
    l.KeyRules = config.KeyRules

    -- Door Coordinate Table, will also include key colour (red, blue, green, nil)
    l.Doors = {}

    -- Key Coordinate Table
    l.Keys = {}

    -- Tileset table, holds the actual images
    l.Tileset = {}

    -- Tiles table holds the info on each tile in the tileset    
    l.Tiles = {}

    -- the size of the cell.  eg. 512px.
    l.CellSize = config.CellSize

    -- A list of visible cells - similar to paths
    l.VisibleCells = {}

    -- Working Data for paths determination
    l.WasHere = {}
    l.TempEnd = {}
    l.TempPath = {}
    l.DeadEnds = {}

    -- temporary debug stuff - will be removed
    l.drawtiles = true
    l.drawlines = true
    l.drawpaths = true
    l.drawdoors = true
    l.drawkeys = true
    l.testforvisible = true
    l.tempfont = love.graphics.newFont(48)

    --initialize the cell array with default values
    for i=1, l.Width do
        l.Cells[i] = {}
        for j=1, l.Height do
            l.Cells[i][j] = {}
            -- Defaults all walls to be on
            l.Cells[i][j].North = true
            l.Cells[i][j].East = true
            l.Cells[i][j].South = true
            l.Cells[i][j].West = true
            l.Cells[i][j].Tileset = 1   -- Default to the first tileset
            l.Cells[i][j].Door = nil    -- no door
            l.Cells[i][j].Key = nil     -- no key
            l.Cells[i][j].Visible = true    -- is visible 
            l.Cells[i][j].Grid = {}     -- the tile grid!
        end
    end

    -- Generate the random seed for everything
    math.randomseed(l.Seed)
    -- Because MacOS is wierd I have to drop the first three random numbers...
    math.random()
    math.random()
    math.random()
    -- End of MacOS weirdness...

    -- Initialize the washere table
    ResetWasHere(l)

    -- Select a preset cell pattern based on a chance (0-100)
    local presetchance = math.random(100)

    -- preset chance pulled from config
    if presetchance <= config.PresetChance then
        
        -- select a random preset
        local presetindex = math.random(#config.Presets)
        -- loop through the present and set the cells up
        for j=1,#config.Presets[presetindex] do
            local x = config.Presets[presetindex][j].x
            local y = config.Presets[presetindex][j].y
            l.Cells[x][y].North = false
            l.Cells[x][y].South = false
            l.Cells[x][y].East = false
            l.Cells[x][y].West = false
            l.Cells[x][y].Visible = false
            l.WasHere[x][y] = true

        end
    end

    -- Lets generate a maze!

    -- Create a stack that holds Cells
    local Stack = {}

    -- Starting point x,y
    local rx
    local ry

    -- Check if it falls into a blocked off area or not
    local TempWasHereCheck = true

    while TempWasHereCheck == true do
        -- Select the starting point at random
        rx = math.random(l.Width)
        ry = math.random(l.Height)

        -- Check to see if it is a blocked off cell (is it already set as true?)
        TempWasHereCheck = l.WasHere[rx][ry]
    end

    -- Assign the location to the stack
    table.insert(Stack, {x=rx,y=ry})

    -- Mark it as visited too...
    l.WasHere[rx][ry] = true

    -- Loop through the Cells until all have been visited and the stack is empty
    while #Stack > 0 do
        -- Peek at the stack
        local CurrentCell = Stack[#Stack]

        -- Create a list of valid adjacent Cells
        local ValidCells = {}

        -- Build a list of adjacent Cells
        -- Check Left: Add if it isn't the left most column and hasn't been visited
        if CurrentCell.x > 1 and l.WasHere[CurrentCell.x-1][CurrentCell.y] == false then
            table.insert(ValidCells, {x=CurrentCell.x-1, y=CurrentCell.y})
        end
        -- Check Right: Add if it isn't the right most column and hasn't been visited
        if CurrentCell.x < l.Width and l.WasHere[CurrentCell.x+1][CurrentCell.y] == false then
            table.insert(ValidCells, {x=CurrentCell.x+1, y=CurrentCell.y})
        end        
        -- Check Up: Add if it isn't the top most row and hasn't been visited
        if CurrentCell.y > 1 and l.WasHere[CurrentCell.x][CurrentCell.y-1] == false then
            table.insert(ValidCells, {x=CurrentCell.x, y=CurrentCell.y-1})
        end        
        -- Check Down: Add if it isn't the bottom most row and hasn't been visited
        if CurrentCell.y < l.Height and l.WasHere[CurrentCell.x][CurrentCell.y+1] == false then
            table.insert(ValidCells, {x=CurrentCell.x, y=CurrentCell.y+1})
        end

        -- Check if there are any valid Cells to choose from
        if #ValidCells > 0 then
            -- Lets pick a random index from the valid Cells
            local rn = math.random(1,#ValidCells)
            local NextCell = ValidCells[rn]

            -- Mark that cell as visited
            l.WasHere[NextCell.x][NextCell.y] = true

            -- Push it onto the stack
            table.insert(Stack, {x=NextCell.x, y=NextCell.y})

            -- Break down the wall between the current and new Cells
            -- Going Right
            if NextCell.x > CurrentCell.x then
                l.Cells[CurrentCell.x][CurrentCell.y].East = false
                l.Cells[NextCell.x][NextCell.y].West = false
            end
            -- Going Right
            if NextCell.x < CurrentCell.x then
                l.Cells[CurrentCell.x][CurrentCell.y].West = false
                l.Cells[NextCell.x][NextCell.y].East = false
            end
            -- Going Down
            if NextCell.y > CurrentCell.y then
                l.Cells[CurrentCell.x][CurrentCell.y].South = false
                l.Cells[NextCell.x][NextCell.y].North = false
            end
            -- Going Up
            if NextCell.y < CurrentCell.y then
                l.Cells[CurrentCell.x][CurrentCell.y].North = false
                l.Cells[NextCell.x][NextCell.y].South = false
            end
        else
            -- There are no valid l.Cells to choose from, pop from the main stack
            table.remove(Stack)
        end
    end

    -- Setup the start and end positions of the level
    -- 1. Randomly choose a starting corner
    -- 2. Set the direction based on the corner
    local startcorner = {} 
    local corner = math.random(1,4)     -- 1=top left, 2=top right, 3=bottom left, 4=bottom right
    local forloopend = {}
    local forloopdirection = {}
    if corner == 1 then
        startcorner = {x=1, y=1}
        forloopend = {x=l.Width, y=l.Height}
        forloopdirection = {x=1, y=1}
    elseif corner == 2 then
        startcorner = {x=l.Width, y=1}
        forloopend = {x=1, y=l.Height}
        forloopdirection = {x=-1, y=1}
    elseif corner == 3 then
        startcorner = {x=1, y=l.Height}
        forloopend = {x=l.Width, y=1}
        forloopdirection = {x=1, y=-1}
    else
        startcorner = {x=l.Width, y=l.Height}
        forloopend = {x=1, y=1}
        forloopdirection = {x=-1, y=-1}
    end

    -- 3. Interate through the cells based on the direction until a dead end is found, set as starting postion, may need to move to a second row/column if it isn't found along the wall
    local found = false
    for i=startcorner.x, forloopend.x, forloopdirection.x do
        for j=startcorner.y, forloopend.y, forloopdirection.y do
            local walls = CountWalls(l,i,j)
            if walls == 3 then
                l.StartCell = {x=i, y=j}
                found = true
                break
            end
        end
        if found == true then break end
    end

    -- Find the closest corner to the starting position, then set the ending corner opposite
    -- Also set the direction to look for a dead end like the starting position
    local endcorner = {}
    if l.StartCell.x <= l.Width/2 then
        endcorner.x = l.Width
        forloopend.x = 1
        forloopdirection.x = -1
    else
        endcorner.x = 1
        forloopend.x = l.Width
        forloopdirection.x = 1
    end

    if l.StartCell.y <= l.Height/2 then
        endcorner.y = l.Height
        forloopend.y = 1
        forloopdirection.y = -1
    else   
        endcorner.y = 1
        forloopend.y = l.Height
        forloopdirection.y = 1
    end

    -- 6. Interate through the cells based on the direction until a dead end is found, set as ending postion, may need to move to a second row/column if it isn't found along the wall
    found = false
    for i=endcorner.x, forloopend.x, forloopdirection.x do
        for j=endcorner.y, forloopend.y, forloopdirection.y do
            local walls = CountWalls(l,i,j)
            if walls == 3 then
                l.EndCell = {x=i, y=j}
                found = true
                break
            end
        end
        if found == true then break end
    end

    -- Determine critical path
    -- Reset the washere array
    ResetWasHere(l)

    -- Set the end cells, we make the TempEnd an array of one to work properly with the SolvePath function
    l.TempEnd = {}
    l.TempEnd[1] = {}
    l.TempEnd[1] = l.EndCell

    -- Solve for the critical path (no door check)
    local solved = SolvePath(l, l.StartCell.x, l.StartCell.y)
    
    -- Assign to the critical path table and reset the temp path
    -- A little more complex than a simply assignment as we will reverse it because the solvepath ends up having the start at the end of the array and end at the start.
    for i=#l.TempPath,1,-1 do
        table.insert(l.CriticalPath, l.TempPath[i])
    end

    --l.CriticalPath = l.TempPath
    l.TempPath = {}

    -- Determine dead end paths
    -- Find dead ends
    for i=1, l.Width do
        for j=1, l.Height do
            local c = CountWalls(l,i, j)
            if c > 2 then
                -- exclude the start and end positions... 
                if not(i == l.StartCell.x and j == l.StartCell.y) and not(i == l.EndCell.x and j == l.EndCell.y) then
                    table.insert(l.DeadEnds, {x=i, y=j})
                end
            end
        end
    end

    -- Set the end cells as the critical path - as we loop through we want to check if we have reached the critical path
    l.TempEnd = l.CriticalPath

    -- If there are dead ends (there probably always will be...)
    if #l.DeadEnds > 0 then
        for i=1, #l.DeadEnds do
            -- Reset the washere table
            ResetWasHere(l)
            -- Solve the dead end path (no door check)
            local solved = SolvePath(l, l.DeadEnds[i].x, l.DeadEnds[i].y)
            -- add the solved dead end to the array of dead end paths
            table.insert(l.DeadEndPath, l.TempPath)
            -- reset the TempPath
            l.TempPath = {}
        end
    end

    -- Determine Door Locations
    
    -- setup the path to use
    l.TempPath = l.CriticalPath
    -- Make some doors on the critical path
    SetDoors(l)

    -- Make doors on the dead end paths    
    for i=1, #l.DeadEndPath do
        -- set the path
        l.TempPath = l.DeadEndPath[i]
        SetDoors(l)
    end

    -- Lock the last door on the critical path
    -- setup an index tracker
    --local CritIndex = #l.CriticalPath
    local CritIndex = 1
    local DoorIndex = 0

    for i=1, #l.Doors do
        for j=1,#l.CriticalPath do
            if l.Doors[i].x == l.CriticalPath[j].x and l.Doors[i].y == l.CriticalPath[j].y then
                if j > CritIndex then
                    CritIndex = j
                    DoorIndex = i
                end
                break
            end
        end
    end

    -- Lock the door!
    if DoorIndex > 0 then
        l.Doors[DoorIndex].locked = true
        l.Doors[DoorIndex].keyindex = 1
        -- set the locked door on the cells table
        l.Cells[l.Doors[DoorIndex].x][l.Doors[DoorIndex].y].Door.locked = true
        l.Cells[l.Doors[DoorIndex].x][l.Doors[DoorIndex].y].Door.keyindex = 1
        -- set the locked door on the critical path
        l.CriticalPath[CritIndex].Door.locked = true
        l.CriticalPath[CritIndex].Door.keyindex = 1
    end

    -- Place some keys randomly
    -- Determine the number of keys based on the rules
    local DeadEndPositionCount = (l.Width * l.Height) - #l.CriticalPath

    local KeyCount = math.ceil(DeadEndPositionCount * l.KeyRules.Rate)
    -- Max it based on the rules
    if KeyCount > l.KeyRules.Max then
        KeyCount = l.KeyRules.Max
    end
    -- Max it based on the number of dead ends
    if KeyCount > #l.DeadEnds then
        KeyCount = #l.DeadEnds
    end

    -- Make a copy of this in case we need the dead end list later
    local TempDeadEndList = l.DeadEnds

    -- Key counter
    local CurrentKey = 0

    -- key error counter
    local keyerrors = 0

    -- Place keys, try to distribute them
    while CurrentKey < KeyCount do
        -- Randomly select a dead end list index
        local TempDeadEndIndex = math.random(#TempDeadEndList)

        -- create the key
        local TempKey = {x=TempDeadEndList[TempDeadEndIndex].x,y=TempDeadEndList[TempDeadEndIndex].y}

        -- Make sure the key isn't behind the door...
        -- prep to use the solvepath function
        ResetWasHere(l)
        l.TempPath = {}
        l.TempEnd = {}
        l.TempEnd[1] = {}
        l.TempEnd[1] = TempKey

        -- Solve for the critical path (no door check)
        local solved = SolvePath(l, l.StartCell.x, l.StartCell.y)

        -- setup a key validity flag
        local InvalidKey = false

        -- check to see if it is behind the locked door

        -- this sometimes has a nil????
        for i=1,#l.TempPath do
            if l.TempPath[i].x == l.Doors[DoorIndex].x and l.TempPath[i].y == l.Doors[DoorIndex].y then
                InvalidKey = true
                keyerrors = keyerrors + 1         
                break
            end
        end        

        -- Add the key to the key table
        if InvalidKey == false then
            -- Add it to the key table
            table.insert(l.Keys, TempKey)
            -- Add the key to the cells table
            l.Cells[TempKey.x][TempKey.y].Key = TempKey
            l.Cells[TempKey.x][TempKey.y].Key.ColorIndex = #l.Keys
            -- Add it to the dead end path???

            -- remove that dead end from the temp dead end list
            table.remove(TempDeadEndList, TempDeadEndIndex)
            -- increment the key count
            CurrentKey = CurrentKey + 1
        end

        -- force the end of the while loop if we hit the max key errors
        if keyerrors >= l.KeyRules.PlacementErrors then
            CurrentKey = KeyCount
        end
    end

    -- TODO
    -- Add the key data to the cell and path tables for use
    -- TODO

    -- Randomly select a few tilesets for the level

    -- Enumerate the tilesets
    local LevelFiles = love.filesystem.getDirectoryItems("Assets/Levels/")
    local TilesetNames = {}

    -- loop through and pull the "TilesetTexture*" files
    for i=1,#LevelFiles do
        if string.find(LevelFiles[i],"TilesetTexture") then
            local tsstart = string.find(LevelFiles[i],"_") + 1
            local tsend = string.find(LevelFiles[i],".png") - 1
            local tsname = string.sub(LevelFiles[i],tsstart,tsend)
            table.insert(TilesetNames, tsname)
        end
    end

    -- Randomly select textures to use
    -- Note: all cells are defaulted to the first tileset
    for i=1,config.NumberofTilesets do
        -- pick a tileset
        local r = math.random(#TilesetNames)
        -- add it
        setTiles(l, TilesetNames[r])
        -- remove from the tilesetnames table so it can't be selected again
        table.remove(TilesetNames,r)
        -- error check the tilesetnames table for length... if it is 0 then break for
        if #TilesetNames == 0 then
            break
        end
    end

    -- randomly assign tilesets to paths
    -- Critical Path
    local r = math.random(#l.Tileset)
    for i=1, #l.CriticalPath do
        l.Cells[l.CriticalPath[i].x][l.CriticalPath[i].y].Tileset = r
    end

    -- Dead end paths
    for i=1, #l.DeadEndPath do
        local r = math.random(#l.Tileset)
        -- Set a tileset to the path
        for j=2,#l.DeadEndPath[i] do
            l.Cells[l.DeadEndPath[i][j].x][l.DeadEndPath[i][j].y].Tileset = r
        end        
    end

    -- Build the cell graphics for each tile

    -- initial indexes for each type of sprite
    local floorindex = 1
    local wallindex = 1
    local doorframeindex = 1
    local decalindex = 1
    local exteriorindex=1
    local outsidecornerindex=1
    local insidecornerindex=1

    -- Loop through the cells and determine the static graphics (floor, walls, door frame, corners, decals)
    for i=1, l.Width do
        for j=1, l.Height do
            -- create the tile table
            l.TileTemp = {}

            -- init the tile physics table
            l.Cells[i][j].Collision = {}

            -- get the cell tileset
            local ts = l.Cells[i][j].Tileset

            -- Floors!
            -- determine if we should change the type of floor
            local rc = math.random(100)
            -- change it if necessary
            if rc <= config.TileRules.FloorChance then
                floorindex = math.random(#l.Tiles[ts].Floors)
            end

            addTileToCell(l, 0, 0, 0, l.Tiles[ts].Floors[floorindex], i, j)


            -- decals??


            -- wall - interior and exterior
            rc = math.random(100)
            -- change it if necessary
            if rc <= config.TileRules.WallChance then
                wallindex = math.random(#l.Tiles[ts].Walls)
            end
            rc = math.random(100)

            if rc <= config.TileRules.ExteriorChance then
                exteriorindex = math.random(#l.Tiles[ts].Exteriors)
            end

            if l.Cells[i][j].North then
                -- it is an exterior (top wall)
                if j == 1 then
                    addTileToCell(l, l.CellSize, 0, math.pi/2, l.Tiles[ts].Exteriors[exteriorindex], i, j)
                else
                    addTileToCell(l, l.CellSize, 0, math.pi/2, l.Tiles[ts].Walls[wallindex], i, j)
                end
            end
            if l.Cells[i][j].South then
                -- it is an exterior (top wall)
                if j == l.Height then
                    addTileToCell(l, 0, l.CellSize, (math.pi*3)/2, l.Tiles[ts].Exteriors[exteriorindex], i, j)
                else
                    addTileToCell(l, 0, l.CellSize, (math.pi*3)/2, l.Tiles[ts].Walls[wallindex], i, j)
                end
            end
            if l.Cells[i][j].East then
                -- it is an exterior (top wall)
                if i == l.Width then
                    addTileToCell(l, l.CellSize, l.CellSize, math.pi, l.Tiles[ts].Exteriors[exteriorindex], i, j)
                else
                    addTileToCell(l, l.CellSize, l.CellSize, math.pi, l.Tiles[ts].Walls[wallindex], i, j)
                end
            end
            if l.Cells[i][j].West then
                -- it is an exterior (top wall)
                if i == 1 then
                    addTileToCell(l, 0, 0, 0, l.Tiles[ts].Exteriors[exteriorindex], i, j)
                else
                    addTileToCell(l, 0, 0, 0, l.Tiles[ts].Walls[wallindex], i, j)
                end
            end

            -- Doorframes!
            rc = math.random(100)
            -- change it if necessary
            if rc <= config.TileRules.DoorFrameChance then
                doorframeindex = math.random(#l.Tiles[ts].DoorFrames)
            end

            if l.Cells[i][j].Door then
                if l.Cells[i][j].Door.wall == "N" then
                    addTileToCell(l, l.CellSize, 0, math.pi/2, l.Tiles[ts].DoorFrames[doorframeindex], i, j)
                end
                if l.Cells[i][j].Door.wall == "S" then
                    addTileToCell(l, 0, l.CellSize, (math.pi*3)/2, l.Tiles[ts].DoorFrames[doorframeindex], i, j)
                end
                if l.Cells[i][j].Door.wall == "E" then
                    addTileToCell(l, l.CellSize, l.CellSize, math.pi, l.Tiles[ts].DoorFrames[doorframeindex], i, j)                
                end
                if l.Cells[i][j].Door.wall == "W" then
                    addTileToCell(l, 0, 0, 0, l.Tiles[ts].DoorFrames[doorframeindex], i, j)               
                end
            end


            if rc <= config.TileRules.CornerChance then
                exteriorindex = math.random(#l.Tiles[ts].Exteriors)
            end
            -- Inside Corner(s)
            -- Pull the door info for testing later
            local d = nil
            if l.Cells[i][j].Door then
                d = l.Cells[i][j].Door.wall
            end
            if not(l.Cells[i][j].North) then
                if not(l.Cells[i][j].East) then
                    if not(d == "E" or d == "N") then
                        -- need a corner in the north east corner
                        addTileToCell(l, l.CellSize, 0, math.pi/2, l.Tiles[ts].OutsideCorners[outsidecornerindex], i, j)                   
                    end
                end
                if not(l.Cells[i][j].West) then
                    if not(d == "W" or d == "N") then
                        -- need a corner in the north west corner
                        addTileToCell(l, 0, 0, 0, l.Tiles[ts].OutsideCorners[outsidecornerindex], i, j)               
                    end
                end
            end
            -- test south then e/w
            if not(l.Cells[i][j].South) then
                if not(l.Cells[i][j].East) then
                    if not(d == "E" or d == "S") then                
                        -- need a corner in the south east corner
                        addTileToCell(l, l.CellSize, l.CellSize, math.pi, l.Tiles[ts].OutsideCorners[outsidecornerindex], i, j)
                    end
                end
                if not(l.Cells[i][j].West) then
                    if not(d == "W" or d == "S") then                
                        -- need a corner in the south west corner
                        addTileToCell(l, 0, l.CellSize, (math.pi*3)/2, l.Tiles[ts].OutsideCorners[outsidecornerindex], i, j)
                    end
                end
            end

            --inside corners!!
            if l.Cells[i][j].North then
                if l.Cells[i][j].East then
                    -- need a corner in the north east corner
                    addTileToCell(l, l.CellSize, 0, math.pi/2, l.Tiles[ts].InsideCorners[insidecornerindex], i, j)                  
                end
                if l.Cells[i][j].West then
                    -- need a corner in the north west corner
                    addTileToCell(l, 0, 0, 0, l.Tiles[ts].InsideCorners[insidecornerindex], i, j)                
                end
            end
            -- test south then e/w
            if l.Cells[i][j].South then
                if l.Cells[i][j].East then
                    -- need a corner in the south east corner
                    addTileToCell(l, l.CellSize, l.CellSize, math.pi, l.Tiles[ts].InsideCorners[insidecornerindex], i, j)
                end
                if l.Cells[i][j].West then
                    -- need a corner in the south west corner
                    addTileToCell(l, 0, l.CellSize, (math.pi*3)/2, l.Tiles[ts].InsideCorners[insidecornerindex], i, j)
                end
            end

            -- Create canvas for the cell
            l.Cells[i][j].BakedTile = love.graphics.newCanvas(l.CellSize, l.CellSize)
            -- draw the tiles to the canvas
            love.graphics.setCanvas(l.Cells[i][j].BakedTile)
            for k=1,#l.TileTemp do
                love.graphics.draw(l.Tileset[l.Cells[i][j].Tileset], l.TileTemp[k].Quad, l.TileTemp[k].x, l.TileTemp[k].y, l.TileTemp[k].rotation, l.Tiles[l.Cells[i][j].Tileset].Scale)                
            end
            love.graphics.setCanvas()
        end
    end

    -- Clean up everything that isn't needed during play
    l.WasHere = nil
    l.TempEnd = nil
    l.TempPath = nil
    l.DeadEnds = nil
    l.DoorRules = nil
    l.KeyRules = nil
    l.Tileset = nil    -- <-- this doesn't seem to make a difference in memory usage..?
    l.Tiles = nil       -- <-- this doesn't seem to make a difference in memory usage..?

    -- return the level object
    return l
end

-- sends back the table of data related to a cell
function Level:getCellData(x, y)
    return self.Cells[x][y]
end

-- returns a path to the closest key.  The last index in the path array is the key location
function Level:getClosestKey(x, y)
    -- find the closest key

    local keypaths = {}
    for i=1,#self.Keys do
        -- Reset the washere array
        ResetWasHere(self)

        -- reset temppath just in case
        self.TempPath = {}

        -- Set the end cells, we make the TempEnd an array of one to work properly with the SolvePath function
        self.TempEnd = {}
        self.TempEnd[1] = {}
        self.TempEnd[1] = self.Keys[i]

        -- Solve for the path from provided cell to key
        local solved = SolvePath(l, x, y)
        
        -- Assign to the keypaths table
        -- A little more complex than a simply assignment as we will reverse it because the solvepath ends up having the start at the end of the array and end at the start.
        table.insert(keypaths, self.TempPath)
    end

    local keycount = nil
    local keyindex = nil

    if #keypaths > 0 then
        keyindex = 1
        keycount = #keypaths[1]
        for i=1,#keypaths do
            if #keypaths[i] < keycount then
                keycount = #keypaths[i]
                keyindex = i
            end
        end
    end

    if keyindex then
        return keypaths[keyindex]
    else
        return nil
    end

end

function Level:buildvisible3(px, py, cx, cy, cx2, cy2)
    -- get the cell bounds in the camera
    local cellstart = {}
    local cellend = {}

    cellstart.x, cellstart.y = self:getCellFromWorldPosition(cx, cy)
    cellend.x, cellend.y = self:getCellFromWorldPosition(cx2, cy2)

    -- reset the rays table
    self.rays = {}
    self.rayindex = 0

    -- light mask triangles
    self.lightmask = {}

    -- loop through cells
    for i=cellstart.x, cellend.x do
        for j=cellstart.y, cellend.y do
            -- loop through the collision data for the cell
            for k=1,#self.Cells[i][j].Collision do
                -- get the points for each collision shape in world points
                local p = {self.Cells[i][j].Collision[k].Body:getWorldPoints(self.Cells[i][j].Collision[k].Shape:getPoints())}
                -- loop through the points assigning rays from the player to the point
                for l=1, #p, 2 do
                    local ray = {}
                    ray.x1 = px
                    ray.y1 = py
                    ray.x2 = p[l]
                    ray.y2 = p[l+1]
                    -- calculate the angle
                    ray.a = math.atan2(ray.y2 - ray.y1, ray.x2 - ray.x1)
                    -- setup a table to hold the hits for when it comes time...
                    ray.hits = {}                    
                    -- add it to the rays table
                    table.insert(self.rays, ray)
                end
            end
        end
    end

    -- sort the rays by angle... you only need to sort if you have more than one ray
    if #self.rays > 1 then
        -- make a copy of the array
        local h = self.rays
        -- get the count - 1
        local c = #h-1
        -- loop through
        while c > 0 do
            for j=1, #h-1 do
                -- is the value greater than the next value (the ray angle)?
                if h[j].a > h[j+1].a then
                    -- yes - swap them... 
                    local t = h[j]
                    h[j] = h[j+1]
                    h[j+1] = t
                end
            end
            -- decrease the index counter for the while loop
            c = c - 1
        end
        -- copy the sorted array back
        self.rays = h
    end
    
    -- shoot the rays!
    for i=1, #self.rays do
        -- set the rayindex for the callback function...
        self.rayindex = i
        w:rayCast(self.rays[i].x1, self.rays[i].y1, self.rays[i].x2, self.rays[i].y2, levelraycallback)

        -- check for no hits... set the point as the hit...
        if #self.rays[i].hits == 0 then
            local hit = {}
            hit.x = self.rays[i].x2
            hit.y = self.rays[i].y2
            hit.fraction = 1.0
            table.insert(self.rays[i].hits, hit)
        end

        -- sort it with a bubble sort!!  only on arrays that have at least 2 elements
        if #self.rays[i].hits > 1 then
            -- make a copy of the array
            local h = self.rays[i].hits
            -- get the count - 1
            local c = #h-1
            -- loop through
            while c > 0 do
                for j=1, #h-1 do
                    -- is the value greater than the next value?
                    if h[j].fraction > h[j+1].fraction then
                        -- yes - swap them... 
                        local t = h[j]
                        h[j] = h[j+1]
                        h[j+1] = t
                    end
                end
                -- decrease the index counter for the while loop
                c = c - 1
            end
            -- copy the sorted array back
            self.rays[i].hits = h
        end
        --print("ray " .. i .. ":" .. #self.rays[i].hits)
    end

    local vl = math.sqrt((cx2-cx)*(cx2-cx) + (cy2-cy)*(cy2-cy))

    -- setup all of the drawing triangles
    local l = 1
    for i=1, #self.rays do
        -- this cond check doesnt actually work...
        self.lightmask[l] = {}
        table.insert(self.lightmask[l], px)
        table.insert(self.lightmask[l], py)
        table.insert(self.lightmask[l], self.rays[i].hits[1].x)
        table.insert(self.lightmask[l], self.rays[i].hits[1].y)
        if i == #self.rays then
            table.insert(self.lightmask[l], self.rays[1].hits[1].x)
            table.insert(self.lightmask[l], self.rays[1].hits[1].y)
        else
            table.insert(self.lightmask[l], self.rays[i+1].hits[1].x)
            table.insert(self.lightmask[l], self.rays[i+1].hits[1].y)
        end
        l=l+1
    end
end


function Level:buildvisible2(px, py, cx, cy, cx2, cy2)
    -- get the cell bounds in the camera
    local cellstart = {}
    local cellend = {}

    cellstart.x, cellstart.y = self:getCellFromWorldPosition(cx, cy)
    cellend.x, cellend.y = self:getCellFromWorldPosition(cx2, cy2)

    -- reset the rays table
    self.rays = {}
    self.rayindex = 0

    -- light mask triangles
    self.lightmask = {}

    -- loop through cells
    for i=cellstart.x, cellend.x do
        for j=cellstart.y, cellend.y do
            -- loop through the collision data for the cell
            for k=1,#self.Cells[i][j].Collision do
                -- get the points for each collision shape in world points
                local p = {self.Cells[i][j].Collision[k].Body:getWorldPoints(self.Cells[i][j].Collision[k].Shape:getPoints())}
                -- loop through the points assigning rays from the player to the point
                for l=1, #p, 2 do
                    local ray = {}
                    ray.x1 = px
                    ray.y1 = py
                    ray.x2 = p[l]
                    ray.y2 = p[l+1]
                    -- calculate the angle
                    ray.a = math.atan2(ray.y2 - ray.y1, ray.x2 - ray.x1)
                    -- setup a table to hold the hits for when it comes time...
                    ray.hits = {}                    
                    -- add it to the rays table
                    table.insert(self.rays, ray)
                end
            end
        end
    end

    -- sort the rays by angle... you only need to sort if you have more than one ray
    if #self.rays > 1 then
        -- make a copy of the array
        local h = self.rays
        -- get the count - 1
        local c = #h-1
        -- loop through
        while c > 0 do
            for j=1, #h-1 do
                -- is the value greater than the next value (the ray angle)?
                if h[j].a > h[j+1].a then
                    -- yes - swap them... 
                    local t = h[j]
                    h[j] = h[j+1]
                    h[j+1] = t
                end
            end
            -- decrease the index counter for the while loop
            c = c - 1
        end
        -- copy the sorted array back
        self.rays = h
    end
    
    -- shoot the rays!
    for i=1, #self.rays do
        -- set the rayindex for the callback function...
        self.rayindex = i
        w:rayCast(self.rays[i].x1, self.rays[i].y1, self.rays[i].x2, self.rays[i].y2, levelraycallback)

        -- check for no hits... set the point as the hit...
        if #self.rays[i].hits == 0 then
            local hit = {}
            hit.x = self.rays[i].x2
            hit.y = self.rays[i].y2
            hit.fraction = 1.0
            table.insert(self.rays[i].hits, hit)
        end

        -- sort it with a bubble sort!!  only on arrays that have at least 2 elements
        if #self.rays[i].hits > 1 then
            -- make a copy of the array
            local h = self.rays[i].hits
            -- get the count - 1
            local c = #h-1
            -- loop through
            while c > 0 do
                for j=1, #h-1 do
                    -- is the value greater than the next value?
                    if h[j].fraction > h[j+1].fraction then
                        -- yes - swap them... 
                        local t = h[j]
                        h[j] = h[j+1]
                        h[j+1] = t
                    end
                end
                -- decrease the index counter for the while loop
                c = c - 1
            end
            -- copy the sorted array back
            self.rays[i].hits = h
        end
        --print("ray " .. i .. ":" .. #self.rays[i].hits)
    end

    local vl = math.sqrt((cx2-cx)*(cx2-cx) + (cy2-cy)*(cy2-cy))

    -- setup all of the drawing triangles
    local l = 1
    for i=1, #self.rays do
        -- this cond check doesnt actually work...
        self.lightmask[l] = {}
        table.insert(self.lightmask[l], px)
        table.insert(self.lightmask[l], py)
        table.insert(self.lightmask[l], self.rays[i].hits[1].x)
        table.insert(self.lightmask[l], self.rays[i].hits[1].y)
        if i == #self.rays then
            table.insert(self.lightmask[l], self.rays[1].hits[1].x)
            table.insert(self.lightmask[l], self.rays[1].hits[1].y)
        else
            table.insert(self.lightmask[l], self.rays[i+1].hits[1].x)
            table.insert(self.lightmask[l], self.rays[i+1].hits[1].y)
        end
        l=l+1
    end
end

-- comment this!
function Level:buildvisible(px, py, ww, wh)
    -- reset rays table
    self.rays = {}
    self.rayindex = 0

    -- reset the rayhits table
    self.rayhits = {}

    -- get the max vector length
    local vl = math.sqrt((ww * ww) + (wh * wh))

    -- going to make 24 rays all the way around the player (15 degrees apart - or pi/12 apart)
    for i=0, 24 do
        self.rayindex = i
        -- set the angle
        local a = math.pi/12 * i
        -- get the end of the vector with the angle and length, adding the origin so it is constant
        local x = math.cos(a) * vl + px
        local y = math.sin(a) * vl + py
        -- add the ray info the ray table (for drawing later)
        self.rays[i] = {}
        self.rays[i].x1 = px
        self.rays[i].y1 = py
        self.rays[i].x2 = x
        self.rays[i].y2 = y
        self.rays[i].hits = {}
        -- send the ray out!
        w:rayCast(px, py, x, y, levelraycallback)

        -- sort it with a bubble sort!!  only on arrays that have at least 2 elements
        if #self.rays[i].hits > 1 then
            -- make a copy of the array
            local h = self.rays[i].hits
            -- get the count - 1
            local c = #h-1
            -- loop through
            while c > 0 do
                for j=1, #h-1 do
                    -- is the value greater than the next value?
                    if h[j].fraction > h[j+1].fraction then
                        -- yes - swap them... 
                        local t = h[j]
                        h[j] = h[j+1]
                        h[j+1] = t
                    end
                end
                -- decrease the index counter for the while loop
                c = c - 1
            end
            -- copy the sorted array back
            self.rays[i].hits = h
        end

        -- get a list of cells where the rayhits happened
        -- only if there is a hit
        if #self.rays[i].hits > 0 then
            -- get the first rayhit
            local xc, yc = self:getCellFromWorldPosition(self.rays[i].hits[1].x, self.rays[i].hits[1].y)
            local found = false
            -- check to see if we already have that cell
            for j=1, #self.rayhits do
                if self.rayhits[j].x == xc and self.rayhits[j].y == yc then
                    found = true
                end
            end
            -- if not, then add it
            if not(found) then
                table.insert(self.rayhits, {x=xc, y=yc})
            end 
        end
    end

    -- reset
    for i=1,self.Width do
        for j=1, self.Height do
            self.Cells[i][j].Visible = false  
        end
    end

    for i=1, #self.rayhits do
        --setup the end
        self.TempEnd = {}
        self.TempEnd[1] = self.rayhits[i]

        --reset was here
        ResetWasHere(self)

        -- reset temppath
        self.TempPath = {}

        -- get the cell position on the player
        local cx, cy = self:getCellFromWorldPosition(px, py)

        -- get the path from the player to where the ray hit
        local solved = SolvePath(self, cx, cy)

        -- mark those cells as visible
        for j=1, #self.TempPath do
            self.Cells[self.TempPath[j].x][self.TempPath[j].y].Visible = true
        end
    end    
end

-- Sends back the cell position in array index's from the world position sent
function Level:getCellFromWorldPosition(x, y)
    local i = clamp(math.floor(x / self.CellSize) + 1, 1, self.Width)
    local j = clamp(math.floor(y / self.CellSize) + 1, 1, self.Height)
    return i, j
end

function Level:update(px, py, ww, wh, dt)
    -- send out rays and determine visibility!!
    if self.testforvisible then
        self:buildvisible(px, py, ww, wh)
    end

end

function Level:draw()
    for i=1, self.Width do
        for j=1, self.Height do
            -- set the colour to white!
            love.graphics.setColor(255,255,255,255)

            if (self.testforvisible and self.Cells[i][j].Visible) or not(self.testforvisible) then
                -- if we are drawing tiles, draw the baked tile canvas for each cell
                if self.drawtiles then
                    love.graphics.draw(self.Cells[i][j].BakedTile, (i-1)*l.CellSize, (j-1)*l.CellSize)
                end    
            end
        end
    end
end

function Level:debugdraw()
    local s = self.CellSize

    local colourindex = {
        {255,0,0,255},
        {0,255,0,255},
        {0,0,255,255},
        {255,0,255,255},
        {255,255,0,255}
    }

    for i=1, self.Width do
        for j=1, self.Height do
            -- set the colour to white!
            love.graphics.setColor(255,255,255,255)

            if (self.testforvisible and self.Cells[i][j].Visible) or not(self.testforvisible) then

                love.graphics.setFont(self.tempfont)

                -- lines for walls
                if self.drawlines then
                    if self.Cells[i][j].North == true then
                        love.graphics.line((i-1)*s, (j-1)*s, (i-1)*s+s, (j-1)*s)   -- x1,y1,x2,y2
                    end
                    if self.Cells[i][j].South == true then
                        love.graphics.line((i-1)*s, (j-1)*s+s, (i-1)*s+s, (j-1)*s+s)   -- x1,y1,x2,y2
                    end
                    if self.Cells[i][j].East == true then
                        love.graphics.line((i-1)*s+s, (j-1)*s, (i-1)*s+s, (j-1)*s+s)   -- x1,y1,x2,y2
                    end
                    if self.Cells[i][j].West == true then
                        love.graphics.line((i-1)*s, (j-1)*s, (i-1)*s, (j-1)*s+s)   -- x1,y1,x2,y2
                    end

                    -- lines for collision polygons
                    love.graphics.setColor(64,64,255,255)
                    for k=1,#self.Cells[i][j].Collision do
                        love.graphics.polygon("line",self.Cells[i][j].Collision[k].Body:getWorldPoints(self.Cells[i][j].Collision[k].Shape:getPoints()))
                    end
                end

                -- lines and direction for doors
                if self.drawdoors then
                    if self.Cells[i][j].Door then
                        if self.Cells[i][j].Door.locked then
                            love.graphics.setColor(255,0,0,255)
                        else
                            love.graphics.setColor(0,255,0,255)            
                        end
                        if self.Cells[i][j].Door.wall == "N" then
                            love.graphics.line((i-1)*s, (j-1)*s, (i-1)*s+s, (j-1)*s)   -- x1,y1,x2,y2
                            love.graphics.print("N", (i-1)*s + 256, (j-1)*s)
                        end
                        if self.Cells[i][j].Door.wall == "S" then
                            love.graphics.line((i-1)*s, (j-1)*s+s, (i-1)*s+s, (j-1)*s+s)   -- x1,y1,x2,y2
                            love.graphics.print("S", (i-1)*s + 256, (j-1)*s+s)
                        end
                        if self.Cells[i][j].Door.wall == "E" then
                            love.graphics.line((i-1)*s+s, (j-1)*s, (i-1)*s+s, (j-1)*s+s)   -- x1,y1,x2,y2
                            love.graphics.print("E", (i-1)*s+s, (j-1)*s + 256)
                        end
                        if self.Cells[i][j].Door.wall == "W" then
                            love.graphics.line((i-1)*s, (j-1)*s, (i-1)*s, (j-1)*s+s)   -- x1,y1,x2,y2
                            love.graphics.print("W", (i-1)*s, (j-1)*s + 256)
                        end         
                    end
                end

                if self.drawkeys then
                    if self.Cells[i][j].Key then
                        love.graphics.setColor(colourindex[self.Cells[i][j].Key.ColorIndex])
                        love.graphics.circle("line", (i-1) * self.CellSize + self.CellSize / 2, (j-1) * self.CellSize + self.CellSize / 2, 16)
                    end
                end
            end
        end
    end

    if self.drawpaths then
        for i=1, #self.CriticalPath do
            if (self.testforvisible and self.Cells[self.CriticalPath[i].x][self.CriticalPath[i].y].Visible) or not(self.testforvisible) then

                if i == 1 then 
                    love.graphics.setColor(128,255,128,255)
                    love.graphics.circle("fill",(self.CriticalPath[i].x-1)*s+s/2, (self.CriticalPath[i].y-1)*s+s/2, 8)
                elseif i == #self.CriticalPath then 
                    love.graphics.setColor(255,64,64,255)
                    love.graphics.circle("fill",(self.CriticalPath[i].x-1)*s+s/2, (self.CriticalPath[i].y-1)*s+s/2, 8)
                end

                love.graphics.setColor(0,0,255,255)
                love.graphics.circle("fill", (self.CriticalPath[i].x-1)*s+s/2, (self.CriticalPath[i].y-1)*s+s/2, 4)
            end
        end

        love.graphics.setColor(255,128,128,255)

        for i=1, #self.DeadEndPath do
            for j=2, #self.DeadEndPath[i] do
                if (self.testforvisible and self.Cells[self.DeadEndPath[i][j].x][self.DeadEndPath[i][j].y].Visible) or not(self.testforvisible) then    
                    love.graphics.circle("fill", (self.DeadEndPath[i][j].x-1)*s+s/2, (self.DeadEndPath[i][j].y-1)*s+s/2, 4)        
                end
            end
        end
    end
end

return Level