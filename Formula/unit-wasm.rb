class UnitWasm < Formula
  desc "Ruby module for Unit application server"
  homepage "https://docs.freeunit.org"
  url "https://github.com/freeunitorg/freeunit.git",
      tag:      "1.37.2",
      revision: "b36f46297b8bf3e075f293f72b206daa72015ed8"
  head "https://github.com/freeunitorg/freeunit.git", branch: "master"

  depends_on "rust" => :build
  depends_on "openssl@3"
  depends_on "unit@1.37.2"
  depends_on "wasmtime"

  def install
    system "./configure",
              "--prefix=#{prefix}",
              "--sbindir=#{bin}",
              "--logdir=#{var}/log",
              "--log=#{var}/log/unit/unit.log",
              "--runstatedir=#{var}/run",
              "--pid=#{var}/run/unit/unit.pid",
              "--control=unix:#{var}/run/unit/control.sock",
              "--modulesdir=#{HOMEBREW_PREFIX}/lib/unit/modules",
              "--statedir=#{var}/state/unit",
              "--tmpdir=/tmp",
              "--openssl",
              "--cc-opt=-I#{formula_opt_include("openssl")} -DNXT_HAVE_ISOLATION_ROOTFS=1",
              "--ld-opt=-L#{formula_opt_lib("openssl")}"

    inreplace "build/autoconf.data",
        "NXT_MODULESDIR='#{HOMEBREW_PREFIX}/lib/unit/modules'",
        "NXT_MODULESDIR='#{lib}/unit/modules'"

    system "./configure", "wasm", "--module=wasm",
      "--include-path=#{HOMEBREW_PREFIX}/usr/include/",
      "--lib-path=#{HOMEBREW_PREFIX}/lib/"
    system "make", "wasm-install"

    system "./configure", "wasm-wasi-component"
    system "make", "wasm-wasi-component-install"
  end

  test do
    assert_path_exists lib/"unit/modules", "wasm modules directory not found"
    Dir.glob(lib/"unit/modules/nxt_wasm*").each do |f|
      assert_path_exists f, "expected wasm module #{f} to exist"
    end
  end
end
