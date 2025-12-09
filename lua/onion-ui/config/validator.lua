local M = {}

-- Validate onion.config availability and functionality
function M.validate()
  local ok = pcall(require, 'onion.config')
  if not ok then
    return false, 'onion.config not found. Please ensure onion.nvim is installed.'
  end

  return true
end

return M
