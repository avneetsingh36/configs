-- lua/runner.lua
local M = {}

-- Customize C++ flags or set NVIM_CPP_FLAGS in your shell
local CPP_FLAGS = os.getenv("NVIM_CPP_FLAGS")
  or "-std=c++20 -O2 -Wall -Wextra -Wpedantic"

-- ----- helpers --------------------------------------------------------------

local function shq(s)  -- POSIX-safe single-quote
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function exists(p)
  return vim.fn.filereadable(p) == 1 or vim.fn.isdirectory(p) == 1
end

local function valid_dir(p)
  return type(p) == "string" and p ~= "" and vim.fn.isdirectory(p) == 1
end

local function project_root()
  -- Prefer git root if available (suppress stderr; check exit code)
  local out = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")
  if vim.v.shell_error == 0 and out and valid_dir(out[1]) then
    return out[1]
  end

  -- Fallback: walk upwards for common project markers
  local markers = {
    "Makefile", "CMakeLists.txt",
    "pyproject.toml", "package.json",
    "go.mod", "Cargo.toml",
  }
  local dir, last = vim.fn.expand("%:p:h"), ""
  while dir ~= "" and dir ~= last do
    for _, m in ipairs(markers) do
      if exists(dir .. "/" .. m) then
        return dir
      end
    end
    last = dir
    dir = vim.fn.fnamemodify(dir, ":h")
  end

  -- Final fallback: the file's directory
  return vim.fn.expand("%:p:h")
end

local function ensure_term()
  if M._buf and vim.api.nvim_buf_is_valid(M._buf) then
    local wins = vim.fn.win_findbuf(M._buf)
    if #wins > 0 then
      vim.api.nvim_set_current_win(wins[1])
    else
      vim.cmd("botright 15split")
      vim.api.nvim_win_set_buf(0, M._buf)
    end
    -- clear previous output
    pcall(vim.api.nvim_buf_set_option, M._buf, "modifiable", true)
    pcall(vim.api.nvim_buf_set_lines, M._buf, 0, -1, false, {})
    return M._buf
  else
    vim.cmd("botright 15split")
    M._buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, M._buf)
    vim.api.nvim_buf_set_option(M._buf, "bufhidden", "hide")
    return M._buf
  end
end

local function build_cmd(args)
  args = args or ""
  local ft    = vim.bo.filetype
  local file  = vim.fn.expand("%:p")
  local root  = project_root()
  local base  = vim.fn.expand("%:t:r")
  local bin   = "/tmp/nvim_run_" .. base

  -- If there's a Makefile at root, prefer it
  if exists(root .. "/Makefile") then
    return "(make run " .. args .. ") || (make " .. args .. ")", root
  end

  if ft == "python" then
    return "python3 " .. shq(file) .. (args ~= "" and (" " .. args) or ""), root

  elseif ft == "cpp" or ft == "c" then
    local cc = (ft == "cpp") and "g++" or "cc"
    local cmd = cc .. " " .. CPP_FLAGS .. " " .. shq(file) .. " -o " .. shq(bin)
    cmd = cmd .. " && " .. shq(bin) .. (args ~= "" and (" " .. args) or "")
    return cmd, root
  end

  -- No recipe for this filetype
  return nil, root
end

-- ----- public API -----------------------------------------------------------

function M.run(args)
  vim.cmd("w") -- save before running
  local cmd, root = build_cmd(args)
  if not cmd then
    vim.notify("No run recipe for filetype: " .. tostring(vim.bo.filetype),
      vim.log.levels.WARN)
    return
  end

  ensure_term()

  -- Guard cwd to avoid E475 when git isn't a repo, etc.
  local safe_cwd = valid_dir(root) and root or vim.fn.expand("%:p:h")

  vim.fn.termopen({ "/bin/bash", "-lc", cmd }, {
    cwd = safe_cwd,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.notify("Run failed (exit " .. code .. ")", vim.log.levels.ERROR)
      end
    end,
  })
  vim.cmd("startinsert")
end

function M.run_with_args()
  vim.ui.input({ prompt = "Args: " }, function(input)
    M.run(input or "")
  end)
end

function M.setup()
  -- Keymaps
  vim.keymap.set("n", "<leader>r", function() M.run("") end,
    { desc = "Run current file/project" })
  vim.keymap.set("n", "<leader>R", M.run_with_args,
    { desc = "Run with args…" })

  -- Commands
  vim.api.nvim_create_user_command("Run", function(opts)
    M.run(opts.args or "")
  end, { nargs = "*" })

  vim.api.nvim_create_user_command("RunArgs", function()
    M.run_with_args()
  end, {})
end

return M

