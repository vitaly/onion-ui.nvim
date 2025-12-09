local M = {}

local config_pane = require('onion-ui.ui.config_pane')
local nav_pane = require('onion-ui.ui.nav_pane')
local nav_state = require('onion-ui.state.navigation')

-- Cursor position for first key (line 3 = after path + separator, column 2 = after indicator)
local FIRST_KEY_POS = { 3, 2 }

-- Layout state
local layout = {
  is_active = false,
  nav_win = nil,
  nav_buf = nil,
  config_win = nil,
  config_buf = nil,
}

-- Module-local flag to track if onion-ui is active

function M.layout()
  return layout
end

-- Show the TUI layout
function M.show()
  if layout.is_active then
    return
  end
  layout.is_active = true

  -- Create layout with error handling
  local ok, err = pcall(M.create_layout)
  if not ok then
    vim.notify('onion-ui: Failed to create layout: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end

  -- Initialize content
  M.update_content()

  -- Set initial cursor position to first key
  local keys = nav_pane.get_current_keys()
  if #keys > 0 then
    vim.api.nvim_win_set_cursor(layout.nav_win, FIRST_KEY_POS)
  else
    vim.api.nvim_win_set_cursor(layout.nav_win, { 1, 0 })
  end

  -- Setup key mappings
  M.setup_keymaps()
end

-- Create the 2-pane floating window layout
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

  -- Navigation pane (left, 40% width)
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

  -- Config pane (right, 60% width)
  local config_width = width - nav_width - 3 -- Account for borders
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

  -- Set window options
  vim.wo[layout.nav_win].wrap = false
  vim.wo[layout.nav_win].cursorline = true
  vim.wo[layout.config_win].wrap = true

  -- Set buffer options
  vim.bo[layout.nav_buf].filetype = 'onion-ui-nav'
  vim.bo[layout.config_buf].filetype = 'lua'
end

-- Update content in both panes
function M.update_content()
  -- Update navigation pane with error handling
  if layout.nav_buf and vim.api.nvim_buf_is_valid(layout.nav_buf) then
    local ok, err = pcall(nav_pane.update, layout.nav_buf, layout.nav_win)
    if not ok then
      vim.notify(
        'onion-ui: Failed to update navigation pane: ' .. tostring(err),
        vim.log.levels.WARN
      )
    end
  end

  -- Update config pane with error handling
  if layout.config_buf and vim.api.nvim_buf_is_valid(layout.config_buf) then
    local ok, err = pcall(config_pane.update, layout.config_buf, layout.config_win)
    if not ok then
      vim.notify('onion-ui: Failed to update config pane: ' .. tostring(err), vim.log.levels.WARN)
    end
  end
end

-- Setup key mappings
function M.setup_keymaps()
  -- Track last cursor position to avoid unnecessary updates
  local last_cursor_line = 1

  -- Cursor movement handler - update selection based on cursor position
  local function update_selection_from_cursor()
    -- Validate window and buffer are still valid
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

    -- Only update if cursor actually moved
    if cursor_line == last_cursor_line then
      return
    end

    local keys = nav_pane.get_current_keys()

    -- Check if cursor is on a key line (line >= 3)
    if cursor_line >= 3 and #keys > 0 then
      local key_index = cursor_line - 2 -- -2 for path and separator lines
      if key_index >= 1 and key_index <= #keys then
        nav_state.set_selected_index(key_index)
        -- Update content without moving cursor
        local current_cursor = vim.api.nvim_win_get_cursor(layout.nav_win)
        M.update_content()
        vim.api.nvim_win_set_cursor(layout.nav_win, current_cursor)
      end
    end

    last_cursor_line = cursor_line
  end

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

  -- Navigation functions
  local function navigate_into()
    local keys = nav_pane.get_current_keys()
    local selected_idx = nav_state.get_selected_index()
    if selected_idx <= #keys then
      local selected_key = keys[selected_idx]
      nav_state.navigate_into(selected_key)
      M.update_content()
      -- Reset cursor to first key after navigation
      local new_keys = nav_pane.get_current_keys()
      if #new_keys > 0 then
        vim.api.nvim_win_set_cursor(layout.nav_win, FIRST_KEY_POS)
      end
    end
  end

  local function navigate_up()
    local current_path = nav_state.get_path()
    if #current_path > 0 then -- Only go up if not at root
      -- The key we navigated into is the last element of current_path
      local parent_key = current_path[#current_path]

      nav_state.navigate_up()
      M.update_content()

      -- Position cursor at the parent key we just navigated out of
      local keys_after = nav_pane.get_current_keys()
      if #keys_after > 0 and parent_key then
        for i, key in ipairs(keys_after) do
          if key == parent_key then
            vim.api.nvim_win_set_cursor(layout.nav_win, { i + 2, 2 }) -- +2 for path and separator
            break
          end
        end
      else
        -- If no parent key found, position at first key
        vim.api.nvim_win_set_cursor(layout.nav_win, FIRST_KEY_POS)
      end
    end
  end

  -- Navigation mappings
  vim.keymap.set('n', '<CR>', navigate_into, { buffer = layout.nav_buf, silent = true })
  vim.keymap.set('n', 'h', navigate_up, { buffer = layout.nav_buf, silent = true })
  vim.keymap.set('n', '<BS>', navigate_up, { buffer = layout.nav_buf, silent = true })
  vim.keymap.set('n', 'l', navigate_into, { buffer = layout.nav_buf, silent = true })

  -- Common quit mappings for both panes
  for _, buf in ipairs({ layout.nav_buf, layout.config_buf }) do
    for _, key in ipairs({ 'q', '<Esc>' }) do
      vim.keymap.set('n', key, M.close, { buffer = buf, silent = true })
    end
  end
  vim.wo[layout.nav_win].winfixbuf = true
  vim.wo[layout.config_win].winfixbuf = true
end

-- Close the TUI layout
function M.close()
  -- Only close if onion-ui is active
  if not layout.is_active then
    return
  end
  layout.is_active = false

  -- Clean up autocmds (with error handling)
  pcall(vim.api.nvim_del_augroup, 'OnionUICursorMove')

  pcall(vim.api.nvim_win_close, layout.config_win, true)
  layout.config_win = nil
  layout.config_buf = nil

  pcall(vim.api.nvim_win_close, layout.nav_win, true)
  layout.nav_win = nil
  layout.nav_buf = nil
end

return M
