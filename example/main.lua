local yes <const> = require('../lib')
local elements, errors = yes.parse('doc.cut')

-- print all elements
for _,v in pairs(elements) do
    print(tostring(v))
end

-- print errors with line numbers, if any
for _,v in pairs(errors) do
    -- do not report empty lines
    if v.type ~= yes.enums.ErrorTypes.EOL_NO_DATA then
        print('Error: '..v.type)
    end
end
