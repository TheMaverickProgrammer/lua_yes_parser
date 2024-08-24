local KeyVal = {}
KeyVal.new = function(key, val)
    local self = {
        key=key,
        val=val
    }

    self.tostring = function()
        if self.key == nil then
            return tostring(self.val)
        end

        return tostring(self.key)..tostring(self.v)
    end
    return self
end

return KeyVal