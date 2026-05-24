local H = require("tests.helpers")
local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local tiny = require("tiny-inline-diagnostic")

--- Set up a minimal config state without running full setup().
local function init_config(overrides)
  tiny.config = H.make_opts(overrides)
  tiny._original_options = vim.deepcopy(tiny.config.options)
end

local function teardown()
  tiny.config = nil
  tiny._original_options = nil
end

T["toggle_cursor_only"] = MiniTest.new_set({
  hooks = { pre_case = function() init_config() end, post_case = teardown },
})

T["toggle_cursor_only"]["flips show_diags_only_under_cursor"] = function()
  MiniTest.expect.equality(tiny.config.options.show_diags_only_under_cursor, false)
  tiny.toggle_cursor_only()
  MiniTest.expect.equality(tiny.config.options.show_diags_only_under_cursor, true)
  tiny.toggle_cursor_only()
  MiniTest.expect.equality(tiny.config.options.show_diags_only_under_cursor, false)
end

T["toggle_cursor_only"]["errors when not initialized"] = function()
  teardown()
  local ok = pcall(tiny.toggle_cursor_only)
  MiniTest.expect.equality(ok, false)
end

T["toggle_all_diags_on_cursorline"] = MiniTest.new_set({
  hooks = { pre_case = function() init_config() end, post_case = teardown },
})

T["toggle_all_diags_on_cursorline"]["flips show_all_diags_on_cursorline"] = function()
  MiniTest.expect.equality(tiny.config.options.show_all_diags_on_cursorline, false)
  tiny.toggle_all_diags_on_cursorline()
  MiniTest.expect.equality(tiny.config.options.show_all_diags_on_cursorline, true)
  tiny.toggle_all_diags_on_cursorline()
  MiniTest.expect.equality(tiny.config.options.show_all_diags_on_cursorline, false)
end

T["toggle_all_diags_on_cursorline"]["errors when not initialized"] = function()
  teardown()
  local ok = pcall(tiny.toggle_all_diags_on_cursorline)
  MiniTest.expect.equality(ok, false)
end

T["reset"] = MiniTest.new_set({
  hooks = { pre_case = function() init_config() end, post_case = teardown },
})

T["reset"]["restores options to original values"] = function()
  tiny.config.options.show_diags_only_under_cursor = true
  tiny.config.options.show_all_diags_on_cursorline = true
  tiny.config.options.severity = { vim.diagnostic.severity.ERROR }

  tiny.reset()

  MiniTest.expect.equality(tiny.config.options.show_diags_only_under_cursor, false)
  MiniTest.expect.equality(tiny.config.options.show_all_diags_on_cursorline, false)
  MiniTest.expect.equality(#tiny.config.options.severity, 4)
end

T["reset"]["restores after toggle_cursor_only"] = function()
  tiny.toggle_cursor_only()
  MiniTest.expect.equality(tiny.config.options.show_diags_only_under_cursor, true)

  tiny.reset()
  MiniTest.expect.equality(tiny.config.options.show_diags_only_under_cursor, false)
end

T["reset"]["restores to custom setup values not defaults"] = function()
  teardown()
  init_config({ options = { show_diags_only_under_cursor = true } })

  tiny.toggle_cursor_only()
  MiniTest.expect.equality(tiny.config.options.show_diags_only_under_cursor, false)

  tiny.reset()
  MiniTest.expect.equality(tiny.config.options.show_diags_only_under_cursor, true)
end

T["reset"]["errors when not initialized"] = function()
  teardown()
  local ok = pcall(tiny.reset)
  MiniTest.expect.equality(ok, false)
end

return T
