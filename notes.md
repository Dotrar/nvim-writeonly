# How to write a plugin

"Neovim is a very extensible editor," which is something everyone says, but I never understood what it takes to make those extensions myself. Many times I've considered what it would take to modify my editor, but without a concrete answer of how easy it is. But once I figured out what I wanted to make and made it, I realised it was an easy process, in which I'm here to share with you today.

This guide assumes you know a little bit of Neovim and a little bit of Lua. Setting up [telescope](https://github.com/nvim-telescope/telescope.nvim) with [FZF](https://github.com/nvim-telescope/telescope-fzf-native.nvim) is also a good idea, so that you can search the help docs along with me, and find some answers to your own questions.

Firstly I'm going to define what our plugin does, and then I'm going to piece it together on how I got there, so you can follow along.

## Making a plugin: "neovim-writeonly"

There is a common trope in writing - a craft I'm trying to get better at - that one should "write more" and "edit after". The issue with using neovim and programming work is that editing is 90% of what one does. It is when I'm writing, that I can get stuck on editing and not make much progress in putting down my thoughts.

This plugin is meant to help us write more, edit less. In this guide we will make a simple plugin that does the following:

1. When activated, forces us into insert mode.
2. Removes the ability to edit text while in insert mode (disable arrow keys, backspace, delete)
3. Requires effort to get out of insert mode ( for now, we have to press `<esc>` 15 times).
4. Will only allow us to `<C-w>` once, (delete word backwards). To enable again, we have to write more.

While it's arguable how beneficial this plugin is in the long run, we can use it to learn how to write a plugin.

## Plugin architecture

Plugins are usually made to reside in their own folder, and added to the `runtimepath` of vim through a plugin manager like [Vim Plug](https://github.com/junegunn/vim-plug), which is what I'll be using.

The folders we are wanting to pay attention to are the `lua/` and `plugin/` folders. Plugin is used at startup and can deal with registering commands and hotkeys, with either `.vim` or `.lua` files, and the lua folder is for the plugin code, written in lua.

Make a new directory to base your plugin from. I'll use `~/plugin` for this guide. Meaning our first code belongs in `~/plugin/lua/writeonly.lua`
```lua
-- plugin/lua/writeonly.lua
print('hellow world')
```

We must load the plugin through vim-plug, which is as simple as putting `Plug '~/plugin'` in your vim-plug setup, where other plugins reside. Then we will be able to test the code, by reloading neovim and writing `:lua require 'writeonly'` - we should then be greeted with `"Hello World"` in the command prompt, (or have a look in `:messages` if it doesn't show up).

This is the basic of lua execution in neovim. Lua is an easy language to learn, but some high level language concepts are good to know going forward, such as maps, higher-order functions, and so on. 

Let's write our plugin.

## Write only - on enable.

Let's change our structure of `writeonly.lua` like so:
```lua
M = {}
M.enable = function() 
    vim.cmd('startinsert')
end

return M
```
This is a general layout that most plugins tend to follow as convention. We are making a table called "M", defining one function called "enable" and then we return M to the calling code. This means when we write `require 'writeonly'` - what is returned, is this table with the enable function in it.

What do we want to do with `enable` ? This will enable our write only mode, so to begin with, let's try looking for a way to enter insert mode. You can search using `:Telescope help_tags` and browsing through the docs, but I found that it's actually a rather cryptic command of `startinsert` ( paired with `stopinsert` ) 

This `startinsert` command is actually a regular vim command ( meaning you can use `:startinsert`) - so to call a command in lua, we can write: `vim.cmd('startinsert')`

```lua
M = {}
M.enable = function() 
    vim.cmd('startinsert')
end

return M
```
Put this in our `enable` function above, save it and **restart neovim** then try to run the following code: `:lua require 'writeonly'.enable()`

You should find that it has put the cursor in insert mode, which is what we want. Good, let's continue.

## Adding the escape wrapper

We can make a change to our plugin code and "override" the escape key -- this is to prevent people from leaving insert mode. We don't want to entirely stop it while we're still developing it, so let's just put a print statement in it for now to test that we can actually override the escape first.

```lua
    -- in enable, after 'startinsert'
    vim.keymap.set('i', '<esc>', function() 
        print("this is escape!")
        vim.cmd("stopinsert")
    end)
```

Let's save and re-run our `:lua require'writeonly'.enable()` code, then try to `<esc>` out of insert mode. You should find no escape print message at all. Why is that? 

### Lua plugin cache.

If your answer was "because the result from the `require` call is cached, so it's still old code" then you are right and can skip this section. When we call `require` lua will first check if the code is in the cache, and load it from disk if it isn't available. The first time we run our `.enable()` function, we load the code up from disk and store it in the cache. 
You can inspect the cache contents in vim, via:
```lua
:lua print(vim.inspect(package.loaded))
```
If you scroll around, you might find our `writeonly` plugin. 

While developing, it is useful to clear out our plugin cache so we load up fresh code each time. To do this, we can write a simple helper command function like such:
```lua
-- note, I like to put this in my init.lua file, so that it's always available.
vim.cmd([[command! -nargs=1 Forget lua package.loaded["<args>"] = nil ]])
```
This is run on the command line like: `:Forget writeonly` which will clear out the cache, and will load a fresh copy next time you call `require 'writeonly'`. Neovim will also store history of the command, so you can just write `:Fo` and autocomplete the rest of it if you so desire, or you could even bind it to a keybind if you really want to.

Forget the `writeonly` library, then run `:lua require 'writeonly'.enable()` again, You should find that it puts you in insert mode, and pressing `<esc>` will print a message and put you back in normal mode. 

### Local scoped variables.

In terms of code, each lua package is a module that is somewhat seperated from everything else. When we return our `M` from the lua code, We are really a table that has links to functions loaded in memory. Those themselves can have links to other functions and variables within memory, but they won't be accessable from vim, only through our `M` module's table.

Let's work on the escape function. We only want to `stopinsert` after 15 key presses.
```lua
-- writeonly.lua 
M = {}
local escape_counter = 0      -- number of times it is pressed
local escape_number = 15    -- number of times it should be pressed.

local function disable ()
    vim.cmd('stopinsert')
end

local function enable()
    vim.cmd('startinsert')
end

M.enable = function()
    escape_cout = 0
    enable()
    vim.keymap.set('i', '<esc>', function()
        escape_counter = escape_counter + 1
        print("pressed escape: " .. escape_counter .. "/" .. escape_number)

        if escape_counter >= escape_number then
            disable()
        end
    end)
end

return M
```

Our plugin is starting to take shape. We have two module local functions and two local variables, and our module's `.enable()` can start and stop insert mode. Note that the `.enable` function is our only entrypoint into the lua code. Now each time we press `<esc>` we run the code to increment the counter, check how many times it's been pressed, and stop insert after 15 presses. We also separate our code to make it a little neater with having the two local functions to `enable` and `disable` (one should mirror the other).

## Disable movement and backspaces
We want to prevent editing, so while we're in our `writeonly` mode we should disable the arrow keys, which we can do by binding them to `<nop>` which is "No operation" - do nothing - when we press the key. We can enable them once we've disabled the plugin mode as well.

Define a list of keys that we want to disable, and then add the following code to the enable and disable.

```lua
-- define keys 
local disabled_keys = {'<backspace>', '<delete>', '<left>', '<right>', '<up>', '<down>'}

-- ...... in enable function:
    for _, key in ipairs(disabled_keys) do
        vim.keymap.set('i',key,'<nop>')
    end

-- ....... in disable function:
    for _, key in ipairs(disabled_keys) do
        vim.keymap.del('i',key)
    end
-------------------------------
```
This will add a `<nop>` operation on top of our keypress stack, and remove it when we're finished. Quick and easy. 

## Allowing only one <c-w>
The final piece of the plugin is to put in our blocker for `<C-w>`. When in insert mode, `<C-w>` (which is ctrl-w) will delete the word backwards, which can be used as a real quick fixup for simple spelling mistakes. We only want to allow one of these each time we write something.

The general idea of how we're going to implement this is when you are writing, a flag is set, and when the flag is set, we can press `<C-w>` which will delete word and also clear the flag.

Using an autocommand is the best bet here, as it will monitor for us when certain events happen. You can look for events under the help text `:help events` - The event `TextChangedI` seems to be what we're looking for here (text changed while in insert mode).

So when we change text, if the `delete_counter` is above zero, decrement it by 1.
```lua
-- at the top of our writeonly.lua
local delete_counter = 0
-- in our enable function
vim.api.nvim_create_autocmd("TextChangedI", {
        callback = function ()
            if delete_counter > 0 then
                delete_counter = delete_counter - 1
            end
        end
    })
```

We can then write a local lua function that we use when we want to `<C-w>` which will check the `delete_counter` and delete word if needed.

```lua
local function delete_word()
    if delete_counter > 0 then
        return
    end
    vim.cmd(":normal db")
    delete_counter = 2
end
```
Our `delete_counter` works like a flag for us. If it is `== 0` then we can delete word backwards, which we just do a `vim.cmd(":normal db")` - then we set the `delete_counter` to be 2. 
This is just a `:normal` command, which is run from within insert mode, and it is like if we were to write the characters `d` and `b` in normal mode. We could also write `diw` for delete entire word, but that won't make much sense as the cursor is usually always going to be at the end of the line.

We use the value 2 here, because we will actually be changing text twice: once when we delete the word, then again when we insert more text. We don't want our own "delete word" to re-enable the flag again.

When we set the keymapping, we want to pass in the function *name* `delete_word` - we don't want to *call* the function by using `delete_word()`.

```lua
-- in local enable we add the keybinding. 
-- add the <C-w> mapping in 'i' - insert mode. 
    vim.keymap.set('i', '<C-w>', delete_word)
-- in local disable we remove the keybinding.
    vim.keymap.del('i', '<C-w>')
```

## Wrapping up

so that is our entire plugin:

```lua
local escape_number = 15
local disabled_keys = {'<backspace>', '<delete>', '<left>', '<right>', '<up>', '<down>'}

local escape_counter = 0
local delete_counter = 0

M = {}

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
    if delete_counter > 0 then
        return
    end
    vim.cmd(":normal db")
    delete_counter = 2
end

M.enable = function ()
    -- start the insert mode, disable backspace, arrows, and delete
    -- reset the escape count and delete_counter
    escape_counter = 0
    enable()

    vim.keymap.set('i', '<C-w>', delete_word)
    vim.keymap.set('i', '<esc>', function()
        escape_counter = escape_counter + 1
        print("pressed escape: " .. escape_counter .. "/" .. escape_number)

        if escape_counter >= escape_number then
            disable()
        end
    end)

    -- set autocmd for buffer
    vim.api.nvim_create_autocmd("TextChangedI", {
            callback = function ()
                if delete_counter > 0 then
                    delete_counter = delete_counter - 1
                end
            end
        })
end

return M
```

Which we can then call as `:lua require 'writeonly'.enable()` - if you wanted to enable this with a simplier command or a keybind, you can put the code you want in the `plugin/` folder, and it will be loaded at startup. 

```lua
-- in plugin/writeonly.lua
vim.cmd([[command! Writeonly lua require 'writeonly'.enable()]])
```
Then we get the command at startup.
