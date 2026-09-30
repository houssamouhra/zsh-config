# How to implement this config

This repo is an XDG zsh setup: a tiny `$HOME/.zshenv` points zsh at `$XDG_CONFIG_HOME/zsh`, plugins clone themselves on first use, and opinions live in an overlay you can keep, edit, or skip.

## Layout

```
.zshenv                         →  $HOME/.zshenv          (sets ZDOTDIR)
.config/zsh/.zshenv             →  env, PATH, path_add
.config/zsh/.zshrc              →  $ZDOTDIR/.zshrc; also $HOME/.zshrc (symlink)
.config/zsh/plugins.zsh         →  clone/load plugins
.config/zsh/config/*.zsh        →  prompt, history, keys, completion, aliases, fzf, functions
.config/zsh/personal-config.zsh →  public overlay (kubectl, kube prompt, …)
.config/fzf/                    →  fzf theme + preview script
.config/zsh-patina/             →  syntax-highlight theme (valid commands = green)
.zsh-config-private.zsh         →  $HOME/.zsh-config-private.zsh (not in git)
```

`$ZDOTDIR/plugins/` is gitignored. `plugin-path` clones into it; `update-plugin` refreshes those clones. Three Oh My Zsh _snippets_ (git / kubectl) ship under `plugins/oh-my-zsh-plugins/` without the framework.

## Requirements

| Need                                                                               | Why                                                                         |
| ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| zsh 5.8+ as login shell                                                            | this config                                                                 |
| git                                                                                | plugin clones                                                               |
| [fzf](https://github.com/junegunn/fzf)                                             | completions, Ctrl-R / Ctrl-T / Alt-C                                        |
| [eza](https://github.com/eza-community/eza), [bat](https://github.com/sharkdp/bat) | `ls` aliases and fzf preview                                                |
| [fd](https://github.com/sharkdp/fd)                                                | overlay `FZF_DEFAULT_COMMAND`                                               |
| rust/`cargo`                                                                       | first-time [zsh-patina](https://github.com/michel-kraemer/zsh-patina) build |

Optional: `kubectl` / `kubecolor` (overlay), `zoxide`, `yazi`, `fnm`, `keychain`, `nvim`. Missing tools are skipped or only break the alias that uses them.

Homebrew is the usual source for these on macOS (`/opt/homebrew` or `/usr/local`) and Linux (`/home/linuxbrew/.linuxbrew` or `~/.linuxbrew`). `.zshenv` evals `brew shellenv` from the first of those that exists.

## 1. Clone and install

```zsh
git clone "https://github.com/jessegoodier/zsh-config.git" ~/git/zsh-config
cd ~/git/zsh-config
./installer.sh
```

The installer moves existing targets into a dated folder under `backups/`, then symlinks this clone into `$HOME`. It can also install missing tools with Homebrew and the Python venv. Re-runs skip paths that already point here. Details, flags, and restore: [README-installer.md](./README-installer.md).

If zsh is not your login shell:

```zsh
chsh -s $(command -v zsh)
```

## 2. First launch

Open a **new** terminal (do not `source` an old interactive session).

On the first run you should see clone messages for gitstatus, zsh-defer, ez-compinit, and the rest. zsh-patina builds with `cargo` if the binary is missing; that is the slow one-time step.

Then:

```zsh
echo $ZDOTDIR    # should be ~/.config/zsh
update-plugin    # later: refresh clones (skips the vendored OMZ snippets)
```

## 3. Make it yours

Three layers, last writer wins:

| File                            | In git? | Use for                                      |
| ------------------------------- | ------- | -------------------------------------------- |
| `config/*.zsh`                  | yes     | shared behavior you are happy to publish     |
| `$ZDOTDIR/personal-config.zsh`  | yes     | public opinions (PATH, aliases, kube prompt) |
| `$HOME/.zsh-config-private.zsh` | no      | secrets, machine-only PATH, extra hooks      |

**Keep the overlay, change the opinions.** Edit `personal-config.zsh`: PATH entries, `EDITOR`, `fd` as the fzf finder, kubectl/kubecolor, the kube prompt prefix (`KUBE_INFO`).

**Skip the overlay.** Remove or rename `personal-config.zsh`. Core prompt, completions, and plugins still load. `KUBE_INFO` stays empty.

**Add secrets.** Create `~/.zsh-config-private.zsh` (already gitignored). That is the place for tokens, extra `path_add` dirs, and company login helpers.

**Steal the loader only.** Copy `plugins.zsh` + `.zshenv` / `.zshrc` wiring and drop in your own `config/` modules. `plugin-path owner repo` clones `https://github.com/owner/repo` on first use.

## 4. What loads when

- **Eager:** gitstatus, zsh-defer, ez-compinit (queues `compdef`; real `compinit` on first prompt), zsh-completions, the `config/*.zsh` modules.
- **Deferred (`zsh-defer`):** fzf-tab, autosuggestions, history-substring-search, colored-man-pages, zsh-patina, overlay alias packs.
- **Lazy:** fzf widgets (Ctrl-R / Ctrl-T / Alt-C), `zoxide`, `fnm` (when `package.json` is in `$PWD`).

That split is what keeps first prompt snappy. Put slow or opinionated work in the overlay and `zsh-defer` it.

## 5. Recreate the benchmark

From a machine where this config is the login shell (or a scratch `HOME` that symlinks it):

```zsh
git clone "https://github.com/romkatv/zsh-bench.git" ~/zsh-bench
~/zsh-bench/zsh-bench --login yes
```

zsh-bench needs the prompt to contain the hostname or the last path component. This prompt does the latter. Numbers go in [README.md](./README.md); they are a min over 16 login iterations on one machine, not a guarantee.

## Troubleshooting

- **`command not found: compdef`** — ez-compinit must load before anything calls `compdef`. Do not defer `plugins.zsh` itself.
- **Plugins missing after clone** — first start needs network; check `$ZDOTDIR/plugins`.
- **zsh-patina missing** — install rust (`https://rustup.rs` or Homebrew `rustup`), then `update-plugin` or `cargo build --release` in `$ZDOTDIR/plugins/zsh-patina`.
- **fzf preview empty** — install `eza` and `bat`; confirm `$XDG_CONFIG_HOME/fzf/preview.sh` is executable.
- **Git aliases missing** — they come from the overlay snippets under `plugins/oh-my-zsh-plugins/` and load after first prompt.
- **Still on the old config** — this repo is not live until `~/.zshenv` and `~/.config/zsh` point at it. `echo $ZDOTDIR; ls -l ~/.zshenv ~/.config/zsh`.

## Scheduled OneDrive backup

`scripts/backup_to_onedrive.sh` tars this whole repo (including gitignored secrets like `.zsh-config-private.zsh`, excluding `.venv`, `.git`, and any `target/` build dirs) to `OneDrive-IBM/backups/zsh-config-backups/zsh-config-backup_<timestamp>.tgz`, keeping the 30 most recent archives.

A launchd agent (`~/Library/LaunchAgents/com.jessegoodier.zsh-config-backup.plist`) runs it every 6 hours and on login. Logs: `~/Library/Logs/zsh-config-backup.log`.

- Force a run now: `launchctl kickstart -k gui/$(id -u)/com.jessegoodier.zsh-config-backup`
- Check it's loaded: `launchctl print gui/$(id -u)/com.jessegoodier.zsh-config-backup`
- Disable it: `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.jessegoodier.zsh-config-backup.plist`
