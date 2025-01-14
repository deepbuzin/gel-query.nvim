vim.api.nvim_create_user_command("GelExecute", function()
    require("gel-query").execute_selection()
end, {})

