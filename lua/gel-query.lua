local M = {}

M.setup = function()
    -- Nothing here for now
end

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
    print(table.concat(query, "\n"))
end

local execute_query = function(query)
    -- Run a query against local Gel project
end

local open_float = function(config, enter)
    if enter == nil then
        enter = false
    end

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, enter, config)

    return { buf = buf, win = win }
end

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
            width = math.floor(ui_width / 2) - 1,
            row = top_row,
            col = math.floor(left_col + ui_width / 2) + 1,
            style = "minimal",
            border = "rounded",
            title = "Output",
            title_pos = "center",
        }
    }

    local query_float = open_float(configs.query)
    local params_float = open_float(configs.params, true)
    local output_float = open_float(configs.output)

    vim.api.nvim_create_autocmd("BufLeave", {
        buffer = params_float.buf,
        callback = function()
            pcall(vim.api.nvim_win_close, query_float.win, true)
            pcall(vim.api.nvim_win_close, output_float.win, true)

            pcall(vim.api.nvim_buf_delete, query_float.buf, { force = true })
            pcall(vim.api.nvim_buf_delete, params_float.buf, { force = true })
            pcall(vim.api.nvim_buf_delete, output_float.buf, { force = true })
        end
    })
end

-- vim.keymap.set("v", "<leader>eq", get_selection)
vim.keymap.set("v", "<leader>eee", create_ui)


create_ui()


return M
