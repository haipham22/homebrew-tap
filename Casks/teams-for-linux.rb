cask "teams-for-linux" do
  os linux: "linux"

  version "2.32.0"
  sha256 "b42232e7d6c7682ac7f438e6935cc6121aeb93d01ee8a2f0743f82c920b15a82"

  url "https://github.com/IsmaelMartinez/teams-for-linux/releases/download/v#{version}/teams-for-linux-#{version}.tar.gz"
  name "Teams for Linux"
  desc "Unofficial Microsoft Teams client for Linux"
  homepage "https://github.com/IsmaelMartinez/teams-for-linux"

  livecheck do
    url "https://github.com/IsmaelMartinez/teams-for-linux/releases/latest"
    strategy :github_latest
  end

  binary "teams-for-linux-#{version}/teams-for-linux"
  artifact "teams-for-linux.desktop",
           target: "#{Dir.home}/.local/share/applications/teams-for-linux.desktop"

  preflight_steps do
    # Disable Electron auto-update; Homebrew manages this install.
    if_path_exists "{{staged_path}}/teams-for-linux-{{version}}/resources/app-update.yml" do
      remove "{{staged_path}}/teams-for-linux-{{version}}/resources/app-update.yml"
    end

    mkdir_p "~/.local/share/applications"
    # ponytail: Icon is name-based; the bundled icon lives inside app.asar.
    # Extract it from app.asar later if a themed menu icon is wanted.
    write_file "{{staged_path}}/teams-for-linux.desktop", <<~EOS
      [Desktop Entry]
      Name=Teams for Linux
      Comment=Unofficial Microsoft Teams client for Linux
      Exec={{HOMEBREW_PREFIX}}/bin/teams-for-linux %U
      Icon=teams-for-linux
      Type=Application
      StartupNotify=true
      StartupWMClass=teams-for-linux
      Categories=Chat;Network;InstantMessaging;
      MimeType=x-scheme-handler/msteams;
      Keywords=teams;microsoft;
    EOS
  end

  postflight_steps do
    # Chromium SUID sandbox: Ubuntu 24.04 blocks unprivileged userns, so
    # Electron needs chrome-sandbox owned by root with mode 4755 or it aborts
    # on launch. No-op on SteamOS. Requires sudo at install time.
    if_path_exists "{{staged_path}}/teams-for-linux-{{version}}/chrome-sandbox" do
      set_ownership "{{staged_path}}/teams-for-linux-{{version}}/chrome-sandbox", user: "root", group: "root"
      set_permissions "{{staged_path}}/teams-for-linux-{{version}}/chrome-sandbox", "4755", recursive: false
    end
  end

  zap trash: [
    "~/.config/Teams for Linux",
    "~/.config/teams-for-linux",
  ]
end
