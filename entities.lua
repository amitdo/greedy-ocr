--[[
    greedy-ocr
    Original Work Copyright (c) 2015 Sebastian Spaar
------------------------------------------------------------------------
    entities.lua

]]

local config = require "_config"

local Entities = {}

Entities.Prototype = class("Prototype")
function Entities.Prototype:init (literal, image)
    self.isPrototype = true
    self.string = literal
    self.image = trim_image(image)
    self.image_bw = threshold_image(self.image)

    getmetatable(self).__tostring = function (t)
        return t.string
    end

    WORLD:addEntity(self)
end


Entities.Page = class("Page")
function Entities.Page:init (image, bounding_boxes)
    self.isPage = true
    self.image = image
    self.image_bw = threshold_image(image)
    self.position = {l = 0, t = 0}

    self.segments = {}

    for _, box in ipairs(bounding_boxes) do
        local l = box[1]
        local t = box[2]
        local width = box[3]
        local height = box[4]

        local segment = Entities.Segment:new(l, t, width, height, self)
        table.insert(self.segments, segment)
    end

    WORLD:addEntity(self)
end


-- all_white:
-- A helper function that checks whether every value in a table is
-- `255' (white).
local function all_white (t)
    for i=1, #t do
        if t[i] ~= 255 then return false end
    end

    return true
end

Entities.Segment = class("Segment")
function Entities.Segment:init (l, t, width, height, parent)
    self.parent = parent
    self.isSegment = true
    self.isNotRecognized = true
    self.position = {l = l, t = t}
    self.size = {width = width, height = height}

    local image_data = love.image.newImageData(width, height)
    image_data:paste(parent.image:getData(), 0, 0, l, t, width, height)
    self.image = love.graphics.newImage(image_data)

    self.components = {}
    local image_bw = threshold_image(self.image)

    -- Automatically split Segment into smaller components when
    -- specified so in `_config.lua'
    if config.automatically_split_segments then
        local lines = {}
        local component_edges = {}
        local search_black = true
        local num_white_rows = 0

        for column_idx=0, image_bw:getWidth() - 1 do
            local colors = {}

            for row_idx=0, image_bw:getHeight() - 1 do
                local r, g, b = image_bw:getData():getPixel(column_idx, row_idx)
                table.insert(colors, rgb2grey(r, g, b))
            end

            if not all_white(colors) then
                if search_black then
                    table.insert(component_edges, math.max(column_idx - 1, 0))
                    search_black = false
                end
            else
                if search_black then
                    goto continue
                else
                    num_white_rows = num_white_rows + 1

                    -- TODO: Magic number `3'---this is the minimum
                    -- amount of white pixels between components
                    if num_white_rows == 3 then
                        search_black = true
                        table.insert(component_edges, column_idx - 1)
                        num_white_rows = 0
                    end
                end
            end
            ::continue::
        end

        for i=1, #component_edges, 2 do
            local start = component_edges[i] - 3
            if start < 0 then start = 0 end

            local _end
            if i+1 == #component_edges then
                _end = image_bw:getWidth()
            else
                _end = component_edges[i+1] or image_bw:getWidth()
            end

            table.insert(self.components, Entities.Component(start, _end, self))
        end

    -- Do not split Segment, just create a single Component covering the
    -- whole Segment
    else
        table.insert(self.components, Entities.Component(0, width, self))
    end --if


    getmetatable(self).__tostring = function (t)
        local str = {}

        for _, component in pairs(t.components) do
            table.insert(str, component.string)
        end

        return table.concat(str)
    end

    WORLD:addEntity(self)
end

function Entities.Segment:recognize ()
    local pre_string, post_string = tostring(self), tostring(self)

    repeat
        pre_string = post_string

        -- local range = #self.components
        for i=1, #self.components do
            for prototype in PROTOTYPES:uniquePrototypes() do
            -- for j=1, #PROTOTYPES.entities do
                local component = self.components[i]

                if  config.UNKNOWN_COMPONENTS[component.string]
                and image_fits_image(prototype.image, component.image) then
                    if config.DEBUG then print("Checking component", i) end

                    local ratio, split_x = component:overlay({image_bw = PROTOTYPES._clusters_images[prototype.string], string = prototype.string})
                    local split_threshold

                    if config.high_confidence[prototype.string] then
                        split_threshold = config.HIGH_SPLIT_THRESHOLD
                    else
                        split_threshold = config.SPLIT_THRESHOLD
                    end

                    if ratio >= split_threshold then
                        component:split(split_x,
                                        split_x + prototype.image:getWidth() - 1,
                                        prototype.string)
                        WORLD:update()
                        goto continue
                    end
                end
            end --for: j
        end --for: i
        ::continue::

        post_string = tostring(self)

    until pre_string == post_string
end


function Entities.Segment:split (prototype)
    for i=1, #self.components do
        local component = self.components[i]

        if  config.UNKNOWN_COMPONENTS[component.string]
        and image_fits_image(prototype.image_bw, component.image) then
            if config.DEBUG then print("Checking component", i) end

            local ratio, split_x = component:overlay(prototype)
            print(ratio, split_x)
            local split_threshold = config.SPLIT_THRESHOLD

            if ratio >= split_threshold then
                component:split(split_x,
                                split_x + prototype.image_bw:getWidth() - 1,
                                prototype.string)
                WORLD:update()
            end
        end
    end
end


Entities.Component = class("Component")
function Entities.Component:init (start, e, parent)
    self.parent = parent
    self.isComponent = true
    self.range = {start, e}
    self.string = ".*"
    self.letter_frequencies = {}

    local width = e - start + 1
    local height = parent.size.height
    local image_data = love.image.newImageData(width, height)
    image_data:paste(parent.image:getData(), 0, 0, start, 0, width, height)
    self.image = love.graphics.newImage(image_data)
    self.image_bw = threshold_image(self.image)

    -- TODO: Write function that checks whether a component consists
    -- of a single character or more than one.
    if width <= 30 then self.string = ".?" end

    getmetatable(self).__tostring = function (t)
        return t.string
    end

    WORLD:addEntity(self)
end

function Entities.Component:split (start, e, str)
    local width = self.range[2] - self.range[1] + 1
    local start = math.max(0, start)
    local e = math.min(e, width)

    local new_components = {}

    if start >= config.MINIMUM_COMPONENT_WIDTH then
        table.insert(new_components, Entities.Component(self.range[1], self.range[1] + start, self.parent))
    end

    local middle_component = Entities.Component(self.range[1] + start, self.range[1] + e, self.parent)
    middle_component.string = str
    table.insert(new_components, middle_component)

    if math.abs(self.range[2] - self.range[1] - e) >= config.MINIMUM_COMPONENT_WIDTH then
        table.insert(new_components, Entities.Component(self.range[1] + e, self.range[2], self.parent))
    end

    local index = invert_table(self.parent.components)[self]
    WORLD:removeEntity(self)
    table.remove(self.parent.components, index)

    for i=1, #new_components do
        table.insert(self.parent.components, index + i - 1, new_components[i])
    end

    -- create a new Prototype from the recognized component (the middle
    -- one)
    if str then
        Entities.Prototype(middle_component.string, middle_component.image)
    end
end


-- Component:overlay:
-- Checks the similarity of this Component's image with another Entity.
-- The entity at least has to provide an `image_bw', that is, a binary
-- image.
-- Returns the x coordinate of the point where the two images are the
-- most similar.
--
-- @params:  prototype: The Entity whose image to check
--           |__@type: (id)
-- @returns: max_ratio: The highest similarity value
--           |__@type: number
--           split_x: The x coordinate where the two Entities are the
--           |        most similar
--           |__@type: number
function Entities.Component:overlay (prototype)
    assert(prototype.image_bw)
    -- assert(prototype.string)

    local sub_image = prototype.image_bw
    local image = self.image_bw

    assert(image:getWidth() >= sub_image:getWidth(), "too large")
    assert(image:getHeight() >= sub_image:getHeight(), "too high")

    local ratios = {}
    -- How many times the smaller image can be shifted over the larger
    -- ones in x/y direction (per pixel)
    local max_y = image:getHeight() - sub_image:getHeight() + 1
    local max_x = image:getWidth() - sub_image:getWidth() + 1

    local image_data = image:getData()
    local sub_image_data = sub_image:getData()
    local sub_width, sub_height = sub_image:getWidth(), sub_image:getHeight()


    for img_y=0, max_y - 1 do
        for img_x=0, max_x - 1 do

            local sum_and, sum_or = 0, 0

            for sub_y=0, sub_height - 1 do
                for sub_x=0, sub_width - 1 do
                    local image_pixel = image:getData():getPixel(img_x+sub_x, img_y+sub_y)
                    local sub_image_pixel = sub_image:getData():getPixel(sub_x, sub_y)

                    -- Let black pixels be evaluated to `1' and white
                    -- pixels to `0' (ref. "Character Segmentation
                    -- Using Visual Inter-word Constraints in a Text
                    -- Page", p. 5)
                    if image_pixel == 255 then
                        image_pixel = 0
                    else
                        image_pixel = 1
                    end

                    if sub_image_pixel == 255 then
                        sub_image_pixel = 0
                    else
                        sub_image_pixel = 1
                    end

                    sum_and = sum_and + bit.band(image_pixel, sub_image_pixel)
                    sum_or = sum_or + bit.bor(image_pixel, sub_image_pixel)

                end
            end
            table.insert(ratios, sum_and/sum_or)
        end
    end

    -- Get the position of the highest ratio
    local max_ratio_index, max_ratio = max_pair(ratios)
    -- IMPORTANT:
    -- From `max_ratio_index', 1 needs to be subtracted because the
    -- `ratios' tables starts indexing at 1 while the ImageData table
    -- (used in `:getData()') starts indexing at 0!
    max_ratio_index = max_ratio_index - 1

    -- The x coordinate where the highest similarity is
    local split_x = max_ratio_index % max_x

    if config.DEBUG then
        print("Overlaying:", prototype.string, max_ratio_index, max_ratio,
                             split_x, split_x + sub_image:getWidth() - 1)
    end


    -- if self.letter_frequencies[prototype.string] ~= nil then
    --     if prototype.string == max_pair(self.letter_frequencies) then
    --         local frequency = self.letter_frequencies[prototype.string]
    --         max_ratio = max_ratio + frequency * 20
    --         print(max_ratio)
    --     end
    -- end

    return max_ratio, split_x

    -- if max_ratio >= config.SPLIT_THRESHOLD then
    --     self:split(split_x, split_x + sub_image:getWidth() - 1, prototype.string)
    -- end
end

return Entities