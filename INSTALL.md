# Installing aSup

How aSup is installed on Linux and Windows, where it puts its files, and how its add-ons,
runtimes and agents get there. Written so a coding agent (Claude Code, Codex) can install and
check aSup end to end without the interface. For editing its configuration, see
[CONFIG.md](CONFIG.md).

## 1. What to download

Releases live on the public repository `gagni/asup-releases` (the source repository is private).

- Signed catalog: `https://raw.githubusercontent.com/gagni/asup-releases/main/catalog.json`
  and `catalog.json.sig` (hex Ed25519 signature of the exact bytes; public key compiled into aSup,
  `crates/asup-core/src/catalog.rs`). The catalog lists every asset with its size and SHA-256.
- Assets of the GitHub release `v<version>`:
  - App: `asup-light-<version>-linux-x86_64.tar.zst`, `asup-light-<version>-windows-x86_64.zip`
  - Add-ons: `asup-<name>-linux-x86_64.asupx`, `asup-<name>-windows-x86_64.asupx`
- x86_64 only. No macOS package.

The archive holds one folder `asup-light-<version>-<os>-x86_64/` with a single file: `asup`
(Linux) or `asup.exe` (Windows). There is no installer and no install command.

Check a download against the catalog (size and `sha256`) before using it. Example:

```bash
curl -fsSL https://raw.githubusercontent.com/gagni/asup-releases/main/catalog.json -o catalog.json
# read the asset's "url", "size" and "sha256" in catalog.json, then:
curl -fsSL -o asup.tar.zst "<url>"
sha256sum asup.tar.zst
```

## 2. Install the app

### One command: aSup and every add-on

The installers download the signed catalog, check each file's SHA-256 and put everything in one
folder: the app and `extensions/<id>/` beside it (read beside the program, no profile entry
needed). Rerun them to update. Options: a folder (`--dir DIR` / `-Dir DIR`), no add-ons
(`--no-addons` / `-NoAddons`).

| OS | Command | Folder |
|---|---|---|
| Linux | `curl -fsSL https://raw.githubusercontent.com/gagni/asup-releases/main/install.sh \| sh` | `~/.local/opt/asup`, link `~/.local/bin/asup` |
| Windows | download and run [`install.bat`](https://raw.githubusercontent.com/gagni/asup-releases/main/install.bat) | `%LOCALAPPDATA%\Programs\asup`, Start menu shortcut |

Linux needs `curl` (or `wget`), `tar` with `zstd`, `unzip`, `sha256sum` and `python3`. Sources:
`tools/install/`. The sections below install by hand.

### Linux

```bash
mkdir -p ~/.local/opt && cd ~/.local/opt
tar --zstd -xf asup-light-<version>-linux-x86_64.tar.zst
ln -sf ~/.local/opt/asup-light-<version>-linux-x86_64/asup ~/.local/bin/asup
asup --version
```

- Any folder you can write works. Self-update replaces the binary in place, so keep it in a
  folder you own, and keep the name `asup` (another name turns self-update off).
- At each start aSup writes `~/.local/share/applications/asup.desktop` and its icon (menu entry).
- Shared libraries needed: `libxkbcommon0 libxkbcommon-x11-0 libxcb1 libpipewire-0.3-0
  libfontconfig1` (Debian names) and a Vulkan driver (Mesa or the GPU vendor's).
- Optional: `pactl` / `pw-record` / `paplay` (audio), KWallet or `secret-tool` (only to import
  other browsers' saved logins), xdg-desktop-portal (printing).

### Windows (10 or later)

```powershell
$dest = "$env:LOCALAPPDATA\Programs\asup"
New-Item -ItemType Directory -Force $dest | Out-Null
tar -xf asup-light-<version>-windows-x86_64.zip -C $env:TEMP
Copy-Item "$env:TEMP\asup-light-<version>-windows-x86_64\asup.exe" "$dest\asup.exe"
& "$dest\asup.exe" --version
```

- `%LOCALAPPDATA%\Programs\asup` is a convention, not a requirement: any folder you can write
  works, and the file must stay `asup.exe`. aSup creates no Start menu shortcut; make one if needed.
- The first run may show a Windows firewall prompt; aSup's own links are local (127.0.0.1) and
  remote access goes through iroh without an open port, so refusing is fine.
- The integrated terminal uses ConPTY and runs `pwsh` if installed, else Windows PowerShell.
- aSup downloads with its own HTTP client (system proxy and certificate store, retries, resumed
  transfers): it never needs `curl.exe`.

### Useful command-line options

| Command | Effect |
|---|---|
| `asup --version` | Prints the version and exits (touches no file). |
| `asup [HOST:]DIR` / `asup FILE...` | Opens a folder (on an SSH host) or files. |
| `asup --home DIR` | Uses `DIR/{config,data,state,cache}` for everything (sets `ASUP_HOME`). |
| `asup --incognito` | Throwaway home, deleted at exit. |
| `asup --client HOST` | Window of a remote aSup (`user@host[:port]`). |
| `asup --server [--password] [--relay URL]` | Headless remote server, no window. |
| `asup pdf|boards|montage|image [PATH]` | A standalone program window. |
| `asup queue build|test|status`, `asup ci status|wait|log` | Build queue and CI from a shell. |

## 3. Where aSup keeps its files

| Kind | Linux | Windows |
|---|---|---|
| Config | `~/.config/asup/` | `%APPDATA%\asup\config\` |
| State | `~/.local/state/asup/` | `%APPDATA%\asup\state\` |
| Data | `~/.local/share/asup/` | `%LOCALAPPDATA%\asup\data\` |
| Cache | `~/.cache/asup/` | `%LOCALAPPDATA%\asup\cache\` |

- `ASUP_HOME=<absolute path>` (or `--home`) puts all four under it. An absolute `XDG_*_HOME`
  gives `<it>/asup` on every OS, Windows included. Source: `platform/src/paths.rs`.
- Profiles: the default profile uses the folders above; profile `<id>` uses
  `<folder>/profiles/<id>/` for config, data and state. The list is
  `<config>/profiles.json`; `ASUP_PROFILE=<id>` forces one. A non-default profile also gives
  Claude Code and Codex their own folders (`<data>/claude`, `<data>/codex`).
- Logs: `<data>/logs/errors.jsonl` (the error journal shown in Console › Erreurs).

## 4. First run

The first start opens a welcome assistant. It needs:

1. A user profile (name of 5 to 32 characters and an email), saved in `<config>/profile.json`.
2. At least one agent signed in (Claude Code or Codex, see section 6).
3. An « Extensions » step where every catalog add-on is ticked; « Suivant » installs them in the
   background.

`<config>/setup.json` is `{"shown": true}` once the assistant was offered. Pre-seeding
`profile.json` and `setup.json` to skip it is plausible but not tested.

## 5. Add-ons (.asupx)

An add-on is an aSup extension shipped prebuilt for one OS: a zip with an `extension.json`
(id, name, version, command, tools, skills, apps) and a program that talks JSON-RPC 2.0 over
stdio. Contract: `extensions/README.md`.

| Add-on | What it brings |
|---|---|
| `web` | Web tabs, HTML preview and the agents' browser (CEF, about 370 MB unpacked). Without it these are hidden. |
| `pdf`, `pdf-conversion` | PDF program and Office/HTML to PDF conversions. |
| `boards` | Design boards (UX/UI screens). |
| `dashboards` | Dashboards (`.asupdash`). |
| `images`, `video` | Image editor, video editor. |
| `vision-engine` | Project vision (architecture, problems). |
| `ctranslate2` | Local translation models. |
| `call-message` | Calls in the messaging. |
| `messaging` | Outlook/Teams/Slack/Mattermost messaging (when published). |
| `office` (Windows) | Word, Excel and PowerPoint through COM (when published). |

Where they go:

- Files: `<shared data>/extensions/<id>/` (`~/.local/share/asup/extensions/` or
  `%LOCALAPPDATA%\asup\data\extensions\`), one copy per PC. A folder `extensions/` next to the
  binary is also read (bundled add-ons, lower priority).
- Per profile: `<config>/extensions.json` = `{"installed": [ids], "disabled": [ids],
  "trusted": [ids]}`. A profile uses a PC add-on only when its id is in `installed`.

How to install:

1. Interface: the Extensions view's « aSup » tab, whose « Disponibles » section lists the signed
   catalog (size and SHA-256 checked), or `+` › « Fichier » › « Extension aSup (.asupx)... ».
2. By hand: unzip the `.asupx` into `<shared data>/extensions/<id>/` (the folder
   holding `extension.json`), then add `<id>` to `installed` in `<config>/extensions.json`. The
   code reads `installed` to activate it; this path is not tested end to end.
3. Updates are offered per add-on in the Extensions view (checked every 12 h).

The ids in the catalog follow `asup.<name>`. An extension sees `ASUP_EXTENSION_ID` and
`ASUP_EXTENSION_DATA` (its data folder for the profile).

## 6. Agents and external tools

| Tool | Needed | Install | Sign in |
|---|---|---|---|
| Claude Code | One agent at least | Linux: `curl -fsSL https://claude.ai/install.sh \| bash`; Windows: `powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://claude.ai/install.ps1 \| iex"` | `claude auth login`, or `ANTHROPIC_API_KEY` |
| Codex | Optional | Linux: `curl -fsSL https://chatgpt.com/codex/install.sh \| CODEX_NON_INTERACTIVE=1 sh`; Windows: `npm install -g @openai/codex` (needs Node) | `codex login`, or `OPENAI_API_KEY` |
| curl | No | aSup downloads with its own client. Where an installer of another vendor calls `curl` or `wget` (agents' installers; Claude Code's and Codex's on Linux or macOS) and there is no curl, aSup puts stand-ins first on its PATH that download through aSup (on an ssh host, through a reverse forward of the connection: the host needs no Internet; bash needed there). On an ssh host, HTTP APIs (Kubernetes, brokers, observability, Elasticsearch) use its curl when present, else an ssh tunnel (a container's `localhost` is reached at the container's address); Claude Code, Codex, Node and Python are sent by the PC when the host cannot download them (checked against their SHA-256 there); a Docker container is recreated through the host's Docker CLI (`docker system dial-stdio`). Building aSup fetches its fonts with curl, else wget, PowerShell or Python | |
| git | Yes | System, else aSup's private copy (section 7) | |
| ssh | For servers | OpenSSH; `~/.ssh/config` is read (`%USERPROFILE%\.ssh\config` on Windows) | |

aSup finds `claude` on the PATH, else in `~/.local/bin`. Settings › Installation installs and
updates them too (`claude update`, `codex update`).

## 7. Runtimes aSup downloads itself

At start, in the background, only when the PC lacks them, into `<shared data>/runtimes/<name>/`
(never added to the system PATH):

| Runtime | Version | Notes |
|---|---|---|
| Git | dugite-native 2.56.0 | MinGit on Windows; its `sh.exe` is aSup's `sh` and Claude Code's Git Bash. |
| Python | python-build-standalone 3.13 | |
| Node | 24.22.1 | |

On demand only: js-debug (JavaScript debugging), language servers, ONNX Runtime (local models),
local models (embeddings, dictation, translation, voices) from Settings › Installation.

Turn the automatic downloads off in `<shared config>/runtimes.json` (all default to `true`):

```json
{"python_auto": false, "node_auto": false, "git_auto": false, "share_path": true}
```

`share_path` adds the private copies to the PATH of aSup's terminals and agents.

## 8. Updates

- aSup checks the signed catalog 30 s after start, then every 4 h (the network at most once a
  day per PC). Mode in `<shared config>/app-update.json`: `Off`, `Notify` (default) or
  `Download`. A dev build, or a binary not named `asup` / `asup.exe`, never updates itself.
- « Mettre à jour » downloads the package to `<shared data>/updates`, checks it, and swaps the
  binary (the old one becomes `<exe>.old`, deleted at the next start). If the folder is not
  writable, aSup shows the package path to install by hand.

## 9. Check an installation

```bash
asup --version                                   # the version
ls ~/.config/asup ~/.local/share/asup            # folders created by the first run
cat ~/.config/asup/extensions.json               # add-ons this profile uses
ls ~/.local/share/asup/extensions                # add-ons on this PC
tail -n 20 ~/.local/share/asup/logs/errors.jsonl # recent errors
claude --version && claude auth status           # the agent
```

On Windows, the same files are under `%APPDATA%\asup\config` and `%LOCALAPPDATA%\asup\data`.

## 10. Building from source

- Linux: `./build.sh` (`cargo build --release -p asup-app`, gives `target/release/asup`).
  Needs read access to the private repositories `platform`, `speech-text` and `motion` on GitLab
  (Cargo uses the system git), Rust 1.98 and the build packages listed in the `Dockerfile`.
- Windows: cross-built from Linux with `cargo xwin build --release --target
  x86_64-pc-windows-msvc -p asup-app --bin asup`, then `ASUP_PACKAGE_OS=windows
  ASUP_PACKAGE_ARCH=x86_64 ASUP_PACKAGE_SKIP_BUILD=1 ASUP_BIN=<asup.exe> tools/package light`.
- Add-ons: `extensions/package-addon <name>` (Windows: `CARGO="cargo xwin"
  ASUP_ADDON_TARGET=x86_64-pc-windows-msvc`).
- Releases and CI: [docs/releases.md](docs/releases.md).
