local enums = require('enums')
local KeyVal = require('keyval')
local trim = require('utils.trim')

local Element = {}
Element.new = function()
    local self = {
        attributes = {},
        text = '',
        args = {},
        type = enums.ElementType.STANDARD
    }

    self.tostring = function()
        return enums.glyphForType(self.type)..self.text..' '..self:printArgs()
    end

    self.setAttributes = function(attrs)
        self.attributes = {}
        for i in ipairs(attrs) do
            local a = attrs[i]
            -- Perform a sanity check
            if a.type ~= enums.ElementType.ATTRIBUTE then
                error('Element is not an attribute!')
            end
            self.attributes[#self.attributes] = a
        end
    end

    -- helper func 
    local findKey = function(key)
        if key == nil then return -1 end
        for i in ipairs(self.args) do
            local e = self.args[i]
            if e.key ~= nil and string.lower(e.key) == string.lower(key) then
                return i
            end
        end
        return -1
    end

    -- public funcs

    self.upsert = function(keyval)
        local idx <const> = findKey(keyval.key)

        -- Insert if no match was found
        if idx == -1 then
            self.args[#self.args] = keyval
            return
        end

        -- Update by replacing
        self.args[idx] = keyval
    end

    self.hasKey = function(key)
        return findKey(key) > -1
    end

    self.hasKeys = function(keyList)
        for i in pairs(keyList) do
            if findKey(keyList[i]) == -1 then
                return false
            end
        end

        return true
    end

    self.getKeyValue = function(key, orValue)
        local idx <const> = findKey(key)

        if idx ~= -1 then
            return self.args[idx].val
        end

        -- return default value
        return orValue
    end

    self.getKeyValueAsInt = function(key, orValue)
        -- Lua does not have strict integer types,
        -- so we just round to the nearest whole number
        local num = self.getKeyValueAsNumber(key, orValue)
        if num >= 0 then num = math.floor(num + 0.5) else num = math.ceil(num - 0.5) end
        return num
    end

    self.getKeyValueAsBool = function(key, orValue)
        -- Get and parse the arg by key
        local val = self.getKeyValue(key, orValue)
        
        if val ~= nil then
            -- Anything else is considered falsey
            return string.lower(val) == 'true'
        end

        return orValue
    end

    self.getKeyValueAsNumber = function(key, orValue)
        -- Get and parse the arg by key
        local val = tonumber(self.getKeyValue(key, orValue))

        if val ~= nil then return val end

        return orValue
    end

    self.printArgs = function()
        local res = ''
        local len <const> = #self.args
        for i = 1, len, 1 do
            res = res..tostring(self.args[i])
            if i < len - 1 then
                res = res..', '
            end
        end

        return res
    end

    return self
end

local ElementParser = {}
ElementParser.new = function()
    local self = {
        delimiter = enums.Delimiters.UNSET,
        element = nil,
        error = nil,
        lineNumber = -1
    }

    local parseTokenStep = function(input, start)
    end

    local evaluateDelimiter = function(input, start)
    end

    local evaluateToken = function(input, start, nd)
    end

    local setDelimiterType = function(type) 
    end

    self.parseTokens = function(input, start)
    end

    return self
end

local read <const> = function(line)
    local parser <const> = ElementParser.new()

    -- Step 1: Trim whitespace and start at the first valid character
    line = trim(line)
    local len <const> = #line

    if len == 0 then
        parser.error = enums.ErrorTypes.EOL_NO_DATA
        return parser
    end

    local pos = 0
    local type = enums.ElementType.STANDARD

    while pos < len do
        ::continue::
 
        local glyph <const> = line[pos]

        -- Find first non-space character
        if glyph == enums.Glyphs.SPACE then
            pos = pos + 1
            goto continue
        end

        -- Potential user-defined element found
        if not enums.glyphIsReserved(glyph) then
            break
        end

        -- Step 2: If the first valid character is a reserved prefix,
        -- then tag the element and continue searching for the name start pos
        if glyph == enums.Glyphs.HASH then
            if type == enums.ElementType.STANDARD then
                -- All characters beyond the hash is treated as a comment
                parser.element = Element.new()
                parser.element.text = string.sub(line, pos+1)
                parser.element.type = enums.ElementType.COMMENT
                return parser
            end
        elseif glyph == enums.Glyphs.AT then
            if type ~= enums.ElementType.STANDARD then
                parser.error = enums.ErrorTypes.BADTOKEN_AT
                return parser
            end
            type = enums.ElementType.ATTRIBUTE
            pos = pos + 1
            goto continue
        elseif glyph == enums.Glyphs.BANG then
            if type ~= enums.ElementType.STANDARD then
                parser.error = enums.ElementType.BADTOKEN_BANG
                return parser
            end
            type = enums.ElementType.GLOBAL
            pos = pos + 1
            goto continue
        end

        -- Terminates
        break
    end

    -- Step 3: find the end of the element name (first space or EOL)
    pos = math.min(pos, len)
    local idx <const> = line.find(enums.Glyphs.SPACE, pos)

    -- EOL
    if idx == nil then
        local err = enums.ErrorTypes.EOL_MISSING_GLOBAL
        if type == enums.ElementType.ATTRIBUTE then
            err = enums.ErrorTypes.EOL_MISSING_ATTRIBUTE
        elseif type == enums.ElementType.GLOBAL then
            err = enums.ErrorTypes.EOL_MISSING_GLOBAL
        end

        parser.error = err
        return parser
    end

    local nd <const> = math.min(len, idx)
    local text <const> = string.sub(line, pos, nd)

    parser.element = Element.new()
    parser.element.type = type
    parser.element.text = text

    -- Step 4: parse remaining tokens, if any, and return results
    parser.parseTokens(line, nd)
    return parser
end

return read