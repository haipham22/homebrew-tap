cask "jivedb" do
  os linux: "linux"

  version "1.5.4"
  sha256 "fdf2a9dc59b3207f971caa127c796138617fc70e27983fc4fb81370991c53be9"

  url "https://github.com/JiveGroup/JiveDBApp/releases/download/#{version}/JiveDB-linux-amd64.tar.gz"
  name "JiveDB"
  desc "Database client for PostgreSQL, MySQL, SQLite and Redis"
  homepage "https://github.com/JiveGroup/JiveDBApp"

  livecheck do
    url "https://github.com/JiveGroup/JiveDBApp/releases/latest"
    strategy :github_latest
  end

  binary "JiveDB-amd64/JiveDB-linux-amd64", target: "jivedb"
  artifact "JiveDB-amd64/appicon.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/jivedb.png"
  artifact "jivedb.desktop",
           target: "#{Dir.home}/.local/share/applications/jivedb.desktop"

  preflight_steps do
    mkdir_p "~/.local/share/applications"
    mkdir_p "~/.local/share/icons/hicolor/512x512/apps"
    # Icon=jivedb resolves via the hicolor theme; the artifact above installs
    # the PNG into ~/.local/share/icons/hicolor/512x512/apps.
    write_file "{{staged_path}}/jivedb.desktop", <<~EOS
      [Desktop Entry]
      Name=JiveDB
      Comment=Database client for PostgreSQL, MySQL, SQLite and Redis
      Exec={{HOMEBREW_PREFIX}}/bin/jivedb %F
      Icon=jivedb
      Type=Application
      StartupNotify=true
      StartupWMClass=JiveDB
      Categories=Development;Database;
      Keywords=database;sql;postgres;mysql;sqlite;redis;
    EOS
  end

  zap trash: [
    "~/.config/JiveDB",
    "~/.config/jivedb",
  ]
end
