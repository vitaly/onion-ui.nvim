local M = {}

-- Current navigation path as list of strings
local current_path = {}

-- Current selected key index
local selected_index = 1

-- Reset navigation state to initial
function M.reset()
  current_path = {}
  selected_index = 1
end

-- Get current path as list
function M.get_path()
  return vim.deepcopy(current_path)
end

-- Set current path
function M.set_path(path)
  current_path = vim.deepcopy(path)
  selected_index = 1
end

-- Navigate to parent directory
function M.navigate_up()
  if #current_path > 0 then
    table.remove(current_path)
    selected_index = 1
  end
end

-- Navigate into a key
function M.navigate_into(key)
  table.insert(current_path, key)
  selected_index = 1
end

-- Get current path as display string
function M.get_display_path()
  if #current_path == 0 then
    return '/'
  end
  return '/' .. table.concat(current_path, '.')
end

-- Get current path as config query string
function M.get_config_path()
  if #current_path == 0 then
    return ''
  end
  return table.concat(current_path, '.')
end

-- Get selected index
function M.get_selected_index()
  return selected_index
end

-- Set selected index
function M.set_selected_index(index)
  selected_index = index
end

-- Increment selected index with wrap-around
function M.move_selection_down(max_items)
  if max_items == 0 then
    return
  end
  selected_index = selected_index % max_items + 1
end

-- Decrement selected index with wrap-around
function M.move_selection_up(max_items)
  if max_items == 0 then
    return
  end
  selected_index = (selected_index - 2) % max_items + 1
end

return M