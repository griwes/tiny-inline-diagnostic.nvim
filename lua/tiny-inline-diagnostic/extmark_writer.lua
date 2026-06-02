local M = {}

local function virt_text_width(virt_text)
  local width = 0

  for _, chunk in ipairs(virt_text or {}) do
    width = width + vim.fn.strdisplaywidth(chunk[1] or "")
  end

  return width
end

local function window_for_buffer(buf)
  local current = vim.api.nvim_get_current_win()

  if vim.api.nvim_win_get_buf(current) == buf then
    return current
  end

  local windows = vim.fn.win_findbuf(buf)
  local win = windows and windows[1]
  if win and vim.api.nvim_win_is_valid(win) then
    return win
  end

  return nil
end

local function window_text_width(win)
  local info = vim.fn.getwininfo(win)[1] or {}
  return math.max(0, vim.api.nvim_win_get_width(win) - (info.textoff or 0))
end

local function line_width_after_leftcol(buf, win, line)
  local text = vim.api.nvim_buf_get_lines(buf, line, line + 1, false)[1] or ""
  local leftcol = vim.api.nvim_win_call(win, function()
    return vim.fn.winsaveview().leftcol or 0
  end)

  return math.max(0, vim.fn.strdisplaywidth(text) - leftcol)
end

local function should_right_align(buf, line, virt_text, right_align)
  if not right_align or not right_align.enabled then
    return false
  end

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local win = window_for_buffer(buf)
  if not win then
    return false
  end

  local diagnostic_width = virt_text_width(virt_text)
  local code_width = line_width_after_leftcol(buf, win, line)
  local min_space = right_align.min_space or 1

  return code_width + min_space + diagnostic_width <= window_text_width(win)
end

---@param buf number
---@param namespace number
---@param line number
---@param virt_text table
---@param win_col number
---@param priority number
---@param pos string|nil
---@param uid_fn function
---@param right_align table|nil
function M.create_single_extmark(
  buf,
  namespace,
  line,
  virt_text,
  win_col,
  priority,
  pos,
  uid_fn,
  right_align
)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  if (pos == nil or pos == "overlay") and should_right_align(buf, line, virt_text, right_align) then
    pos = "right_align"
    win_col = nil
  end

  local extmark_opts = {
    id = uid_fn(),
    virt_text = virt_text,
    virt_text_pos = pos or "eol",
    virt_text_win_col = win_col,
    priority = priority,
    strict = false,
  }

  vim.api.nvim_buf_set_extmark(buf, namespace, line, 0, extmark_opts)
end

---@param buf number
---@param namespace number
---@param curline number
---@param virt_lines table
---@param priority number
---@param uid_fn function
---@param right_align table|nil
function M.create_multiline_extmark(
  buf,
  namespace,
  curline,
  virt_lines,
  priority,
  uid_fn,
  right_align
)
  local remaining_lines = { unpack(virt_lines, 2) }

  local virt_lines_trimmed = {}
  for i, t in ipairs(virt_lines[1]) do
    local ktrimmed = t[1]
    if not (right_align and right_align.enabled) and i ~= 1 then
      ktrimmed = ktrimmed:gsub("%s+", " ")
    end
    virt_lines_trimmed[i] = { ktrimmed, t[2] }
  end

  local virt_text_pos = "eol"
  local virt_text_win_col = nil

  if should_right_align(buf, curline, virt_lines_trimmed, right_align) then
    virt_text_pos = "right_align"
  end

  vim.api.nvim_buf_set_extmark(buf, namespace, curline, 0, {
    id = uid_fn(),
    virt_text_pos = virt_text_pos,
    virt_text_win_col = virt_text_win_col,
    virt_text = virt_lines_trimmed,
    virt_lines = remaining_lines,
    priority = priority,
    strict = false,
  })
end

---@param buf number
---@param namespace number
---@param params table
---@param uid_fn function
---@param right_align table|nil
function M.create_overflow_extmarks(buf, namespace, params, uid_fn, right_align)
  local existing_lines = params.buf_lines_count - params.curline
  local start_index = params.need_to_be_under and 3 or 1
  local signs_offset = params.need_to_be_under and (params.signs_offset == 0 and 0 or 1)
    or params.signs_offset

  if params.need_to_be_under then
    M.create_single_extmark(
      buf,
      namespace,
      params.curline + 1,
      params.virt_lines[2],
      params.win_col,
      params.priority,
      nil,
      uid_fn,
      right_align
    )
  end

  for i = start_index, existing_lines do
    local col_offset = params.win_col + params.offset + (i > start_index and signs_offset or 0)
    M.create_single_extmark(
      buf,
      namespace,
      params.curline + i - 1,
      params.virt_lines[i],
      col_offset,
      params.priority,
      "overlay",
      uid_fn,
      right_align
    )
  end

  local overflow_lines = {}
  for i = existing_lines + 1, #params.virt_lines do
    local line = vim.deepcopy(params.virt_lines[i])
    local col_offset = params.win_col + params.offset + (i > start_index and signs_offset or 0)
    table.insert(line, 1, { string.rep(" ", col_offset), "None" })
    table.insert(overflow_lines, line)
  end

  if #overflow_lines > 0 then
    vim.api.nvim_buf_set_extmark(buf, namespace, params.buf_lines_count - 1, 0, {
      id = uid_fn(),
      virt_lines_above = false,
      virt_lines = overflow_lines,
      priority = params.priority,
      strict = false,
    })
  end
end

---@param buf number
---@param namespace number
---@param curline number
---@param virt_lines table
---@param win_col number
---@param offset number
---@param signs_offset number
---@param priority number
---@param uid_fn function
---@param right_align table|nil
function M.create_simple_extmarks(
  buf,
  namespace,
  curline,
  virt_lines,
  win_col,
  offset,
  signs_offset,
  priority,
  uid_fn,
  right_align
)
  for i = 1, #virt_lines do
    local col_offset = i == 1 and win_col or (win_col + offset + signs_offset)
    M.create_single_extmark(
      buf,
      namespace,
      curline + i - 1,
      virt_lines[i],
      col_offset,
      priority,
      i > 1 and "overlay" or nil,
      uid_fn,
      right_align
    )
  end
end

return M
