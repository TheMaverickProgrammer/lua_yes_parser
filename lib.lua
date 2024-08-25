local enums = require('src.enums.lua')
local element = require('src.element.lua')

local Collector = {}

Collector.new = function()
    local self = {
        lineCount = 0,
        pendingAttrs = {},
        elements = {},
        errors = {}
    }

    function self.handleLine(line)
        self.lineCount = self.lineCount + 1
        local p = element.read(line)

        if(p.error ~= nil) then
            self.errors[#self.errors] = {
                line=self.lineCount,
                type=p.error
            }
            return
        end

        if(p.element.type == enums.ElementTypes.ATTRIBUTE) then
            self.pendingAttrs[#self.pendingAttrs] =  p.element
            return
        elseif p.element.type == enums.ElementTypes.STANDARD then
            p.element:setAttributes(self.pendingAttrs)
            self.pendingAttrs = {}
        end

        self.elements[#self.elements] = p.element
    end

    return self
end

local function parse(path)
    local c = Collector.new()

    for line in io.lines(path) do
        c.handleLine(line)
    end
    return c.elements, c.errors
end

return {
    parse=parse,
    enums=enums,
    element=element
}