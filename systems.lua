LineDrawSystem = class("LineDrawSystem", System)
function LineDrawSystem:draw()
    for i, v in pairs(self.targets) do
        love.graphics.draw(v:get("Image").image, v:get("Position").l, v:get("Position").t)
    end
end

function LineDrawSystem:requires()
    return {"isLine"}
end


SegmentStringDrawSystem = class("SegmentStringDrawSystem", System)
function SegmentStringDrawSystem:draw()
    for i, v in pairs(self.targets) do
        local position = v:get("Position")
        local size = v:get("Size")

        love.graphics.setColor(0, 0, 0)
        love.graphics.print(v:tostring(), position.l , math.floor(position.t + size.height))
        love.graphics.setColor(255, 255, 255)
    end
end

function SegmentStringDrawSystem:requires()
    return {"isSegment"}
end


SegmentDrawSystem = class("SegmentDrawSystem", System)
function SegmentDrawSystem:draw()
    for i, v in pairs(self.targets) do
        local position = v:get("Position")
        local size = v:get("Size")

        love.graphics.setColor(255, 0, 255)
        love.graphics.rectangle("line", position.l, position.t, size.width, size.height)
        -- love.graphics.line(position.l, 0, position.l + size.width, 0)
        -- love.graphics.line(position.l + size.width, 0, position.l + size.width, size.height)
        -- love.graphics.line(position.l, size.height, position.l + size.width, size.height)
        -- love.graphics.line(position.l, 0, position.l, size.height)
        love.graphics.setColor(255, 255, 255)
    end
end

function SegmentDrawSystem:requires()
    return {"isSegment"}
end


ComponentsDrawSystem = class("ComponentsDrawSystem", System)
function ComponentsDrawSystem:draw()
    love.graphics.setColor(0, 255, 0)
    for i, v in pairs(self.targets) do
        local parent_position = v:getParent():get("Position")
        local parent_size = v:getParent():get("Size")
        local range = v:get("Range")

        love.graphics.push()
            love.graphics.translate(parent_position.l, parent_position.t)
            love.graphics.line(range.s, 0, range.s, parent_size.height)
            love.graphics.line(range.e, 0, range.e, parent_size.height)
        love.graphics.pop()
    end
    love.graphics.setColor(255, 255, 255)
end

function ComponentsDrawSystem:requires()
    return {"isComponent"}
end



SegmentRecognitionSystem = class("SegmentRecognitionSystem", System)
function SegmentRecognitionSystem:update (dt)
    for i, segment in pairs(self.targets) do
        local match = lexicon:lookup(segment:tostring())

        if #match == 1 then
            if config.DEBUG then
                print("Segment " .. i .. " succesfully recognized as `" .. match[1] .."'.")
            end

            local match_copy = match[1]

            local recognized_components = {}
            for j, component in pairs(segment._components) do
                local comp_string = component:get("String").string
                if comp_string ~= ".*" then
                    table.insert(recognized_components, comp_string)
                end
            end

            table.sort(recognized_components, function (a, b) return #a > #b end)

            for j=1, #recognized_components do
                match_copy = string.gsub(match_copy, recognized_components[j], "#")
            end

            local match_substring = explode("#", match_copy)
            local match_table = {}
            for j=1, #match_substring do
                if match_substring[j] ~= "" then
                    table.insert(match_table, match_substring[j])
                end
            end

            local match_components = {}
            for j=1, #segment._components do
                if segment._components[j]:get("String").string == ".*" then
                    table.insert(match_components, segment._components[j])
                end
            end

            assert(#match_table == #match_components)

            for j=1, #match_table do
                match_components[j]:get("String").string = match_table[j]
            end

            segment:remove("isNotRecognized")
        end
    end
end

function SegmentRecognitionSystem:requires ()
    return {"isSegment", "isNotRecognized"}
end



local HUD_HEIGHT = 24
local HUD_PADDING = 4
local HUD_COLOR = {32, 40, 63}
local HUD_LINE_COLOR = {56, 61, 81}
-- local HUD_COLOR = {73, 93, 127}
-- local HUD_LINE_COLOR = {125, 143, 165}

HUDDrawSystem = class("HUDDrawSystem", System)
function HUDDrawSystem:draw()
    local width, height = love.graphics.getDimensions()
    local x, y = love.mouse.getPosition() -- get the position of the mouse

    love.graphics.setColor(unpack(HUD_COLOR))
    love.graphics.rectangle("fill", 0, height - HUD_HEIGHT, width, height)
    love.graphics.setColor(unpack(HUD_LINE_COLOR))
    love.graphics.line(0, height - HUD_HEIGHT - 1, width, height - HUD_HEIGHT - 1)

    love.graphics.setColor(255, 255, 255)
    love.graphics.push()
        love.graphics.translate(HUD_PADDING, height - HUD_HEIGHT + HUD_PADDING)

        for _, seg in pairs(engine:getEntitiesWithComponent("isSegment")) do
            local pos = seg:get("Position")
            local size = seg:get("Size")
            if x >= pos.l and x < pos.l + size.width and y >= pos.t and y < pos.t + size.height then
                love.graphics.print("Segment Coordinates: " .. tostring(x - pos.l) .. "|" .. tostring(y - pos.t), 0, 0)
            end
        end
        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), width - 55, 0)
    love.graphics.pop()
end

function HUDDrawSystem:requires()
    return {}
end