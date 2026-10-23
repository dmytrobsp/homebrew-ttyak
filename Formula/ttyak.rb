# Rendered by packaging/render.py from the release's SHA256SUMS (github.com/dmytrobsp/ttyak); edit the template.
# No `version`: brew reads it from the urls (`brew audit --strict` refuses a redundant one).
class Ttyak < Formula
  desc "Slack client for the terminal, with huddles"
  homepage "https://ttyak.sh/"
  license any_of: ["MIT", "Apache-2.0"]

  on_macos do
    on_arm do
      url "https://github.com/dmytrobsp/ttyak/releases/download/v0.11.0/ttyak-0.11.0-aarch64-macos.zip"
      sha256 "4eb676db46f4118c1a4fd39cb7ab0540a9d1b2b30e3df8c2c5142b266944cee5"
    end
    on_intel do
      url "https://github.com/dmytrobsp/ttyak/releases/download/v0.11.0/ttyak-0.11.0-x86_64-macos.zip"
      sha256 "55686bb52036629e5047f0fc71fa9b885f9ae078b9678d613e28d0c88e86b446"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/dmytrobsp/ttyak/releases/download/v0.11.0/ttyak-0.11.0-aarch64-linux.zip"
      sha256 "e119876bd51fd18ce4ed3270ea8845e8a10328459a865be8d99166ff12e90b3e"
    end
    on_intel do
      url "https://github.com/dmytrobsp/ttyak/releases/download/v0.11.0/ttyak-0.11.0-x86_64-linux.zip"
      sha256 "68f8f64a2c1a024f48c51da16d871d3cc072aff325a8fb47085808bbc55492ba"
    end
    depends_on "alsa-lib"
  end

  def install
    if OS.mac?
      bin.install "ttyak"
      return
    end

    # Linux: the program links libasound.so.2. The system's, set up for the desktop's sound server (PipeWire,
    # PulseAudio), comes first; Homebrew's alsa-lib only when the system has none. So no rpath (it would win): the
    # program goes in libexec and bin gets a launcher that picks. (`brew linkage` reads libexec/ttyak without the
    # launcher, so it reports libasound.so.2, or on old systems libgcc_s and libstdc++, as missing.)
    libexec.install "ttyak"
    arch = Hardware::CPU.arm? ? "aarch64" : "x86_64"
    cache_tag = Hardware::CPU.arm? ? "AArch64" : "x86-64"
    (bin/"ttyak").write <<~SH
      #!/bin/sh
      # ttyak's launcher from Homebrew: the system's libasound.so.2 when its loader finds one, else Homebrew's.
      exe="#{libexec}/ttyak"
      dirs="/lib/#{arch}-linux-gnu /usr/lib/#{arch}-linux-gnu /lib64 /usr/lib64"
      ldconfigs="/sbin/ldconfig /usr/sbin/ldconfig"
      tag="libasound.so.2 (libc6,#{cache_tag})"
      for dir in $dirs; do
        [ -e "$dir/libasound.so.2" ] && exec "$exe" "$@"
      done
      for ldconfig in $ldconfigs; do
        if [ -x "$ldconfig" ] && "$ldconfig" -p 2> /dev/null | grep -qF "$tag"; then
          exec "$exe" "$@"
        fi
      done
      unset ALSA_CONFIG_PATH
      # The programs ttyak starts get this too; only alsa-lib's own folder is added.
      LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}#{formula_opt_lib("alsa-lib")}"
      export LD_LIBRARY_PATH
      exec "$exe" "$@"
    SH
    (bin/"ttyak").chmod 0755
  end

  def caveats
    text = <<~EOS
      ttyak keeps its settings, sign-ins, drafts and caches in your home folder, and
      `brew uninstall ttyak` leaves them there. To delete them, run this first:
        ttyak purge
    EOS
    if OS.linux?
      text += <<~EOS
        ttyak uses your system's ALSA library: libasound2 (libasound2t64 on Ubuntu 24.04, Debian 13 and later) on
        Debian/Ubuntu, alsa-lib on Fedora/Arch. Homebrew's alsa-lib is only a fallback for systems without one, and it
        needs glibc 2.38 or newer.
      EOS
    end
    text
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ttyak --version")
  end
end
