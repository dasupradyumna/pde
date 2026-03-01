###################################### GDB EXPRESSION WATCHER ######################################

import gdb

# Global list of watch expressions
WATCH_LIST = []


class Watcher(gdb.Command):
    """Persistent expression watcher."""

    USAGE = """Usage:
  [Add]       watcher add <expr>
  [Remove]    watcher rm <expr>
  [List]      watcher ls"""

    def __init__(self):
        super().__init__("watcher", gdb.COMMAND_USER)

    def invoke(self, arg, _):
        global WATCH_LIST

        # Display command description and usage if no arguments are given
        args = arg.strip().split(' ', 1)
        if not args[0]:
            print(Watcher.__doc__)
            print(Watcher.USAGE)
            return

        cmd = args[0]
        # List all watched expressions and their current values
        if cmd == "ls":
            if not WATCH_LIST:
                return

            print("-------------------- WATCH EXPRESSIONS ---------------------")
            for i, exp in enumerate(WATCH_LIST, start=1):
                # Print variable name with CYAN color (must match GDB style)
                print(f"{i:2}. \x1b[36m{exp}\x1b[0m = ", end="")
                try:
                    gdb.execute(f"output {exp}")
                    print()
                except gdb.error as e:
                    # Handle when the expression is invalid
                    print(f"[ ERROR: {e} ]")

        # Add an expression to the watcher
        elif cmd == "add":
            if len(args) == 1:
                print("!! Watch expression not provided.\n    Usage: watcher add <expr>")
                return

            expr = args[1].strip()
            if expr in WATCH_LIST:
                # Prevent duplicate expressions in the watch list
                print(f"!! Already watching expression: {expr}")
            else:
                WATCH_LIST.append(expr)
                print(f">> Watching expression: {expr}")

        # Remove an expression using its index
        elif cmd == "rm":
            if not WATCH_LIST:
                print("!! No watch expressions found.")
                return

            # If no index is specified, prompt user to select an expression
            if len(args) == 1:
                print("WATCH LIST:")
                for i, exp in enumerate(WATCH_LIST, start=1):
                    print(f"{i:2}. \x1b[36m{exp}\x1b[0m")
                target = input(f"Select expression to remove [1-{len(WATCH_LIST)}]: ")
            else:
                target = args[1].strip()

            try:
                expr = WATCH_LIST.pop(int(target) - 1)
                print(f">> Removed expression: {expr}")
            except (ValueError, IndexError):
                print(f"!! Invalid index for removing expression")

        else:
            print(f"!! Unknown subcommand: {cmd}\n{Watcher.USAGE}")

    # Command-line completion
    def complete(self, text, _):
        args = text.strip().split(' ', 1)
        # Completing subcommand
        if len(args) <= 1:
            return [cmd for cmd in ["add", "ls", "rm"] if cmd.startswith(args[0])]
        # Delegate expression completion to GDB
        if args[0] == "add":
            return gdb.COMPLETE_EXPRESSION
        return []


Watcher()
