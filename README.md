# onion-ui.nvim
A TUI for onion.nvim config editing.

## Usage

Start the TUI with:
```lua
require('onion-ui').start()
```

## Keybindings

- `j/k` - Navigate up/down through keys
- `h/l` - Navigate to parent/into selected key
- `<Enter>` - Navigate into selected key
- `x` - Reset selected key to default value
- `<Tab>` - Cycle config view (merged/default/user)
- `q/<Esc>` - Quit the TUI

## Requirements

Requires onion.nvim to be installed and available as `require('onion.config')`.
