-- Minimal init for running tests
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
local nui_path = vim.fn.stdpath("data") .. "/lazy/nui.nvim"

-- Add plenary and nui to runtime path
vim.opt.rtp:append(plenary_path)
vim.opt.rtp:append(nui_path)

-- Add the plugin itself
vim.opt.rtp:append(".")

-- Add nui.nvim to Lua package.path
package.path = package.path .. ";" .. nui_path .. "/lua/?.lua"
package.path = package.path .. ";" .. nui_path .. "/lua/?/init.lua"

-- Disable swap files
vim.opt.swapfile = false

-- Load plenary
vim.cmd([[runtime plugin/plenary.vim]])
