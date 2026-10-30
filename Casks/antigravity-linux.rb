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

  preflight_steps do
    # Disable Electron auto-update checks; Homebrew manages this install.
    if_path_exists "{{staged_path}}/Antigravity-x64/resources/app-update.yml" do
      remove "{{staged_path}}/Antigravity-x64/resources/app-update.yml"
    end

    # Extract the app icon from the ASAR package without requiring external tools.
    write_file "{{staged_path}}/antigravity-extract-icon.py", <<~PY
      import json, struct, sys

      asar = open(sys.argv[1], "rb")
      asar.seek(8)
      header_size = struct.unpack("<I", asar.read(4))[0] - 4
      asar.seek(16)
      header = json.loads(asar.read(header_size))
      entry = header.get("files", {}).get("icon.png")
      if entry:
          asar.seek(16 + header_size + int(entry["offset"]))
          open(sys.argv[2], "wb").write(asar.read(int(entry["size"])))
    PY
    if_path_exists "{{staged_path}}/Antigravity-x64/resources/app.asar" do
      run "/usr/bin/python3", args: [
        "{{staged_path}}/antigravity-extract-icon.py",
        "{{staged_path}}/Antigravity-x64/resources/app.asar",
        "{{staged_path}}/antigravity.png",
      ], writable_paths: ["{{staged_path}}"]
    end

    # Create a placeholder icon if extraction fails
    unless_path_exists "{{staged_path}}/antigravity.png" do
      touch "{{staged_path}}/antigravity.png"
    end

    mkdir_p "~/.local/share/applications"
    mkdir_p "~/.local/share/icons/hicolor/512x512/apps"

    write_file "{{staged_path}}/antigravity.desktop", <<~EOS
      [Desktop Entry]
      Name=Antigravity
      Comment=Agent orchestration platform
      GenericName=AI Agent Platform
      Exec="{{HOMEBREW_PREFIX}}/bin/antigravity" %F
      Icon=antigravity
      Type=Application
      StartupNotify=false
      StartupWMClass=Antigravity
      Categories=Development;Utility;
      Keywords=antigravity;agent;ai;
    EOS

    write_file "{{staged_path}}/antigravity-url-handler.desktop", <<~EOS
      [Desktop Entry]
      Name=Antigravity - URL Handler
      Comment=Agent orchestration platform
      GenericName=AI Agent Platform
      Exec="{{HOMEBREW_PREFIX}}/bin/antigravity" "%U"
      Icon=antigravity
      Type=Application
      NoDisplay=true
      Terminal=false
      StartupNotify=true
      StartupWMClass=Antigravity
      Categories=Utility;Development;
      MimeType=x-scheme-handler/antigravity;
      Keywords=antigravity;
    EOS
  end

  postflight_steps do
    # Chromium SUID sandbox: Ubuntu 24.04 blocks unprivileged user namespaces,
    # so Electron can't fall back to the userns sandbox and instead aborts unless
    # chrome-sandbox is owned by root with the setuid bit (mode 4755). SteamOS
    # allows userns, so this is a no-op there. Requires sudo at install time.
    if_path_exists "{{staged_path}}/Antigravity-x64/chrome-sandbox" do
      set_ownership "{{staged_path}}/Antigravity-x64/chrome-sandbox", user: "root", group: "root"
      set_permissions "{{staged_path}}/Antigravity-x64/chrome-sandbox", "4755", recursive: false
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
