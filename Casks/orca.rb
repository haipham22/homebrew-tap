cask "orca" do
  arch arm: "-arm64", intel: "-x64"

  version "1.4.280"
  sha256 arm:          "3e2dd7fe4c6dc6db227142b16d8f69bdfb5a66ce86746945b12c7c13ef4f9528",
         intel:        "57a926062872137547bc23b135956de412071c6c0f7eaafdd0cbe451a8c52516",
         x86_64_linux: "7fa4d975bdd151787bb12537908464f87695ecc3f1c26cf553220ee86d3c06c2"

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
