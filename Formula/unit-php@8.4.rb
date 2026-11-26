class UnitPhpAT84 < Formula
  desc "PHP module for Unit application server"
  homepage "https://docs.freeunit.org"
  url "https://github.com/freeunitorg/freeunit.git",
      tag:      "1.37.2",
      revision: "b36f46297b8bf3e075f293f72b206daa72015ed8"
  head "https://github.com/freeunitorg/freeunit.git", branch: "master"

  depends_on "openssl@3"
  depends_on "php-embed@8.4"
  depends_on "unit@1.37.2"

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
              "--cc-opt=-I#{formula_opt_include("openssl")}",
              "--ld-opt=-L#{formula_opt_lib("openssl")}"

    inreplace "build/autoconf.data",
        "NXT_MODULESDIR='#{HOMEBREW_PREFIX}/lib/unit/modules'",
        "NXT_MODULESDIR='#{lib}/unit/modules'"

    system "./configure", "php",
        "--config=#{formula_opt_bin("php@8.4")}/php-config",
        "--lib-path=#{formula_opt_lib("php-embed@8.4")}",
        "--module=php84"
    system "make", "php84-install"
  end

  test do
    require "socket"

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    expected_output = "Hello world!"
    (testpath/"unit.conf").write <<~EOS
      {
        "listeners": { "*:#{port}": { "pass": "applications/test" } },
        "applications": {
          "test": { "type": "php", "root": "#{testpath}" }
        }
      }
    EOS
    (testpath/"index.php").write <<~EOS
      <?php print("#{expected_output}"); ?>
    EOS
    (testpath/"state/certs").mkpath

    system "#{HOMEBREW_PREFIX}/bin/unitd", "--log", "#{testpath}/unit.log",
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
