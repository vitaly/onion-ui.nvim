local M = {}

local config_pane = require('onion-ui.ui.config_pane')
local nav_pane = require('onion-ui.ui.nav_pane')
local nav_state = require('onion-ui.state.navigation')

---@class Layout
local layout = {
  is_active = false,
  nav_win = nil, ---@type number|nil Window handle for navigation pane
  nav_buf = nil, ---@type number|nil Buffer handle for navigation pane
  config_win = nil, ---@type number|nil Window handle for config pane
  config_buf = nil, ---@type number|nil Buffer handle for config pane
  config_mode = 'merged', ---@type 'merged'|'default'|'user'
}

---@class EditState
local edit_state = {
  win = nil, ---@type number|nil
  buf = nil, ---@type number|nil
  original_path = nil, ---@type string|nil
}

-- Track cursor position to avoid unnecessary config pane updates
local last_cursor_line = 1

-- ============================================================================
-- Utility Functions
-- ============================================================================

---@param value any
---@return string
local function value_to_string(value)
  if value == nil then
    return 'nil'
  elseif type(value) == 'function' then
    return '<function>'
  else
    return vim.inspect(value, { newline = '\n', indent = '  ' })
  end
end

---@param value any
---@return string
local function generate_commented_defaults(value)
  local defaults_str = vim.inspect(value, { newline = '\n', indent = '  ' })
  local lines = {}

  for line in defaults_str:gmatch('[^\n]+') do
    table.insert(lines, '-- ' .. line)
  end

  return table.concat(lines, '\n')
end

-- ============================================================================
-- Edit Window Functions
-- ============================================================================

---@param value_str string
---@return number|nil win Window handle
---@return number|nil buf Buffer handle
local function create_edit_window(value_str)
  local ui = vim.api.nvim_list_uis()[1]
  if not ui then
    vim.notify('onion-ui: No UI available', vim.log.levels.ERROR)
    return nil, nil
  end

  local width = math.floor(ui.width * 0.8)
  local height = math.floor(ui.height * 0.6)
  local col = math.floor((ui.width - width) / 2)
  local row = math.floor((ui.height - height) / 2)

  local config = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    border = 'single',
    style = 'minimal',
    title = ' Edit Value ',
    title_pos = 'center',
  }

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, config)

  vim.bo[buf].filetype = 'lua'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].modifiable = true

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(value_str, '\n'))

  vim.wo[win].wrap = true
  vim.wo[win].cursorline = false

  return win, buf
end

local function apply_edit()
  if not edit_state.win or not vim.api.nvim_win_is_valid(edit_state.win) then
    return
  end

  local content = table.concat(vim.api.nvim_buf_get_lines(edit_state.buf, 0, -1, false), '\n')

  local fn, err = loadstring('return ' .. content)
  if not fn then
    vim.notify('Invalid Lua syntax: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end

  local ok, value = pcall(fn)
  if not ok then
    vim.notify('Error evaluating Lua: ' .. tostring(value), vim.log.levels.ERROR)
    return
  end

  local config = require('onion.config')

  if value == nil then
    if edit_state.original_path == '' then
      vim.notify('Cannot reset the entire root config', vim.log.levels.WARN)
      return
    end
    local set_ok, set_err = pcall(config.reset, edit_state.original_path)
    if not set_ok then
      vim.notify('Failed to reset value: ' .. tostring(set_err), vim.log.levels.ERROR)
      return
    end
  else
    -- Root path requires setting each key individually (config.set doesn't accept empty path)
    if edit_state.original_path == '' then
      if type(value) ~= 'table' then
        vim.notify('Root config must be a table', vim.log.levels.ERROR)
        return
      end
      for key, val in pairs(value) do
        local set_ok, set_err = pcall(config.set, tostring(key), val)
        if not set_ok then
          vim.notify(
            'Failed to set ' .. tostring(key) .. ': ' .. tostring(set_err),
            vim.log.levels.ERROR
          )
          return
        end
      end
    else
      local set_ok, set_err = pcall(config.set, edit_state.original_path, value)
      if not set_ok then
        vim.notify('Failed to set value: ' .. tostring(set_err), vim.log.levels.ERROR)
        return
      end
    end
  end

  vim.api.nvim_win_close(edit_state.win, true)
  edit_state.win = nil
  edit_state.buf = nil
  edit_state.original_path = nil

  M.update_content()
end

local function cancel_edit()
  if edit_state.win and vim.api.nvim_win_is_valid(edit_state.win) then
    vim.api.nvim_win_close(edit_state.win, true)
  end
  edit_state.win = nil
  edit_state.buf = nil
  edit_state.original_path = nil
end

-- ============================================================================
-- Navigation Handlers
-- ============================================================================

local function update_selection_from_cursor()
  if not layout.nav_win or not vim.api.nvim_win_is_valid(layout.nav_win) then
    return
  end
  if not layout.nav_buf or not vim.api.nvim_buf_is_valid(layout.nav_buf) then
    return
  end

  local ok, cursor_pos = pcall(vim.api.nvim_win_get_cursor, layout.nav_win)
  if not ok then
    return
  end

  local cursor_line = cursor_pos[1]

  if cursor_line == last_cursor_line then
    return
  end

  local keys = nav_pane.get_current_keys()

  -- Cursor on path/separator (lines 1-2) shows whole path config
  if cursor_line <= 2 then
    nav_state.set_selected_index(0)
    local current_cursor = vim.api.nvim_win_get_cursor(layout.nav_win)
    M.update_content()
    vim.api.nvim_win_set_cursor(layout.nav_win, current_cursor)
  elseif cursor_line >= 3 and #keys > 0 then
    local key_index = cursor_line - 2
    if key_index >= 1 and key_index <= #keys then
      nav_state.set_selected_index(key_index)
      local current_cursor = vim.api.nvim_win_get_cursor(layout.nav_win)
      M.update_content()
      vim.api.nvim_win_set_cursor(layout.nav_win, current_cursor)
    end
  end

  last_cursor_line = cursor_line
end

local function navigate_into()
  local keys = nav_pane.get_current_keys()
  local selected_idx = nav_state.get_selected_index()

  if selected_idx > 0 and selected_idx <= #keys then
    local selected_key = keys[selected_idx]
    nav_state.navigate_into(selected_key)
    M.update_content()

    -- After navigation, show whole path config
    nav_state.set_selected_index(0)
    vim.api.nvim_win_set_cursor(layout.nav_win, { 1, 0 })
  end
end

local function navigate_up()
  local current_path = nav_state.get_path()

  if #current_path == 0 then
    return
  end

  local parent_key = current_path[#current_path]
  nav_state.navigate_up()
  M.update_content()

  -- Position cursor at the parent key we just navigated out of
  local keys_after = nav_pane.get_current_keys()
  if #keys_after > 0 and parent_key then
    for i, key in ipairs(keys_after) do
      if key == parent_key then
        vim.api.nvim_win_set_cursor(layout.nav_win, { i + 2, 2 })
        return
      end
    end
  end

  vim.api.nvim_win_set_cursor(layout.nav_win, { 3, 2 })
end

-- ============================================================================
-- Action Handlers
-- ============================================================================

local function reset_selected_key()
  local keys = nav_pane.get_current_keys()
  local selected_idx = nav_state.get_selected_index()

  if selected_idx <= 0 then
    vim.notify('Select a specific key to reset', vim.log.levels.WARN)
    return
  end

  if #keys == 0 or selected_idx > #keys then
    return
  end

  local selected_key = keys[selected_idx]
  local nav_path = nav_state.get_config_path()
  local config = require('onion.config')

  -- Array elements require reconstructing the parent array without the element
  if type(selected_key) == 'number' then
    local user_array = config.get_user(nav_path)

    if user_array and type(user_array) == 'table' then
      local new_array = {}
      for i, v in ipairs(user_array) do
        if i ~= selected_key then
          table.insert(new_array, v)
        end
      end

      local ok, err = pcall(config.set, nav_path, new_array)
      if not ok then
        vim.notify('onion-ui: Failed to update array: ' .. tostring(err), vim.log.levels.ERROR)
      else
        M.update_content()
      end
    else
      vim.notify('onion-ui: No user modification to reset', vim.log.levels.WARN)
    end
  else
    local reset_path = nav_path ~= '' and (nav_path .. '.' .. selected_key)
      or tostring(selected_key)
    local ok, err = pcall(config.reset, reset_path)

    if not ok then
      vim.notify('onion-ui: Failed to reset key: ' .. tostring(err), vim.log.levels.ERROR)
    else
      M.update_content()
    end
  end
end

local function edit_selected_key()
  local keys = nav_pane.get_current_keys()
  local selected_idx = nav_state.get_selected_index()
  local nav_path = nav_state.get_config_path()
  local config = require('onion.config')

  local full_path
  if selected_idx > 0 and selected_idx <= #keys then
    local selected_key = keys[selected_idx]

    -- Array elements must be edited via parent array
    if type(selected_key) == 'number' then
      vim.notify(
        'Cannot edit array elements individually. Navigate up to edit the whole array.',
        vim.log.levels.WARN
      )
      return
    end

    full_path = nav_path ~= '' and (nav_path .. '.' .. selected_key) or tostring(selected_key)
  else
    full_path = nav_path
  end

  local user_value = config.get_user(full_path)
  local default_value = config.get_default(full_path)

  if type(user_value) == 'function' then
    vim.notify('Cannot edit function values', vim.log.levels.WARN)
    return
  end

  local content_lines = {}

  local user_str = value_to_string(user_value)
  for line in user_str:gmatch('[^\n]+') do
    table.insert(content_lines, line)
  end

  if default_value ~= nil then
    table.insert(content_lines, '')
    table.insert(content_lines, '-- Default value for reference:')
    local default_commented = generate_commented_defaults(default_value)
    for line in default_commented:gmatch('[^\n]+') do
      table.insert(content_lines, line)
    end
  end

  local content_str = table.concat(content_lines, '\n')

  local win, buf = create_edit_window(content_str)
  if win and buf then
    edit_state.win = win
    edit_state.buf = buf
    edit_state.original_path = full_path

    vim.keymap.set('n', '<CR>', apply_edit, { buffer = buf, silent = true })
    vim.keymap.set('n', '<Esc>', cancel_edit, { buffer = buf, silent = true })
  end
end

local function toggle_selected_key()
  local keys = nav_pane.get_current_keys()
  local selected_idx = nav_state.get_selected_index()
  local nav_path = nav_state.get_config_path()
  local config = require('onion.config')

  local full_path
  if selected_idx > 0 and selected_idx <= #keys then
    local selected_key = keys[selected_idx]

    -- Array elements cannot be toggled individually
    if type(selected_key) == 'number' then
      vim.notify('Cannot toggle array elements individually', vim.log.levels.WARN)
      return
    end

    full_path = nav_path ~= '' and (nav_path .. '.' .. selected_key) or tostring(selected_key)
  else
    full_path = nav_path
  end

  local ok, err = pcall(config.toggle, full_path)

  if not ok then
    vim.notify('onion-ui: Failed to toggle key: ' .. tostring(err), vim.log.levels.ERROR)
  else
    M.update_content()
  end
end

local function cycle_config_mode()
  if layout.config_mode == 'merged' then
    layout.config_mode = 'default'
  elseif layout.config_mode == 'default' then
    layout.config_mode = 'user'
  else
    layout.config_mode = 'merged'
  end

  M.update_content()
end

-- ============================================================================
-- Public API
-- ============================================================================

function M.update_content()
  if layout.nav_buf and vim.api.nvim_buf_is_valid(layout.nav_buf) then
    local ok, err = pcall(nav_pane.update, layout.nav_buf, layout.nav_win)
    if not ok then
      vim.notify(
        'onion-ui: Failed to update navigation pane: ' .. tostring(err),
        vim.log.levels.WARN
      )
    end
  end

  if layout.config_buf and vim.api.nvim_buf_is_valid(layout.config_buf) then
    local ok, err =
      pcall(config_pane.update, layout.config_buf, layout.config_win, layout.config_mode)
    if not ok then
      vim.notify('onion-ui: Failed to update config pane: ' .. tostring(err), vim.log.levels.WARN)
    end
  end
end

function M.create_layout()
  local ui = vim.api.nvim_list_uis()[1]
  if not ui then
    vim.notify('onion-ui: No UI available', vim.log.levels.ERROR)
    return
  end

  local width = math.floor(ui.width * 0.8)
  local height = math.floor(ui.height * 0.8)
  local col = math.floor((ui.width - width) / 2)
  local row = math.floor((ui.height - height) / 2)

  local nav_width = math.floor(width * 0.4)
  local nav_config = {
    relative = 'editor',
    width = nav_width,
    height = height,
    col = col,
    row = row,
    border = 'single',
    style = 'minimal',
    title = ' Navigation ',
    title_pos = 'center',
  }

  layout.nav_buf = vim.api.nvim_create_buf(false, true)
  layout.nav_win = vim.api.nvim_open_win(layout.nav_buf, true, nav_config)

  local config_width = width - nav_width - 3
  local config_window_config = {
    relative = 'editor',
    width = config_width,
    height = height,
    col = col + nav_width + 3,
    row = row,
    border = 'single',
    style = 'minimal',
    title = ' Config ',
    title_pos = 'center',
  }

  layout.config_buf = vim.api.nvim_create_buf(false, true)
  layout.config_win = vim.api.nvim_open_win(layout.config_buf, false, config_window_config)

  vim.wo[layout.nav_win].wrap = false
  vim.wo[layout.nav_win].cursorline = true
  vim.wo[layout.nav_win].winfixbuf = true

  vim.wo[layout.config_win].wrap = true
  vim.wo[layout.config_win].winfixbuf = true

  vim.bo[layout.nav_buf].filetype = 'onion-ui-nav'
  vim.bo[layout.config_buf].filetype = 'lua'
end

function M.setup_keymaps()
  -- Set up autocmd to track cursor movement
  vim.defer_fn(function()
    if layout.nav_buf and vim.api.nvim_buf_is_valid(layout.nav_buf) then
      local cursor_move_group = vim.api.nvim_create_augroup('OnionUICursorMove', { clear = true })
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = layout.nav_buf,
        group = cursor_move_group,
        callback = update_selection_from_cursor,
      })
    end
  end, 50)

  -- Navigation mappings
  vim.keymap.set('n', '<CR>', navigate_into, { buffer = layout.nav_buf, silent = true })
  vim.keymap.set('n', 'l', navigate_into, { buffer = layout.nav_buf, silent = true })
  vim.keymap.set('n', '<Right>', navigate_into, { buffer = layout.nav_buf, silent = true })
  vim.keymap.set('n', 'h', navigate_up, { buffer = layout.nav_buf, silent = true })
  vim.keymap.set('n', '<Left>', navigate_up, { buffer = layout.nav_buf, silent = true })
  vim.keymap.set('n', '<BS>', navigate_up, { buffer = layout.nav_buf, silent = true })

  -- Action mappings
  vim.keymap.set('n', 'x', reset_selected_key, { buffer = layout.nav_buf, silent = true })
  vim.keymap.set('n', 'e', edit_selected_key, { buffer = layout.nav_buf, silent = true })
  vim.keymap.set('n', 't', toggle_selected_key, { buffer = layout.nav_buf, silent = true })

  -- Common mappings for both panes
  for _, buf in ipairs({ layout.nav_buf, layout.config_buf }) do
    vim.keymap.set('n', 'q', M.close, { buffer = buf, silent = true })
    vim.keymap.set('n', '<Esc>', M.close, { buffer = buf, silent = true })
    vim.keymap.set('n', '<Tab>', cycle_config_mode, { buffer = buf, silent = true })
  end
end

function M.show()
  if layout.is_active then
    return
  end
  layout.is_active = true

  local ok, err = pcall(M.create_layout)
  if not ok then
    vim.notify('onion-ui: Failed to create layout: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end

  nav_state.set_selected_index(0)
  M.update_content()
  vim.api.nvim_win_set_cursor(layout.nav_win, { 1, 0 })

  M.setup_keymaps()
end

function M.close()
  if not layout.is_active then
    return
  end
  layout.is_active = false

  pcall(vim.api.nvim_del_augroup, 'OnionUICursorMove')

  cancel_edit()

  pcall(vim.api.nvim_win_close, layout.config_win, true)
  layout.config_win = nil
  layout.config_buf = nil

  pcall(vim.api.nvim_win_close, layout.nav_win, true)
  layout.nav_win = nil
  layout.nav_buf = nil
end

return M
