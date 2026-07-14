cask "teams-for-linux" do
  os linux: "linux"

  version "2.11.1"
  sha256 "6baec9f22bdd57e5d38ef054b0d609e52baa2354ca3732e281716856a6361e26"

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

  preflight do
    app_root = "#{staged_path}/teams-for-linux-#{version}"
    # Disable Electron auto-update; Homebrew manages this install.
    FileUtils.rm_f "#{app_root}/resources/app-update.yml"

    FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
    # ponytail: Icon is name-based; the bundled icon lives inside app.asar.
    # Extract it from app.asar later if a themed menu icon is wanted.
    File.write("#{staged_path}/teams-for-linux.desktop", <<~EOS)
      [Desktop Entry]
      Name=Teams for Linux
      Comment=Unofficial Microsoft Teams client for Linux
      Exec=#{HOMEBREW_PREFIX}/bin/teams-for-linux %U
      Icon=teams-for-linux
      Type=Application
      StartupNotify=true
      StartupWMClass=teams-for-linux
      Categories=Chat;Network;InstantMessaging;
      MimeType=x-scheme-handler/msteams;
      Keywords=teams;microsoft;
    EOS
  end

  postflight do
    # Chromium SUID sandbox: Ubuntu 24.04 blocks unprivileged userns, so
    # Electron needs chrome-sandbox owned by root with mode 4755 or it aborts
    # on launch. No-op on SteamOS. Requires sudo at install time.
    sandbox = "#{staged_path}/teams-for-linux-#{version}/chrome-sandbox"
    if File.exist?(sandbox)
      system "sudo", "chown", "root:root", sandbox
      system "sudo", "chmod", "4755", sandbox
    end
  end

  zap trash: [
    "~/.config/Teams for Linux",
    "~/.config/teams-for-linux",
  ]
end
