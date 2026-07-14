# haipham22/homebrew-tap

Personal [Homebrew](https://brew.sh) tap — Linux-first formulae for **Ubuntu** and **Steam Deck** (SteamOS).

## Install

```bash
brew tap haipham22/tap
brew install haipham22/tap/jetbrains-toolbox
```

Then launch `jetbrains-toolbox`. The app self-updates after first run.

> **Why the fully-qualified name?** There's an official macOS cask also called `jetbrains-toolbox` (`homebrew/cask/jetbrains-toolbox`). The bare name `brew install jetbrains-toolbox` resolves to that cask and fails on Linux with *"This cask requires macOS."* Qualifying with `haipham22/tap/jetbrains-toolbox` (or passing `--formula`) picks this Linux formula instead.

## Formulae

| Name | What |
|------|------|
| [`jetbrains-toolbox`](./Formula/jetbrains-toolbox.rb) | JetBrains Toolbox App (Linux x86_64 / arm64) |

> **macOS:** JetBrains Toolbox already has an official cask — run `brew install --cask jetbrains-toolbox`. This tap's formula is Linux-only (`depends_on :linux`).

## Steam Deck notes

SteamOS has a read-only root that resets on every OS update. Install Homebrew under `$HOME` so it survives updates:

```bash
# one-time Homebrew install (do NOT use the default /usr/local prefix here)
git clone https://github.com/Homebrew/brew ~/.linuxbrew
eval "$(~/.linuxbrew/bin/brew shellenv)"
brew tap haipham22/tap
brew install jetbrains-toolbox
```

Add the `eval "$(~/.linuxbrew/bin/brew shellenv)"` line to `~/.bashrc` / `~/.zshrc` so `brew` is on `PATH` after reboot.

## Updating a formula

```bash
brew livecheck haipham22/tap/jetbrains-toolbox      # show latest vs. pinned
brew bump-formula-pr haipham22/tap/jetbrains-toolbox  # or edit Formula/*.rb and bump version + sha256 by hand
```
