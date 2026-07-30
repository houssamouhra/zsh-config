# Zsh Config

A modular, lightweight, and performance-focused Zsh configuration built for my workflow as a software engineer.

---

## Philosophy

Every part of the configuration has a purpose, with functionality split into focused modules rather than relying on a large framework.

## Plugin Management

Plugins are managed through a small custom loader [plugins.zsh](https://github.com/houssamouhra/zsh-config/blob/main/.config/zsh/plugins.zsh) that handles installation, loading, updates, and optional deferred loading.

No heavy plugin manager required.

## Prompt

The prompt follows a **Zen-inspired design** with a minimal, clean, and native feel.
It focuses on useful information like the current directory, Git status, and command state without the need for a separate prompt framework.

## Plugins

A small set of focused plugins keeps the shell efficient and practical.

[gitstatus](https://github.com/romkatv/gitstatus) — fast Git status information for the prompt.
[zsh-defer](https://github.com/romkatv/zsh-defer) — defers non-critical plugin initialization to improve startup time.
[ez-compinit](https://github.com/mattmc3/ez-compinit) — lightweight and fast Zsh completion setup.
[zsh-completions](https://github.com/zsh-users/zsh-completions) — additional completion definitions.
[fzf-tab](https://github.com/Aloxaf/fzf-tab) — replaces standard completion menus with an interactive fzf interface.
[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) — suggests commands as you type based on your history.
[zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) — searches through history using the current command line as a substring.
[colored-man-pages](https://github.com/houssamouhra/colored-man-pages) — adds colors to man pages for easier reading.
[zsh-patina](https://github.com/michel-kraemer/zsh-patina) — blazingly fast Zsh syntax highlighter.

## Benchmark

Measured with the shell running interactively using [zsh-bench](https://github.com/romkatv/zsh-bench)

| Metric            |     Result |
| ----------------- | ---------: |
| First prompt lag  | 144.372 ms |
| First command lag | 148.695 ms |
| Command lag       |  26.045 ms |
| Input lag         |   3.743 ms |
| Exit time         | 209.463 ms |

## License

[MIT](./LICENSE)
