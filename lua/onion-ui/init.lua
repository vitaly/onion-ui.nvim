local M = {}

-- Start the onion-ui TUI
function M.start()
  -- Validate onion.config availability
  local validator = require('onion-ui.config.validator')
  local ok, result = validator.validate()

  if not ok then
    vim.notify('onion-ui: ' .. result, vim.log.levels.ERROR)
    return
  end

  local config = result

  -- Initialize the TUI
  local layout = require('onion-ui.ui.layout')
  local nav_state = require('onion-ui.state.navigation')

  -- Reset navigation state
  nav_state.reset()

  -- Create and show the TUI layout
  layout.show(config)
end

return M
