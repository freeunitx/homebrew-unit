class Unit < Formula
  desc "Dynamic web and application server"
  homepage "https://docs.freeunit.org"
  url "https://github.com/freeunitorg/freeunit.git",
      tag:      "1.37.2",
      revision: "b36f46297b8bf3e075f293f72b206daa72015ed8"
  head "https://github.com/freeunitorg/freeunit.git", branch: "master"

  depends_on "rust" => :build
  depends_on "libedit"
  depends_on "openssl@3"
  depends_on "pcre2"
  depends_on "pkg-config"

  resource "njs" do
    url "https://github.com/freeunitorg/njs.git",
        tag:      "1.0.2",
        revision: "10d6f68480b6be67ba2b0c5213702006cc4d4d74"
  end

  resource "unitctl" do
    src_repo = "https://github.com/freeunitorg/freeunit"
    if OS.mac? && Hardware::CPU.intel?
      url "#{src_repo}/releases/download/unitctl/#{Unit.version}/unitctl-#{Unit.version}-x86_64-apple-darwin"
      sha256 "603f83bfdfe42a6c0f03c49b48c2b0dfb731052f48b4e45099b8d311d050ac6f"
    elsif OS.mac? && Hardware::CPU.arm?
      url "#{src_repo}/releases/download/unitctl/#{Unit.version}/unitctl-#{Unit.version}-aarch64-apple-darwin"
      sha256 "e20320870795493025441166dce1c4211d11f30118b3d37d1855d06d043c443f"
    elsif OS.linux? && Hardware::CPU.intel?
      url "#{src_repo}/releases/download/unitctl/#{Unit.version}/unitctl-#{Unit.version}-x86_64-unknown-linux-gnu"
      sha256 "2136127ee9ef3743c3b552068c0343303438e7be5f69aeeb5d58afc37898f9d0"
    elsif OS.linux? && Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "#{src_repo}/releases/download/unitctl/#{Unit.version}/unitctl-#{Unit.version}-aarch64-unknown-linux-gnu"
      sha256 "392d8c62b3b3ec599343eb4884907cf4597c7428f7c07302b904d789e6862163"
    else
      odie "Unsupported architecture"
    end
  end

  def install
    resource("unitctl").stage buildpath/"unitctl"
    cd "unitctl" do
      bin.install Dir.glob("unitctl-*").first => "unitctl"
    end

    resource("njs").stage buildpath/"njs"
    cd "njs" do
      system "./configure", "--no-libxml2", "--no-zlib", "--no-openssl", "--no-quickjs"
      system "make", "libnjs", "njs"
      bin.install "build/njs" => "njs-unit"
    end

    ENV.prepend_path "PKG_CONFIG_PATH", buildpath/"njs/build"
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
              "--njs",
              "--otel",
              "--cc-opt=-I#{formula_opt_include("openssl")}",
              "--ld-opt=-L#{formula_opt_lib("openssl")}"

    system "make"
    system "make", "install", "libunit-install"
    bin.install "tools/setup-unit"
    bin.install "tools/unitc"
  end

  def post_install_steps
    (lib/"unit/modules").mkpath
    (var/"log/unit").mkpath
    (var/"run/unit").mkpath
    (var/"state/unit/certs").mkpath
  end

  service do
    run [opt_bin/"unitd", "--no-daemon"]
    run_type :immediate
  end

  test do
    require "socket"

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    expected_output = "Hello world!"
    (testpath/"index.html").write expected_output
    (testpath/"unit.conf").write <<~EOS
      {
        "routes": [ { "action": { "share": "#{testpath}/$uri" } } ],
        "listeners": { "*:#{port}": { "pass": "routes" } }
      }
    EOS

    system bin/"unitd", "--log", "#{testpath}/unit.log",
                        "--control", "unix:#{testpath}/control.sock",
                        "--pid", "#{testpath}/unit.pid",
                        "--statedir", "#{testpath}/state"
    sleep 3

    pid = File.open(testpath/"unit.pid") { |f| f.gets.chop.to_i }

    system "curl", "-s", "--unix-socket", "#{testpath}/control.sock",
                    "-X", "PUT",
                    "-d", "@#{testpath}/unit.conf", "127.0.0.1/config"

    assert_match expected_output, shell_output("curl -s 127.0.0.1:#{port}")
  ensure
    Process.kill("TERM", pid)
  end
end
