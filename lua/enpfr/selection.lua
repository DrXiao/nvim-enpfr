local M = {}

local function comes_after(left, right)
  return left[1] > right[1] or (left[1] == right[1] and left[2] > right[2])
end

local function normalize(first, last)
  if comes_after(first, last) then
    return last, first
  end
  return first, last
end

local function character_length(line, byte_column)
  if byte_column >= #line then
    return 0
  end

  local character = vim.fn.nr2char(vim.fn.char2nr(line:sub(byte_column + 1)))
  return #character
end

local function inclusive_end(line, byte_column)
  return byte_column + character_length(line, byte_column)
end

local function character_start(line, byte_column)
  while byte_column > 0 do
    local byte = line:byte(byte_column + 1)
    if not byte or byte < 128 or byte >= 192 then
      break
    end
    byte_column = byte_column - 1
  end
  return byte_column
end

function M.extract(lines, mode, first, last)
  first, last = normalize(first, last)

  if mode == "V" then
    local selected = {}
    for row = first[1], last[1] do
      selected[#selected + 1] = lines[row] or ""
    end
    return table.concat(selected, "\n")
  end

  if mode == "\22" then
    local selected = {}
    local start_column = math.min(first[2], last[2])
    local end_column = math.max(first[2], last[2])
    for row = first[1], last[1] do
      local line = lines[row] or ""
      selected[#selected + 1] = line:sub(
        start_column + 1,
        inclusive_end(line, end_column)
      )
    end
    return table.concat(selected, "\n")
  end

  local selected = {}
  for row = first[1], last[1] do
    local line = lines[row] or ""
    if first[1] == last[1] then
      selected[#selected + 1] = line:sub(
        first[2] + 1,
        inclusive_end(line, last[2])
      )
    elseif row == first[1] then
      selected[#selected + 1] = line:sub(first[2] + 1)
    elseif row == last[1] then
      selected[#selected + 1] = line:sub(1, inclusive_end(line, last[2]))
    else
      selected[#selected + 1] = line
    end
  end
  return table.concat(selected, "\n")
end

function M.from_buffer(buffer, mode, first, last)
  first, last = normalize(first, last)

  if mode == "\22" then
    local window = vim.fn.bufwinid(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer, first[1] - 1, last[1], false)
    local first_line = lines[1] or ""
    local last_line = lines[#lines] or ""
    local first_start = vim.fn.strdisplaywidth(first_line:sub(1, first[2])) + 1
    local last_start = vim.fn.strdisplaywidth(last_line:sub(1, last[2])) + 1
    local first_end = vim.fn.virtcol({ first[1], first[2] + 1, 0 })
    local last_end = vim.fn.virtcol({ last[1], last[2] + 1, 0 })
    local start_virtual = math.min(first_start, last_start)
    local end_virtual = math.max(first_end, last_end)
    local selected = {}

    for index, line in ipairs(lines) do
      local row = first[1] + index - 1
      if vim.fn.strdisplaywidth(line) < start_virtual then
        selected[#selected + 1] = ""
      else
        local start_column = character_start(
          line,
          vim.fn.virtcol2col(window, row, start_virtual) - 1
        )
        local end_column = character_start(
          line,
          vim.fn.virtcol2col(window, row, end_virtual) - 1
        )
        selected[#selected + 1] = M.extract(
          { line },
          "v",
          { 1, start_column },
          { 1, end_column }
        )
      end
    end
    return table.concat(selected, "\n")
  end

  local lines = vim.api.nvim_buf_get_lines(buffer, first[1] - 1, last[1], false)
  return M.extract(lines, mode, { 1, first[2] }, { #lines, last[2] })
end

local function previous_position(lines, position)
  local row, column = position[1], position[2]
  if column > 0 then
    local character_count = vim.fn.strchars((lines[row] or ""):sub(1, column))
    return { row, vim.str_byteindex(lines[row] or "", character_count - 1) }
  end
  if row <= 1 then
    return nil
  end

  local line = lines[row - 1] or ""
  if line == "" then
    return { row - 1, 0 }
  end
  return { row - 1, vim.str_byteindex(line, vim.fn.strchars(line) - 1) }
end

function M.adjust_exclusive(lines, first, last)
  first, last = normalize(first, last)
  last = previous_position(lines, last)

  if not first or not last or comes_after(first, last) then
    return nil, nil
  end
  return first, last
end

return M
