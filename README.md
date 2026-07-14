# haipham22/homebrew-tap

Personal [Homebrew](https://brew.sh) tap — **Linux casks** for **Ubuntu** and **Steam Deck** (SteamOS).

These are Linux GUI-app casks (VS Code, JetBrains Toolbox, 1Password, Google Antigravity) — the kind of apps that don't run well as Flatpaks. The casks are ported from [ublue-os/homebrew-tap](https://github.com/ublue-os/homebrew-tap) and tuned to also work on plain Ubuntu (not just immutable distros).

> Cask names carry a `-linux` suffix to avoid colliding with the official macOS casks (e.g. `homebrew/cask/jetbrains-toolbox`). macOS users should use the official casks; this tap is Linux-only (`os linux: "linux"`).

## Install

```bash
brew tap haipham22/tap
brew install --cask haipham22/tap/visual-studio-code-linux
brew install --cask haipham22/tap/jetbrains-toolbox-linux
brew install --cask haipham22/tap/1password-gui-linux
brew install --cask haipham22/tap/antigravity-linux
brew install --cask haipham22/tap/antigravity-ide-linux
```

## Casks

| Cask | App | Binary |
|------|-----|--------|
| `visual-studio-code-linux` | Microsoft VS Code | `code` |
| `jetbrains-toolbox-linux` | JetBrains Toolbox | `jetbrains-toolbox` |
| `1password-gui-linux` | 1Password | `1password` |
| `antigravity-linux` | Google Antigravity (hub) | `antigravity` |
| `antigravity-ide-linux` | Google Antigravity IDE | `antigravity-ide` (`agy-ide`) |

## Ubuntu notes (launch crash fix)

On a minimal Ubuntu, these apps may **open then immediately crash** because the bundled runtimes need a few system libraries that SteamOS ships by default. Install them once:

```bash
sudo apt-get install -y libxtst6 libxrender1 libxi6 libxss1 \
  libnss3 libnspr4 libasound2t64 libgbm1 libdrm2 libxkbcommon0 libfontconfig1
```

Electron apps (Antigravity, VS Code) on Ubuntu 24.04 can also hit the AppArmor unprivileged-userns sandbox restriction. If one crashes at startup, either allow user namespaces or launch with `--no-sandbox`.

## Steam Deck notes

SteamOS has a read-only root that resets on every OS update. Install Homebrew under `$HOME` so it survives:

```bash
git clone https://github.com/Homebrew/brew ~/.linuxbrew
eval "$(~/.linuxbrew/bin/brew shellenv)"
```

Add that `eval` line to `~/.bashrc` / `~/.zshrc`, then `brew tap haipham22/tap` and install as above. The casks put desktop entries in `~/.local/share/applications`, which persists across SteamOS updates.

## 1Password install caveat

The `1password-gui-linux` cask runs a `postflight` that needs **sudo** (creates the `onepassword` group, sets the setuid bit on `chrome-sandbox`, installs the polkit policy and browser native-messaging hosts). You'll be prompted for your password. On Steam Deck / immutable OSes, make sure `sudo` works for your user first.

## Auto-updates

A scheduled workflow (`.github/workflows/bump.yml`) runs `brew bump` daily and opens PRs for any cask whose `livecheck` finds a newer upstream version — no PAT needed, it uses the built-in `GITHUB_TOKEN`. Merge the PRs (or enable auto-merge) to land updates.

```bash
brew livecheck --cask haipham22/tap/<name>   # check a single cask manually
```

## Credits

Casks are adapted from [ublue-os/homebrew-tap](https://github.com/ublue-os/homebrew-tap) (Universal Blue). Go star their tap.
