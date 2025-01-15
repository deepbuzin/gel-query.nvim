local M = {}

local state = {
    param_values = {},
    connection_opts = {},
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


---@return string[]
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


local table_extend = function(left, right)
    for _, line in ipairs(right) do
        table.insert(left, line)
    end
    return left
end


---@param query string
---@param connection_opts string[]
local execute_query = function(query, connection_opts)
    -- Run a query against Gel instance
    local command = table_extend({ "edgedb", "query" }, connection_opts)
    local result  = vim.system(table_extend(command, { query }), { text = true }):wait()

    local out     = vim.split(result.stdout, "\n")
    local err     = vim.split(result.stderr, "\n")

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
            height = math.floor(ui_height / 2) - 1 - 3, -- offset for border
            width = math.floor(ui_width / 2) - 1,
            row = math.floor(top_row + ui_height / 2) + 1,
            col = left_col,
            style = "minimal",
            border = "rounded",
            title = "Params",
            title_pos = "center",
        },
        connection = {
            relative = "editor",
            height = 1,
            width = math.floor(ui_width / 2) - 1,
            row = math.floor(top_row + ui_height) - 1,
            col = left_col,
            style = "minimal",
            border = "rounded",
            title = "Connection",
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
        output = open_float(configs.output),
        query = open_float(configs.query),
        connection = open_float(configs.connection),
        params = open_float(configs.params, true),
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

    vim.bo[floats.query.buf].filetype = "edgeql"
    vim.bo[floats.params.buf].filetype = "conf"
    vim.bo[floats.output.buf].filetype = "markdown"

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


local parse_params = function(text_params)
    -- Parse input values for params
    local input_pattern = "(%w-) = (.+)"
    local params = {}

    for _, line in ipairs(text_params) do
        for name, value in string.gmatch(line, input_pattern) do
            params[name] = value
        end
    end

    return params
end


local insert_params = function(query, params)
    local rendered_query = query

    -- Replace placeholders with values
    for name, value in pairs(params) do
        local query_pattern = string.format("<.->$%s", name)
        rendered_query = string.gsub(rendered_query, query_pattern, vim.trim(value))
    end

    return rendered_query
end


local execute_selection = function()
    local query = get_selection() -- this query is a list of lines

    -- Remove quotes and whitespaces
    local stripped_query = string.match(table.concat(query, "\n"), "^[ \"\']*(.-)[ \"\']*$")
    query = vim.split(stripped_query, "\n")

    local floats = create_ui()

    vim.api.nvim_buf_set_text(floats.query.buf, 0, 0, -1, -1, query)

    -- Parse params from the query
    local concat_query = table.concat(query, "\n")

    local params = find_params(concat_query)
    local display_params = {}

    for _, param in ipairs(params) do
        local param_value = ""

        if state.param_values[param.name] ~= nil then
            param_value = state.param_values[param.name]
        end

        table.insert(display_params, string.format("(%s) %s = %s", param.type, param.name, param_value))
    end

    vim.api.nvim_buf_set_text(floats.params.buf, 0, 0, -1, -1, display_params)
    vim.api.nvim_buf_set_text(floats.connection.buf, 0, 0, -1, -1, { table.concat(state.connection_opts, " ") })

    foreach_float(floats, function(_, float)
        vim.keymap.set("n", "X", function()
            local text_params = vim.api.nvim_buf_get_text(floats.params.buf, 0, 0, -1, -1, {})
            state.param_values = parse_params(text_params)

            local connection_string = vim.api.nvim_buf_get_text(floats.connection.buf, 0, 0, -1, -1, {})[1]
            state.connection_opts = vim.split(connection_string, " ")

            local edited_query = table.concat(vim.api.nvim_buf_get_text(floats.query.buf, 0, 0, -1, -1, {}), "\n")
            local rendered_query = insert_params(edited_query, state.param_values)

            local query_result = execute_query(rendered_query, state.connection_opts)

            local output = {}

            output = table_extend(output, { "### Rendered query", "", "```edgeql" })
            output = table_extend(output, vim.split(rendered_query, "\n"))
            output = table_extend(output, { "```" })

            output = table_extend(output, { "", "### Gel output", "", "```json" })
            output = table_extend(output, query_result)
            output = table_extend(output, { "```" })
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

M._find_params = find_params
M._insert_params = insert_params
M.execute_selection = execute_selection

return M
