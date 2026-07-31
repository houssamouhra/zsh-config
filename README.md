# Zsh Config

A modular, lightweight, and performance-focused Zsh configuration built for my workflow as a software engineer.

## Philosophy

Every part of the configuration has a purpose, with functionality split into focused modules rather than relying on a large framework.

## Plugin Management

Plugins are managed through a small custom loader [plugins.zsh](https://github.com/houssamouhra/zsh-config/blob/main/.config/zsh/plugins.zsh) that handles installation, loading, updates, and optional deferred loading.

No heavy plugin manager required.

## Prompt

The prompt follows a Zen-inspired design that is minimal, clean, and native.

It focuses on useful information such as the current directory with smart path truncation, Git status, and command state without relying on a separate prompt framework like [Starship](https://github.com/starship/starship) or [Powerlevel10k](https://github.com/romkatv/powerlevel10k)

## Plugins

A small set of focused plugins keeps the shell efficient and practical.

- [gitstatus](https://github.com/romkatv/gitstatus) — fast Git status information for the prompt.
- [zsh-defer](https://github.com/romkatv/zsh-defer) — defers non-critical plugin initialization to improve startup time.
- [ez-compinit](https://github.com/mattmc3/ez-compinit) — lightweight and fast Zsh completion setup.
- [zsh-completions](https://github.com/zsh-users/zsh-completions) — additional completion definitions.
- [fzf-tab](https://github.com/Aloxaf/fzf-tab) — replaces standard completion menus with an interactive fzf interface.
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) — suggests commands as you type based on your history.
- [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) — searches history by substring.
- [colored-man-pages](https://github.com/houssamouhra/colored-man-pages) — adds colors to man pages for easier reading.
- [zsh-patina](https://github.com/michel-kraemer/zsh-patina) — blazingly fast Zsh syntax highlighter.

## Benchmark

Measured with the shell running interactively using [zsh-bench](https://github.com/romkatv/zsh-bench)

| Metric            |     Result |
| ----------------- | ---------: |
| First prompt lag  |109.829 ms |
| First command lag |112.493 ms |
| Command lag       |  16.707 ms |
| Input lag         |   3.332 ms |
| Exit time         | 105.280 ms |

## License

[MIT](./LICENSE)
