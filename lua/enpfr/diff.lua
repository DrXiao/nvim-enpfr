local M = {}

-- Skip diffing texts large enough that the O(n*m) LCS table below would be
-- slow or memory-heavy. Highlighting is a nicety; falling back to "nothing
-- changed" (no highlights) is a safe degradation, never a wrong answer.
local MAX_LCS_CELLS = 250000

-- Splits `text` into whitespace-delimited words, keeping each word's
-- (row, start_col, end_col) position. Rows and columns are 0-based; columns
-- are byte offsets, matching what nvim_buf_set_extmark expects. Splitting on
-- plain ASCII whitespace is UTF-8 safe: a multibyte character's continuation
-- bytes never collide with an ASCII whitespace byte.
local function tokenize(text)
  local words = {}
  local positions = {}
  local lines = vim.split(text, "\n", { plain = true })
  for row, line in ipairs(lines) do
    for start_pos, word, end_pos in line:gmatch("()(%S+)()") do
      words[#words + 1] = word
      positions[#positions + 1] = {
        row = row - 1,
        start_col = start_pos - 1,
        end_col = end_pos - 1,
      }
    end
  end
  return words, positions
end

-- Returns a boolean array `matched` of length #words_b: matched[j] is true
-- when words_b[j] is part of the longest common subsequence shared with
-- words_a, i.e. it also existed in the original text (possibly having moved).
-- Unmatched words are the ones the backend actually changed.
local function lcs_matched(words_a, words_b)
  local n, m = #words_a, #words_b
  local matched = {}
  for j = 1, m do
    matched[j] = false
  end
  if n == 0 or m == 0 then
    return matched
  end

  local lcs = {}
  for i = 0, n do
    lcs[i] = {}
    lcs[i][0] = 0
  end
  for j = 0, m do
    lcs[0][j] = 0
  end
  for i = 1, n do
    for j = 1, m do
      if words_a[i] == words_b[j] then
        lcs[i][j] = lcs[i - 1][j - 1] + 1
      else
        lcs[i][j] = math.max(lcs[i - 1][j], lcs[i][j - 1])
      end
    end
  end

  local i, j = n, m
  while i > 0 and j > 0 do
    if words_a[i] == words_b[j] then
      matched[j] = true
      i = i - 1
      j = j - 1
    elseif lcs[i - 1][j] >= lcs[i][j - 1] then
      i = i - 1
    else
      j = j - 1
    end
  end
  return matched
end

-- Returns a list of { row, start_col, end_col } ranges (0-based, end_col
-- exclusive) marking the words in `text` that differ from `original`, at
-- word granularity. Word order changes are not flagged: a word that merely
-- moved is still "in" the original text, only substituted or inserted words
-- are considered changed.
function M.changed_ranges(original, text)
  local original_words = tokenize(original)
  local text_words, positions = tokenize(text)

  if #original_words * #text_words > MAX_LCS_CELLS then
    return {}
  end

  local matched = lcs_matched(original_words, text_words)
  local ranges = {}
  for index, position in ipairs(positions) do
    if not matched[index] then
      ranges[#ranges + 1] = {
        row = position.row,
        start_col = position.start_col,
        end_col = position.end_col,
      }
    end
  end
  return ranges
end

return M
