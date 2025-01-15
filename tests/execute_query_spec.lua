local gel_query = require("gel-query")


describe('parameter parsing', function()
    it('should correctly parse parameters from query', function()
        local query = [[
                select <int64>$param1 + <float64>$param2;
            ]]
        local params = gel_query._find_params(query)
        assert.are.same({
            { type = 'int64',   name = 'param1' },
            { type = 'float64', name = 'param2' }
        }, params)
    end)

    it('should handle queries with no parameters', function()
        local query = "select 1 + 1;"
        local params = gel_query._find_params(query)
        assert.are.same({}, params)
    end)
end)

describe('parameter insertion', function()
    it('should correctly substitute parameter values', function()
        local query = "select <int64>$x + <int64>$y;"
        local params = {
            x = "1",
            y = "2"
        }
        local result = gel_query._insert_params(query, params)
        assert.are.equal("select 1 + 2;", result)
    end)

    it('should handle missing parameters', function()
        local query = "select <int64>$x + <int64>$y;"
        local params = {
            x = "1"
        }
        local result = gel_query._insert_params(query, params)
        -- The $y parameter should remain unchanged
        assert.are.equal("select 1 + <int64>$y;", result)
    end)
end)
