# onion-ui.nvim

Hey there! Ever wished you could just *see* and tweak your Neovim config layers without diving into Lua files? That's what onion-ui.nvim is all about - a slick terminal UI that makes managing your [onion.nvim](https://github.com/vitaly/onion.nvim) configurations a breeze.

If you're using onion.nvim to layer your config like an onion (defaults underneath, your personal tweaks on top), this UI gives you a visual way to navigate, edit, and reset those settings. No more guessing what's overridden or hunting through tables - just browse and modify right in your editor.

## Quick Start

First, make sure you've got [onion.nvim](https://github.com/vitaly/onion.nvim) set up. Then install this UI companion and fire it up:

```lua
require('onion-ui').start()
```

Boom! You'll see your config tree laid out nicely, with colors showing what's default vs. what you've customized.

## Getting Around

The navigation feels natural if you're used to Vim:

- `j/k` - Move up and down through your config keys
- `h/l` - Go back to parent or dive into the selected key
- `<Enter>` - Same as `l` - drill down into nested settings
- `x` - Reset the selected key back to its default value (bye-bye custom override!)
- `e` - Edit the value right there as a Lua expression
- `<Tab>` - Switch between viewing merged config, just defaults, or only your user overrides
- `q` or `<Esc>` - Get out when you're done

## What You Need

This is a UI for [onion.nvim](https://github.com/vitaly/onion.nvim), so you'll need that installed first. It expects to find the config module at `require('onion.config')`.

## Why This Exists

I got tired of mentally juggling config layers and wanted a way to see exactly what was going on. Now you can spot at a glance what's default, what's customized, and easily tweak things without touching code. It's like having a config explorer built right into Neovim!
