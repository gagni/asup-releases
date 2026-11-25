# Configuring aSup without the interface

Which file holds which setting, connection or secret, and how to change it safely from a
script or a coding agent. Install and folders: [INSTALL.md](INSTALL.md).

In this page `<config>`, `<data>`, `<state>` are the profile's folders:

| | Linux | Windows |
|---|---|---|
| `<config>` | `~/.config/asup/` | `%APPDATA%\asup\config\` |
| `<data>` | `~/.local/share/asup/` | `%LOCALAPPDATA%\asup\data\` |
| `<state>` | `~/.local/state/asup/` | `%APPDATA%\asup\state\` |

A non-default profile `<id>` uses `<folder>/profiles/<id>/`. Files marked « shared » stay in the
top folder for every profile. `ASUP_HOME` moves everything (see INSTALL.md).

## 1. Rules before editing anything

1. **Plain JSON, UTF-8 without BOM.** No comments, no trailing commas. A BOM makes the file
   invalid. Windows PowerShell 5.1's `Set-Content -Encoding UTF8` adds one: use
   `[IO.File]::WriteAllText($path, $json)` (no BOM) instead.
2. **An invalid file is silently replaced by the defaults**, and the next save overwrites it.
   Keep a copy (`cp settings.json settings.json.bak`) and validate before writing
   (`python3 -m json.tool file.json`).
3. **Unknown keys are dropped** at the next rewrite. Only `mcp.json` (per server) and
   `datastores.json` (whole entries) keep what they cannot read.
4. Writes are atomic (temp file then rename). Files holding secrets are created with mode 0600.

### The safest way: an import bundle

aSup applies `<config>/import-pending.json` at the next start, before reading anything, then
deletes it (`crates/asup-app/src/settings/transfer.rs`, `apply_pending`). It is the format of
Settings › Exporter:

```json
{
  "asup_export": 1,
  "files": {
    "settings.json": { "language": "en", "keep_alive_grace": 0 },
    "shared:runtimes.json": { "python_auto": false, "node_auto": true, "git_auto": true, "share_path": true }
  }
}
```

A key names a file of `<config>`; `data:` puts it in `<data>`, `shared:` in the shared config
folder; a key ending with `/` is a folder (relative path to text). Each file is written whole:
export first (Settings › Exporter) and edit that, rather than writing a partial file. A
bundle without `asup_export` is taken as a whole `settings.json`. Imported `custom_agents`
without an `api_key` keep the key they have on this PC.

Only these files are imported (other keys are ignored), by part:

| Part | Files |
|---|---|
| Interface | `settings.json`, `thread-view.json`, `server-settings.json`, `file_pins.json`, `item_pins.json`, `item_hidden.json`, `item_order.json`, `screen-record.json`, `extensions.json`, `vscode-extensions.json`, `i18n/`, `shared:runtimes.json`, `shared:setup.json` |
| Profile | `profile.json` |
| AI | `mcp.json`, `command-rules.json`, `agent-files.json`, `compute.json`, `conversation-tools.json`, `instructions.md`, `quick-prompts.json`, `vscode-lm.json`, `prices.json`, the video editor's engines file, `skills/` |
| Projects | `config.json`, `spaces.json`, `conversation-groups.json`, `descriptions.json`, `notes.json`, `thread-notes.json`, `autonomous.json`, `vision.json`, `vscode-auto-tasks.json`, `group-memory/`, `workspace-templates/`, `data:layout.json` |
| Machines | `hosts.json`, `ssh-key.json`, `machines.json`, `ports.json`, `shared:queue.json`, `servers.json`, `server-groups.json`, `clusters.json`, `profiler.json`, `broker-templates.json`, `data:http/collections/`, `data:http/globals.json` |
| Tasks | `tasks.json`, `managers.json`, `alerts.json` |
| Accounts | `forges.json`, `tickets.json`, `ticket-watch.json`, `mail.json`, `calendar.json`, `messaging.json`, `registries.json`, `packages.json`, `volumes.json`, `channels.json`, `agent-vars.json`, `machine-tokens.json`, `host-secrets.json`, `brokers.json`, `datastores.json`, `cluster-infra.json`, `ssh-keys/` (written 0600) |

Source: `crates/asup-app/src/settings/transfer.rs` (`Part::files`). Sealed secrets (section 6)
are never part of a bundle.

## 2. Main settings

### `<config>/settings.json`: the interface and the agents

Owner: `crates/asup-app/src/settings/model.rs` (`struct Settings`), defaults in
`settings/model/defaults.rs`. Missing keys take their default. Main keys:

| Group | Keys (default) |
|---|---|
| Appearance | `theme` (`custom`; `auto`, `light`, `dark`), `background`, `accent`, `vscode_theme`, `vscode_icon_theme`, `chat_theme`, `ui_font`, `code_font`, `chat_font`, `*_font_size`, `language` (`fr`) |
| Claude / Codex | `claude_model`, `claude_mode`, `claude_effort`, `codex_model`, `codex_mode`, `codex_effort`, `claude_path`, `codex_path`, `claude_args`, `codex_args`, `env`, `claude_env`, `codex_env`, `optimized_context` (false), `optional_tools` |
| Other agents | `custom_agents[]` (`id`, `name`, `base`, `provider`, `base_url`, `api_key`, `binary`, `env`, `args`, `model`, `models`, `enabled`), `disabled_agents`, `isolated_agents` |
| Features | `disabled_features`, `enabled_features`, `disabled_widgets`, `widget_agents` |
| aSup's MCP servers and skills | `disabled_mcp`, `mcp_targets`, `mcp_agents`, `office_agents`, `skill_choices` |
| Terminal | `terminal_shell` (null: `$SHELL`, or `pwsh`/PowerShell on Windows), `terminal_font_size` |
| Sessions | `keep_alive_grace` (30 minutes; 0 off, 4294967295 unlimited), `resume_minutes` (30), `idle_minutes` |
| Notifications | `notify_*`, `quiet_hours`, `quiet_start` (22), `quiet_end` (7) |
| Web | `web_*` (cache size, purge, sleep, number of agent browsers) |
| SSH | `ssh_timeout` (20), `ssh_keepalive` (15), `auto_reconnect` |
| Budgets | `budget_session`, `budget_day` (0: none) |
| Updates | `check_updates` (true), `auto_update` (false) |
| Window | `window_bounds`, `window_maximized`, `window_remember` (true) |

- Rewritten whole on every change, window moves included.
- While aSup runs, an outside write is picked up within 2 s if the whole file parses and is not
  aSup's own write; some values (web cache, cleanup, monitor retention) apply only at start.
  `custom_agents` is re-read when the file changes.
- `custom_agents[].api_key` is stored in plain text.

### Other general files

| File | Content | Notes |
|---|---|---|
| `<config>/config.json` | `workspaces[]`, `semantic_search`, `voice_language`, `tab_history`, `pinned_conversations`, `git_secret_check`; sub-objects `speech`, `embedding`, `voice`, `translation`, `summary`, `quick_ai`... Remote models are `{base_url, model, api_key, api_key_env}` | `api_key_env` (an environment variable name) wins over a plain `api_key` |
| `<config>/server-settings.json` | `{ "<host>": "display" \| "all" \| "agents" }`: which settings a served workspace takes from the remote aSup | Read on each use |
| shared `profiles.json` | `{active, profiles:[{id, name}], startup}` | `ASUP_PROFILE` overrides `active` |
| `<config>/profile.json` | The user's profile (name, email) | 0600 |
| shared `setup.json` | `{"shown": bool}`: welcome assistant already offered | |
| shared `runtimes.json` | `{python_auto, node_auto, git_auto, share_path}`, all true | See INSTALL.md section 7 |
| shared `app-update.json` | Update mode `Off` / `Notify` / `Download` | |
| shared `queue.json` | Build and test queue: limits, `machines{}`, cleaning, timeout | Re-read when it changes |
| `<config>/extensions.json` | `{installed[], disabled[], trusted[]}` add-on ids for this profile | See INSTALL.md section 5 |
| `<config>/vision.json` | Project vision choices | |
| `<config>/instructions.md` | Instructions added to every agent | |

## 3. Workspaces, projects, conversations

| File | Content | Notes |
|---|---|---|
| `<config>/spaces.json` | `{spaces:[{id, name, host ("" = this PC), roots[], hidden, pinned, machines, ssh_key, compute, ...}]}` | New workspaces are picked up within 2 s |
| `<config>/conversation-groups.json` | `{groups:[{id, host, cwd, name, parent, pinned, archived, color, instructions}], members{session: group}}` | |
| `<config>/thread-notes.json`, `descriptions.json` | Notes and descriptions of conversations | |
| `<config>/group-memory/<id>/MEMORY.md`, `space-memory/<id>/MEMORY.md` | Memories shared by a group's or workspace's agents, `## Title` per entry | Markdown |
| `<config>/skills/` | aSup's global skills: a Claude plugin (`.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`) | Built-in skills are re-synced at start |
| `<config>/skill-links.json` | Folders of skills linked from elsewhere | Re-read at each agent launch |
| `<config>/agent-vars.json` | Variables given to agents: `{vars, workspaces, conversations}` | Plain values, 0600 |
| `<config>/command-rules.json`, `compute.json`, `agent-files.json`, `autonomous.json` | Command rules, build/test instructions, agent files, autonomous mode | |
| `<data>/session.json`, `past-sessions.json`, `tab-history.json`, `layout.json`, `spaces-session.json` | Open tabs and layout | Rewritten on every tab change |
| `<state>/reprise.json`, `unread.json`, `relaunch.json` | Resume list, unread marks | |

`asup --client HOST` keeps its own window files with a `-HOST` suffix (`session-HOST.json`).

## 4. Machines and connections

| File | Content | Secrets |
|---|---|---|
| `<config>/hosts.json` | `{hosts:[{name, target}], auto_connect[], hidden[], ssh_configs[], in_projects[]}`; hosts of `~/.ssh/config` are read too | |
| `<config>/host-secrets.json` | `{host: password}` for SSH passwords to remember | Plain, 0600 |
| `<config>/servers.json`, `server-groups.json` | Monitoring preferences, server groups | |
| `<config>/machines.json`, `machine-tokens.json` | Work machines and the agent tokens copied to them | Plain, 0600 |
| `<config>/volumes.json` | Storage: `{volumes:[{id, name, type, ...}]}`, `type` = `s3` (`endpoint`, `region`, `bucket`, `access_key`, `secret_key`), `ssh` (`host`, `root`, `user`, `port`, `key`, `password`), `ftp`, `webdav`, `microsoft` | Plain keys and passwords, 0600 |
| `<config>/datastores.json` | Databases: `{connections:[{name, kind, machine, host, port, user, password, database, read_only (true), options{}}]}`, `kind` = `postgres`, `starrocks`, `mysql`, `redis`, `mongo`, `elastic`, `cassandra`, `leveldb`, `sqlite` | Plain `password`, 0600 |
| `<config>/brokers.json` | `{connections:[{name, kind, machine, url, address, user, password, token, sasl, insecure}]}` (RabbitMQ, NATS, Kafka; JSON spelling of `kind` not verified) | Plain, 0600 |
| `<config>/clusters.json` | `{clusters:[{name, access:{type: "Kubeconfig" \| "Direct" \| "Swarm", ...}}]}`; `Kubeconfig`: `host`, `context`, `kubeconfig`, `kubectl`, `sudo`; `Direct`: `url`, `token`, `ca`, `via` | Plain `token`, 0600 |
| `<config>/observe.json` | `{connections:[{name, kind, machine, url, user, tenant, organization, project, insecure}]}`, `kind` = `loki`, `prometheus`, `alertmanager`, `grafana`, `sentry`, `glitchtip`, `tempo`, `jaeger`, `traefik`, `nginx`, `apache`, `caddy` | Sealed (section 6) |
| `<data>/http/collections/<id>.json` | HTTP client collections: `vars`, `environments`, `headers`, `auth`, `requests[]`, `folders`; `<data>/http/globals.json` | Auth values plain |
| `<config>/mcp.json` | See section 5 | `env` and `headers` plain, 0600 |

## 5. MCP servers

`<config>/mcp.json`, the servers aSup gives its agents (`crates/asup-core/src/mcp_global`):

```json
{
  "mcpServers": {
    "my-server": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "some-mcp-server"],
      "env": { "API_KEY": "..." },
      "agents": [],
      "workspaces": [],
      "disabled": false
    },
    "remote": { "type": "http", "url": "https://example.com/mcp", "headers": { "Authorization": "Bearer ..." } }
  }
}
```

- `type`: `stdio`, `http` or `sse`. Names: `[A-Za-z0-9_-]`, 64 characters at most.
- `workspaces` empty = every workspace; otherwise ids from `spaces.json`. `agents` empty = every
  agent.
- Read once per run: a change applies at the next start.
- aSup's own `asup_*` servers are switched in `settings.json` (`disabled_mcp`, `mcp_targets`,
  `mcp_agents`), not here.

## 6. Accounts, tokens and secrets

aSup uses **no system keyring** (no Secret Service, KWallet or Windows Credential Manager) for its
own secrets. They are either plain text in 0600 JSON files, or in sealed stores.

### Plain text (0600 JSON in `<config>`)

| File | Account | Token field | Environment alternative |
|---|---|---|---|
| `forges.json` | GitLab / GitHub: `{accounts:[{id, name, kind: "gitlab" \| "github", url, token, enabled, agent_access:{allowed, env, env_name}}]}` | `token` | `token_env` |
| `packages.json` | npm, PyPI, Cargo, Hugging Face (`HF_TOKEN`): `username`, `password`, `agent_access` | `password` | `password_env` |
| `tickets.json` | GitLab, GitHub, Trello, Notion, Linear boards: `{accounts:[{id, name, kind, token, key, user, api, boards, enabled}]}` (`api`: API address, empty = the tool's own) | `token`, `key` | `token_env` |
| `<data>/local-tickets.sqlite` | Local tickets of aSup (source « aSup »), no secret | | |
| `registries.json` | Container registries | `password` | `password_env` |
| `mail.json` | Mail accounts: `{accounts:[{id, name, email, kind, protocol, incoming, outgoing, smtp_password, ...}], default}` | `smtp_password` | |
| `channels.json` | Mailjet, SMTP channels of notifications | plain fields | |
| `settings.json` | `custom_agents[].api_key` | `api_key` | |
| `config.json` | Remote models | `api_key` | `api_key_env` |

`agent_access` in `forges.json` and `packages.json` is what lets agents use a token:
`allowed` (the `token_get` tool may return it), `env` (also put in the agents' environment),
`env_name` (the variable; empty = the kind's usual one, `GITLAB_TOKEN`, `HF_TOKEN`...),
`hidden` (left out of the views, still given to agents). Source:
`crates/asup-core/src/agent_vars/accounts.rs`.

Claude Code and Codex sign-ins of the accounts aSup manages: `<data>/accounts/<engine>/<id>/`
(`account.json`, `secret.json`, folder 0700). The default profile also uses the agents' own
folders (`~/.claude`, `~/.codex`).

### Sealed stores

AES-256-GCM, `<data>/<dir>/<stem>.sealed` with its key in `<stem>.key` next to it
(`crates/asup-core/src/sealed.rs`). Values are by id:

| Store | Files | Id | Value |
|---|---|---|---|
| Observability | `<data>/observe/secrets.*` | source name | password or token |
| Calendar | `<data>/calendar/secrets.*` | account id | JSON text `{password, fields{client_secret, access_token, refresh_token, expires_at}}` |
| Messaging | `<data>/messaging/secrets.*` | account id | Mattermost or Slack token |
| Microsoft 365 storage | `<data>/storage/secrets.*` | volume id | OAuth tokens (JSON) |
| Mail | `<data>/mail/passwords.*` | account id | `{incoming, outgoing, oauth}` |

To seed a sealed store from a script: with **no `<stem>.sealed` yet**, write
`<stem>.json` as `{"<id>": <value>}`. aSup reads it, seals it at the next save and deletes the
plain file. When a `.sealed` file exists, the `.json` is ignored: use the interface, or delete
both `.sealed` and `.key` (losing that store's other secrets) and write the `.json`.

### Secrets for agents

- MCP secrets reach agents as `ASUP_MCP_SECRET_<SERVER>_<KEY>`.
- Account tokens reach agents only when `agent_access.allowed` is true; in their environment
  only with `env` too.

## 7. Other features

| File | Content |
|---|---|
| `<config>/calendar.json` | `{list:[{id, kind: "local" \| "cal_dav" \| "subscription" \| "google" \| "microsoft" \| "outlook_web", name, email, url, user, enabled, agents, poll_minutes, ...}], default_calendar}`; secrets in the calendar sealed store |
| `<config>/messaging.json` | `{accounts:[{id, service, name, config:{enabled, connector, mode, url}}]}`; tokens sealed |
| `<config>/tasks.json` | Scheduled tasks `{tasks:[{id, title, prompt, agent, model, cwd, access: "read" \| "edit" \| "full", schedule, until, status: "active" \| "paused" \| "done" \| "stopped", ...}]}`; re-read on every tick; runs in `<data>/tasks/<id>.jsonl` |
| `<data>/notes.sqlite` | Sticky notes |
| `<config>/alerts.json`, `ports.json`, `security.json`, `syncs.json`, `env-sync.json`, `prices.json`, `quick-prompts.json` | Alerts, port filters, secrets guard, folder syncs, environment copy, model prices, quick prompts |
| shared `remote/` | Remote access: `secret.key`, `remote.json` (Argon2id password hash, paired devices); `asup --server --password` sets it |

## 8. Environment variables

| Variable | Effect |
|---|---|
| `ASUP_HOME` | Root of all folders |
| `ASUP_PROFILE` | Profile to run |
| `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME` | Absolute: `<it>/asup`, on every OS |
| `CLAUDE_CONFIG_DIR`, `CODEX_HOME` | The agents' folders (a non-default profile sets them) |
| `ASUP_REMOTE_PASSWORD` | Password of `asup --server` without a prompt |
| `ASUP_DAEMON_IDLE` | Idle time of the remote daemon, in seconds (1800) |
| `ASUP_WEB` | Path to an `asup-web` binary |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` | Agents ready without `claude auth login` / `codex login` |

## 9. Recipes

Turn keep-alive off and pick a terminal shell (Linux):

```bash
f=~/.config/asup/settings.json; cp "$f" "$f.bak"
python3 - "$f" <<'EOF'
import json, sys
p = sys.argv[1]; s = json.load(open(p))
s["keep_alive_grace"] = 0
s["terminal_shell"] = "/bin/bash"
json.dump(s, open(p, "w"), indent=2)
EOF
```

Same on Windows (PowerShell, no BOM):

```powershell
$f = "$env:APPDATA\asup\config\settings.json"; Copy-Item $f "$f.bak"
$s = Get-Content $f -Raw | ConvertFrom-Json
$s | Add-Member -Force keep_alive_grace 0
$s | Add-Member -Force terminal_shell "cmd.exe"
[IO.File]::WriteAllText($f, ($s | ConvertTo-Json -Depth 50))
```

Add a GitLab account whose token agents may use:

```json
{"accounts": [{"id": "gitlab-perso", "name": "GitLab perso", "kind": "gitlab",
  "url": "https://gitlab.com", "token": "glpat-...", "enabled": true,
  "agent_access": {"allowed": true, "env": true, "env_name": "GITLAB_TOKEN_PERSO", "hidden": false}}]}
```

(`<config>/forges.json`; merge into the existing `accounts` instead of replacing them.)

Add a PostgreSQL connection, read-only (`<config>/datastores.json`):

```json
{"connections": [{"name": "prod-db", "kind": "postgres", "host": "db.example.com",
  "port": 5432, "user": "reader", "password": "...", "database": "app", "read_only": true}]}
```

After any change, start aSup and check `<data>/logs/errors.jsonl` and the matching view.
