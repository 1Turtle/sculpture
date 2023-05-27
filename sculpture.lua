--- sculpture
-- This program can generate and manipulate .3dj files and generate 3D sculptures made out of player skins.
--
-- @version 1.0
-- @author Sammy L. Koch
-- @copyright 2023
-- @licence MIT (https://mit-license.org/)

local strings = require("cc.strings")
local success, pngImage = pcall(require, "png")
local w,h = term.getSize()

--- Downloads a given url while running a loading animation.
-- If completed, the loading bar will update its content to 'OK' or 'FAIL', depending on its result.
-- Will return a boolean, whenever it was successfull or not and then either the gotten content or the error message.
--
---@param url string The url to download.
---@return boolean success Whenever it was successfull or not.
---@return string content The returned content or error message.
local function downloadFile(url, isBinary)
    if not http then
        return false, "The http API is not available but needed"
    end

    if type(isBinary) ~= "boolean" then isBinary  = false end

    -- Setup loading bar
    local load_anim_dir,load_anim_pos = 1, 1
    local x,y = term.getCursorPos()
    -- Loading bar drawing function
    local function load_anim_update(result)
        term.setCursorPos(x,y)
        term.setTextColor(colors.lightGray)
        term.write("[      ]")

        -- Loading animation
        if not result then
            -- Positioning bar
            term.setCursorPos(x+load_anim_pos,y)
            load_anim_pos = load_anim_pos + load_anim_dir
            if load_anim_pos >= 3 then
                load_anim_dir = -load_anim_dir
                load_anim_pos = 3
            elseif load_anim_pos <= 1 then
                load_anim_dir = -load_anim_dir
                load_anim_pos = 1
            end

            -- Draw bar
            term.blit("***", "141", "fff")
        elseif result == "ok" then
            term.setCursorPos(x+3,y)
            term.setTextColor(colors.lime)
            term.write("OK")
        elseif result == "fail" then
            term.setCursorPos(x+2,y)
            term.setTextColor(colors.red)
            term.write("FAIL")
        end
    end

    -- Trying to request a download 
    if not http.request({ url = url, timeout = 7, binary = isBinary }) then
        return false, ("Could not request url \'%s\'"):format(url)
    end

    -- Waiting for download
    local timer = os.startTimer(1/20*2)
    while true do
        local event, request_url, body = os.pullEvent()

        if event == "http_failure" and request_url == url then
            -- Error
            timer = -1
            load_anim_update("fail")

            return false, ("Could not download url \'%s\': %s"):format(url, (body or "unknown"))
        elseif event == "http_success" and request_url == url then
            -- Return content
            timer = -1
            load_anim_update("ok")

            local content = body.readAll()
            body.close()

            return true, content
        elseif event == "timer" and request_url == timer then
            -- Update loadbar
            load_anim_update()

            timer = os.startTimer(1/20*2)
        end
    end
end

-- Check for dependency
if not success then
    local _,y = term.getCursorPos()
    local input = "?"

    -- Prompt
    term.setCursorPos(1,y)
    term.setTextColor(colors.white)
    printError("Module \'pngLua\' is missing!")
    term.write("Would you like to download it? [Y/n] ")
    input = io.read()

    if input:upper() == 'Y' or input == '' or input:lower() == "yes" then
        -- Download
        local destination = fs.getDir(shell.getRunningProgram())
        local url = "https://raw.githubusercontent.com/9551-Dev/pngLua/master/png.lua"

        -- Status message
        term.setCursorPos(1,y+2)
        term.write("Downloading url ")
        term.setTextColor(colors.gray)
        print(("\'%s\'"):format(url))

        _,y = term.getCursorPos()
        if (16+#url)%w >= 51-9 then
            term.setCursorPos(1,y-1)
        else
            term.setCursorPos(((16+#url)%w+4), y-1)
        end

        local module_success, module = downloadFile(url)
        
        -- Save module
        if not module_success then
            term.setCursorPos(1,y+3)
            printError(module)
        end

        local path = fs.combine(destination, "png.lua")

        local file = fs.open(path, 'w')
        file.write(module)
        file.close()

        _,y = term.getCursorPos()
        term.setCursorPos(1,y+1)
        term.setTextColor(colors.green)
        print(("Saved at \'/%s\'"):format(path))
    else
        -- Aborting
        term.setTextColor(colors.white)
        print("Aborting.")
        return false, "Module \'pngLua\' is missing"
    end
end

--- Encodes a given string via base64.
-- Original one stolen from GitHub iskolbin/Ibase64 | MIT licence
--
-- @param b64 string The encoded base64 string.
-- @return string The decoded base64 string.
local function base64Decode(b64)
    local encoder = {}
	for b64code, char in pairs{[0]='A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/','='} do
		encoder[b64code] = char:byte()
	end

	local decoder = {}
	for b64code, charcode in pairs(encoder) do
		decoder[charcode] = b64code
	end

	local pattern = '[^%w%+%/%=]'
	if decoder then
		local s62, s63
		for charcode, b64code in pairs(decoder) do
			if b64code == 62 then s62 = charcode
			elseif b64code == 63 then s63 = charcode
			end
		end
		pattern = ('[^%%w%%%s%%%s%%=]'):format(string.char(s62), string.char(s63))
	end

	b64 = b64:gsub(pattern, '')
	local cache = {}
	local t, k = {}, 1
	local n = #b64
	local padding = b64:sub(-2) == '==' and 2 or b64:sub(-1) == '=' and 1 or 0
	for i = 1, (padding > 0 and n-4 or n), 4 do
		local a, b, c, d = b64:byte(i, i+3)
		local s
		local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
		s = string.char(bit32.extract(v,16,8), bit32.extract(v,8,8), bit32.extract(v,0,8))
		t[k] = s
		k = k + 1
	end

	if padding == 1 then
		local a, b, c = b64:byte(n-3, n-1)
		local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
		t[k] = string.char(bit32.extract(v,16,8), bit32.extract(v,8,8))
	elseif padding == 2 then
		local a, b = b64:byte(n-3, n-2)
		local v = decoder[a]*0x40000 + decoder[b]*0x1000
		t[k] = string.char(bit32.extract(v,16,8))
	end
	return table.concat(t)
end

-- Logging
local term = term

local _, log_offset = term.getCursorPos()
local log_output
local log_limit_upper, log_limit_lower = 1,log_offset
local log = {}

local original_scroll = term.scroll
local function log_scroll(amount)
    
    for i=1, amount do
        for j=log_limit_upper,h do
            log[j-1] = log[j]
            log[j] = nil
        end
        log_limit_upper = log_limit_upper - 1
        log_limit_lower = log_limit_lower - 1
    end

    original_scroll(amount)
end

local original_write = term.write
local function log_write(line)
    local x,y = term.getCursorPos()
    y = y-log_offset
    if y > log_limit_lower then
        log_limit_lower = y
    end

    if not log[y] then
        log[y] = (' '):rep(w)
    end

    log[y] = strings.ensure_width(log[y]:sub(1,x-1)..line..log[y]:sub(x+#line-1), w)
    original_write(line)
end

term.write = log_write
term.scroll = log_scroll

-- Variables
local skin

local dont_ask = false
local destination = 'output.3dj'
local mode = ''

-- Options
local argument_zero = fs.getName(shell.getRunningProgram())
local args = { ... }
local options
options = {
    [{short = 'v', full = "version"}] = {
        has_value = false,
        value_optional = false,
        description =
[[Short description of the program, including the version, author etc.]],
        func = function()
            -- Get header
            local file = fs.open(shell.getRunningProgram(), 'r')
            local line = ""
            local info = {}
            local headerEnded = false

            -- Parse informations
            repeat
                line = file.readLine()
                if line then
                    if not line:match("^%-%-") then
                        headerEnded = true
                    else
                        local key, value = line:match("^%-%- @([%w_]+)%s+(.*)$")
                        if key and value then
                            info[key] = value
                        end
                    end
                else
                    headerEnded = true
                end
            until headerEnded
            file.close()

            -- Print out
            term.setTextColor(colors.white)
            print(("sculpture %s  Copyright (C) %s %s\nLicence: %s"):format(info.version, info.copyright, info.author, info.licence))

            return true
        end
    },

    [{short = 'h', full = "help"}] = {
        has_value = true,
        value_optional = true,
        description =
[[Returns the programs usage and all its arguments. '--help <argument>' will explain a given argument in detail.
You are using it right now.]],
        func = function(value)
            if value then
                -- Print the arguments given description
                for option, body in pairs(options) do
                    if option.short == value or option.full == value then
                        -- Usage
                        term.setTextColor(colors.lightGray)
                        term.write(("Usage: %s [...] <-%s | --%s>"):format(argument_zero, option.short, option.full))
                        if body.has_value then
                            term.write((" <value%s>"):format(body.value_optional and '?' or ''))
                        end

                        -- Description
                        term.setTextColor(colors.white)
                        print(("\n\n%s"):format(body.description))
                        return true
                    end
                end
                -- Given argument does not exist; Proceed with default help text
            end

            -- Description
            local file = fs.open(shell.getRunningProgram(), 'r')
            local line = ""
            local description = ""
            local headerEnded = false

            -- Get informations from header
            repeat
                line = file.readLine()
                if line then
                    if not line:match("^%-%-") then
                        headerEnded = true
                    elseif line:sub(1,4) ~= "-- @" and line:sub(1,3) ~= "---" then
                        description = description..line:sub(4).."\n"
                    end
                else
                    headerEnded = true
                end
            until headerEnded
            file.close()

            term.setTextColor(colors.white)
            print(description:sub(1, #description-1))

            -- Usage
            print("Usage:")
            print(("  %s <mode> -p <username | UUID> [options]"):format(argument_zero))
            print(("  %s <mode> -i <path> [options]"):format(argument_zero))
            print(("  %s -h <option_name>"):format(argument_zero))
            print(("  %s -v\n"):format(argument_zero))

            print("Modes:\n  head, normal\n")

            print("Options:")

            -- Options max length
            local option_len = 1
            for option, body in pairs(options) do
                if #option.full > option_len then
                    option_len = #option.full
                end
            end

            -- Options
            local scroll
            for option, body in pairs(options) do
                -- Option name
                term.setTextColor(colors.white)
                term.write('  -'..option.short..','.."--"..option.full)

                -- Connector
                term.setTextColor(colors.gray)
                term.write(('.'):rep(option_len-#option.full+1))

                -- Setup description
                local description_begin = 9+option_len
                local description = strings.wrap(body.description:sub(1, (body.description:find('\n') or #body.description+1)-1), w-description_begin)
                
                -- Print out description aligned
                term.setTextColor(colors.lightGray)
                local _,y = term.getCursorPos()
                scroll = false
                for i,line in ipairs(description) do
                    local ypos = y+i-1
                    if ypos > h then
                        ypos = h
                        term.scroll(1)
                        scroll = true
                    end
                    term.setCursorPos(description_begin, ypos)
                    term.write(line)
                end

                -- Reposition cursor for next option
                if scroll then
                    term.scroll(2)
                    term.setCursorPos(1, h)
                else
                    term.setCursorPos(1,y+#description+1)
                end
            end

            -- Reposition cursor and advertice log feature if needed
            if scroll then
                term.setCursorPos(1,h-1)
            end
            print()

            return true
        end
    },

    [{short = 'f', full = "force"}] = {
        has_value = false,
        value_optional = false,
        description =
[[Forces to continue instead of prompting for permission on certain steps.
This option should only be used with caution!]],
        func = function()
            dont_ask = true
        end
    },

    [{short = 'l', full = "log"}] = {
        has_value = true,
        value_optional = true,
        description =
[[Opens the output at the end in a scrollable window.
An aditional value will tell the program to log the output in a desired file.]],
        func = function(value)
            if not value then
                local path = "log_sculp_"
                local num = 1

                while fs.exists(path..num) do
                    num = num+1
                end

                value = path..num..".log"
            end

            log_output = value
            return true
        end
    },

    [{short = 'p', full = "player"}] = {
        has_value = true,
        value_optional = false,
        description =
[[Determines the player skin that should be used (input).
A request to the Mojang API will be made to fetch the skin.

The following value either represents the Minecraft player ...
* username  ; length: 3-16, chars: { a-z, A-Z, 0-9, _ }
* UUID      ; 32-bit value in hex

Either of those must be in the given format.
Cannot be set within a local image file. (@see -f, --file)]],
        func = function(value)
            -- Skin already defined
            if skin then
                return false, "A skin png already got provided. Only one can be procceeded at the same time"
            end

            --Validate given value
            local valid_username = (string.match(value, "^%a[%w_]*$") ~= nil and string.len(value) >= 3 and string.len(value) <= 16)
            local valid_UUID = (string.match(value, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil or string.match(value, "^%x%x%x%x%x%x%x%x%%x%x%x%x%%x%x%x%x%%x%x%x%x%%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil)

            if not (valid_UUID or valid_username) then
                return false, "Given player name or UUID is invalid"
            end
            
            if not valid_UUID and valid_username then
                -- Get players UUID from their username via the Mojang API
                local _,y = term.getCursorPos()
                term.setCursorPos(1,y)
                term.setTextColor(colors.white)
                term.write("Get player UUID ")
                local profile_data_success, profile_data = downloadFile(("https://api.mojang.com/users/profiles/minecraft/%s"):format(value))
                print()

                -- Failed
                if not profile_data_success then
                    return false, ("Error while requesting player data from Mojang: %s"):format(profile_data_success)
                end

                -- Decode profile data
                profile_data = textutils.unserialiseJSON(profile_data)
                if not (profile_data and profile_data.id) then
                    return false, "Could not decode player profile data from Mojang"
                end

                -- Store UUID
                value = profile_data.id
            end

            -- Request player data from Mojang
            local _,y = term.getCursorPos()
            term.setCursorPos(1,y)
            term.setTextColor(colors.white)
            term.write("Request player data ")

            local skin_url = ("https://sessionserver.mojang.com/session/minecraft/profile/%s?unsigned=false"):format(value)
            local profile_data_success, profile_data = downloadFile(skin_url)
            print()

            -- Failed
            if not profile_data_success then
                return false, "Could not decode player profile data from Mojang"
            end

            -- Decode profile data
            profile_data = textutils.unserializeJSON(profile_data)
            if not profile_data.properties then
                return false, "Could not parse profile data"
            end

            -- Process profile data
            for _, property in ipairs(profile_data.properties) do
                if property.name == "textures" then
                    -- Decode texture data to get actual skin URL
                    local texture_data = textutils.unserializeJSON(base64Decode(property.value)) -- @todo Base 64 decode
                    if not texture_data then
                        return false, "Could not parse property of profile data"
                    end

                    if texture_data.textures and texture_data.textures.SKIN then
                        -- Download skin FOR REAL NOW
                        _,y = term.getCursorPos()
                        term.setCursorPos(1,y)
                        term.setTextColor(colors.white)
                        term.write("Download player skin ")
                        local skin_data_success, skin_data = downloadFile(texture_data.textures.SKIN.url, true)
                        print()

                        -- Failed
                        if not skin_data_success then
                            return false, ("Could not download player skin: %s"):format(skin_data)
                        end

                        local success, loadedPng = pcall(pngImage, nil, { input=skin_data })
                        if not success then
                            return false, ("Could not load provided skin: %s"):format(loadedPng)
                        end
                    
                        skin = loadedPng
                        return true
                    end
                end
            end

            return false, "Uncaught error during fetching the skin from Mojang"
        end
    },

    [{short = 'i', full = "input"}] = {
        has_value = true,
        value_optional = false,
        description =
[[Uses a .png image for the player skin (input).
The image can be either in the old (before 1.8) or new
Minecraft skin format.

Cannot be set within a local image file. (@see -p, --player)]],
        func = function(value)
            -- Get correct path
            local second_guess = fs.combine(fs.getDir(shell.getRunningProgram(), value))
            if not fs.exists(value) then
                if fs.exists(second_guess) then
                    value = second_guess
                else
                    -- Path does not exist
                    return false, ("File \'%s\' does not exist"):format(value)
                end
            end

            -- We dont do that here
            if fs.isDir(value) then
                return false, "Cannot load skin; A .png file must be provided instead of a folder"
            end

            local success, loadedPng = pcall(pngImage, value)
            if not success then
                return false, ("Could not load provided skin: %s"):format(loadedPng)
            end

            skin = loadedPng
            return true
        end
    },

    [{short = 'o', full = "output"}] = {
        has_value = true,
        value_optional = false,
        description =
[[Destination to where the result(s) should be stored.
If multible files are going to be saved as output,
they get numbered by either adding a number to the end or inserting them via string.format, if \'%d\' is inside the name.
A second \'%d\' will indicate the maximum.]],
        func = function(value)
            destination = value
        end
    }
}

-- No arguments? Print out help
if #args < 2 then
    table.insert(args, "-h")
end

-- Check mode
if not (args[1] == "head" or args[1] == "normal") then
    printError("Given mode is not valid. Get some help.")
    return false
end

-- Go through all given arguments
mode = args[1]
local option_pos = 2
while option_pos <= #args do
    local valid = false

    -- Check for valid option
    for option, body in pairs(options) do
        if '-'..option.short == args[option_pos] or "--"..option.full == args[option_pos] then
            -- Found; Execute options logic
            if body.has_value then
                if args[option_pos+1] and args[option_pos+1]:sub(1,1) ~= '-' then
                    -- Run with value
                    local success, err = body.func(args[option_pos+1])
                    if not success then
                        term.setTextColor(colors.white)
                        printError(("Option \'%s\' has thrown the following error: %s"):format(args[option_pos], err))
                        print("Aborting.")

                        return false
                    end
                    valid = true
                    option_pos = option_pos+2
                    break
                elseif not body.value_optional then
                    -- Invalid command passed
                    term.setTextColor(colors.white)
                    printError(("Option \'%s\' requires a value. Type \'%s --help\'."):format(args[option_pos], argument_zero))
                    print("Aborting.")

                    return false, "Option requires value"
                end
            end

            -- Run without value
            local success, err = body.func()
            if not success then
                term.setTextColor(colors.white)
                printError(("Option \'%s\' has thrown the following error: %s"):format(args[option_pos], err))
                print("Aborting.")

                return false
            end

            valid = true
            option_pos = option_pos+1
        end
    end

    if not valid then
        -- Non-existent argument found
        term.setTextColor(colors.white)
        printError(("Argument \'%s\' does not exist. Type \'%s --help\'."):format(args[option_pos], argument_zero))
        print("Aborting.")

        return false, "Given argument does not exist"
    end
end

-- @todo Check if all needed arguments were provided!

-- Actual start of program
local model = {}

-- Space sizes
local space_size = {
    head = {
        size = vector.new(16, 16, 16),
        offset = vector.new(4,1,4)
    },
    normal = {
        size = vector.new(16, 32, 16),
        offset = vector.new(1,1,6)
    }
}

-- Generate space
for x=1, space_size[mode].size.x do
    for y=1, space_size[mode].size.y do
        for z=1, space_size[mode].size.z do
            if not model[x] then
                model[x] = {}
            end
            if not model[x][y] then
                model[x][y] = {}
            end

            model[x][y][z] = ' '
        end
    end
end

-- Generate Head
if mode == "head" then
    print(("pixel 12,12 has the colors r:%d g:%d b:%d"):format(skin:get_pixel(12,12):unpack()))
end

-- Save log file
if log_output then
    local file = fs.open(log_output, 'w')

    -- Write command to file
    local command = ("> %s"):format(argument_zero)
    for i=1,#args do
        command = command..' '..args[i]
    end
    file.writeLine(command)

    -- Write logs to file
    for i=log_limit_upper,log_limit_lower do
        file.writeLine(log[i] or whitespace)
    end

    file.close()

    -- Notice
    term.setTextColor(colors.pink)
    print(("Log has been saved to \'%s\'."):format(log_output))
end