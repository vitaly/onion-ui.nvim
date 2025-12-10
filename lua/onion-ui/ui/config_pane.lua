local config = require('onion.config')

local M = {}

-- Convert Lua value to display string using vim.inspect
local function value_to_string(value)
  if value == nil then
    return 'nil'
  elseif type(value) == 'function' then
    return '<function>'
  else
    return vim.inspect(value, { newline = '\n', indent = '  ' })
  end
end

-- Update config pane content
function M.update(buf, win, config_mode)
  config_mode = config_mode or 'merged' -- Default to merged if not specified
  local nav_state = require('onion-ui.state.navigation')
  local nav_pane = require('onion-ui.ui.nav_pane')

  -- Make buffer modifiable
  vim.bo[buf].modifiable = true

  -- Get current path and selected key
  local current_path = nav_state.get_config_path()
  local keys = nav_pane.get_current_keys()
  local selected_idx = nav_state.get_selected_index()

  -- Build the full path for config
  local config_path = current_path
  if #keys > 0 and selected_idx > 0 and selected_idx <= #keys then
    local selected_key = keys[selected_idx]
    if config_path ~= '' then
      config_path = config_path .. '.' .. selected_key
    else
      config_path = selected_key
    end
  end

  -- Get the config data based on mode
  local data
  if config_mode == 'default' then
    data = config.get_default(config_path)
  elseif config_mode == 'user' then
    data = config.get_user(config_path)
  else
    data = config.get(config_path)
  end

  -- Build content lines
  local lines = {}

  -- Add tabs header
  local modes = { 'merged', 'default', 'user' }
  local tab_parts = {}

  for _, mode in ipairs(modes) do
    if mode == config_mode then
      -- Active tab - use brackets and capitalization
      table.insert(tab_parts, '[' .. mode:upper() .. ']')
    else
      -- Inactive tab - lowercase
      table.insert(tab_parts, mode)
    end
  end

  -- Center the tabs
  local tab_line = ' ' .. table.concat(tab_parts, ' ') .. ' '
  table.insert(lines, tab_line)

  local win_width = vim.api.nvim_win_get_width(win) - 4 -- Account for borders and padding
  table.insert(lines, string.rep('─', math.max(10, win_width)))
  table.insert(lines, '')

  -- Add the data content
  local content = value_to_string(data)
  for line in content:gmatch('[^\r\n]+') do
    table.insert(lines, line)
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set cursor to top
  vim.api.nvim_win_set_cursor(win, { 1, 0 })

  -- Make buffer non-modifiable again
  vim.bo[buf].modifiable = false
end

return M

