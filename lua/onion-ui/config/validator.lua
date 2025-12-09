local M = {}

-- Validate onion.config availability and functionality
function M.validate()
  local ok, config = pcall(require, 'onion.config')
  if not ok then
    return false, 'onion.config not found. Please ensure onion.nvim is installed.'
  end

  -- Check required methods
  local required_methods = { 'get', 'get_default', 'get_user' }
  for _, method in ipairs(required_methods) do
    if type(config[method]) ~= 'function' then
      return false, string.format('onion.config missing required method: %s', method)
    end
  end

  -- Test basic functionality
  local test_ok, test_err = pcall(function()
    config.get('')
    config.get_default('')
    config.get_user('')
  end)

  if not test_ok then
    return false, string.format('onion.config methods failed: %s', test_err)
  end

  return true, config
end

return M
