-- Simple test script for onion-ui.nvim
-- This can be used to test the plugin without onion.nvim

-- Mock onion.config for testing
package.loaded["onion.config"] = {
  get = function(path)
    local mock_config = {
      foo = {
        bar = true,
        baz = 42,
        nested = {
          deep = "value",
        },
      },
      hello = "world",
      number = 123,
      flag = false,
    }

    if path == "" then
      return mock_config
    elseif path == "foo" then
      return mock_config.foo
    elseif path == "foo.bar" then
      return mock_config.foo.bar
    elseif path == "foo.baz" then
      return mock_config.foo.baz
    elseif path == "foo.nested" then
      return mock_config.foo.nested
    elseif path == "foo.nested.deep" then
      return mock_config.foo.nested.deep
    elseif path == "hello" then
      return mock_config.hello
    elseif path == "number" then
      return mock_config.number
    elseif path == "flag" then
      return mock_config.flag
    else
      return nil
    end
  end,
  get_default = function(path)
    return {}
  end,
  get_user = function(path)
    return {}
  end,
}

-- Test the plugin
local onion_ui = require("onion-ui")
print("Starting onion-ui test...")
onion_ui.start()

