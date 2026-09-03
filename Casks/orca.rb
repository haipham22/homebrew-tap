cask "orca" do
  os linux: "linux"

  version "1.4.195"
  sha256 "6fbb4b9b46e2ce06406df96ce1c835543ded13dd011820d6b88b3a152897b814"

  url "https://github.com/stablyai/orca/releases/download/v#{version}/orca-linux.AppImage"
  name "Orca"
  desc "Next-gen IDE for parallel agentic development"
  homepage "https://github.com/stablyai/orca"

  livecheck do
    url "https://github.com/stablyai/orca/releases/latest"
    strategy :github_latest
  end

  binary "orca-linux.AppImage", target: "orca"
  artifact "orca-ide.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/orca-ide.png"
  artifact "orca.desktop",
           target: "#{Dir.home}/.local/share/applications/orca.desktop"

  preflight do
    # Extract only the icon from the AppImage (offset = first hsqs magic past
    # the ELF headers). unsquashfs avoids running the AppImage at install time.
    offset = File.open("#{staged_path}/orca-linux.AppImage", "rb") do |f|
      data = f.read(512_000)
      data.index("hsqs", 186_344) or raise "squashfs offset not found"
    end
    system "unsquashfs", "-o", offset.to_s, "-f", "-d", "#{staged_path}/icon",
           "#{staged_path}/orca-linux.AppImage",
           "usr/share/icons/hicolor/512x512/apps/orca-ide.png"
    FileUtils.cp "#{staged_path}/icon/usr/share/icons/hicolor/512x512/apps/orca-ide.png",
                 "#{staged_path}/orca-ide.png"
    FileUtils.rm_rf "#{staged_path}/icon"

    FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
    FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/512x512/apps"
    File.write("#{staged_path}/orca.desktop", <<~EOS)
      [Desktop Entry]
      Name=Orca
      Comment=Next-gen IDE for parallel agentic development
      Exec=#{HOMEBREW_PREFIX}/bin/orca --no-sandbox %U
      Icon=#{Dir.home}/.local/share/icons/hicolor/512x512/apps/orca-ide.png
      Type=Application
      StartupNotify=true
      StartupWMClass=orca
      Categories=Development;IDE;
      MimeType=x-scheme-handler/orca;
      Keywords=orca;ide;agent;ai;
    EOS
  end

  zap trash: [
    "~/.config/Orca",
    "~/.local/share/orca",
  ]
end
