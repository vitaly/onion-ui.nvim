local M = {}

-- Layout state
local layout_state = {
  nav_win = nil,
  nav_buf = nil,
  preview_win = nil,
  preview_buf = nil,
  config = nil,
}

-- Global flag to track if onion-ui is active
_G.onion_ui_active = false

-- Show the TUI layout
function M.show(config)
  layout_state.config = config
  _G.onion_ui_active = true

  -- Create layout with error handling
  local ok, err = pcall(M.create_layout)
  if not ok then
    vim.notify("onion-ui: Failed to create layout: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  -- Initialize content
  M.update_content()

  -- Set initial cursor position to first key
  local nav_pane = require("onion-ui.ui.nav_pane")
  local keys = nav_pane.get_current_keys()
  if #keys > 0 then
    vim.api.nvim_win_set_cursor(layout_state.nav_win, { 3, 2 }) -- Line 3, column 2 (after ▶)
  else
    vim.api.nvim_win_set_cursor(layout_state.nav_win, { 1, 0 })
  end

  -- Setup key mappings
  M.setup_keymaps()
end

-- Create the 2-pane floating window layout
function M.create_layout()
  local ui = vim.api.nvim_list_uis()[1]
  if not ui then
    vim.notify("onion-ui: No UI available", vim.log.levels.ERROR)
    return
  end

  local width = math.floor(ui.width * 0.8)
  local height = math.floor(ui.height * 0.8)
  local col = math.floor((ui.width - width) / 2)
  local row = math.floor((ui.height - height) / 2)

  -- Navigation pane (left, 40% width)
  local nav_width = math.floor(width * 0.4)
  local nav_config = {
    relative = "editor",
    width = nav_width,
    height = height,
    col = col,
    row = row,
    border = "single",
    style = "minimal",
    title = " Navigation ",
    title_pos = "center",
  }

  layout_state.nav_buf = vim.api.nvim_create_buf(false, true)
  layout_state.nav_win = vim.api.nvim_open_win(layout_state.nav_buf, true, nav_config)

  -- Preview pane (right, 60% width)
  local preview_width = width - nav_width - 3 -- Account for borders
  local preview_config = {
    relative = "editor",
    width = preview_width,
    height = height,
    col = col + nav_width + 3,
    row = row,
    border = "single",
    style = "minimal",
    title = " Preview ",
    title_pos = "center",
  }

  layout_state.preview_buf = vim.api.nvim_create_buf(false, true)
  layout_state.preview_win = vim.api.nvim_open_win(layout_state.preview_buf, false, preview_config)

  -- Set window options
  vim.api.nvim_win_set_option(layout_state.nav_win, "wrap", false)
  vim.api.nvim_win_set_option(layout_state.nav_win, "cursorline", true)
  vim.api.nvim_win_set_option(layout_state.preview_win, "wrap", true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(layout_state.nav_buf, "filetype", "onion-ui-nav")
  vim.api.nvim_buf_set_option(layout_state.preview_buf, "filetype", "lua")
end

-- Update content in both panes
function M.update_content()
  local nav_pane = require("onion-ui.ui.nav_pane")
  local preview_pane = require("onion-ui.ui.preview_pane")

  -- Preserve cursor positions before updating
  local nav_cursor = layout_state.nav_win and vim.api.nvim_win_is_valid(layout_state.nav_win) and vim.api.nvim_win_get_cursor(layout_state.nav_win) or nil
  local preview_cursor = layout_state.preview_win and vim.api.nvim_win_is_valid(layout_state.preview_win) and vim.api.nvim_win_get_cursor(layout_state.preview_win) or nil

  -- Update navigation pane with error handling
  if layout_state.nav_buf and vim.api.nvim_buf_is_valid(layout_state.nav_buf) then
    local ok, err = pcall(nav_pane.update, layout_state.nav_buf, layout_state.config)
    if not ok then
      vim.notify("onion-ui: Failed to update navigation pane: " .. tostring(err), vim.log.levels.WARN)
    end
  end

  -- Update preview pane with error handling
  if layout_state.preview_buf and vim.api.nvim_buf_is_valid(layout_state.preview_buf) then
    local ok, err = pcall(preview_pane.update, layout_state.preview_buf, layout_state.config)
    if not ok then
      vim.notify("onion-ui: Failed to update preview pane: " .. tostring(err), vim.log.levels.WARN)
    end
  end

  -- Restore cursor positions with bounds checking
  if nav_cursor then
    local total_lines = vim.api.nvim_buf_line_count(layout_state.nav_buf)
    local safe_line = math.min(nav_cursor[1], total_lines)
    vim.api.nvim_win_set_cursor(layout_state.nav_win, { safe_line, nav_cursor[2] })
  end
  if preview_cursor then
    local total_lines = vim.api.nvim_buf_line_count(layout_state.preview_buf)
    local safe_line = math.min(preview_cursor[1], total_lines)
    vim.api.nvim_win_set_cursor(layout_state.preview_win, { safe_line, preview_cursor[2] })
  end
end

-- Setup key mappings
function M.setup_keymaps()
  local nav_state = require("onion-ui.state.navigation")
  local nav_pane = require("onion-ui.ui.nav_pane")

  -- Track last cursor position to avoid unnecessary updates
  local last_cursor_line = 1

  -- Cursor movement handler - update selection based on cursor position
  local function update_selection_from_cursor()
    -- Validate window and buffer are still valid
    if not layout_state.nav_win or not vim.api.nvim_win_is_valid(layout_state.nav_win) then
      return
    end
    if not layout_state.nav_buf or not vim.api.nvim_buf_is_valid(layout_state.nav_buf) then
      return
    end

    local ok, cursor_pos = pcall(vim.api.nvim_win_get_cursor, layout_state.nav_win)
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
        local current_cursor = vim.api.nvim_win_get_cursor(layout_state.nav_win)
        M.update_content()
        vim.api.nvim_win_set_cursor(layout_state.nav_win, current_cursor)
      end
    end

    last_cursor_line = cursor_line
  end

  -- Set up autocmd to track cursor movement
  vim.defer_fn(function()
    if layout_state.nav_buf and vim.api.nvim_buf_is_valid(layout_state.nav_buf) then
      local cursor_move_group = vim.api.nvim_create_augroup("OnionUICursorMove", { clear = true })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = layout_state.nav_buf,
        group = cursor_move_group,
        callback = update_selection_from_cursor,
      })
    end
  end, 50)

  vim.api.nvim_buf_set_keymap(layout_state.nav_buf, "n", "<CR>", "", {
    callback = function()
      local keys = nav_pane.get_current_keys()
      local selected_idx = nav_state.get_selected_index()
      if selected_idx <= #keys then
        local selected_key = keys[selected_idx]
        nav_state.navigate_into(selected_key)
        M.update_content()
        -- Reset cursor to first key after navigation
        local new_keys = nav_pane.get_current_keys()
        if #new_keys > 0 then
          vim.api.nvim_win_set_cursor(layout_state.nav_win, { 3, 2 })
        end
      end
    end,
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(layout_state.nav_buf, "n", "h", "", {
    callback = function()
      local current_path = nav_state.get_path()
      if #current_path > 0 then -- Only go up if not at root
        nav_state.navigate_up()
        M.update_content()
        -- Reset cursor to first key after going up
        local keys = nav_pane.get_current_keys()
        if #keys > 0 then
          vim.api.nvim_win_set_cursor(layout_state.nav_win, { 3, 2 })
        end
      end
    end,
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(layout_state.nav_buf, "n", "<BS>", "", {
    callback = function()
      local current_path = nav_state.get_path()
      if #current_path > 0 then -- Only go up if not at root
        nav_state.navigate_up()
        M.update_content()
        -- Reset cursor to first key after going up
        local keys = nav_pane.get_current_keys()
        if #keys > 0 then
          vim.api.nvim_win_set_cursor(layout_state.nav_win, { 3, 2 })
        end
      end
    end,
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(layout_state.nav_buf, "n", "l", "", {
    callback = function()
      local keys = nav_pane.get_current_keys()
      local selected_idx = nav_state.get_selected_index()
      if selected_idx <= #keys then
        local selected_key = keys[selected_idx]
        nav_state.navigate_into(selected_key)
        M.update_content()
        -- Reset cursor to first key after navigation
        local new_keys = nav_pane.get_current_keys()
        if #new_keys > 0 then
          vim.api.nvim_win_set_cursor(layout_state.nav_win, { 3, 2 })
        end
      end
    end,
    noremap = true,
    silent = true,
  })

  -- Quit mappings
  local quit_mapping = function()
    M.close()
  end

  vim.api.nvim_buf_set_keymap(layout_state.nav_buf, "n", "q", "", {
    callback = quit_mapping,
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(layout_state.nav_buf, "n", "<Esc>", "", {
    callback = quit_mapping,
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(layout_state.preview_buf, "n", "q", "", {
    callback = quit_mapping,
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(layout_state.preview_buf, "n", "<Esc>", "", {
    callback = quit_mapping,
    noremap = true,
    silent = true,
  })

-- Add buffer close detection to close both panes
  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = layout_state.nav_buf,
    callback = M.close,
  })

  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = layout_state.preview_buf,
    callback = M.close,
  })
end

-- Close the TUI layout
function M.close()
  -- Only close if onion-ui is active
  if not _G.onion_ui_active then
    return
  end

  -- Clean up autocmd (with error handling)
  pcall(vim.api.nvim_del_augroup, "OnionUICursorMove")

  if layout_state.nav_win and vim.api.nvim_win_is_valid(layout_state.nav_win) then
    vim.api.nvim_win_close(layout_state.nav_win, true)
  end
  if layout_state.preview_win and vim.api.nvim_win_is_valid(layout_state.preview_win) then
    vim.api.nvim_win_close(layout_state.preview_win, true)
  end

  -- Reset state
  layout_state.nav_win = nil
  layout_state.nav_buf = nil
  layout_state.preview_win = nil
  layout_state.preview_buf = nil
  layout_state.config = nil
  _G.onion_ui_active = false
end

return M
