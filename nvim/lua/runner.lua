-- lua/runner.lua
-- Run the current file (C/C++/Python) or project (Makefile) in a bottom split.
-- Prefers Homebrew GCC (g++-15/14) over Apple clang++ when available.
-- Bulletproof against: Vim:jobstart(...,{term=true}) requires unmodified buffer

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

-- Resolve the C/C++ compiler with smart fallbacks.
-- For C++, we prefer real GCC from Homebrew (g++-15/14/13) over Apple's clang++.
local function resolve_cxx()
  -- Explicit override
  local env = os.getenv("NVIM_CXX")
  if env and vim.fn.executable(env) == 1 then return env end

  local candidates = {
    "g++-15", "g++-14", "g++-13", -- Homebrew GCC
    "g++",                        -- could be clang++ on macOS
    "c++",                        -- system default
  }
  for _, c in ipairs(candidates) do
    if vim.fn.executable(c) == 1 then return c end
  end
  return "c++"
end

local function resolve_cc()
  local env = os.getenv("NVIM_CC")
  if env and vim.fn.executable(env) == 1 then return env end

  local candidates = { "gcc-15", "gcc-14", "gcc-13", "gcc", "cc" }
  for _, c in ipairs(candidates) do
    if vim.fn.executable(c) == 1 then return c end
  end
  return "cc"
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
    -- Try `make run <args>` first, fall back to `make <args>`
    return "(make run " .. args .. ") || (make " .. args .. ")", root
  end

  if ft == "python" then
    return "python3 " .. shq(file) .. (args ~= "" and (" " .. args) or ""), root

  elseif ft == "cpp" then
    local cc = resolve_cxx()
    local cmd = cc .. " " .. CPP_FLAGS .. " " .. shq(file) .. " -o " .. shq(bin)
    cmd = cmd .. " && " .. shq(bin) .. (args ~= "" and (" " .. args) or "")
    return cmd, root

  elseif ft == "c" then
    local cc = resolve_cc()
    local cmd = cc .. " -O2 -Wall -Wextra -Wpedantic " .. shq(file) .. " -o " .. shq(bin)
    cmd = cmd .. " && " .. shq(bin) .. (args ~= "" and (" " .. args) or "")
    return cmd, root
  end

  -- No recipe for this filetype
  return nil, root
end

-- Always start a brand-new terminal buffer so it's never "modified" pre-termopen
local function ensure_term()
  vim.cmd("botright 15split | enew")
  local buf = vim.api.nvim_get_current_buf()
  -- Make the buffer ephemeral so it doesn't linger when hidden
  pcall(vim.api.nvim_buf_set_option, buf, "bufhidden", "wipe")
  return buf
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

  local term_buf = ensure_term()

  -- Guard cwd to avoid issues when not in a repo, etc.
  local safe_cwd = valid_dir(root) and root or vim.fn.expand("%:p:h")

  vim.fn.termopen({ "/bin/bash", "-lc", cmd }, {
    cwd = safe_cwd,
    on_exit = function(_, code)
      if code ~= 0 then
        vim.notify("Run failed (exit " .. code .. ")", vim.log.levels.ERROR)
      end
    end,
  })

  -- Enter terminal mode
  vim.schedule(function() vim.cmd("startinsert") end)
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

