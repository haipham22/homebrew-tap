cask "saint" do
  arch arm: "-arm64", intel: "-x64"

  version "1.1.14"
  sha256 arm:          "56a2c7f6bef54ffb2e2019e8d34367822ce4dad40a4e0f0d740622ff9cc2b213",
         intel:        "dbcebbb69e91feb15a61c1f29030e9c1d2589a38b46f203935d925b975457a7b",
         x86_64_linux: "6fe13eaafa950ea2faf666c14bc57388f16258ec73f94af4337d4cfb5a6cdf6e"

  # No linux-arm build upstream; declare it so brew bump stops probing that arch.
  on_linux do
    depends_on arch: :x86_64
  end

  if OS.mac?
    depends_on macos: :ventura
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

    preflight_steps do
      write_file "{{staged_path}}/saint-setup.sh", <<~'SH'
        #!/bin/sh
        set -e
        stage="{{staged_path}}"
        appimage_name="$(find "$stage" -maxdepth 1 -type f -name 'Saint-*.AppImage' -printf '%f\n' | sort -V | tail -n1)"
        [ -n "$appimage_name" ] || exit 1
        appimage="$stage/$appimage_name"
        chmod 0755 "$appimage"
        # Wrapper: extract-and-run avoids the libfuse2 + fusermount dependency
        # (unprivileged userns is blocked on Ubuntu 24.04, so FUSE mounts fail).
        # \$@ is escaped so the inner wrapper keeps its own "$@".
        cat > "{{staged_path}}/saint" <<EOF
        #!/bin/sh
        exec "$appimage" --appimage-extract-and-run --no-sandbox --class=saint --ozone-platform=x11 "\$@"
        EOF
        chmod 0755 "{{staged_path}}/saint"

        # Extract only the icon from the AppImage; unsquashfs is optional, the
        # menu entry falls back to a generic icon without it. The last "hsqs"
        # magic wins: the ELF runtime contains a stray one before the real
        # squashfs superblock.
        if command -v unsquashfs >/dev/null 2>&1; then
          offset="$(grep -abo hsqs "$appimage" | tail -n1 | cut -d: -f1)"
          if unsquashfs -o "$offset" -f -d "{{staged_path}}/icon" "$appimage" \
               "usr/share/icons/hicolor/1024x1024/apps/saint.png" >/dev/null 2>&1; then
            cp "{{staged_path}}/icon/usr/share/icons/hicolor/1024x1024/apps/saint.png" \
               "{{staged_path}}/saint.png"
            rm -rf "{{staged_path}}/icon"
          fi
        fi

        mkdir -p "$HOME/.local/share/applications"
        mkdir -p "$HOME/.local/share/icons/hicolor/1024x1024/apps"
        # Icon=saint resolves via the hicolor theme: the artifact stanza below
        # installs saint.png into ~/.local/share/icons/hicolor/1024x1024/apps.
        # ($HOME inside the brew sandbox is a redirected path, unusable here.)
        cat > "{{staged_path}}/saint.desktop" <<EOF
        [Desktop Entry]
        Name=Saint
        Comment=Saint desktop build
        Exec={{HOMEBREW_PREFIX}}/bin/saint %U
        Icon=saint
        Type=Application
        StartupNotify=true
        StartupWMClass=saint
        Categories=Development;
        MimeType=x-scheme-handler/saint;
        Keywords=saint;agent;ai;
        EOF
      SH
      run "/bin/sh", args: ["{{staged_path}}/saint-setup.sh"], writable_paths: ["{{staged_path}}"]
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
