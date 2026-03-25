--------------------------------------- EVENTIDE COLORSCHEME ---------------------------------------

-- Skip if colorscheme is already active
if vim.g.colors_name == 'eventide' then return end
-- Clear existing syntax and highlights
vim.cmd 'syntax reset'
vim.cmd 'highlight clear'

-- Set theme variables
if not vim.opt.termguicolors then
    vim.notify_once(
        '[eventide.nvim] Theme requires 24-bit RGB color support with `termguicolors` enabled',
        vim.log.levels.WARN)
    vim.opt.termguicolors = true
end
vim.g.colors_name = 'eventide'

------------------------------- THEME COLORS ------------------------------

local colors = {
    bg      = '#191b18',  -- 1.5
    -- fg      = '#c4ccc0',  -- 12
    fg      = '#ccd4c8',  -- 12.5
    -- XXX: Each color will have 3 variants : dark, normal, bright
    -- black   = { '#313330', '#4a4e48', '#626660' },  -- 3 | 4.5 | 6
    -- black   = { '#2a2e28', '#3a3e38', '#4a4e48' },  -- 2.5 | 3.5 | 4.5
    black   = { '#212320', '#313330', '#414340' },  -- 2 | 3 | 4
    -- white   = { '#7a7e78', '#939990', '#abb1a8' },  -- 7.5 | 9 | 10.5
    -- white   = { '#6a6e68', '#939990', '#abb1a8' },  -- 6.5 | 9 | 10.5
    -- white   = { '#626660', '#939990', '#abb1a8' },  -- 6 | 9 | 10.5
    -- TODO: make comment lighter??
    white   = { '#6a6e68', '#9ba198', '#b3b9b0' },  -- 6.5 | 9.5 | 11
    magenta = { '#b363a9', '#c5aac1' },             -- fg(dark, light)
    red     = { '#32100d', '#f0626a' },             -- bg(dark), fg(light)
    orange  = { '#503408', '#d47452', '#e0b080' },  -- bg(dark) fg(dark, light)
    yellow  = { '#2a2200', '#3a2e00', '#c4c780' },  -- bg(darker,dark) fg(light)
    green   = { '#082a03', '#589b70', '#92b58c' },  -- bg(dark), fg(dark, light)
    cyan    = { '#043430', '#5ca09d', '#9cbdb8' },  -- bg(dark), fg(dark, light)
    blue    = { '#4f9dbc', '#90c6e4' },             -- fg(dark, light)
}

-- XXX: Do I need component colors?? Mostly yes, but double-check

----------------------------- HIGHLIGHT GROUPS ----------------------------

---@type table<string, vim.api.keyset.highlight>
local highlights = {
    -------------------- BUILT-IN --------------------
    -- :help highlight-groups

    ColorColumn = { link = 'CursorLine' },
    Conceal = { bold = true, fg = colors.fg },
    CurSearch = { link = 'Search' },
    Cursor = {},
    lCursor = {},
    CursorIM = {},
    CursorColumn = { link = 'CursorLine' },
    CursorLine = { bg = colors.black[2] },
    Directory = { fg = colors.blue[2] },
    DiffAdd = { bg = colors.green[1] },
    DiffChange = { bg = colors.yellow[1] },
    DiffDelete = { bg = colors.red[1] },
    DiffText = { bg = colors.yellow[2] },
    EndOfBuffer = { link = 'NonText' },
    TermCursor = {},
    ErrorMsg = { link = 'DiagnosticError' },
    WinSeparator = { fg = colors.black[3] },
    Folded = { italic = true, fg = colors.black[3] },
    FoldColumn = { link = 'LineNr' },
    SignColumn = { link = 'LineNr' },
    IncSearch = { link = 'Search' },
    Substitute = { link = 'Search' },
    LineNr = { fg = colors.white[1] },
    LineNrAbove = { link = 'LineNr' },
    LineNrBelow = { link = 'LineNr' },
    CursorLineNr = { bold = true, fg = colors.white[1] },
    CursorLineFold = { link = 'FoldColumn' },
    CursorLineSign = { link = 'SignColumn' },
    MatchParen = { link = 'Visual' },
    ModeMsg = { bold = true, fg = colors.white[2] },
    MsgArea = { link = 'Normal' },
    MsgSeparator = { link = 'WinSeparator' },
    MoreMsg = { link = 'Question' },
    NonText = { fg = colors.black[3] },
    Normal = { fg = colors.fg, bg = colors.bg },
    NormalFloat = { link = 'Normal' },
    FloatBorder = { link = 'WinSeparator' },
    FloatTitle = { link = 'Title' },
    FloatFooter = { link = 'Title' },
    NormalNC = { link = 'Normal' },
    -- Pmenu = {},
    -- PmenuSel = {},
    -- PmenuKind = {},
    -- PmenuKindSel = {},
    -- PmenuExtra = {},
    -- PmenuExtraSel = {},
    -- PmenuSbar = {},
    -- PmenuThumb = {},
    -- PmenuMatch = {},
    -- PmenuMatchSel = {},
    -- ComplMatchIns = {},
    Question = { fg = colors.blue[2] },
    QuickFixLine = { bold = true, bg = colors.black[2] },
    Search = { bg = colors.orange[1] },
    SnippetTabstop = {},  -- NOTE: Defaults to Visual highlighting the current placeholder
    SpecialKey = { link = 'NonText' },
    SpellBad = { underdotted = true, sp = colors.red[2] },
    SpellCap = { underdotted = true, sp = colors.yellow[3] },
    SpellLocal = { underdotted = true, sp = colors.cyan[2] },
    SpellRare = { underdotted = true, sp = colors.magenta[1] },
    StatusLine = { bold = true, fg = colors.fg, bg = colors.black[1] },
    StatusLineNC = { fg = colors.white[3], bg = colors.black[1] },
    StatusLineTerm = { link = 'StatusLine' },
    StatusLineTermNC = { link = 'StatusLineNC' },
    TabLine = {},
    TabLineFill = {},
    TabLineSel = { bold = true, bg = colors.black[3] },
    Title = { bold = true, fg = colors.magenta[1] },
    Visual = { bg = colors.cyan[1] },
    VisualNOS = {},
    WarningMsg = { link = 'DiagnosticWarn' },
    Whitespace = { link = 'NonText' },
    WildMenu = { link = 'PmenuSel' },
    WinBar = { bold = true, fg = colors.fg },
    WinBarNC = { fg = colors.white[3] },

    --------------------- SYNTAX ---------------------
    -- :help group-name

    Comment = { fg = colors.white[2] },

    Constant = { fg = colors.blue[1] },
    String = { fg = colors.orange[3] },
    Character = { link = 'String' },
    Number = { link = 'Constant' },
    Boolean = { link = 'Constant' },
    Float = { link = 'Constant' },

    Identifier = { fg = colors.cyan[3] },
    Function = { fg = colors.yellow[3] },

    Statement = { fg = colors.magenta[1] },
    Conditional = { link = 'Statement' },
    Repeat = { link = 'Statement' },
    Label = { link = 'Statement' },
    Operator = { fg = colors.red[2] },
    Keyword = { link = 'Statement' },
    Exception = { link = 'Statement' },

    PreProc = { fg = colors.orange[2] },
    Include = { link = 'Operator' },
    Define = { link = 'Operator' },
    Macro = { link = 'Operator' },
    PreCondit = { link = 'Operator' },

    Type = { fg = colors.green[2] },
    StorageClass = { link = 'Operator' },
    Structure = { link = 'Keyword' },
    Typedef = { link = 'Type' },

    Special = { link = 'PreProc' },
    SpecialChar = { link = 'PreProc' },
    Tag = { link = '@markup.link' },
    Delimiter = { link = 'Normal' },
    SpecialComment = { bold = true },
    Debug = { link = 'Operator' },

    Underlined = { link = '@markup.underline' },

    Ignore = {},

    Error = { link = 'DiagnosticError' },

    Todo = { bold = true },

    Added = { fg = colors.green[3] },
    Changed = { fg = colors.yellow[3] },
    Removed = { fg = colors.red[2] },

    ------------------- DIAGNOSTICS ------------------
    -- :help diagnostic-highlights

    DiagnosticError = { fg = colors.red[2] },
    DiagnosticWarn = { fg = colors.orange[2] },
    DiagnosticInfo = { fg = colors.cyan[3] },
    DiagnosticHint = { fg = colors.blue[2] },
    DiagnosticOk = { fg = colors.green[3] },

    DiagnosticVirtualTextError = { italic = true, fg = colors.red[2] },
    DiagnosticVirtualTextWarn = { italic = true, fg = colors.orange[2] },
    DiagnosticVirtualTextInfo = { italic = true, fg = colors.cyan[3] },
    DiagnosticVirtualTextHint = { italic = true, fg = colors.blue[2] },
    DiagnosticVirtualTextOk = { italic = true, fg = colors.green[3] },

    DiagnosticVirtualLinesError = { link = 'DiagnosticVirtualTextError' },
    DiagnosticVirtualLinesWarn = { link = 'DiagnosticVirtualTextWarn' },
    DiagnosticVirtualLinesInfo = { link = 'DiagnosticVirtualTextInfo' },
    DiagnosticVirtualLinesHint = { link = 'DiagnosticVirtualTextHint' },
    DiagnosticVirtualLinesOk = { link = 'DiagnosticVirtualTextOk' },

    DiagnosticUnderlineError = { underdotted = true, sp = colors.red[2] },
    DiagnosticUnderlineWarn = { underdotted = true, sp = colors.orange[3] },
    DiagnosticUnderlineInfo = { underdotted = true, sp = colors.cyan[3] },
    DiagnosticUnderlineHint = { underdotted = true, sp = colors.blue[2] },
    DiagnosticUnderlineOk = { underdotted = true, sp = colors.green[3] },

    DiagnosticFloatingError = { link = 'DiagnosticError' },
    DiagnosticFloatingWarn = { link = 'DiagnosticWarn' },
    DiagnosticFloatingInfo = { link = 'DiagnosticInfo' },
    DiagnosticFloatingHint = { link = 'DiagnosticHint' },
    DiagnosticFloatingOk = { link = 'DiagnosticOk' },

    DiagnosticSignError = { link = 'DiagnosticError' },
    DiagnosticSignWarn = { link = 'DiagnosticWarn' },
    DiagnosticSignInfo = { link = 'DiagnosticInfo' },
    DiagnosticSignHint = { link = 'DiagnosticHint' },
    DiagnosticSignOk = { link = 'DiagnosticOk' },

    DiagnosticDeprecated = { strikethrough = true },
    DiagnosticUnnecessary = { link = 'Comment' },

    ------------------- TREE-SITTER ------------------
    -- :help treesitter-highlight-groups

    ['@variable'] = { link = 'Identifier' },
    ['@variable.builtin'] = { link = 'Keyword' },
    ['@variable.parameter'] = { fg = colors.cyan[2] },
    ['@variable.parameter.builtin'] = { link = 'Keyword' },
    ['@variable.member'] = { link = '@property' },

    ['@constant'] = { link = 'Constant' },
    ['@constant.builtin'] = { link = 'Constant' },
    ['@constant.macro'] = { link = 'PreProc' },

    ['@module'] = { fg = colors.magenta[2] },
    ['@module.builtin'] = { link = '@module' },
    ['@label'] = { link = 'Operator' },

    ['@string'] = { link = 'String' },
    ['@string.documentation'] = { link = 'Comment' },
    ['@string.regexp'] = { link = 'PreProc' },
    ['@string.escape'] = { link = 'Operator' },
    ['@string.special'] = { link = 'String' },
    -- ['@string.special.symbol'] = {}, -- XXX: where??
    -- ['@string.special.path'] = {},
    ['@string.special.url'] = { link = '@markup.link' },

    ['@character'] = { link = 'Character' },
    ['@character.special'] = { link = 'Operator' },

    ['@boolean'] = { link = 'Boolean' },
    ['@number'] = { link = 'Number' },
    ['@number.float'] = { link = 'Float' },

    ['@type'] = { link = 'Type' },
    ['@type.builtin'] = { link = 'Keyword' },
    ['@type.definition'] = { link = 'Type' },
    ['@type.qualifier'] = { link = 'Operator' },  -- NOTE: Not in neovim documentation

    ['@attribute'] = { link = 'Operator' },
    ['@attribute.builtin'] = { link = 'Operator' },
    ['@property'] = { fg = colors.green[3] },

    ['@function'] = { link = 'Function' },
    ['@function.builtin'] = { link = 'Function' },
    ['@function.call'] = { link = 'Function' },
    ['@function.macro'] = { link = 'PreProc' },
    ['@function.method'] = { link = 'Function' },
    ['@function.method.call'] = { link = 'Function' },

    ['@constructor'] = { link = 'Type' },
    ['@operator'] = { link = 'Operator' },

    ['@keyword'] = { link = 'Keyword' },
    ['@keyword.coroutine'] = { link = 'Operator' },
    ['@keyword.function'] = { link = 'Keyword' },
    ['@keyword.operator'] = { link = 'Operator' },
    ['@keyword.import'] = { link = 'Operator' },
    ['@keyword.type'] = { link = 'Keyword' },
    ['@keyword.modifier'] = { link = 'Operator' },
    ['@keyword.repeat'] = { link = 'Keyword' },
    ['@keyword.return'] = { link = 'Keyword' },
    ['@keyword.debug'] = { link = 'Operator' },
    ['@keyword.exception'] = { link = 'Keyword' },
    ['@keyword.conditional'] = { link = 'Keyword' },
    ['@keyword.conditional.ternary'] = { link = 'Operator' },
    ['@keyword.directive'] = { link = 'PreProc' },
    ['@keyword.directive.define'] = { link = 'Operator' },

    ['@punctuation.delimiter'] = { link = 'Delimiter' },
    ['@punctuation.bracket'] = { link = 'Delimiter' },
    ['@punctuation.special'] = { link = 'Operator' },

    ['@comment'] = { link = 'Comment' },
    ['@comment.documentation'] = { link = 'Comment' },
    ['@comment.error'] = { link = 'DiagnosticError' },
    ['@comment.warning'] = { link = 'DiagnosticWarn' },
    ['@comment.todo'] = { link = 'DiagnosticHint' },
    ['@comment.note'] = { link = 'DiagnosticInfo' },

    ['@markup.strong'] = { bold = true },
    ['@markup.italic'] = { italic = true },
    ['@markup.strikethrough'] = { strikethrough = true },
    ['@markup.underline'] = { underline = true },

    ['@markup.heading'] = { link = 'Title' },
    ['@markup.heading.1'] = { link = 'Title' },
    ['@markup.heading.2'] = { link = 'Title' },
    ['@markup.heading.3'] = { link = 'Title' },
    ['@markup.heading.4'] = { link = 'Title' },
    ['@markup.heading.5'] = { link = 'Title' },
    ['@markup.heading.6'] = { link = 'Title' },

    ['@markup.quote'] = { link = 'Comment' },
    ['@markup.math'] = { link = '@property' },
    ['@markup.environment'] = { link = 'Type' },  -- NOTE: not in docs

    ['@markup.link'] = { underline = true, fg = colors.magenta[2] },
    ['@markup.link.label'] = { link = '@markup.link' },
    ['@markup.link.url'] = { link = '@markup.link' },

    ['@markup.raw'] = { fg = colors.red[2], bg = colors.black[1] },
    ['@markup.raw.block'] = { link = 'Comment' },
    ['@markup.raw.delimiter'] = { link = 'Delimiter' },

    ['@markup.list'] = { link = '@variable.parameter' },
    ['@markup.list.checked'] = { fg = colors.green[3] },
    ['@markup.list.unchecked'] = { fg = colors.red[2] },

    ['@diff.plus'] = { link = 'DiffAdd' },
    ['@diff.minus'] = { link = 'DiffDelete' },
    ['@diff.delta'] = { link = 'DiffChange' },

    ['@tag'] = { link = '@variable.parameter' },
    ['@tag.builtin'] = { link = '@tag' },
    ['@tag.attribute'] = { link = '@property' },
    ['@tag.delimiter'] = { link = 'Operator' },

    ['@spell'] = {},
    ['@nospell'] = {},

    -- LSP highlights :h lsp-semantic-highlight & :h lsp-highlight
    LspInlayHint = { fg = colors.white[1] },
    -- Filetype highlights
    ['@constructor.lua'] = {},
    ['@lsp.type.variable.lua'] = {},
    -- Plugin highlights
    -- Commonly used highlights ??
}
-- X = _G

-- Update highlight groups for transparent background
if vim.g.eventide_transparent then
    ---@format disable-next
    local transparent_groups = { 'Normal', 'StatusLine', 'StatusLineNC',
        'WinBar', 'WinBarNC', 'TabLine', 'TabLineFill', 'TabLineSel' }
    for _, group in ipairs(transparent_groups) do highlights[group].bg = 'NONE' end
end

-- Apply above defined highlight groups
for group, spec in pairs(highlights) do vim.api.nvim_set_hl(0, group, spec) end
