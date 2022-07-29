-- Write only
-- Author: Dre Westcook (@Dotrar)
--
-- This plugin provides a way to be "locked" into insert mode
-- and disable movement and editing. It forces a more
-- "Get it down on paper, then edit" mentality, rather than
-- trying to edit as you write to slow everything down.

M = {}

local escape_number = 15
local disabled_keys = {'<backspace>', '<delete>', '<left>', '<right>', '<up>', '<down>'}

local escape_count = 0
local delete_stage = 0

local function disable ()
    vim.keymap.del('i','<esc>')
    vim.keymap.del('i','<c-w>')
    for _, key in ipairs(disabled_keys) do
        vim.keymap.del('i',key)
    end
    vim.cmd('stopinsert')
end

local function enable()
    vim.cmd('startinsert')
    for _, key in ipairs(disabled_keys) do
        vim.keymap.set('i',key,'<nop>')
    end
end

local function delete_word()
    if delete_stage > 0 then
        return
    end
    vim.cmd(":normal db")
    delete_stage = 2
end

M.enable = function ()
    -- start the insert mode, disable backspace, arrows, and delete
    -- reset the escape count and delete_stage
    escape_count = 0
    enable()

    vim.keymap.set('i', '<C-w>', delete_word)
    vim.keymap.set('i', '<esc>', function()
        escape_count = escape_count + 1
        print("pressed escape: " .. escape_count .. "/" .. escape_number)

        if escape_count >= escape_number then
            disable()
        end
    end)

    -- set autocmd for buffer
    vim.api.nvim_create_autocmd("TextChangedI", {
            callback = function ()
                if delete_stage > 0 then
                    delete_stage = delete_stage - 1
                end
            end
        })
end

return M
