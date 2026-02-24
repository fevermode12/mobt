_addon.name = 'mobt'
_addon.author = 'Fever'
_addon.version = '2.0'
_addon.command = 'mobt'

require('luau')
config = require('config')
texts = require('texts')

-- DEFAULT SETTINGS
local defaults = {
    max_distance = 50,
    max_display  = 15,
    pos = { x = 300, y = 200 },

    bg = { alpha = 180, red = 0, green = 0, blue = 0 },

    text = {
        font = 'Consolas',
        size = 12,
        alpha = 255,
        red = 255,
        green = 255,
        blue = 255,
    },

    color_rules = {
        nm = { names = {}, ids = {} },
        ph = { ids = {} }
    }
}

local settings = config.load(defaults)

settings.color_rules = settings.color_rules or {}
settings.color_rules.nm = settings.color_rules.nm or {}
settings.color_rules.ph = settings.color_rules.ph or {}

settings.color_rules.nm.names = settings.color_rules.nm.names or {}
settings.color_rules.nm.ids = settings.color_rules.nm.ids or {}
settings.color_rules.ph.ids = settings.color_rules.ph.ids or {}

if type(settings.pos) ~= "table" then
    settings.pos = { x = defaults.pos.x, y = defaults.pos.y }
end


-- GUI
local tracker_box = texts.new("", settings)
tracker_box:draggable(true)
tracker_box:show()


-- HELPERS
local function normalize_hex(input)
    input = tostring(input):gsub("0x","")
    return tonumber(input,16)
end

local function is_in_table(tbl, value)
    if type(tbl) ~= "table" then return false end
    for _,v in ipairs(tbl) do
        if tonumber(v) == tonumber(value) then
            return true
        end
    end
    return false
end

local function remove_from_table(tbl, value, is_string)
    if type(tbl) ~= "table" then return end
    for i,v in ipairs(tbl) do
        if (is_string and v:lower() == value:lower())
        or (not is_string and tonumber(v) == tonumber(value)) then
            table.remove(tbl,i)
            return
        end
    end
end

local function get_color_type(mob)
    if is_in_table(settings.color_rules.nm.ids, mob.index) then
        return "nm"
    end

    for _,name in ipairs(settings.color_rules.nm.names) do
        if mob.name:lower() == name:lower() then
            return "nm"
        end
    end

    if is_in_table(settings.color_rules.ph.ids, mob.index) then
        return "ph"
    end

    return nil
end


-- MOB SCANNING
local function get_nearby_mobs()
    local mobs = {}
    local mob_array = windower.ffxi.get_mob_array()

    if type(mob_array) ~= "table" then return mobs end

    for _,mob in pairs(mob_array) do
        if mob and mob.valid_target and mob.status == 0 and mob.spawn_type == 16 then
            local dist = math.sqrt(mob.distance or 0)
            if dist <= settings.max_distance then
                table.insert(mobs,{
                    name = mob.name,
                    index = mob.index,
                    distance = dist,
                    color_type = get_color_type(mob),
                })
            end
        end
    end

    table.sort(mobs,function(a,b) return a.distance < b.distance end)
    return mobs
end


-- UPDATE LOOP
windower.register_event('prerender', function()

    local mobs = get_nearby_mobs()

    if #mobs == 0 then
        tracker_box:hide()
        return
    end

    local output = "Nearby Monsters\n"
    output = output .. "-----------------------------\n"

    local target = windower.ffxi.get_mob_by_target("t")
    local target_index = target and target.index

    for i,mob in ipairs(mobs) do
        if i > settings.max_display then break end

        local is_target = (target_index and mob.index == target_index)

        local r,g,b

        -- Base colors
        if mob.color_type == "nm" then
            if is_target then
                r,g,b = 255,40,40
            else
                r,g,b = 255,80,80
            end

        elseif mob.color_type == "ph" then
            if is_target then
                r,g,b = 0,220,255
            else
                r,g,b = 120,200,255
            end

        else
            if is_target then
                r,g,b = 255,255,180
            else
                r,g,b = 255,255,255
            end
        end

        local color_prefix = string.format("\\cs(%d,%d,%d)", r,g,b)

        -- Arrow logic
        local marker = " "
        if is_target then
            if mob.color_type == "nm" then
                marker = "\\cs(255,0,0)>>\\cr "
            elseif mob.color_type == "ph" then
                marker = "\\cs(0,255,255)>>\\cr "
            else
                marker = "\\cs(255,255,0)>\\cr "
            end
        end

        -- IMPORTANT: marker first, then apply row color
        output = output .. string.format(
            "%s%s%-20s [%.3X] %5.1f\\cr\n",
            marker,
            color_prefix,
            mob.name,
            mob.index,
            mob.distance
        )
    end

    tracker_box:text(output)
    tracker_box:show()

end)


-- SAVE GUI POSITION
windower.register_event('mouse', function(type)
    if type == 2 then
        local x,y = tracker_box:pos()
        settings.pos = { x = x, y = y }
        config.save(settings)
    end
end)

-- COMMANDS
windower.register_event('addon command', function(cmd, type, value)

    cmd = cmd and tostring(cmd):lower()
    type = type and tostring(type):lower()
    value = value and tostring(value)

    if cmd == "add" and type and value then

        if type == "nm" then
            if value:match("^%x+$") then
                table.insert(settings.color_rules.nm.ids, normalize_hex(value))
                windower.add_to_chat(207, "Added NM ID: "..value)
            else
                table.insert(settings.color_rules.nm.names, value)
                windower.add_to_chat(207, "Added NM Name: "..value)
            end

        elseif type == "ph" then
            if value:match("^%x+$") then
                table.insert(settings.color_rules.ph.ids, normalize_hex(value))
                windower.add_to_chat(207, "Added PH ID: "..value)
            end
        end

        config.save(settings)

    elseif cmd == "remove" and type and value then

        if type == "nm" then
            if value:match("^%x+$") then
                remove_from_table(settings.color_rules.nm.ids, normalize_hex(value))
                windower.add_to_chat(207, "Removed NM ID: "..value)
            else
                remove_from_table(settings.color_rules.nm.names, value, true)
                windower.add_to_chat(207, "Removed NM Name: "..value)
            end

        elseif type == "ph" then
            if value:match("^%x+$") then
                remove_from_table(settings.color_rules.ph.ids, normalize_hex(value))
                windower.add_to_chat(207, "Removed PH ID: "..value)
            end
        end

        config.save(settings)

    elseif cmd == "distance" and type then
        settings.max_distance = tonumber(type)
        config.save(settings)

    elseif cmd == "max" and type then
        settings.max_display = tonumber(type)
        config.save(settings)

    elseif cmd == "help" then
        windower.add_to_chat(200,"mobt commands:")
        windower.add_to_chat(207,"mobt add nm \"Name\"")
        windower.add_to_chat(207,"mobt add nm HEX")
        windower.add_to_chat(207,"mobt add ph HEX")
        windower.add_to_chat(207,"mobt remove nm \"Name\"")
        windower.add_to_chat(207,"mobt remove nm HEX")
        windower.add_to_chat(207,"mobt remove ph HEX")
        windower.add_to_chat(207,"mobt distance <number>")
        windower.add_to_chat(207,"mobt max <number>")

    end
end)

-- CLEANUP
windower.register_event('logout', function()
    tracker_box:hide()
    tracker_box:destroy()
end)