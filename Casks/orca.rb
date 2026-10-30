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
