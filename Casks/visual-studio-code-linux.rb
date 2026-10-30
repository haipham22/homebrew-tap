cask "visual-studio-code-linux" do
  os linux: "linux"

  version "1.127.0"
  sha256 "e06fb36791c9baf7495d4b7dc0f5aaa8254e7d1a60a5ee43e6c7debc05c962b5"

  url "https://update.code.visualstudio.com/#{version}/linux-x64/stable"
  name "Microsoft Visual Studio Code"
  name "VS Code"
  desc "Open-source code editor"
  homepage "https://code.visualstudio.com/"

  livecheck do
    url "https://update.code.visualstudio.com/api/update/linux-x64/stable/latest"
    strategy :json do |json|
      json["productVersion"]
    end
  end

  binary "VSCode-linux-x64/bin/code"
  binary "VSCode-linux-x64/bin/code-tunnel"
  bash_completion "#{staged_path}/VSCode-linux-x64/resources/completions/bash/code"
  zsh_completion  "#{staged_path}/VSCode-linux-x64/resources/completions/zsh/_code"
  artifact "VSCode-linux-x64/code.desktop",
           target: "#{Dir.home}/.local/share/applications/code.desktop"
  artifact "VSCode-linux-x64/code-url-handler.desktop",
           target: "#{Dir.home}/.local/share/applications/code-url-handler.desktop"

  preflight_steps do
    # Disable VS Code's built-in update checks; Homebrew manages this install.
    write_file "{{staged_path}}/vscode-update-config.py", <<~PY
      import json, sys

      path = sys.argv[1]
      config = json.load(open(path))
      config.pop("updateUrl", None)
      config.setdefault("configurationDefaults", {})["update.mode"] = "none"
      json.dump(config, open(path, "w"), indent=2)
    PY
    run "/usr/bin/python3", args: [
      "{{staged_path}}/vscode-update-config.py",
      "{{staged_path}}/VSCode-linux-x64/resources/app/product.json",
    ], writable_paths: ["{{staged_path}}"]

    mkdir_p "~/.local/share/applications"
    write_file "{{staged_path}}/VSCode-linux-x64/code.desktop", <<~EOS
      [Desktop Entry]
      Name=Visual Studio Code
      Comment=Code Editing. Redefined.
      GenericName=Text Editor
      Exec={{HOMEBREW_PREFIX}}/bin/code %F
      Icon={{staged_path}}/VSCode-linux-x64/resources/app/resources/linux/code.png
      Type=Application
      StartupNotify=false
      StartupWMClass=Code
      Categories=TextEditor;Development;IDE;
      MimeType=application/x-code-workspace;
      Actions=new-empty-window;
      Keywords=vscode;

      [Desktop Action new-empty-window]
      Name=New Empty Window
      Exec={{HOMEBREW_PREFIX}}/bin/code --new-window %F
      Icon={{staged_path}}/VSCode-linux-x64/resources/app/resources/linux/code.png
    EOS
    write_file "{{staged_path}}/VSCode-linux-x64/code-url-handler.desktop", <<~EOS
      [Desktop Entry]
      Name=Visual Studio Code - URL Handler
      Comment=Code Editing. Redefined.
      GenericName=Text Editor
      Exec={{HOMEBREW_PREFIX}}/bin/code --open-url %U
      Icon={{staged_path}}/VSCode-linux-x64/resources/app/resources/linux/code.png
      Type=Application
      NoDisplay=true
      StartupNotify=true
      Categories=Utility;TextEditor;Development;IDE;
      MimeType=x-scheme-handler/vscode;
      Keywords=vscode;
    EOS
  end

  zap trash: [
    "~/.config/Code",
    "~/.vscode",
  ]
end
