-- Minimal init for running tests
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
local nui_path = vim.fn.stdpath("data") .. "/lazy/nui.nvim"

-- Add plenary and nui to runtime path
vim.opt.rtp:append(plenary_path)
vim.opt.rtp:append(nui_path)

-- Add the plugin itself
vim.opt.rtp:append(".")

-- Disable swap files
vim.opt.swapfile = false

-- Load plenary
vim.cmd([[runtime plugin/plenary.vim]])
