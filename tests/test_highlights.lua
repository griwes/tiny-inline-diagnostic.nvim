local MiniTest = require("mini.test")
local highlights = require("tiny-inline-diagnostic.highlights")

local T = MiniTest.new_set()

T["get_diagnostic_highlights"] = MiniTest.new_set()

-- Test: Regular diagnostic NOT on cursor line
T["get_diagnostic_highlights"]["not on cursor line uses regular highlights"] = function()
  local diag_ret = { line = 5, severity = 1 }
  local curline = 10
  local blend_factor = 0.5
  local index_diag = 1

  local diag_hi, diag_inv_hi, body_hi = highlights.get_diagnostic_highlights(
    blend_factor,
    diag_ret,
    curline,
    index_diag
  )

  -- Should use regular highlights, not CursorLine variants
  MiniTest.expect.equality(diag_hi, "TinyInlineDiagnosticVirtualTextError")
  MiniTest.expect.equality(diag_inv_hi, "TinyInlineInvDiagnosticVirtualTextErrorNoBg")
  MiniTest.expect.equality(body_hi, "TinyInlineInvDiagnosticVirtualTextErrorNoBg")
end

-- Test: Diagnostic on cursor line with blend_factor = 0 (transparent mode)
T["get_diagnostic_highlights"]["on cursor line with blend_factor=0 uses CursorLine"] = function()
  vim.opt.cursorline = true
  vim.api.nvim_set_hl(0, "CursorLine", { bg = "#ff0000" })

  local diag_ret = { line = 10, severity = 1 }
  local curline = 10
  local blend_factor = 0
  local index_diag = 1

  local diag_hi, diag_inv_hi, body_hi = highlights.get_diagnostic_highlights(
    blend_factor,
    diag_ret,
    curline,
    index_diag
  )

  -- With blend_factor=0, should use CursorLine variants to show cursor line through
  MiniTest.expect.equality(diag_hi, "TinyInlineDiagnosticVirtualTextErrorCursorLine")
  MiniTest.expect.equality(diag_inv_hi, "TinyInlineInvDiagnosticVirtualTextErrorCursorLine")
  MiniTest.expect.equality(body_hi, "TinyInlineInvDiagnosticVirtualTextErrorNoBg")
end

-- Test: Diagnostic on cursor line with blend_factor != 0 (colored mode)
T["get_diagnostic_highlights"]["on cursor line with blend_factor!=0 uses colored background"] =
  function()
    vim.opt.cursorline = true
    vim.api.nvim_set_hl(0, "CursorLine", { bg = "#ff0000" })

    local diag_ret = { line = 10, severity = 1 }
    local curline = 10
    local blend_factor = 0.5
    local index_diag = 1

    local diag_hi, diag_inv_hi, body_hi = highlights.get_diagnostic_highlights(
      blend_factor,
      diag_ret,
      curline,
      index_diag
    )

    -- With blend_factor!=0, should use ERROR background color, NOT cursor line background
    -- The message should have red background for errors, not the cursor line background
    MiniTest.expect.equality(diag_hi, "TinyInlineDiagnosticVirtualTextError")
    MiniTest.expect.equality(diag_inv_hi, "TinyInlineInvDiagnosticVirtualTextError")
    MiniTest.expect.equality(body_hi, "TinyInlineInvDiagnosticVirtualTextErrorNoBg")
  end

-- Test: Diagnostic on cursor line with need_to_be_under (overflow to next line)
T["get_diagnostic_highlights"]["with need_to_be_under uses NoBg"] = function()
  vim.opt.cursorline = true
  vim.api.nvim_set_hl(0, "CursorLine", { bg = "#ff0000" })

  local diag_ret = { line = 10, severity = 1, need_to_be_under = true }
  local curline = 10
  local blend_factor = 0.5
  local index_diag = 1

  local diag_hi, diag_inv_hi, body_hi = highlights.get_diagnostic_highlights(
    blend_factor,
    diag_ret,
    curline,
    index_diag
  )

  -- With need_to_be_under, should NOT use CursorLine, should use NoBg
  MiniTest.expect.equality(diag_hi, "TinyInlineDiagnosticVirtualTextError")
  MiniTest.expect.equality(diag_inv_hi, "TinyInlineInvDiagnosticVirtualTextErrorNoBg")
  MiniTest.expect.equality(body_hi, "TinyInlineInvDiagnosticVirtualTextErrorNoBg")
end

-- Test: Second diagnostic (index_diag > 1) uses NoBg
T["get_diagnostic_highlights"]["second diagnostic uses NoBg"] = function()
  local diag_ret = { line = 10, severity = 1 }
  local curline = 10
  local blend_factor = 0.5
  local index_diag = 2

  local diag_hi, diag_inv_hi, body_hi = highlights.get_diagnostic_highlights(
    blend_factor,
    diag_ret,
    curline,
    index_diag
  )

  -- Second diagnostic should use NoBg for inv highlights
  MiniTest.expect.equality(diag_hi, "TinyInlineDiagnosticVirtualTextError")
  MiniTest.expect.equality(diag_inv_hi, "TinyInlineInvDiagnosticVirtualTextErrorNoBg")
  MiniTest.expect.equality(body_hi, "TinyInlineInvDiagnosticVirtualTextErrorNoBg")
end

-- Test: Different severity levels
T["get_diagnostic_highlights"]["respects severity levels"] = function()
  local severities = { 1, 2, 3, 4 }
  local expected = { "Error", "Warn", "Info", "Hint" }

  for i, severity in ipairs(severities) do
    local diag_ret = { line = 5, severity = severity }
    local curline = 10
    local blend_factor = 0.5
    local index_diag = 1

    local diag_hi, _, _ = highlights.get_diagnostic_highlights(blend_factor, diag_ret, curline, index_diag)

    MiniTest.expect.equality(diag_hi, "TinyInlineDiagnosticVirtualText" .. expected[i])
  end
end

-- Test: When cursorline is disabled but CursorLine highlight exists
T["get_diagnostic_highlights"]["cursorline disabled uses NoBg for signs"] = function()
  -- Cursorline is disabled
  vim.opt.cursorline = false
  -- But CursorLine highlight is still defined
  vim.api.nvim_set_hl(0, "CursorLine", { bg = "#ff0000" })

  local diag_ret = { line = 10, severity = 1 }
  local curline = 10
  local blend_factor = 0.5
  local index_diag = 1

  local diag_hi, diag_inv_hi, body_hi = highlights.get_diagnostic_highlights(
    blend_factor,
    diag_ret,
    curline,
    index_diag
  )

  -- When cursorline is disabled, even if on cursor line, signs should be NoBg (transparent)
  -- The message can have colored background, but signs should be transparent
  MiniTest.expect.equality(diag_hi, "TinyInlineDiagnosticVirtualTextError")
  MiniTest.expect.equality(diag_inv_hi, "TinyInlineInvDiagnosticVirtualTextErrorNoBg")
  MiniTest.expect.equality(body_hi, "TinyInlineInvDiagnosticVirtualTextErrorNoBg")
end

return T
