"---------------------------------------- BUILT-IN OPTIONS ----------------------------------------"

" OS-specific shell options
" let s:config_path = stdpath('config')
" if has('win32')
"    set shell=pwsh shellcmdflag=-Command shellxquote=
"    " HACK: excluding drive modifier on Windows works for 'spellfile' option
"    let s:config_path = s:config_path[2:]
" elseif has('linux')
"    set shell=/bin/bash
"    let $BASH_ENV = expand('~/.pde/dotfiles/bash/__nvim_bash_env.sh')
" endif

" NOTE:
" 1. belloff/errorbells/visualbell for terminal readiness? (launch-tool)
" 2. bufhidden for plugin-specific buffers
" 3. cpoptions after setting all others
" 4. exrc for project-local config
" 5. formatprg if LSP cannot format
" 6. grepXXX to customize grep using rg
" 7. spellXXX: let &spellfile = s:config_path .. '/spell/en.utf-8.add' | set spelloptions=camel

"------------------------------ TEXT EDITING -----------------------------"

set backspace+=nostop
set expandtab
set shiftwidth=4
set softtabstop=-1
set whichwrap=h,l,<,>,[,]

"------------------------------ TEXT VIEWING -----------------------------"

set breakindent breakindentopt=shift:2
set display+=uhex
set linebreak
set list listchars=leadmultispace:│\ \ \ ,tab:──,trail:· " TODO: autocmd depend on shiftwidth
let &showbreak = '\ '
set textwidth=100

"-------------------------------- BEHAVIOR -------------------------------"

set cdhome
set complete=  " XXX: remove after exploring integration with blink.cmp
set confirm
set diffopt=algorithm:histogram,closeoff,context:3,filler,foldcolumn:0,followwrap,hiddenoff
set diffopt+=indent-heuristic,internal,linematch:60,vertical " inline:char in v0.12.x
set formatoptions+=ro/n1
set gdefault  " TODO: check if this breaks any plugins?
set history=1000
set ignorecase smartcase
set matchpairs+=<:>
set mousescroll=ver:10,hor:6
set report=0
set scrolloff=4
set shada=!,'100,/100,<10,@10,h,s10
set smartindent
set splitbelow splitright
set startofline
set switchbuf+=useopen
set updatetime=500
set tabclose=uselast
let &verbosefile = stdpath('data') .. '/verbose.txt'
set nowildmenu

"-------------------------------- DISPLAY --------------------------------"

set cmdheight=0
set cmdwinheight=10
set colorcolumn=+1
set cursorlineopt=line
set debug=msg
set fillchars=diff:╳,eob:\ ,fold:\ ,foldclose:,foldopen:,foldsep:\ ,lastline:~,msgsep:━,stl:─
" XXX: this is not working as expected... WezTerm config / issue?
set guicursor=n-v:block,i-c-ci:ver50,r-cr-o:hor50,t:block-blinkon500-blinkoff500-TermCursor
set laststatus=3
set matchtime=3 showmatch
set number relativenumber
set noruler
set shortmess=aoOsIcCF
set showcmdloc=tabline
set noshowmode
set signcolumn=auto:1
set statuscolumn=%=%s%l\ %{FoldColumn()}
set statusline=─
set tabline=%!TabLine()
set showtabline=2
set winbar=\ %f

"-------------------- FOLDING -------------------"

set foldcolumn=auto:1
set foldexpr=v:lua.vim.treesitter.foldexpr()
set foldlevelstart=10
set foldopen+=insert,jump
set foldtext=

"--------------------------------------- TEMPORARY FUNCTIONS --------------------------------------"

" custom tabline
function TabLine()
    let s = ''
    let c = 0
    for i in nvim_list_tabpages()
        " tab highlight
        let s ..= i == nvim_get_current_tabpage() ? '%#TabLineSel#' : '%#TabLine#'
        try | let name = nvim_tabpage_get_var(i, 'tabpage_name')
        catch | let name = '[no name]' | endtry
        let s ..= ' ' .. name .. ' '
        let c += len(name) + 2
    endfor
    " empty fill highlight
    let s ..= '%#TabLineFill#'
    let s ..= '%=%S '
    return repeat(' ', (&columns - c) / 2) .. s
endfunction

" foldcolumn without levels
function FoldColumn()
    if foldclosed(v:lnum) == v:lnum
        return ' '
    elseif foldlevel(v:lnum) > foldlevel(v:lnum - 1)
        return ' '
    else
        return '  '
    endif
endfunction
