# nvim-compare-with-clipboard

Compare text against your clipboard (or any Vim register) in **diff view** — either from an **LSP code action (null-ls/none-ls)**, from **Visual mode**, or via an **interactive prompt**.

This plugin opens a new tab with two scratch buffers and calls `:diffthis` on both, so you get a clean, side-by-side or top/bottom diff without touching your real files.

---

## ✨ Features

- **Visual selection → clipboard** in one command
- **Register ↔ register** comparison (`"+", "*", "a"…"z", "0"…"9", etc.)
- **Interactive compare**: choose to compare your clipboard with:
  - Current buffer (whole contents)
  - Another register
  - Raw text typed in a `vim.ui.input` prompt
  - **Raw text in a floating scratch buffer** (paste multi-line, then submit with `<C-s>`)
- Works **with or without null-ls/none-ls**:
  - With null-ls: shows a “Compare selection with clipboard” **code action** in Visual mode
  - Without null-ls: direct Lua API + user commands
- Configurable **vertical/horizontal** split and default **clipboard register** (`+` by default)

---

## 📦 Installation

Using **packer.nvim**:
```lua
use 'antosha417/nvim-compare-with-clipboard'
````

Using **lazy.nvim**:

```lua
{
  'antosha417/nvim-compare-with-clipboard',
  opts = {
    -- optional configuration (see "Configuration")
  },
}
```

---

## ⚙️ Setup

If you only need the defaults, you can skip `setup()` entirely.
Call it only to override options or to auto-create user commands (enabled by default).

```lua
require('compare-with-clipboard').setup({
  -- by default splits are horizontal
  vertical_split = false,

  -- default source register for "clipboard" actions
  register = "+",

  -- auto-create user commands:
  create_user_commands = true,

  -- floating input settings (used by the interactive "raw text (floating buffer)" option)
  float = {
    border = 'rounded',
    width = 0.8,   -- 80% of editor width
    height = 0.5,  -- 50% of editor height
    title = "Compare with Clipboard — Input",
    submit_mapping = "<C-s>", -- press to submit the floating input
  },
})
```

### With null-ls / none-ls (code action)

```lua
local null_ls = require("null-ls") -- or require("none-ls")

null_ls.setup({
  sources = {
    -- your other sources...
    require('compare-with-clipboard.null-ls').code_actions.compare_with_clipboard({
      -- by default splits are horizontal
      vertical_split = false,
      -- by default compares with `+` register
      register = "+",
    }),
  },
})
```

> The code action appears when you select text in **Visual mode** and trigger LSP code actions.

---

## 🧰 Commands

These are automatically created when `create_user_commands = true` (default).
If you prefer not to create commands automatically, set `create_user_commands = false`
and call the Lua functions directly (see **API** below).

### `:CompareSelectionWithRegister [reg]`  *(Visual)*

Compare the **current visual selection** with a register (defaults to `+`):

* From Visual mode:

  ```
  :CompareSelectionWithRegister
  :CompareSelectionWithRegister *
  :'<,'>CompareSelectionWithRegister a
  ```

### `:CompareClipboardWith [reg]`  *(Normal)*

Show an interactive picker (`vim.ui.select`) asking what to compare the clipboard with:

* **Current buffer**
* **Another register...** (prompts via `vim.ui.input`)
* **Raw text (single-line prompt)...**
* **Raw text (floating buffer)...** (multi-line; submit with `<C-s>`, cancel with `<Esc>`)

Examples:

```
:CompareClipboardWith      " uses + register by default
:CompareClipboardWith *    " use * register as the source clipboard
```

### `:CompareRegisters {reg1} {reg2}`

Directly diff two registers:

```
:CompareRegisters + *
:CompareRegisters a b
```

All commands support register completion (`+`, `*`, `"`, `0`…`9`, `a`…`z`, `A`…`Z`).

---

## 🎛️ Lua API

```lua
local cwc = require('compare-with-clipboard')

-- Compare two registers (existing API)
cwc.compare_registers(reg1, reg2, { vertical_split = false })

-- Compare current visual selection with a register (default "+")
cwc.compare_visual_selection_with_register("+", {
  -- range = {line1, line2} -- optional fallback if not called from Visual mode
  vertical_split = false,
})

-- Interactive: pick a target to compare the clipboard with
cwc.compare_clipboard_with_prompt({
  register = "+",       -- source register to treat as "clipboard"
  vertical_split = true -- choose split direction
})
```

All functions open a **new tab** with two scratch buffers in **diff** mode.

---

## ⌨️ Example keymaps

```lua
-- Compare visual selection with system clipboard (+)
vim.keymap.set('x', '<leader>vc', function()
  require('compare-with-clipboard').compare_visual_selection_with_register('+')
end, { desc = 'Diff selection ↔ clipboard' })

-- Same, but prompt for a specific register
vim.keymap.set('x', '<leader>v"', function()
  vim.ui.input({ prompt = 'Register to compare (e.g. +, *, ", a, 0): ' }, function(reg)
    if reg and reg ~= '' then
      require('compare-with-clipboard').compare_visual_selection_with_register(reg)
    end
  end)
end, { desc = 'Diff selection ↔ chosen register' })

-- Open the interactive chooser (Normal mode)
vim.keymap.set('n', '<leader>vi', '<cmd>CompareClipboardWith<CR>', { desc = 'Diff clipboard ↔ pick target' })

-- Direct register ↔ register
vim.keymap.set('n', '<leader>vr', function()
  -- example: compare + vs *
  require('compare-with-clipboard').compare_registers('+', '*')
end, { desc = 'Diff register ↔ register' })
```

---

## 🧩 Notes

* Buffers are scratch (`buftype=nofile`, `buflisted=false`) to avoid touching disk.
* Diff views are snapshots at the time of invocation.
* The floating input buffer uses a fixed submit mapping (default `<C-s>`) and `<Esc>` to cancel.
  Customize it via `require('compare-with-clipboard').setup({ float = { submit_mapping = "<C-s>" } })`.

---

## 🤝 Contributing

PRs are welcome! If you have an idea for an additional target (e.g. compare clipboard with a file on disk), open an issue or a PR.

```

---

### What changed at a glance

- **New API**
  - `compare_visual_selection_with_register(reg?, opts?)`
  - `compare_clipboard_with_prompt(opts?)`
- **New user commands**
  - `:CompareSelectionWithRegister [reg]` (Visual or via `:'<,'>`)
  - `:CompareClipboardWith [reg]` (Normal; interactive)
  - `:CompareRegisters {reg1} {reg2}`
- **Utilities**
  - Visual selection capture (char/line/block)
  - Whole-buffer capture
  - Multi-line floating input with `<C-s>` submit / `<Esc>` cancel
  - Register completion for commands
- **README** fully expanded with examples and keymaps

If you want me to also convert the null‑ls example to **none‑ls** syntax or add tests, I can do that too.
