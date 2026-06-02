---@class HighlightColor
---@field fg string
---@field bg string
---@field italic boolean

---@class BlendOptions
---@field factor number

---@class DefaultHighlights
---@field error string
---@field warn string
---@field info string
---@field hint string
---@field ok string
---@field arrow string
---@field background string
---@field mixing_color string

local M = {}

local highlighter_builder = require("tiny-inline-diagnostic.highlighter_builder")
local utils = require("tiny-inline-diagnostic.utils")

-- Constants
local DIAGNOSTIC_SEVERITIES = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  HINT = 4,
}

local SEVERITY_NAMES = { "Error", "Warn", "Info", "Hint" }
local HIGHLIGHT_PREFIX = "TinyInlineDiagnosticVirtualText"
local INV_HIGHLIGHT_PREFIX = "TinyInlineInvDiagnosticVirtualText"

---Get highlight attributes for a given highlight group
---@param name string
---@return HighlightColor
local function get_highlight(name)
  local hi = vim.api.nvim_get_hl(0, {
    name = name,
    link = false,
  })

  return {
    fg = utils.int_to_hex(hi.fg),
    bg = utils.int_to_hex(hi.bg),
    italic = hi.italic or false,
  }
end

---Get background color based on configuration
---@param color string
---@return string
local function get_background_color(color)
  if color == "None" or color:sub(1, 1) == "#" then
    return color
  end
  return get_highlight(color).bg
end

---@param key "fg"|"bg"
---@return string
local function get_configured_color(color, key)
  if color == "None" or color:sub(1, 1) == "#" then
    return color
  end
  return get_highlight(color)[key]
end

---@param color string
---@return HighlightColor|table
local function get_configured_highlight(color)
  if color == "None" or color:sub(1, 1) == "#" then
    return {}
  end
  return get_highlight(color)
end

---Get foreground color based on configuration
---@param color string
---@return string
local function get_foreground_color(color)
  return get_configured_color(color, "fg")
end

---Get mixing color based on configuration
---@param color string
---@return string
local function get_mixing_color(color)
  if color == "None" then
    return vim.o.background == "light" and "#ffffff" or "#000000"
  end
  if color:sub(1, 1) == "#" then
    return color
  end

  local resolved = get_highlight(color).bg
  if resolved == "None" then
    return vim.o.background == "light" and "#ffffff" or "#000000"
  end
  return resolved
end

---Check if the cursorline is visible
---@return boolean
local function is_cursorline_visible()
  if vim.opt.cursorline:get() then
    local cursorline_opt = vim.opt.cursorlineopt:get()
    return not (#cursorline_opt == 1 and cursorline_opt[1] == "number")
  end

  return false
end

---@param base table
---@param style table
---@return table
local function apply_highlight_style(base, style)
  local result = vim.deepcopy(base)

  if style.fg then
    result.fg = get_configured_color(style.fg, "fg")
  end
  if style.bg then
    result.bg = get_configured_color(style.bg, "bg")
  end

  for _, key in ipairs({ "bold", "italic", "underline", "undercurl", "strikethrough" }) do
    if style[key] ~= nil then
      result[key] = style[key]
    end
  end

  return result
end

---@param base table
---@param style table
---@return table
local function apply_highlight_style_preserve_no_bg(base, style)
  local result = apply_highlight_style(base, style)
  result.bg = "None"
  return result
end

---@param blend BlendOptions
---@param default_hi DefaultHighlights
---@param transparent_bg boolean
---@param highlight_opts table|nil
function M.setup_highlights(blend, default_hi, transparent_bg, highlight_opts)
  if not transparent_bg then
    transparent_bg = false
  end

  if blend.factor == 0 then
    transparent_bg = true
  end

  local cursorline_hl = get_highlight("CursorLine")
  local cursorline_is_visible = is_cursorline_visible()
  local has_cursorline_bg = cursorline_hl.bg ~= "None"

  local cursor_line_color = (cursorline_is_visible and has_cursorline_bg) and cursorline_hl
    or { bg = "None" }

  local colors = {
    error = get_highlight(default_hi.error),
    warn = get_highlight(default_hi.warn),
    info = get_highlight(default_hi.info),
    hint = get_highlight(default_hi.hint),
    ok = get_highlight(default_hi.ok),
    arrow = get_highlight(default_hi.arrow),
    cursor_line = cursor_line_color,
  }

  -- Get special colors
  colors.background = get_background_color(default_hi.background)
  colors.mixing_color = get_mixing_color(default_hi.mixing_color)

  -- Create blended colors
  local blends = {
    error = utils.blend(colors.error.fg, colors.mixing_color, blend.factor),
    warn = utils.blend(colors.warn.fg, colors.mixing_color, blend.factor),
    info = utils.blend(colors.info.fg, colors.mixing_color, blend.factor),
    hint = utils.blend(colors.hint.fg, colors.mixing_color, blend.factor),
    background = colors.background,
  }

  local base_groups = highlighter_builder.build_base_groups(colors, blends, transparent_bg)
  local mixed_groups = highlighter_builder.build_mixed_groups(base_groups)
  local hi = highlighter_builder.merge_groups(base_groups, mixed_groups)
  local non_current = highlight_opts and highlight_opts.non_current or {}
  local current_line = highlight_opts and highlight_opts.current_line or {}
  local under_cursor = highlight_opts and highlight_opts.under_cursor or {}

  if non_current.enabled then
    local dim_highlight = get_configured_highlight(non_current.dim_color or "Comment")
    local dim_color = get_foreground_color(non_current.dim_color or "Comment")

    for _, name in pairs(SEVERITY_NAMES) do
      local name_lower = string.lower(name)
      local base_name = HIGHLIGHT_PREFIX .. name
      local base = hi[base_name]
      local style = {
        fg = utils.blend(colors[name_lower].fg, dim_color, non_current.dim_factor or 0.35),
      }

      if non_current.bg ~= nil then
        style.bg = get_background_color(non_current.bg)
      end

      if non_current.italic ~= nil then
        style.italic = non_current.italic
      elseif dim_highlight.italic ~= nil then
        style.italic = dim_highlight.italic
      end

      hi[base_name .. "NonCurrent"] = vim.tbl_deep_extend("force", base, style)
    end
  end

  if current_line.enabled then
    for _, name in pairs(SEVERITY_NAMES) do
      local text_name = HIGHLIGHT_PREFIX .. name
      local sign_name = INV_HIGHLIGHT_PREFIX .. name

      hi[text_name .. "CurrentLine"] = apply_highlight_style(hi[text_name], current_line)
      hi[sign_name .. "CurrentLine"] = apply_highlight_style(hi[sign_name], current_line)
      hi[sign_name .. "CurrentLineNoBg"] =
        apply_highlight_style_preserve_no_bg(hi[sign_name .. "NoBg"], current_line)
    end
  end

  if under_cursor.enabled then
    for _, name in pairs(SEVERITY_NAMES) do
      local text_name = HIGHLIGHT_PREFIX .. name
      local sign_name = INV_HIGHLIGHT_PREFIX .. name

      hi[text_name .. "UnderCursor"] = apply_highlight_style(hi[text_name], under_cursor)
      hi[sign_name .. "UnderCursor"] = apply_highlight_style(hi[sign_name], under_cursor)
      hi[sign_name .. "UnderCursorNoBg"] =
        apply_highlight_style_preserve_no_bg(hi[sign_name .. "NoBg"], under_cursor)

      if current_line.enabled then
        hi[text_name .. "CurrentLineUnderCursor"] =
          apply_highlight_style(hi[text_name .. "CurrentLine"], under_cursor)
        hi[sign_name .. "CurrentLineUnderCursor"] =
          apply_highlight_style(hi[sign_name .. "CurrentLine"], under_cursor)
        hi[sign_name .. "CurrentLineUnderCursorNoBg"] =
          apply_highlight_style_preserve_no_bg(hi[sign_name .. "CurrentLineNoBg"], under_cursor)
      end
    end
  end

  for name, opts in pairs(hi) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

---Get diagnostic highlight groups
---@param blend_factor number
---@param diag_ret table
---@param curline number
---@param index_diag number
---@param opts table|nil
---@return string diag_hi
---@return string diag_inv_hi
---@return string body_hi
function M.get_diagnostic_highlights(blend_factor, diag_ret, curline, index_diag, opts)
  local diag_hi, diag_inv_hi, body_hi = M.get_diagnostic_highlights_from_severity(diag_ret.severity)

  local cursorline_is_visible = is_cursorline_visible()
  local non_current = opts and opts.non_current or {}
  local current_line = opts and opts.current_line or {}
  local under_cursor = opts and opts.under_cursor or {}
  local is_current_line = diag_ret.line and diag_ret.line == curline
  local sign_suffix = ""

  if
    (diag_ret.line and diag_ret.line == curline)
    and index_diag == 1
    and not diag_ret.need_to_be_under
  then
    if blend_factor == 0 then
      diag_hi = diag_hi .. "CursorLine"
      diag_inv_hi = diag_inv_hi .. "CursorLine"
    end
  end

  if
    (diag_ret.line and diag_ret.line ~= curline)
    or index_diag > 1
    or diag_ret.need_to_be_under
    or not cursorline_is_visible
  then
    diag_inv_hi = diag_inv_hi .. "NoBg"
  end

  if diag_inv_hi:find("NoBg$") then
    sign_suffix = "NoBg"
  end

  if diag_ret.under_cursor and under_cursor.enabled then
    local severity_name = SEVERITY_NAMES[diag_ret.severity]
      or SEVERITY_NAMES[DIAGNOSTIC_SEVERITIES.ERROR]
    local suffix = current_line.enabled and "CurrentLineUnderCursor" or "UnderCursor"
    diag_hi = HIGHLIGHT_PREFIX .. severity_name .. suffix
    diag_inv_hi = INV_HIGHLIGHT_PREFIX .. severity_name .. suffix .. sign_suffix
  elseif is_current_line and current_line.enabled then
    local severity_name = SEVERITY_NAMES[diag_ret.severity]
      or SEVERITY_NAMES[DIAGNOSTIC_SEVERITIES.ERROR]
    diag_hi = HIGHLIGHT_PREFIX .. severity_name .. "CurrentLine"
    diag_inv_hi = INV_HIGHLIGHT_PREFIX .. severity_name .. "CurrentLine" .. sign_suffix
  elseif diag_ret.line and diag_ret.line ~= curline and non_current.enabled then
    diag_hi = diag_hi .. "NonCurrent"
  end

  return diag_hi, diag_inv_hi, body_hi
end

---Get base diagnostic highlight groups from severity
---@param severity number
---@return string diag_hi
---@return string diag_inv_hi
---@return string body_hi
function M.get_diagnostic_highlights_from_severity(severity)
  local hi = SEVERITY_NAMES[severity]
  if not hi then
    hi = SEVERITY_NAMES[DIAGNOSTIC_SEVERITIES.ERROR]
  end

  return HIGHLIGHT_PREFIX .. hi, INV_HIGHLIGHT_PREFIX .. hi, INV_HIGHLIGHT_PREFIX .. hi .. "NoBg"
end

---Get mixed diagnostic highlight groups from two severities
---@param severity_a number
---@param severity_b number
---@return string diag_hi
---@return string diag_inv_hi
function M.get_diagnostic_mixed_highlights_from_severity(severity_a, severity_b)
  local hi_a = SEVERITY_NAMES[severity_a] or SEVERITY_NAMES[DIAGNOSTIC_SEVERITIES.ERROR]
  local hi_b = SEVERITY_NAMES[severity_b] or SEVERITY_NAMES[DIAGNOSTIC_SEVERITIES.ERROR]

  return HIGHLIGHT_PREFIX .. hi_b .. "Mix" .. hi_a, INV_HIGHLIGHT_PREFIX .. hi_a .. "Mix" .. hi_b
end

---Get diagnostic icon
---@param severity number|string
---@return string
function M.get_diagnostic_icon(severity)
  local name = vim.diagnostic.severity[severity]:lower():gsub("^%l", string.upper)
  local sign = vim.fn.sign_getdefined("DiagnosticSign" .. name)[1]

  if vim.fn.has("nvim-0.10.0") == 1 then
    local config = vim.diagnostic.config() or {}
    if config.signs == nil or type(config.signs) == "boolean" then
      return sign and sign.text or name:sub(1, 1)
    end
    local signs = config.signs or {}
    if type(signs) == "function" then
      signs = signs(0, 0)
    end
    return type(signs) == "table" and signs.text and signs.text[severity]
      or sign and sign.text
      or name:sub(1, 1)
  end

  return sign and sign.text or name or SEVERITY_NAMES[severity]:sub(1, 1)
end

return M
