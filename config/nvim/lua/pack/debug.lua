--------------------------------------- DEBUG ADAPTER SUPPORT --------------------------------------

local function nnoremap(k, cb) vim.keymap.set('n', k, cb) end
local function nunmap(k) vim.keymap.del('n', k) end

----------------------------- NVIM-DAP CONFIG -----------------------------

---Program picker for a language
---@param lang string
---@return function
local function program_picker(lang)
    return function ()
        local file = ''
        vim.ui.input({ prompt = ('Debug target (%s): '):format(lang), completion = 'file' },
            function (input)
                if not input or input == '' then return end
                file = input
            end)
        return file ~= '' and file or require('dap').ABORT
    end
end

---Debug adapter configurations
local adapter_configs = {
    codelldb = { type = 'executable', command = 'codelldb' },  -- C++ and Rust
    debugpy = function (launcher, config)
        if config.request == 'launch' then
            launcher {
                type = 'executable',
                command = vim.fs.joinpath(vim.env.HOME, '.pde/bin/.debugpy/bin/python'),
                args = { '-m', 'debugpy.adapter' },
            }
        else
            launcher {
                type = 'server',
                host = config.connect.host or '127.0.0.1',
                port = config.connect.port,
            }
        end
    end,
}

---Global debugger launch configurations
local global_launch_configs = {
    -- Refer: https://github.com/vadimcn/codelldb/blob/master/MANUAL.md
    cpp = {
        {
            name = 'Debug C++ (Default)',
            type = 'codelldb',
            request = 'launch',
            cwd = '${workspaceFolder}',
            program = program_picker 'cpp',
            stopOnEntry = false,
        },
    },
    rust = {
        {
            name = 'Debug Rust (Default)',
            type = 'codelldb',
            sourceLanguages = { 'rust' },
            request = 'launch',
            cwd = '${workspaceFolder}',
            program = 'target/debug/' .. vim.fs.basename(vim.uv.cwd()),
            stopOnEntry = false,
        },
    },
    -- Refer: https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings
    python = {
        {
            name = 'Debug Python (Default)',
            type = 'debugpy',
            request = 'launch',
            pythonPath = vim.fn.exepath 'python',
            cwd = '${workspaceFolder}',
            program = program_picker 'python',
            stopOnEntry = true,
            justMyCode = false,
            showReturnValue = true,
        },
    },
}

local nvim_dap = {
    'mfussenegger/nvim-dap',
    config = function ()
        local dap = require('dap')
        dap.adapters = adapter_configs
        dap.configurations = global_launch_configs
        -- dap.set_log_level 'TRACE'  -- Uncomment when needed

        -- Load debug adapter configurations from current project
        local cwd_dap_config = vim.fs.joinpath(vim.uv.cwd(), '.dap.lua')
        if vim.uv.fs_stat(cwd_dap_config) then
            dap.providers.configs['local'] = function () return dofile(cwd_dap_config) end
        end

        -- Setup debugger and breakpoint signs
        vim.fn.sign_define {
            { name = 'DapBreakpoint', text = '⬤', texthl = 'DapBreakpoint' },
            { name = 'DapBreakpointCondition', text = '◆', texthl = 'DapBreakpoint' },
            { name = 'DapLogPoint', text = '▲', texthl = 'DapBreakpoint' },
            { name = 'DapBreakpointRejected', text = '✖', texthl = 'DapBreakpoint' },
            { name = 'DapStopped', text = '', linehl = 'DapCurrentLine' },
        }

        ---Set up global keymaps which can be called outside debug session
        local function input(prompt)
            local ret
            vim.ui.input({ prompt = prompt }, function (inp)
                if not inp or inp == '' then return end
                ret = inp
            end)
            return ret
        end
        nnoremap('<Leader>dbb', dap.toggle_breakpoint)
        nnoremap('<Leader>dbc', function ()
            local msg = input 'Breakpoint condition: '
            if not msg then return end
            dap.set_breakpoint(msg)
        end)
        nnoremap('<Leader>dbh', function ()
            local msg = input 'Breakpoint hit number: '
            if not msg then return end
            dap.set_breakpoint(nil, msg)
        end)
        nnoremap('<Leader>dbl', function ()
            local msg = input 'Breakpoint log message: '
            if not msg then return end
            dap.set_breakpoint(nil, nil, msg)
        end)
        nnoremap('<Leader>dbs', function ()
            dap.list_breakpoints()
            vim.cmd 'copen'
        end)
        nnoremap('<Leader>dbC', dap.clear_breakpoints)
        nnoremap('<Leader>dc', dap.continue)

        -- Set up keymaps local to the active debug session
        local is_debug_active = false
        dap.listeners.after.event_initialized.debug_map_keys = function ()
            vim.cmd [[highlight! link StatusLine Function]]
            is_debug_active = true
            nnoremap('<Leader>dC', dap.run_to_cursor)
            nnoremap('<Leader>dp', dap.pause)
            nnoremap('<Leader>dn', dap.step_over)
            nnoremap('<Leader>di', dap.step_into)
            nnoremap('<Leader>do', dap.step_out)
            nnoremap('<Leader>dt', dap.terminate)
            nnoremap('<Leader>dr', dap.restart)
            nnoremap('<Leader>dsu', dap.up)
            nnoremap('<Leader>dsd', dap.down)
        end

        ---Remove keymaps local to the active debug session
        local function debug_unmap_keys()
            -- TODO: how to restore previous highlight without hard-coding?
            vim.cmd [[highlight! link StatusLine Comment]]
            if is_debug_active then
                nunmap '<Leader>dp'
                nunmap '<Leader>dn'
                nunmap '<Leader>di'
                nunmap '<Leader>do'
                nunmap '<Leader>dt'
                nunmap '<Leader>dr'
                nunmap '<Leader>dsu'
                nunmap '<Leader>dsd'
                is_debug_active = false
            end
        end
        dap.listeners.after.disconnect.debug_unmap_keys = debug_unmap_keys
        dap.listeners.after.event_exited.debug_unmap_keys = debug_unmap_keys
        dap.listeners.after.event_terminated.debug_unmap_keys = debug_unmap_keys
    end,
}

---------------------------- NVIM-DAP-UI CONFIG ---------------------------

---@class DAPUIToggle
---Inline module to toggle DAP UI components
local dapui_toggle = {
    ---Whether the UI layout is visible as a whole
    visible = false,

    ---Cache of layouts to open during UI toggle
    layouts_to_open = {},

    ---Toggle entire UI layout together
    ---@param self DAPUIToggle
    ui = function (self)
        local dapui = require('dapui')
        local layouts = require('dapui.windows').layouts
        for id = #layouts, 1, -1 do
            if self.visible and layouts[id]:is_open() then
                self.layouts_to_open[id] = true
                dapui.close { layout = id }
            elseif not self.visible and self.layouts_to_open[id] then
                self.layouts_to_open[id] = false
                dapui.open { layout = id, reset = true }
            end
        end
        self.visible = not self.visible
    end,

    ---Toggle individual layouts in overall UI
    ---@param self DAPUIToggle
    ---@param id integer Layout to toggle
    ---@return function
    layout = function (self, id)
        local dapui = require('dapui')
        return function ()
            if self.visible then dapui.toggle { layout = id, reset = true } end
        end
    end,
}

local nvim_dap_ui = {
    'rcarriga/nvim-dap-ui',
    dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
    opts = {
        icons = { expanded = '', collapsed = '', current_frame = '' },
        layouts = {
            {
                elements = { { id = 'scopes', size = 0.7 }, { id = 'watches', size = 0.3 } },
                size = 0.25,
                position = 'left',
            },
            {
                elements = { 'repl' },
                size = 0.25,
                position = 'right',
            },
            {
                elements = { { id = 'stacks', size = 0.5 }, { id = 'breakpoints', size = 0.5 } },
                size = 0.25,
                position = 'right',
            },
            {
                elements = { 'console' },
                size = 0.3,
                position = 'bottom',
            },
        },
        floating = { border = 'rounded', max_width = 60, max_height = 20 },
        controls = { enabled = false },
        render = { indent = 2, max_value_lines = 500 },
    },
    config = function (_, opts)
        local dap = require 'dap'
        local dapui = require('dapui')
        dapui.setup(opts)

        -- Set up UI keymaps local to the active debug session
        local is_debug_active = false
        dap.listeners.after.event_initialized.dapui_init_layout = function ()
            is_debug_active = true
            dapui_toggle.visible = true
            dapui.open { layout = 1 }
            dapui.open { layout = 4 }
            nnoremap('<Leader>dut', function () dapui_toggle:ui() end)
            nnoremap('<Leader>duv', dapui_toggle:layout(1))  -- Variables
            nnoremap('<Leader>dur', dapui_toggle:layout(2))  -- REPL
            nnoremap('<Leader>dub', dapui_toggle:layout(3))  -- Breakpoints
            nnoremap('<Leader>duc', dapui_toggle:layout(4))  -- Console
        end
        -- Remove UI keymaps local to the active debug session
        local function dapui_clear_layout()
            if is_debug_active then
                is_debug_active = false
                dapui.close { layout = 1 }
                dapui.close { layout = 2 }
                dapui.close { layout = 3 }
                nunmap('<Leader>dut')
                nunmap('<Leader>duv')
                nunmap('<Leader>dur')
                nunmap('<Leader>dub')
                nunmap('<Leader>duc')
            end
        end
        dap.listeners.after.disconnect.dapui_clear_layout = dapui_clear_layout
        dap.listeners.after.event_exited.dapui_clear_layout = dapui_clear_layout
        dap.listeners.after.event_terminated.dapui_clear_layout = dapui_clear_layout
    end,
}

return {
    nvim_dap,
    nvim_dap_ui,
}
