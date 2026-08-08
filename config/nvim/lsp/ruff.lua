------------------------------------------ RUFF LSP CONFIG -----------------------------------------

---@type vim.lsp.Config
return {
    cmd = { 'ruff', 'server' },
    filetypes = { 'python' },
    root_markers = { '.git', 'requirements.txt', 'ty.toml', 'pyproject.toml', 'setup.py' },
    init_options = {
        settings = {
            configurationPreference = 'filesystemFirst',
            configuration = {
                ['fix-only'] = true,
                ['line-length'] = 100,
                format = {
                    ['docstring-code-format'] = true,
                    ['skip-magic-trailing-comma'] = true,
                },
                lint = {
                    -- Reference: https://docs.astral.sh/ruff/rules
                    ignore = { 'B007', 'COM812', 'D202', 'D204', 'D400', 'F821', 'F841', 'RUF059' },
                    select = {
                        'ERA',   -- Eradicate: commented code
                        'ANN',   -- Type annotations
                        'S',     -- Bandit: code security
                        'B',     -- BugBear: common design flaws & bugs
                        'A',     -- Built-in (symbol shadowing)
                        'COM',   -- Commas
                        'C4',    -- List & dictionary comprehensions
                        'EM',    -- Error messages
                        'EXE',   -- Executables & shebangs
                        'ISC',   -- Implicit string concatentation
                        'ICN',   -- Import conventions
                        'PIE',   -- Misc
                        'PYI',   -- PYI stub files
                        'PT',    -- PyTest
                        'Q',     -- Quotes
                        'RSE',   -- Unneccesary `raise`
                        'RET',   -- `return`
                        'SLF',   -- Private member access
                        'SIM',   -- Simplify code
                        'SLOT',  -- Class slots
                        'PTH',   -- Pathlib python library
                        'I',     -- Isort
                        'NPY',   -- NumPy
                        'PD',    -- Pandas
                        'N',     -- PEP naming conventions
                        'E',     -- PyCodeStyle errors
                        'W',     -- PyCodeStyle warnings
                        'DOC',   -- Documentation checks (extra)
                        'D',     -- Documentation checks
                        'F',     -- PyFlakes
                        'UP',    -- Upgrade python syntax
                        'FURB',  -- Refurb: modernize codebase
                        'RUF',   -- Ruff-specific
                    },
                },
            },
            fixAll = false,
            organizeImports = false,
            showSyntaxErrors = false,
            -- logFile = vim.fs.joinpath(vim.fn.stdpath 'state', 'ruff.log'),
            -- logLevel = 'trace',
        },
    },
}
