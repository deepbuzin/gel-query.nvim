local M = {}

local options = {
    connection_flags = "-I edgedb_mcp"
}

M.setup = function()
    -- Nothing here for now
end


---@class gel_query.Param
---@field type string
---@field name string

---@class gel_query.Float
---@field buf integer
---@field win integer


local get_selection = function()
    vim.cmd("normal! gv") -- restore visual mode because it gets lost and messes up the selection

    local buf = vim.api.nvim_get_current_buf()
    local start_pos = vim.fn.getcharpos("'<")
    local start_row = start_pos[2] - 1
    local start_col = start_pos[3] - 1
    local end_pos = vim.fn.getcharpos("'>")
    local end_row = end_pos[2] - 1
    local end_col = end_pos[3] -- every coordinate is off by 1 except for this one

    local query = vim.api.nvim_buf_get_text(buf, start_row, start_col, end_row, end_col, {})
    vim.cmd("normal! gv") -- restore visual mode again

    return query
end

---@param query string
local execute_query = function(query)
    -- Run a query against Gel instance
    local result = vim.system({ "edgedb", "query", "-I", "edgedb_mcp", query },
            { text = true })
        :wait()

    local out    = vim.split(result.stdout, "\n")
    local err    = vim.split(result.stderr, "\n")

    for _, line in ipairs(out) do table.insert(err, line) end

    return out
end

local open_float = function(config, enter)
    if enter == nil then
        enter = false
    end

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, enter, config)

    return { buf = buf, win = win }
end

---@param floats table{string, gel_query.Float}
---@param callback fun(name: string, float: gel_query.Float)
local foreach_float = function(floats, callback)
    for name, float in pairs(floats) do
        callback(name, float)
    end
end

---@return table{string, gel_query.Float}
local create_ui = function()
    local ui_height = math.floor(vim.o.lines * 0.8)
    local ui_width = math.floor(vim.o.columns * 0.8)
    local top_row = math.floor((vim.o.lines - ui_height) / 2)
    local left_col = math.floor((vim.o.columns - ui_width) / 2)

    ---@type vim.api.keyset.win_config[]
    local configs = {
        query = {
            relative = "editor",
            height = math.floor(ui_height / 2) - 1, -- offset for border
            width = math.floor(ui_width / 2) - 1,
            row = top_row,
            col = left_col,
            style = "minimal",
            border = "rounded",
            title = "Query",
            title_pos = "center"
        },
        params = {
            relative = "editor",
            height = math.floor(ui_height / 2) - 1, -- offset for border
            width = math.floor(ui_width / 2) - 1,
            row = math.floor(top_row + ui_height / 2) + 1,
            col = left_col,
            style = "minimal",
            border = "rounded",
            title = "Params",
            title_pos = "center",
        },
        output = {
            relative = "editor",
            height = ui_height,
            width = math.floor(ui_width / 2) - 2,
            row = top_row,
            col = math.floor(left_col + ui_width / 2) + 2,
            style = "minimal",
            border = "rounded",
            title = "Output",
            title_pos = "center",
        }
    }

    local floats = {
        query = open_float(configs.query),
        params = open_float(configs.params, true),
        output = open_float(configs.output),
    }

    foreach_float(floats, function(_, float)
        -- Quit all three windows in case one of them gets closed
        vim.api.nvim_create_autocmd("WinClosed", {
            buffer = float.buf,
            callback = function()
                foreach_float(floats, function(_, other_float)
                    pcall(vim.api.nvim_win_close, other_float.win, true)
                    pcall(vim.api.nvim_buf_delete, other_float.buf, { force = true })
                end)
            end
        })

        vim.keymap.set("n", "<Esc>", function()
            vim.cmd("quit")
        end, { buffer = float.buf })
    end)

    return floats
end

---@param query string
---@return gel_query.Param[]
local find_params = function(query)
    local pattern = "<(.-)>$(%w+)"
    local params = {}

    for param_type, param_name in string.gmatch(query, pattern) do
        table.insert(params, { type = param_type, name = param_name })
    end

    return params
end


local insert_params = function(query, params, param_values)
    -- Parse input values for params


    -- Replace placeholders with values

    local pattern = "<(.-)>$(%w+)"
    local subbed_query = string.gsub(query, pattern, param_values)
end


local execute_selection = function()
    local query = get_selection()

    -- Remove quotes and whitespaces
    local stripped_query = string.match(table.concat(query, "\n"), "^[ \"\']*(.-)[ \"\']*$")
    query = vim.split(stripped_query, "\n")

    local floats = create_ui()

    vim.api.nvim_buf_set_text(floats.query.buf, 0, 0, -1, -1, query)
    local concat_query = table.concat(query, "\n")

    local params = find_params(concat_query)
    local display_params = {}

    for _, param in ipairs(params) do
        table.insert(display_params, string.format("(%s) %s =  ", param.type, param.name))
    end

    vim.api.nvim_buf_set_text(floats.params.buf, 0, 0, -1, -1, display_params)


    foreach_float(floats, function(_, float)
        vim.keymap.set("n", "X", function()
            local output = execute_query(concat_query)
            vim.api.nvim_buf_set_text(floats.output.buf, 0, 0, -1, -1, output)
        end, { buffer = float.buf })
    end)
end




local test_query = [[
with a := 1
select a + <int64>$a + <int64>$b;
]]

-- vim.keymap.set("v", "<leader>eq", get_selection)
vim.keymap.set("v", "<space>ex", execute_selection)


-- execute_selection()

return M
