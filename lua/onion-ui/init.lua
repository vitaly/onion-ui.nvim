local M = {}

-- Start the onion-ui TUI
function M.start()
  -- Setup highlight groups first
  local highlights = require('onion-ui.ui.highlights')
  highlights.setup()

  -- Validate onion.config availability
  local validator = require('onion-ui.config.validator')
  local ok = validator.validate()

  if not ok then
    vim.notify('onion-ui: ' .. result, vim.log.levels.ERROR)
    return
  end

  -- Initialize the TUI
  local layout = require('onion-ui.ui.layout')
  local nav_state = require('onion-ui.state.navigation')

  -- Reset navigation state
  nav_state.reset()

  -- Create and show the TUI layout
  layout.show()
end

return M
