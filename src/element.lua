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

    local setDelimiterType = function(type)
        if self.delimiter == enums.Delimiters.UNSET then
            self.delimiter = type
            return true
        end

        return self.delimiter == type
    end
    
    local evaluateDelimiter = function(input, start)
        local quoted = false
        local len <const> = #input
        local curr = start

        -- Step 1: skip string literals which are wrapped in matching quotes
        while curr < len do
            ::continue::
            local quotePos = string.find(input, enums.Glyphs.QUOTE, curr)
            if quoted then
                if quotePos == -1 then
                    self.error = enums.ErrorTypes.UNTERMINATED_QUOTE
                    return len
                end
                quoted = false
                curr = start + 1
                goto continue
            end

            local spacePos = string.find(input, enums.Glyphs.SPACE, curr)
            local commaPos = string.find(input, enums.Glyphs.COMMA, curr)

            if spacePos == nil then
                spacePos = -1
            end

            if commaPos == nil then
                commaPos = -1
            end

            if quotePos > -1 and quotePos < spacePos and quotePos < commaPos then
                quoted = true
                start = quotePos
                curr = start + 1
                goto continue
            elseif spacePos == commaPos then
                -- EOL
                return len
            end

            -- Use the first valid delimiter
            if spacePos == -1 and commaPos > -1 then
                curr = commaPos
            elseif spacePos > -1 and commaPos == -1 then
                curr = spacePos
            elseif spacePos > -1 and commaPos > -1 then
                curr = math.min(spacePos, commaPos)
            end
            break
        end

        -- Step 2: Determine delimiter if not set
        local space = -1
        local equal = -1
        local quote = -1
        while self.delimiter == enums.Delimiters.UNSET and curr < len do
            local c <const> = input[curr]

            if c == enums.Glyphs.COMMA then
                self.setDelimiterType(enums.Delimiters.COMMA)
                break
            end

            if c == enums.Glyphs.SPACE and space == -1 then
                space = curr
            end

            if c == enums.Glyphs.EQUAL and equal == -1 and quote == -1 then
                equal = curr
            end

            -- Ensure quotes are toggled, if tokens was reached
            if c == enums.Glyphs.QUOTE then
                if quote == -1 then
                    quote = curr
                else
                    quote = -1
                end
            end

            curr = curr + 1
        end

        -- Case: EOL with no delimiter found
        if self.delimiter == enums.Delimiters.UNSET then
            if space == -1 then return len end

            setDelimiterType(enums.Delimiters.SPACE)
            curr = space
        end

        -- Step 3: use delimiter type to find the next end pos
        -- which will result in the range [start,end] to be the next token
        local idx <const> = string.find(input, self.delimiter, start)
        if idx == nil then
            return len
        end
        
        return math.min(len, idx)
    end

    local evaluateToken = function(input, start, nd)
        -- Sanity check.
        if self.element == nil then
            error('Element was no initialized.')
        end

        local token <const> = trim(string.sub(input, start, nd))
        local equalPos <const> = string.find(token, enums.Glyphs.EQUAL)
        if equalPos ~= nil then
            local key <const> = trim(string.sub(token, 0, equalPos))
            local val <const> = trim(string.sub(token, equalPos + 1, #token))
            self.element.upsert(KeyVal.new(key, val))
            return
        end

        self.element.upsert(KeyVal.new(nil, token))
    end
    
    local parseTokenStep = function(input, start)
        local len <const> = #input
        
        -- Find first non-space character
        while start < len do
            ::continue::
            if input[start] == enums.Glyphs.SPACE then
                start = start + 1
                goto continue
            end

            -- else, current char is non-space
            break
        end

        if start >= len then
            return
        end

        local nd <const> = evaluateDelimiter(input, start)
        evaluateToken(input, start, nd)
        return nd
    end

    -- public 

    self.parseTokens = function(input, start)
        local nd = start
        while nd < #input do
            nd = parseTokenStep(input, nd+1)
            if self.error ~= nil then break end
        end
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