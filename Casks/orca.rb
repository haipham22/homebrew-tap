cask "orca" do
  arch arm: "-arm64", intel: "-x64"

  version "1.4.253"
  sha256 arm:          "26794e3138006e063506e5fbbc0597cfd9df2d060bd7bc1e2c66bf89896c1900",
         intel:        "e93bfc5a8288deb5662a47ed1d82a6c62a87e65f912f0fbed0a2d25012c887eb",
         x86_64_linux: "fce9baedb617c03dde941c6a4408d5bab92d17d2bed1def4015ddbd8fa74efdc"

  # No linux-arm build upstream; declare it so brew bump stops probing that arch.
  on_linux do
    depends_on arch: :x86_64
  end

  if OS.mac?
    depends_on macos: :monterey
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

    preflight_steps do
      write_file "{{staged_path}}/orca-setup.sh", <<~'SH'
        #!/bin/sh
        set -e
        appimage="{{staged_path}}/orca-linux.AppImage"
        chmod 0755 "$appimage"
        # Wrapper: extract-and-run avoids the libfuse2 + fusermount dependency
        # (unprivileged userns is blocked on Ubuntu 24.04, so FUSE mounts fail).
        # \$@ is escaped so the inner wrapper keeps its own "$@".
        cat > "{{staged_path}}/orca-ide" <<EOF
        #!/bin/sh
        exec "$appimage" --appimage-extract-and-run --no-sandbox "\$@"
        EOF
        chmod 0755 "{{staged_path}}/orca-ide"

        # Extract only the icon from the AppImage; unsquashfs is optional, the
        # menu entry falls back to a generic icon without it. The last "hsqs"
        # magic wins: the ELF runtime contains a stray one before the real
        # squashfs superblock.
        if command -v unsquashfs >/dev/null 2>&1; then
          offset="$(grep -abo hsqs "$appimage" | tail -n1 | cut -d: -f1)"
          if unsquashfs -o "$offset" -f -d "{{staged_path}}/icon" "$appimage" \
               "usr/share/icons/hicolor/512x512/apps/orca-ide.png" >/dev/null 2>&1; then
            cp "{{staged_path}}/icon/usr/share/icons/hicolor/512x512/apps/orca-ide.png" \
               "{{staged_path}}/orca-ide.png"
            rm -rf "{{staged_path}}/icon"
          fi
        fi

        mkdir -p "$HOME/.local/share/applications"
        mkdir -p "$HOME/.local/share/icons/hicolor/512x512/apps"
        # Icon=orca-ide resolves via the hicolor theme: the artifact stanza
        # below installs orca-ide.png into ~/.local/share/icons/hicolor/512x512/apps.
        # ($HOME inside the brew sandbox is a redirected path, unusable here.)
        cat > "{{staged_path}}/orca.desktop" <<EOF
        [Desktop Entry]
        Name=Orca
        Comment=Next-gen IDE for parallel agentic development
        Exec={{HOMEBREW_PREFIX}}/bin/orca-ide %U
        Icon=orca-ide
        Type=Application
        StartupNotify=true
        StartupWMClass=orca
        Categories=Development;IDE;
        MimeType=x-scheme-handler/orca;
        Keywords=orca;ide;agent;ai;
        EOF
      SH
      run "/bin/sh", args: ["{{staged_path}}/orca-setup.sh"], writable_paths: ["{{staged_path}}"]
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
