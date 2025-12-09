local M = {}

-- Setup highlight groups for onion-ui
function M.setup()
  -- Default key highlight (gray)
  vim.api.nvim_set_hl(0, 'OnionUIDefaultKey', {
    fg = '#808080',  -- Gray
    bold = false,
  })

  -- User-only key highlight (green)
  vim.api.nvim_set_hl(0, 'OnionUIUserKey', {
    fg = '#00ff00',  -- Green
    bold = true,
  })

  -- Key in both default and user (orange)
  vim.api.nvim_set_hl(0, 'OnionUIBothKey', {
    fg = '#ff8800',  -- Orange
    bold = true,
  })
end

return M