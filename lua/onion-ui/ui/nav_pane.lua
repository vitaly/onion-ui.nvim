local M = {}

-- Current keys cache
local current_keys = {}

local config = require('onion.config')

-- Update navigation pane content
function M.update(buf, win)
  local nav_state = require('onion-ui.state.navigation')

  -- Make buffer modifiable
  vim.bo[buf].modifiable = true

  -- Get current path and keys
  local config_path = nav_state.get_config_path()
  local current_data = config.get(config_path)

  -- Extract keys from current data
  if type(current_data) == 'table' then
    current_keys = {}
    for key, _ in pairs(current_data) do
      table.insert(current_keys, key)
    end
    -- Sort keys properly: numeric keys first, then string keys
    table.sort(current_keys, function(a, b)
      local a_num = tonumber(a)
      local b_num = tonumber(b)
      if a_num and b_num then
        return a_num < b_num
      elseif a_num then
        return true
      elseif b_num then
        return false
      else
        return tostring(a) < tostring(b)
      end
    end)
  else
    current_keys = {}
  end

  -- Build content lines
  local lines = {}

  -- Add current path display
  local display_path = nav_state.get_display_path()
  table.insert(lines, display_path)
  local win_width = vim.api.nvim_win_get_width(win) - 4 -- Account for borders and padding
  table.insert(lines, string.rep('─', math.max(10, win_width)))

  -- Add keys
  for i, key in ipairs(current_keys) do
    local display_key = key
    -- Format numeric keys as [1] foo, [2] bar, etc.
    if type(key) == 'number' then
      local value = current_data[key]
      if type(value) == 'string' then
        display_key = string.format('[%d] %s', key, value)
      else
        display_key = string.format('[%d] %s', key, tostring(value))
      end
    end

    local line = '  ' .. display_key
    if i == nav_state.get_selected_index() and #current_keys > 0 then
      line = '▶ ' .. display_key
    end
    table.insert(lines, line)
  end

  -- If no keys, show message
  if #current_keys == 0 then
    table.insert(lines, '')
    table.insert(lines, '  (no keys at this level)')
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set cursor position (handled by layout.lua key mappings)
  -- Cursor positioning is now handled in layout.lua to sync with j/k navigation

  -- Make buffer non-modifiable again
  vim.bo[buf].modifiable = false
end

-- Get current keys list
function M.get_current_keys()
  return current_keys
end

return M
