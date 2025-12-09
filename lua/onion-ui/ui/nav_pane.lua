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
  local default_data = config.get_default(config_path) or {}
  local user_data = config.get_user(config_path) or {}

  -- Store key sources for highlighting
  local key_sources = {}
  current_keys = {}

  -- Extract keys from current data and determine their source
  if type(current_data) == 'table' then
    for key, _ in pairs(current_data) do
      table.insert(current_keys, key)

      -- Determine where this key exists
      local in_default = default_data[key] ~= nil
      local in_user = user_data[key] ~= nil

      if in_default and in_user then
        key_sources[key] = 'both'
      elseif in_default then
        key_sources[key] = 'default'
      else
        key_sources[key] = 'user'
      end
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
  end

  -- Build content lines
  local lines = {}

  -- Add current path display
  local display_path = nav_state.get_display_path()
  table.insert(lines, display_path)
  local win_width = vim.api.nvim_win_get_width(win) - 4 -- Account for borders and padding
  table.insert(lines, string.rep('─', math.max(10, win_width)))

  -- Add keys with highlighting
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

  -- Apply syntax highlighting based on key sources
  -- Start from line 3 (after path and separator)
  local start_line = 3
  local ns_id = vim.api.nvim_create_namespace('onion_ui_keys')

  -- Clear previous highlights
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  for i, key in ipairs(current_keys) do
    local line_num = start_line + i - 1
    local source = key_sources[key]

    -- Define highlight groups
    local hl_group
    if source == 'default' then
      hl_group = 'OnionUIDefaultKey'
    elseif source == 'user' then
      hl_group = 'OnionUIUserKey'
    elseif source == 'both' then
      hl_group = 'OnionUIBothKey'
    end

    if hl_group then
      -- Find where the key display starts in the line
      local col_start = 2
      if i == nav_state.get_selected_index() and #current_keys > 0 then
        -- Skip the '▶ ' arrow
        local line_content = lines[line_num]
        local _, key_start = string.find(line_content, '^▶%s*')
        if key_start then
          col_start = key_start - 1
        end
      else
        -- Skip the '  ' spaces
        local line_content = lines[line_num]
        local _, key_start = string.find(line_content, '^  %s*')
        if key_start then
          col_start = key_start - 1
        end
      end

      -- Get the line content to calculate end column
      local line_content = lines[line_num] or ''

      -- Highlight the entire line content (after the arrow/spaces)
      vim.api.nvim_buf_set_extmark(buf, ns_id, line_num - 1, col_start, {
        end_col = #line_content,
        hl_group = hl_group,
        priority = 100,
      })
    end
  end

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
