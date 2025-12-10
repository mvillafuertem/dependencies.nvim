-- Set vim as a known global to avoid diagnostics warnings
_G.vim = vim

-- Cargar runtime de Treesitter
require("nvim-treesitter.configs").setup({
	ensure_installed = {"scala"},
	highlight = { enable = false },
})

-- Ruta al plugin local
vim.opt.rtp:append(vim.fn.getcwd())
require("dependencies.parser")
