# Command Metadata

Read this before adding or changing commands in `bin/`.

Commands in `bin/` can declare CLI metadata in comments near the top of the
file. `bin/omarchy` scans the first 80 lines, and tests expect command metadata
to remain valid.

Supported metadata keys:

- `# omarchy:group=...` - override the command group inferred from the filename
- `# omarchy:name=...` - override the command name inferred from the filename
- `# omarchy:summary=...` - short help text
- `# omarchy:args=...` - usage arguments
- `# omarchy:subcommand=<args> — <summary>` - one line per subcommand, for a command that takes subcommands (`omarchy bar use <id>`, `omarchy bar reset`, ...); listings and help show each on its own row with its own summary, and `args` is derived from them
- `# omarchy:examples=...` - examples separated with ` | `
- `# omarchy:alias=...` / `# omarchy:aliases=...` - alternate routes
- `# omarchy:hidden=true` - hide from default command listings
- `# omarchy:requires-sudo=true` - mark commands that require sudo
- `# omarchy:requires=desktop` - mark a command that needs the desktop session, in a group that otherwise works without one

Only use `omarchy:examples` where there are args that need explaining.

Omarchy Server has no desktop session (`omarchy-edition` prints `server` there), so the router hides desktop-only commands from its listings and refuses to run them. Whole groups are classified in `DESKTOP_GROUPS` in `bin/omarchy`: when adding a group to `GROUP_DESCRIPTIONS`, add it there too if every command in it needs Hyprland, the Omarchy shell or a display. Use `omarchy:requires=desktop` only for the exceptions in a mixed group such as `toggle`, `refresh` or `restart`. When unsure, leave a command available.

Prefer explicit metadata for user-facing commands. Keep routes consistent with
the filename unless there is a deliberate alias or compatibility route.

Example:

```bash
# omarchy:summary=Take a screenshot
# omarchy:args=[smart|region|windows|fullscreen] [slurp|copy]
# omarchy:examples=omarchy screenshot | omarchy capture screenshot region
```
