cask "fmess" do
  os linux: "linux"

  version "0.1.33"
  sha256 "2205f4c02e6ed21fdd961001e6f271a38378387d46ceb630252b4f8970ca6ec8"

  url "https://github.com/toanbku/fmess/releases/download/v#{version}/fMess_#{version}_amd64.AppImage"
  name "fMess"
  desc "Desktop app for Facebook Messenger"
  homepage "https://github.com/toanbku/fmess"

  livecheck do
    url "https://github.com/toanbku/fmess/releases/latest"
    strategy :github_latest
  end

  auto_updates true

  binary "fmess"
  artifact "fmess.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/256x256/apps/fmess.png"
  artifact "fmess.desktop",
           target: "#{Dir.home}/.local/share/applications/fmess.desktop"

  preflight_steps do
    write_file "{{staged_path}}/fmess-setup.sh", <<~'SH'
      #!/bin/sh
      set -e
      appimage_name="$(find "{{staged_path}}" -maxdepth 1 -type f -name 'fMess_*.AppImage' -printf '%f\n' | sort -V | tail -n1)"
      [ -n "$appimage_name" ] || exit 1
      appimage="{{staged_path}}/$appimage_name"
      chmod 0755 "$appimage"
      cat > "{{staged_path}}/fmess" <<EOF
      #!/bin/sh
      export GDK_BACKEND=x11
      exec "$appimage" --appimage-extract-and-run --class=fmess --name=fmess "\$@"
      EOF
      chmod 0755 "{{staged_path}}/fmess"

      if command -v unsquashfs >/dev/null 2>&1; then
        offset="$(grep -abo hsqs "$appimage" | tail -n1 | cut -d: -f1)"
        if unsquashfs -o "$offset" -f -d "{{staged_path}}/icon" "$appimage" \
             fMess.png >/dev/null 2>&1; then
          cp "{{staged_path}}/icon/fMess.png" "{{staged_path}}/fmess.png"
          rm -rf "{{staged_path}}/icon"
        fi
      fi

      mkdir -p "$HOME/.local/share/applications"
      mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"
      cat > "{{staged_path}}/fmess.desktop" <<EOF
      [Desktop Entry]
      Name=fMess
      Comment=Desktop app for Facebook Messenger
      Exec={{HOMEBREW_PREFIX}}/bin/fmess %U
      Icon=fmess
      Type=Application
      StartupNotify=true
      StartupWMClass=fmess
      Categories=Network;InstantMessaging;
      EOF
    SH
    run "/bin/sh", args: ["{{staged_path}}/fmess-setup.sh"], writable_paths: ["{{staged_path}}"]
  end

  zap trash: [
    "~/.cache/io.github.toanbku.fmess",
    "~/.config/io.github.toanbku.fmess",
    "~/.local/share/io.github.toanbku.fmess",
  ]
end
