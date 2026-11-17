# Codex usage for KDE Plasma

A panel and desktop widget that displays the remaining Codex 5-hour and weekly allowances. The panel shows two circular meters; clicking opens reset details. A right-click **Configure Codex usage** action opens settings for that widget instance.

## Requirements

- KDE Plasma 5.27 or Plasma 6, with the executable data engine (Plasma 6 uses `plasma5support`)
- KDE Quick Charts QML modules (`org.kde.quickcharts` and `org.kde.quickcharts.controls`)
- Python 3 (standard library only)
- Codex CLI signed in with a ChatGPT account (`codex login`)

The widget reads the CLI's `account/rateLimits/read` app-server response. It does not use an OpenAI API key or store credentials. Some plans expose only a weekly window; the 5-hour meter then reads **Unavailable**.

## Build and install

Run `python3 package.py`. This creates `dist/codex-usage-plasma5.plasmoid` and `dist/codex-usage-plasma6.plasmoid`. Install the archive matching your Plasma major version:

```sh
kpackagetool5 --type Plasma/Applet --install dist/codex-usage-plasma5.plasmoid
# or, on Plasma 6:
kpackagetool6 --type Plasma/Applet --install dist/codex-usage-plasma6.plasmoid
```

Add **Codex usage** from Plasma's widget picker to a panel or the desktop. To update an existing installation, use `--upgrade` instead of `--install`, then restart Plasma or log out and back in if QML is cached.

## Settings

Right-click the widget and select **Configure Codex usage**. Leave **Codex install path** empty to search `PATH`, `~/.local/bin/codex`, `~/.npm-global/bin/codex`, `/usr/local/bin/codex`, `/usr/bin/codex`, and `/usr/lib/chatgpt/resources/codex`. A custom path is used exclusively. Plasma saves the path when you select **Apply** or **OK**; the widget checks it with `codex --version` during refresh and reports a missing installation if it is invalid. The default refresh interval is one minute; the menu also offers 1, 5, 10, and 30 seconds; 5, 10, and 30 minutes; and one hour.

The Python bridge runs in the user session and shares one Codex app-server process among widget instances. It listens on a private Unix socket under `XDG_RUNTIME_DIR` (or a private `/tmp` directory) and exits after ten minutes of inactivity. At most one usage read runs at a time; a refresh tick is skipped while a previous read is still pending.

## Development

Run `python3 -m unittest discover -s tests -v` for the reader tests. The Plasma 5 and Plasma 6 QML entry points are in `plasma5/contents/ui/main.qml` and `plasma6/contents/ui/main.qml`. `codex_usage.py` at the repository root is authoritative; `package.py` copies it into both packages before creating the archives.

Plasma 6 layout and integration still need a live Plasma 6 environment for verification.
