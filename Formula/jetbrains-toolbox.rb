class JetbrainsToolbox < Formula
  desc "JetBrains Toolbox App — installer and updater for JetBrains IDEs"
  homepage "https://www.jetbrains.com/toolbox-app/"
  # Version is inferred from the URL by Homebrew.
  url "https://download.jetbrains.com/toolbox/jetbrains-toolbox-3.6.1.85592.tar.gz"
  sha256 "9282664b47b6d14c96e865a0b54738d4252a9c2824c20e99101eaba0575c183d"

  # Linux only: macOS users should use the official cask `homebrew/cask/jetbrains-toolbox`.
  depends_on :linux

  on_arm do
    url "https://download.jetbrains.com/toolbox/jetbrains-toolbox-3.6.1.85592-arm64.tar.gz"
    sha256 "400e69206f4038eb7c5a17cec009e10b77e696eea7e4ba72dedd42aa363d2c15"
  end

  livecheck do
    url "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"
    strategy :json do |json|
      json["TBA"]&.map { |release| release["build"] }
    end
  end

  def install
    bin.install "jetbrains-toolbox"
  end

  # GUI app: launching it headless hangs, so test only that the binary landed
  # and is executable rather than running it.
  test do
    assert_predicate bin/"jetbrains-toolbox", :executable?
  end
end
