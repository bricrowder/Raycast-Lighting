local json = require "dkjson"

function love.conf(t)
--[[
    --- this can go in a function!!
    local jsonpresetfile = "Assets/Config.json"
    -- open and pull the data from the file
    local jsonstring, jsonsize = love.filesystem.read(jsonpresetfile)
    -- setup the decoding fields
    local jsondata, jsonpos, jsonerr

    -- if we were able to get the json string from the file
    if jsonstring then
        print(jsonstring)
        -- decode the string into the jsondata table
        jsondata, jsonpos, jsonerr = json.decode(jsonstring)
    end
]]
    local jsondata = json.opendecode("Assets/Config.json")

    t.window.width = jsondata.WindowWidth
    t.window.height = jsondata.WindowHeight
    t.window.vsync = jsondata.Vsync
end