class Mpv < Formula
  desc "Media player based on MPlayer and mplayer2 (dogfood build with local patches)"
  homepage "https://mpv.io"
  license all_of: ["GPL-2.0-or-later", "LGPL-2.1-or-later"]
  revision 5
  compatibility_version 1
  # Dogfood build: built with --HEAD from the fork's homebrew-build branch, which
  # is the release tag below + the same stable patches + our feature commits, so
  # the stable block here is only used to read the version/patches (and as a
  # reference copy of homebrew/core). Re-sync this file from `brew cat mpv` when
  # homebrew/core changes flags, deps, version or patches; keep only the `head`
  # line repointed at the fork.
  head "https://github.com/feldgendler/mpv.git", branch: "homebrew-build"

  stable do
    url "https://github.com/mpv-player/mpv/archive/refs/tags/v0.41.0.tar.gz"
    sha256 "ee21092a5ee427353392360929dc64645c54479aefdb5babc5cfbb5fad626209"

    # Backport support for Vapoursynth 74+
    patch do
      url "https://github.com/mpv-player/mpv/commit/75b2ccfeb1ce4ed5a40ac9860fa74f3d1265e13f.patch?full_index=1"
      sha256 "3906b98b02071a0d5747a400406494ca69cef7afd8d3eee4a99fdbe40dc90c1f"
    end
    patch do
      url "https://github.com/mpv-player/mpv/commit/8aabba933bd600ea89924b97d4e5b2361b96f6fa.patch?full_index=1"
      sha256 "96ccb2407a2e053299089c821f2f0f68919d79868d795a87af057ebe70910d09"
    end
  end

  depends_on "docutils" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => [:build, :test]
  depends_on xcode: :build
  depends_on "ffmpeg"
  depends_on "jpeg-turbo"
  depends_on "libarchive"
  depends_on "libass"
  depends_on "libbluray"
  depends_on "libplacebo"
  depends_on "little-cms2"
  depends_on "luajit"
  depends_on "mujs"
  depends_on "rubberband"
  depends_on "uchardet"
  depends_on "vapoursynth"
  depends_on "vulkan-loader"
  depends_on "yt-dlp"
  depends_on "zimg"

  on_macos do
    depends_on "molten-vk"
  end

  on_linux do
    depends_on "alsa-lib"
    depends_on "libva"
    depends_on "libvdpau"
    depends_on "libx11"
    depends_on "libxext"
    depends_on "libxfixes"
    depends_on "libxkbcommon"
    depends_on "libxpresent"
    depends_on "libxrandr"
    depends_on "libxscrnsaver"
    depends_on "libxv"
    depends_on "mesa"
    depends_on "pulseaudio"
    depends_on "wayland"
    depends_on "wayland-protocols" => :no_linkage # needed by mpv.pc
    depends_on "zlib-ng-compat"
  end

  conflicts_with cask: "stolendata-mpv", because: "both install `mpv` binaries"

  def install
    # LANG is unset by default on macOS and causes issues when calling getlocale
    # or getdefaultlocale in docutils. Force the default c/posix locale since
    # that's good enough for building the manpage.
    ENV["LC_ALL"] = "C"

    # force meson find ninja from homebrew
    ENV["NINJA"] = which("ninja")

    # libarchive is keg-only
    ENV.prepend_path "PKG_CONFIG_PATH", Formula["libarchive"].opt_lib/"pkgconfig" if OS.mac?

    args = %W[
      -Dbuild-date=false
      -Dhtml-build=enabled
      -Djavascript=enabled
      -Dlibmpv=true
      -Dlua=luajit
      -Dlibarchive=enabled
      -Duchardet=enabled
      -Dvulkan=enabled
      --sysconfdir=#{pkgetc}
      --datadir=#{pkgshare}
      --mandir=#{man}
    ]
    if OS.linux?
      args += %w[
        -Degl=enabled
        -Dwayland=enabled
        -Dx11=enabled
      ]
    end

    system "meson", "setup", "build", *args, *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"

    if OS.mac?
      # `pkg-config --libs mpv` includes libarchive, but that package is
      # keg-only so it needs to look for the pkgconfig file in libarchive's opt
      # path.
      libarchive = Formula["libarchive"].opt_prefix
      inreplace lib/"pkgconfig/mpv.pc" do |s|
        s.gsub!(/^Requires\.private:(.*)\blibarchive\b(.*?)(,.*)?$/,
                "Requires.private:\\1#{libarchive}/lib/pkgconfig/libarchive.pc\\3")
      end
    end

    bash_completion.install "etc/mpv.bash-completion" => "mpv"
    zsh_completion.install "etc/_mpv.zsh" => "_mpv"
  end

  test do
    system bin/"mpv", "--ao=null", "--vo=null", test_fixtures("test.wav")
    assert_match "vapoursynth", shell_output("#{bin}/mpv --vf=help")

    # Make sure `pkgconf` can parse `mpv.pc` after the `inreplace`.
    system "pkgconf", "--print-errors", "mpv"
  end
end
