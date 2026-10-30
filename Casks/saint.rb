cask "saint" do
  arch arm: "-arm64", intel: "-x64"

  version "1.1.1"
  sha256 arm:          "f07b5a39e9850df3ceb06582c14b3afee4568135aeccd2b07086d0577fbd7c97",
         intel:        "3f52791cba5ce333d84005814005473524af8dfd72e56c0dcd4265312f8d1d0d",
         x86_64_linux: "76143c82af04762609714a5c8e50b5c2310165e21d11247822a150e668838f57"

  if OS.mac?
    url "https://github.com/Locotine/saint-hyper-agent/releases/download/v#{version}/Saint-#{version}#{arch}.dmg"
    app "Saint.app"
    zap trash: [
      "~/Library/Application Support/Saint",
      "~/Library/Caches/Saint",
      "~/Library/Preferences/com.locotine.saint.plist",
      "~/Library/Saved Application State/com.locotine.saint.savedState",
    ]
  else
    os linux: "linux"
    url "https://github.com/Locotine/saint-hyper-agent/releases/download/v#{version}/Saint-#{version}-x86_64.AppImage"
    binary "saint"
    artifact "saint.png",
             target: "#{Dir.home}/.local/share/icons/hicolor/1024x1024/apps/saint.png"
    artifact "saint.desktop",
             target: "#{Dir.home}/.local/share/applications/saint.desktop"

    preflight do
      appimage = "#{staged_path}/Saint-#{version}-x86_64.AppImage"
      FileUtils.chmod 0755, appimage
      # Wrapper: extract-and-run avoids the libfuse2 + fusermount dependency
      # (unprivileged userns is blocked on Ubuntu 24.04, so FUSE mounts fail).
      File.write("#{staged_path}/saint", <<~EOS)
        #!/bin/sh
        exec "#{appimage}" --appimage-extract-and-run --no-sandbox "$@"
      EOS
      FileUtils.chmod 0755, "#{staged_path}/saint"

      # Extract only the icon from the AppImage. unsquashfs avoids running the
      # AppImage at install time. rindex finds the real squashfs superblock:
      # the ELF runtime contains a stray "hsqs" earlier in the file, so a plain
      # index() would land on the wrong offset.
      offset = File.open(appimage, "rb") do |f|
        data = f.read(512_000)
        data.rindex("hsqs") || raise("squashfs offset not found")
      end
      system "unsquashfs", "-o", offset.to_s, "-f", "-d", "#{staged_path}/icon",
             appimage, "usr/share/icons/hicolor/1024x1024/apps/saint.png"
      FileUtils.cp "#{staged_path}/icon/usr/share/icons/hicolor/1024x1024/apps/saint.png",
                   "#{staged_path}/saint.png"
      FileUtils.rm_r("#{staged_path}/icon")

      FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
      FileUtils.mkdir_p "#{Dir.home}/.local/share/icons/hicolor/1024x1024/apps"
      File.write("#{staged_path}/saint.desktop", <<~EOS)
        [Desktop Entry]
        Name=Saint
        Comment=Saint desktop build
        Exec=#{HOMEBREW_PREFIX}/bin/saint %U
        Icon=#{Dir.home}/.local/share/icons/hicolor/1024x1024/apps/saint.png
        Type=Application
        StartupNotify=true
        StartupWMClass=saint
        Categories=Development;
        MimeType=x-scheme-handler/saint;
        Keywords=saint;agent;ai;
      EOS
    end

    zap trash: [
      "~/.config/Saint",
      "~/.saint",
    ]
  end

  name "Saint"
  desc "Focused workspace for coding agents"
  homepage "https://github.com/Locotine/saint-hyper-agent"

  livecheck do
    url "https://github.com/Locotine/saint-hyper-agent/releases/latest"
    strategy :github_latest
  end

  auto_updates true
end
