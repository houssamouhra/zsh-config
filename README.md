# Zsh Config

A modular, lightweight, and performance-focused Zsh configuration built for my workflow as a software engineer.

## Philosophy

Speed and simplicity first.

No frameworks. No bloat.

The configuration is fully modular, deliberately minimal, and built so that every piece has a clear reason to exist.

## Features

- **Modular configuration**  
  Split into focused modules (`prompt`, `history`, `keybinds`, `aliases`, `fzf`, `functions`) for easy maintenance.

- **Fast startup**  
  Deferred plugin loading (`zsh-defer`), cached completions (`ez-compinit`), and a non-blocking prompt. First prompt appears in ~17 ms.

- **Minimal native prompt**  
  Smart path truncation, real-time Git status, command duration, and command state. No external prompt frameworks.

- **Enhanced completions**  
  Interactive `fzf-tab` menu with extra completions from `zsh-completions`.

- **Smart history**  
  Substring search, history-based autosuggestions, and optimized history settings.

- **Quality-of-life features**  
  Syntax highlighting (`zsh-patina`), colored man pages, useful aliases, custom functions, and thoughtful keybindings.

- **Lightweight by design**  
  No Oh My Zsh, no heavy plugin managers. Just a [minimal custom loader](https://github.com/houssamouhra/zsh-config/blob/main/.config/zsh/plugins.zsh), lazy-loaded functionality, and a carefully chosen set of plugins.

## Plugins

A small set of focused plugins keeps the shell efficient and practical.

- [gitstatus](https://github.com/romkatv/gitstatus) — extremely fast Git status for the prompt
- [zsh-defer](https://github.com/romkatv/zsh-defer) — defers non-critical plugins to improve startup time
- [ez-compinit](https://github.com/mattmc3/ez-compinit) — lightweight and fast completion initialization
- [zsh-completions](https://github.com/zsh-users/zsh-completions) — additional completion definitions
- [fzf-tab](https://github.com/Aloxaf/fzf-tab) — interactive fzf completion menu
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) — fish-like history-based suggestions
- [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) — search history by substring
- [colored-man-pages](https://github.com/houssamouhra/colored-man-pages) — colored man pages
- [zsh-patina](https://github.com/michel-kraemer/zsh-patina) — fast syntax highlighting

## Benchmark

Measured interactively **on login** with [zsh-bench](https://github.com/romkatv/zsh-bench):

| Metric              | Result     |
|---------------------|-----------:|
| First prompt lag    | 16.963 ms  |
| First command lag   | 17.380 ms  |
| Command lag         | 13.187 ms  |
| Input lag           |  3.318 ms  |
| Exit time           | 15.100 ms  |

## License

[MIT](./LICENSE)
