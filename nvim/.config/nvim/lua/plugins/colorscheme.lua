return {
	-- {
	-- 	"catppuccin/nvim",
	-- 	lazy = true,
	-- 	name = "catppuccin",
	-- 	opts = {
	-- 		transparent_background = true,
	-- 		float = {
	-- 			transparent = true,
	-- 			solid = true,
	-- 		},
	-- 	},
	-- },
	-- {
	-- 	"LazyVim/LazyVim",
	-- 	opts = {
	-- 		colorscheme = "catppuccin-mocha",
	-- 	},
	-- },

	-- lua/plugins/tokyonight.lua
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			style = "night",
			transparent = true,
			terminal_colors = true,
			styles = {
				sidebars = "transparent",
				floats = "transparent",
			},
		},
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "tokyonight-night",
		},
	},
}
