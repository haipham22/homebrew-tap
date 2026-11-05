cask "neovim" do
  arch arm: "-arm64", intel: "-x86_64"

  version "0.12.6"
  sha256 arm:          "1dbd148222b051ba6c307c4d17a318ed083df018a4f6a5a0ce46955ffc9ab87b",
         intel:        "481424f1dbc85f637d57e47d27d042aa9c883e5a4fe9ee64fc4ee9573b221998",
         x86_64_linux: "474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87"

  # Match this tap's Linux support; upstream also publishes Linux ARM64.
  on_linux do
    depends_on arch: :x86_64
  end

  name "Neovim"
  desc "Vim-fork focused on extensibility and agility"
  homepage "https://neovim.io/"

  if OS.mac?
    depends_on :macos
    url "https://github.com/neovim/neovim/releases/download/v#{version}/nvim-macos#{arch}.tar.gz"
    binary "nvim-macos#{arch}/bin/nvim"
    manpage "nvim-macos#{arch}/share/man/man1/nvim.1"
  else
    os linux: "linux"
    url "https://github.com/neovim/neovim/releases/download/v#{version}/nvim-linux-x86_64.tar.gz"
    binary "nvim-linux-x86_64/bin/nvim"
    manpage "nvim-linux-x86_64/share/man/man1/nvim.1"
  end

  livecheck do
    url "https://github.com/neovim/neovim/releases/latest"
    strategy :github_latest
  end

  zap trash: [
    "~/.cache/nvim",
    "~/.config/nvim",
    "~/.local/share/nvim",
  ]
end
