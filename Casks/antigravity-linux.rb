cask "antigravity-linux" do
  os linux: "linux"

  version "2.0.6,5413878570549248"
  sha256 "ad1e04535149b07c27030eb1ead40f4efda388cb39020bcbb9accdfb49e44cc5"

  url "https://storage.googleapis.com/antigravity-public/antigravity-hub/#{version.csv.first}-#{version.csv.second}/linux-x64/Antigravity.tar.gz",
      verified: "storage.googleapis.com/antigravity-public/antigravity-hub/"
  name "Google Antigravity"
  desc "Agent orchestration platform"
  homepage "https://antigravity.google/product/antigravity-2"

  livecheck do
    url "https://antigravity-auto-updater-974169037036.us-central1.run.app/api/update/linux-x64/stable/latest"
    regex(%r{/antigravity-hub/([^/]+)/}i)
    strategy :json do |json, regex|
      match = json["url"]&.match(regex)
      next if match.blank?

      match[1]&.tr("-", ",").to_s
    end
  end

  binary "#{staged_path}/Antigravity-x64/antigravity"
  artifact "antigravity.desktop",
           target: "#{Dir.home}/.local/share/applications/antigravity.desktop"
  artifact "antigravity-url-handler.desktop",
           target: "#{Dir.home}/.local/share/applications/antigravity-url-handler.desktop"
  artifact "antigravity.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/antigravity.png"

  preflight do
    app_root = "#{staged_path}/Antigravity-x64"
    app_update_yml = "#{app_root}/resources/app-update.yml"
    asar_path = "#{app_root}/resources/app.asar"

    FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
    FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/512x512/apps"

    # Disable Electron auto-update checks; Homebrew manages this install.
    FileUtils.rm app_update_yml

    # Extract the app icon from the ASAR package without requiring external tools.
    if File.exist?(asar_path)
      File.open(asar_path, "rb") do |asar|
        asar.seek(8)
        header_size = asar.read(4).unpack1("V") - 4
        asar.seek(16)
        header = JSON.parse(asar.read(header_size))
        icon_entry = header.dig("files", "icon.png")

        if icon_entry
          asar.seek(16 + header_size + icon_entry["offset"].to_i)
          File.binwrite("#{staged_path}/antigravity.png", asar.read(icon_entry["size"]))
        end
      end
    end

    File.write("#{staged_path}/antigravity.desktop", <<~EOS)
      [Desktop Entry]
      Name=Antigravity
      Comment=Agent orchestration platform
      GenericName=AI Agent Platform
      Exec="#{HOMEBREW_PREFIX}/bin/antigravity" %F
      Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/antigravity.png
      Type=Application
      StartupNotify=false
      StartupWMClass=Antigravity
      Categories=Development;Utility;
      Keywords=antigravity;agent;ai;
    EOS

    File.write("#{staged_path}/antigravity-url-handler.desktop", <<~EOS)
      [Desktop Entry]
      Name=Antigravity - URL Handler
      Comment=Agent orchestration platform
      GenericName=AI Agent Platform
      Exec="#{HOMEBREW_PREFIX}/bin/antigravity" "%U"
      Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/antigravity.png
      Type=Application
      NoDisplay=true
      Terminal=false
      StartupNotify=true
      StartupWMClass=Antigravity
      Categories=Utility;Development;
      MimeType=x-scheme-handler/antigravity;
      Keywords=antigravity;
    EOS

    # Create a placeholder icon if extraction fails
    FileUtils.touch "#{staged_path}/antigravity.png" unless File.exist?("#{staged_path}/antigravity.png")
  end

  postflight do
    # Chromium SUID sandbox: Ubuntu 24.04 blocks unprivileged user namespaces,
    # so Electron can't fall back to the userns sandbox and instead aborts unless
    # chrome-sandbox is owned by root with the setuid bit (mode 4755). SteamOS
    # allows userns, so this is a no-op there. Requires sudo at install time.
    sandbox = "#{staged_path}/Antigravity-x64/chrome-sandbox"
    if File.exist?(sandbox)
      system "sudo", "chown", "root:root", sandbox
      system "sudo", "chmod", "4755", sandbox
    end
  end

  zap trash: [
    "~/.antigravity",
    "~/.config/Antigravity",
    "~/.config/antigravity",
    "~/.gemini/antigravity",
  ]

  caveats <<~EOS
    Installing this cask runs `sudo` once to set the setuid bit on the bundled
    chrome-sandbox (required to launch on Ubuntu). You will be prompted for your
    password.

    If authentication fails or the browser doesn't open Antigravity, try running:
      xdg-mime default antigravity-url-handler.desktop x-scheme-handler/antigravity
      update-desktop-database ~/.local/share/applications
  EOS
end
