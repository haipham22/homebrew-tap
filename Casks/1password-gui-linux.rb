cask "1password-gui-linux" do
  os linux: "linux"

  version "8.12.42"
  sha256 "2ce64d1bd53dd6fd4408739a079d10be01aff35cb4e8eaeca3dc9b7c6a8418de"

  arch_suffix = "x64"

  url "https://downloads.1password.com/linux/tar/stable/x86_64/1password-#{version}.#{arch_suffix}.tar.gz"
  name "1Password"
  desc "Password manager that keeps all passwords secure behind one password"
  homepage "https://1password.com/"

  livecheck do
    url "https://releases.1password.com/linux/stable/index.xml"
    regex(/v?(\d+(?:\.\d+)+)/i)
    strategy :xml do |xml, regex|
      xml.get_elements("rss//channel//item//link").map { |item| item.text[regex, 1] }
    end
  end

  binary "1password-#{version}.#{arch_suffix}/1password", target: "1password"
  binary "1password-#{version}.#{arch_suffix}/op-ssh-sign", target: "op-ssh-sign"
  binary "1password-#{version}.#{arch_suffix}/1Password-BrowserSupport", target: "1Password-BrowserSupport"
  binary "1password-#{version}.#{arch_suffix}/1Password-Crash-Handler", target: "1Password-Crash-Handler"
  binary "1password-#{version}.#{arch_suffix}/1Password-LastPass-Exporter", target: "1Password-LastPass-Exporter"
  artifact "1password-#{version}.#{arch_suffix}/resources/1password.desktop",
           target: "#{Dir.home}/.local/share/applications/1password.desktop"
  artifact "1password-#{version}.#{arch_suffix}/resources/icons/hicolor/256x256/apps/1password.png",
           target: "#{Dir.home}/.local/share/icons/1password.png"
  artifact "1password-#{version}.#{arch_suffix}/com.1password.1Password.policy.tpl",
           target: "#{HOMEBREW_PREFIX}/etc/polkit-1/actions/com.1password.1Password.policy"
  artifact "1password-#{version}.#{arch_suffix}/resources/custom_allowed_browsers",
           target: "#{HOMEBREW_PREFIX}/etc/1password/custom_allowed_browsers"

  preflight_steps do
    inreplace "{{staged_path}}/1password-{{version}}.x64/resources/1password.desktop",
              "Exec=/opt/1Password/1password", "Exec={{HOMEBREW_PREFIX}}/bin/1password"

    # set up flatpak browser support
    run "/bin/sh", args: [
      "-c",
      'f="{{staged_path}}/1password-{{version}}.x64/resources/custom_allowed_browsers"; ' \
      'printf "\nflatpak-session-helper" >> "$f"',
    ], writable_paths: ["{{staged_path}}"]

    # Browser wrapper for flatpak sandboxes: spawn the host-side BrowserSupport
    # binary instead of the one inside the flatpak mount.
    write_file "{{staged_path}}/1PasswordWrapper.sh", <<~EOS
      #!/bin/bash
      if [ "${container-}" = flatpak ]; then
        flatpak-spawn --host "{{HOMEBREW_PREFIX}}/bin/1Password-BrowserSupport" "$@"
      else
        exec "{{HOMEBREW_PREFIX}}/bin/1Password-BrowserSupport" "$@"
      fi
    EOS
    set_permissions "{{staged_path}}/1PasswordWrapper.sh", "755", recursive: false
  end

  postflight_steps do
    write_file "{{staged_path}}/1password-user-setup.sh", <<~EOS
      #!/bin/bash
      set -euo pipefail
      staged="{{staged_path}}"
      pkg="$staged/1password-{{version}}.x64"

      # Supported browser native-messaging hosts paths, as observed in
      # ~/.config/1Password/logs/1Password_rCURRENT.log
      nmh_dirs=(
        "$HOME/.mozilla/native-messaging-hosts"
        "$HOME/.config/google-chrome/NativeMessagingHosts"
        "$HOME/.config/google-chrome-beta/NativeMessagingHosts"
        "$HOME/.config/google-chrome-unstable/NativeMessagingHosts"
        "$HOME/.config/chromium/NativeMessagingHosts"
        "$HOME/.config/microsoft-edge-dev/NativeMessagingHosts"
        "$HOME/.config/BraveSoftware/BraveBrowser/NativeMessagingHosts"
        "$HOME/.config/vivaldi/NativeMessagingHosts"
        "$HOME/.config/vivaldi-snapshot/NativeMessagingHosts"
      )
      for d in "${nmh_dirs[@]}"; do
        mkdir -p "$d"
        # copy wrapper script to each browser support folder so the flatpak
        # filesystem restrictions won't prevent the browser from launching it
        cp -f "$staged/1PasswordWrapper.sh" "$d/1PasswordWrapper.sh"

        if [[ "$d" == *mozilla* ]]; then
          cat > "$d/com.1password.1password.json" <<JSON
      {
        "name": "com.1password.1password",
        "description": "1Password BrowserSupport",
        "path": "$d/1PasswordWrapper.sh",
        "type": "stdio",
        "allowed_extensions": [
          "{0a75d802-9aed-41e7-8daa-24c067386e82}",
          "{25fc87fa-4d31-4fee-b5c1-c32a7844c063}",
          "{d634138d-c276-4fc8-924b-40a0ea21d284}"
        ]
      }
      JSON
        else
          cat > "$d/com.1password.1password.json" <<JSON
      {
        "name": "com.1password.1password",
        "description": "1Password BrowserSupport",
        "path": "$d/1PasswordWrapper.sh",
        "type": "stdio",
        "allowed_origins": [
          "chrome-extension://hjlinigoblmkhjejkmbegnoaljkphmgo/",
          "chrome-extension://bkpbhnjcbehoklfkljkkbbmipaphipgl/",
          "chrome-extension://gejiddohjgogedgjnonbofjigllpkmbf/",
          "chrome-extension://khgocmkkpikpnmmkgmdnfckapcdkgfaf/",
          "chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/",
          "chrome-extension://dppgmdbiimibapkepcbdbmkaabgiofem/"
        ]
      }
      JSON
        fi
        # read-only, or else 1Password will overwrite the manifest on launch
        chmod 444 "$d/com.1password.1password.json"
      done
    EOS

    write_file "{{staged_path}}/1password-system-setup.sh", <<~EOS
      #!/bin/bash
      # Runs as root (runner executes the step with sudo).
      set -euo pipefail
      staged="{{staged_path}}"
      pkg="$staged/1password-{{version}}.x64"

      echo "Installing polkit policy file to /etc/polkit-1/actions/, you may be prompted for your password."
      if [ ! -e /etc/polkit-1/actions/com.1password.1Password.policy ] ||
         ! cmp -s "$pkg/com.1password.1Password.policy.tpl" \
                  /etc/polkit-1/actions/com.1password.1Password.policy; then
        # First 10 human users (1000 <= UID <= 9999) are allowed to unlock
        # 1Password via polkit: `unix-user:username` space separated.
        policy_owners="$(awk -F: '$3 >= 1000 && $3 <= 9999 && $1 != "nobody" { print $1 }' /etc/passwd \\
          | head -n 10 | sed 's/^/unix-user:/' | paste -sd ' ' -)"
        sed "s/\\${POLICY_OWNERS}/$policy_owners/g" "$pkg/com.1password.1Password.policy.tpl" \\
          > "$pkg/com.1password.1Password.policy"
        install -Dm0644 "$pkg/com.1password.1Password.policy" \\
          /etc/polkit-1/actions/com.1password.1Password.policy
        echo "Installed /etc/polkit-1/actions/com.1password.1Password.policy"
      else
        echo "Skipping polkit policy: already installed and identical."
      fi

      if ! grep -q '^flatpak-session-helper' /etc/1password/custom_allowed_browsers 2>/dev/null; then
        mkdir -p /etc/1password
        if [ -e /etc/1password/custom_allowed_browsers ]; then
          printf '\\nflatpak-session-helper' >> /etc/1password/custom_allowed_browsers
        else
          install -Dm0644 "$pkg/resources/custom_allowed_browsers" /etc/1password/custom_allowed_browsers
        fi
        echo "Configured /etc/1password/custom_allowed_browsers"
      fi

      # Browser support binary must be root:onepassword with the setgid bit;
      # chrome-sandbox needs root ownership + setuid; the main binary must be
      # root-executable for browser support running with elevated permissions.
      if ! getent group onepassword >/dev/null; then
        echo "Creating group 'onepassword' for 1Password browser support."
        groupadd onepassword
      fi
      chown root:onepassword "$pkg/1Password-BrowserSupport"
      chmod 2755 "$pkg/1Password-BrowserSupport"
      chown root:root "$pkg/1password"
      chown root:root "$pkg/chrome-sandbox"
      chmod 4755 "$pkg/chrome-sandbox"
      chown root:root "$pkg"
    EOS

    write_file "{{staged_path}}/1password-uninstall.sh", <<~EOS
      #!/bin/bash
      # Runs as root on uninstall (runner executes the step with sudo).
      set -e
      staged="{{staged_path}}"
      pkg="$staged/1password-{{version}}.x64"
      owner="${SUDO_USER:-$(id -un)}"

      echo "Uninstalling polkit policy file from /etc/polkit-1/actions/com.1password.1Password.policy"
      rm -f /etc/polkit-1/actions/com.1password.1Password.policy || true

      # re-take ownership of the staged tree so Homebrew can remove it
      chown -R "$owner" "$staged" || true

      nmh_dirs=(
        "$HOME/.mozilla/native-messaging-hosts"
        "$HOME/.config/google-chrome/NativeMessagingHosts"
        "$HOME/.config/google-chrome-beta/NativeMessagingHosts"
        "$HOME/.config/google-chrome-unstable/NativeMessagingHosts"
        "$HOME/.config/chromium/NativeMessagingHosts"
        "$HOME/.config/microsoft-edge-dev/NativeMessagingHosts"
        "$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
        "$HOME/.config/vivaldi/NativeMessagingHosts"
        "$HOME/.config/vivaldi-snapshot/NativeMessagingHosts"
      )
      for d in "${nmh_dirs[@]}"; do
        f="$d/com.1password.1password.json"
        # allow write access again so 1Password can clean the manifest itself
        if [ -e "$f" ]; then chmod 644 "$f" || true; fi
        rm -f "$d/1PasswordWrapper.sh" || true
      done
    EOS

    set_permissions "{{staged_path}}/1password-user-setup.sh", "755", recursive: false
    set_permissions "{{staged_path}}/1password-system-setup.sh", "744", recursive: false
    set_permissions "{{staged_path}}/1password-uninstall.sh", "740", recursive: false

    run "/bin/bash", args:           ["{{staged_path}}/1password-user-setup.sh"],
                     writable_paths: ["{{staged_path}}", "~/.mozilla", "~/.config"]
    run "/bin/bash", args: ["{{staged_path}}/1password-system-setup.sh"], sudo: true
  end

  uninstall_preflight_steps do
    if_path_exists "{{staged_path}}/1password-uninstall.sh" do
      run "/bin/bash", args: ["{{staged_path}}/1password-uninstall.sh"], sudo: true
    end
  end

  zap trash: [
    "~/.cache/1password",
    "~/.config/1Password",
    "~/.local/share/keyrings/1password.keyring",
  ]
end
