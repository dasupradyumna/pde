"----------------------------------------- AUTO-COMPLETION ----------------------------------------"

" Prevent completion information from polluting the command-line
set shortmess+=c

" Enable fuzzy matching without selecting or inserting the top match
set completeopt=fuzzy,menuone,noinsert,noselect,popup

" Check if argument character is a valid keyword character
function! s:is_char_valid(c) abort
    return a:c == '_' || ('a' <= a:c && a:c <= 'z') || ('0' <= a:c && a:c <= '9')
endfunction

"--------------------- IMPLEMENTATION ---------------------"

let s:auto_completion = #{ word_start: -1, comp_active: v:false }

" Reset auto-completion state
function! s:auto_completion.reset() abort
    " Reset current word starting index
    let self.word_start = -1
    " Reset completion flag
    let self.comp_active = v:false
endfunction

" Callback for CursorMovedI event
function! s:auto_completion.on_moved() abort
    " Check if character preceding the cursor is valid for completion
    const [col, line] = [getpos('.')[2] - 1, getline('.')]
    const valid_char = col != 0 && s:is_char_valid(line[col - 1])

    if valid_char
        " Ensure current word starting index is computed
        if self.word_start == -1
            let self.word_start = col - 1
            while self.word_start > 0 && s:is_char_valid(line[self.word_start - 1])
                let self.word_start -= 1
            endwhile
        endif
        " Trigger completion if not active and word length is at least 3
        if !self.comp_active && (col - self.word_start) >= 3
            call feedkeys("\<C-N>", 'i')
            let self.comp_active = v:true
        endif
    else
        " Reset state when word ends
        call self.reset()
    endif

    "echom printf('[MOVED] col:%d(%s) ws:%d comp:(%s) valid:%d', col,
    "            \ col == 0 ? '><' : line[col - 1], self.word_start, self.comp_active, valid_char)
endfunction

" Callback for CompleteChanged event
function! s:auto_completion.on_changed() abort
    " Cancel completion if active and word length is less than 3
    const col = getpos('.')[2] - 1
    if self.comp_active && (col - self.word_start) < 3
        call feedkeys("\<C-E>", 'i')
        let self.comp_active = v:false
    endif

    "echom printf('[CHANGED] col:%d(%s) ws:%d comp:(%s)', col,
    "            \ col == 0 ? '><' : getline('.')[col - 1], self.word_start, self.comp_active)
endfunction

"------------------------ AUTOCMDS ------------------------"

augroup __auto_completion__
    autocmd!

    " Reset module state when entering insert mode
    autocmd InsertEnter * call s:auto_completion.reset()

    " Automatically trigger completion
    autocmd CursorMovedI * call s:auto_completion.on_moved()

    " Automatically cancel completion
    autocmd CompleteChanged * call s:auto_completion.on_changed()

augroup END
