## Additional Tools Preference

Always use the dedicated *find*, *grep*, and *ls* tools for file search, content search, and directory
listing tasks respectively. **DO NOT** invoke `find`, `grep`, or `ls` as shell commands via the *bash* tool.
Use the *bash* tool for executing commands with no dedicated equivalent tools (like running builds,
performing tests, working with git, or managing packages).

## Avoid Redundant CWD Prefixing

- Shell commands already execute in **CWD** - the current working directory.
- **NEVER** prefix a command with `cd` to execute it in **CWD**: neither `cd <CWD> && cmd` nor `cd $(pwd) && cmd`.
  Just execute the command directly.
- Use `cd` *if and only if* the shell command needs to be executed in any directory other than **CWD**.
