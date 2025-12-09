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

-- Update preview pane content
function M.update(buf, win, config)
  local nav_state = require('onion-ui.state.navigation')
  local nav_pane = require('onion-ui.ui.nav_pane')

  -- Make buffer modifiable
  vim.bo[buf].modifiable = true

  -- Get current path and selected key
  local current_path = nav_state.get_config_path()
  local keys = nav_pane.get_current_keys()
  local selected_idx = nav_state.get_selected_index()

  -- Build the full path for preview
  local preview_path = current_path
  if #keys > 0 and selected_idx <= #keys then
    local selected_key = keys[selected_idx]
    if preview_path ~= '' then
      preview_path = preview_path .. '.' .. selected_key
    else
      preview_path = selected_key
    end
  end

  -- Get the config data
  local data = config.get(preview_path)

  -- Build content lines
  local lines = {}

  -- Add header with path
  table.insert(lines, 'Config path: ' .. (preview_path == '' and '/' or preview_path))
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
