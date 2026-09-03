cask "orca" do
  arch arm: "-arm64", intel: "-x64"

  version "1.4.196"
  sha256 arm:          "0890987a40d7307e86efba5d3cb853ad77844962e6cef65f93e8b604bb7d2e9f",
         intel:        "bc37fca76ef0db34a5c8db1d83d61e242d1c13145ae0d1d8e0f8357d77b7b10e",
         x86_64_linux: "9abb595010afba8922b4a9e92fab99827ee43e97c1e14acbf6a6c2738aa9e12e"

  if OS.mac?
    url "https://github.com/stablyai/orca/releases/download/v#{version}/orca-macos#{arch}.dmg"
    app "Orca.app"
    zap trash: [
      "~/Library/Application Support/Orca",
      "~/Library/Caches/Orca",
      "~/Library/Preferences/com.stablyai.orca.plist",
      "~/Library/Saved Application State/com.stablyai.orca.savedState",
    ]
  else
    os linux: "linux"
    url "https://github.com/stablyai/orca/releases/download/v#{version}/orca-linux.AppImage"
    binary "orca-ide"
    artifact "orca-ide.png",
             target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/orca-ide.png"
    artifact "orca.desktop",
             target: "#{Dir.home}/.local/share/applications/orca.desktop"

    preflight do
      appimage = "#{staged_path}/orca-linux.AppImage"
      FileUtils.chmod 0755, appimage
      # Wrapper: extract-and-run avoids the libfuse2 + fusermount dependency
      # (unprivileged userns is blocked on Ubuntu 24.04, so FUSE mounts fail).
      File.write("#{staged_path}/orca-ide", <<~EOS)
        #!/bin/sh
        exec "#{appimage}" --appimage-extract-and-run --no-sandbox "$@"
      EOS
      FileUtils.chmod 0755, "#{staged_path}/orca-ide"

      # Extract only the icon from the AppImage (offset = first hsqs magic past
      # the ELF headers). unsquashfs avoids running the AppImage at install time.
      offset = File.open(appimage, "rb") do |f|
        data = f.read(512_000)
        data.index("hsqs", 186_344) || raise("squashfs offset not found")
      end
      system "unsquashfs", "-o", offset.to_s, "-f", "-d", "#{staged_path}/icon",
             appimage, "usr/share/icons/hicolor/512x512/apps/orca-ide.png"
      FileUtils.cp "#{staged_path}/icon/usr/share/icons/hicolor/512x512/apps/orca-ide.png",
                   "#{staged_path}/orca-ide.png"
      FileUtils.rm_r("#{staged_path}/icon")

      FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
      FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/512x512/apps"
      File.write("#{staged_path}/orca.desktop", <<~EOS)
        [Desktop Entry]
        Name=Orca
        Comment=Next-gen IDE for parallel agentic development
        Exec=#{HOMEBREW_PREFIX}/bin/orca-ide %U
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

  name "Orca"
  desc "Next-gen IDE for parallel agentic development"
  homepage "https://github.com/stablyai/orca"

  livecheck do
    url "https://github.com/stablyai/orca/releases/latest"
    strategy :github_latest
  end

  auto_updates true
end
