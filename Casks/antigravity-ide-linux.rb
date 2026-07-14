cask "antigravity-ide-linux" do
  os linux: "linux"

  version "2.1.1,6123990880747520"
  sha256 "5b2cebf7d33a68d003fd8f1fa988d1600905ace22504a085e5384214290878bd"

  url "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/#{version.csv.first}-#{version.csv.second}/linux-x64/Antigravity%20IDE.tar.gz",
      verified: "edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/"
  name "Google Antigravity IDE"
  desc "AI Coding Agent IDE"
  homepage "https://antigravity.google/product/antigravity-ide"

  livecheck do
    url "https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/api/update/linux-x64/stable/latest"
    regex(%r{/stable/([^/]+)/}i)
    strategy :json do |json, regex|
      match = json["url"]&.match(regex)
      next if match.blank?

      match[1]&.tr("-", ",").to_s
    end
  end

  binary "#{staged_path}/Antigravity IDE/bin/antigravity-ide"
  binary "#{staged_path}/Antigravity IDE/bin/antigravity-ide", target: "agy-ide"
  bash_completion "#{staged_path}/Antigravity IDE/resources/completions/bash/antigravity-ide"
  zsh_completion  "#{staged_path}/Antigravity IDE/resources/completions/zsh/_antigravity-ide"
  artifact "antigravity-ide.desktop",
           target: "#{Dir.home}/.local/share/applications/antigravity-ide.desktop"
  artifact "antigravity-ide-url-handler.desktop",
           target: "#{Dir.home}/.local/share/applications/antigravity-ide-url-handler.desktop"
  artifact "Antigravity IDE/resources/app/resources/linux/code.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/antigravity-ide.png"

  preflight do
    product_json = "#{staged_path}/Antigravity IDE/resources/app/product.json"
    if File.exist?(product_json)
      product = JSON.parse(File.read(product_json))
      product.delete("updateUrl")
      product["configurationDefaults"] ||= {}
      product["configurationDefaults"]["update.mode"] = "none"
      File.write(product_json, JSON.pretty_generate(product))
    end

    FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
    FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/512x512/apps"

    File.write("#{staged_path}/antigravity-ide.desktop", <<~EOS)
      [Desktop Entry]
      Name=Antigravity IDE
      Comment=AI Coding Agent IDE
      GenericName=Text Editor
      Exec="#{HOMEBREW_PREFIX}/bin/antigravity-ide" %F
      Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/antigravity-ide.png
      Type=Application
      StartupNotify=false
      StartupWMClass=Antigravity IDE
      Categories=TextEditor;Development;IDE;
      MimeType=text/plain;inode/directory;application/x-code-workspace;x-scheme-handler/antigravity-ide;
      Actions=new-empty-window;
      Keywords=antigravity;code;editor;ai;

      [Desktop Action new-empty-window]
      Name=New Empty Window
      Exec="#{HOMEBREW_PREFIX}/bin/antigravity-ide" --new-window %F
      Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/antigravity-ide.png
    EOS

    File.write("#{staged_path}/antigravity-ide-url-handler.desktop", <<~EOS)
      [Desktop Entry]
      Name=Antigravity IDE - URL Handler
      Comment=AI Coding Agent IDE
      GenericName=Text Editor
      Exec="#{HOMEBREW_PREFIX}/bin/antigravity-ide" --open-url "%U"
      Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/antigravity-ide.png
      Type=Application
      NoDisplay=true
      Terminal=false
      StartupNotify=true
      StartupWMClass=Antigravity IDE
      Categories=Utility;TextEditor;Development;IDE;
      MimeType=x-scheme-handler/antigravity-ide;
      Keywords=antigravity;code;editor;ai;
    EOS
  end

  postflight do
    # Chromium SUID sandbox: see antigravity-linux. Ubuntu 24.04 blocks
    # unprivileged userns, so Electron needs chrome-sandbox owned by root
    # with mode 4755 or it aborts on launch. No-op on SteamOS.
    app_root = "#{staged_path}/Antigravity IDE"
    sandbox = ["#{app_root}/chrome-sandbox", "#{app_root}/bin/chrome-sandbox"]
              .find { |p| File.exist?(p) }
    if sandbox
      system "sudo", "chown", "root:root", sandbox
      system "sudo", "chmod", "4755", sandbox
    end
  end

  zap trash: [
    "~/.antigravity-ide",
    "~/.antigravity-ide-server",
    "~/.config/Antigravity IDE",
    "~/.config/antigravity-ide",
    "~/.gemini/antigravity-ide",
  ]

  caveats <<~EOS
    Installing this cask runs `sudo` once to set the setuid bit on the bundled
    chrome-sandbox (required to launch on Ubuntu). You will be prompted for your
    password.

    If authentication fails or the browser doesn't open Antigravity IDE, try running:
      xdg-mime default antigravity-ide-url-handler.desktop x-scheme-handler/antigravity-ide
      update-desktop-database ~/.local/share/applications
  EOS
end
