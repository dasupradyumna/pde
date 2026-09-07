# Guidelines: Pi Coding Agent

**NOTE**: Pi documentation and examples will *NOT* be found here. Search in the paths specified
earlier for additional documentation and examples.

## Testing

When manually testing/smoke-checking (e.g. `pi -e ... -p ...`), never invoke `pi` with a bare
default session. Always pass either `--no-session` (stateless one-off checks, e.g "does it load") or
an explicit `--session /tmp/<name>.jsonl` (anything relying on state persisting across calls: guard
checks, `/reload` recovery, multi-step command flows). This way, there's no cleanup step to execute.

## Code Style

- Wrap all lines (code & comments) at 100 characters - not less, not more. Split at word boundaries.
- **Naming Convention**
  - Constants:
    - Top-level + literal value: UPPER_SNAKE_CASE
    - Top-level + object value: camelCase
    - Function-level: camelCase
  - Variables, functions: camelCase
  - Classes, types, interfaces: PascalCase
