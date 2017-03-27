require "formula"

class Mongodb268 < Formula
  homepage "https://www.mongodb.org/"

  url "https://fastdl.mongodb.org/src/mongodb-src-r2.6.8.tar.gz"
  sha256 "1997f60d9de17320f22c604d8aa1cbe5f38d877142cd0e9130fe3dae7b311a06"

  bottle do
#    sha1 "4b1749b645a744b38b4959daac46bf80353e3b32" => :yosemite
#    sha1 "95725282b89443fafcdc0974e60b10bd295b48ee" => :mavericks
#    sha1 "2da546a136e48a5f9dc86287c329b5741b77bd14" => :mountain_lion
  end

  devel do
    # This can't be bumped past 2.7.7 until we decide what to do with
    # https://github.com/Homebrew/homebrew/pull/33652
    url "https://fastdl.mongodb.org/src/mongodb-src-r2.7.7.tar.gz"
    sha256 "fce75a5be14c39c517f51408585ce02358d64f2bfe9a8980e19d3dcdf22995d4"
    # Remove this with the next devel release. Already merged in HEAD.
    # https://github.com/mongodb/mongo/commit/8b8e90fb
    patch do
      url "https://github.com/mongodb/mongo/commit/8b8e90fb.diff"
      sha256 "12af2a72d90cb566bd89c03745b0eebb6a0f4aab0b4923c701e95bff3eb6b5a7"
    end
  end

  option "with-boost", "Compile using installed boost, not the version shipped with mongodb"

  depends_on "boost" => :optional
  depends_on :macos => :snow_leopard
  depends_on "scons" => :build
  depends_on "openssl" => :optional

  # Review this patch with each release.
  # This modifies the SConstruct file to include 10.10 as an accepted build option.
  if MacOS.version == :yosemite
    patch do
      url "https://raw.githubusercontent.com/DomT4/scripts/fbc0cda/Homebrew_Resources/Mongodb/mongoyosemite.diff"
      sha25 "5eb3ff4ebcc90b3db7c1e9240a135660191f3a2dfbc678968cfa642c76dca758"
    end
  end

  def install
    args = %W[
      --prefix=#{prefix}
      -j#{ENV.make_jobs}
      --cc=#{ENV.cc}
      --cxx=#{ENV.cxx}
      --osx-version-min=#{MacOS.version}
    ]

    # --full installs development headers and client library, not just binaries
    # (only supported pre-2.7)
    args << "--full" if build.stable?
    args << "--use-system-boost" if build.with? "boost"
    args << "--64" if MacOS.prefer_64_bit?

    if build.with? "openssl"
      args << "--ssl" << "--extrapath=#{Formula["openssl"].opt_prefix}"
    end

    scons "install", *args

    (buildpath+"mongod.conf").write mongodb_conf
    etc.install "mongod.conf"

    (var+"mongodb").mkpath
    (var+"log/mongodb").mkpath
  end

  def mongodb_conf; <<-EOS.undent
    systemLog:
      destination: file
      path: #{var}/log/mongodb/mongo.log
      logAppend: true
    storage:
      dbPath: #{var}/mongodb
    net:
      bindIp: 127.0.0.1
    EOS
  end

  plist_options :manual => "mongod --config #{HOMEBREW_PREFIX}/etc/mongod.conf"

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/mongod</string>
        <string>--config</string>
        <string>#{etc}/mongod.conf</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>KeepAlive</key>
      <false/>
      <key>WorkingDirectory</key>
      <string>#{HOMEBREW_PREFIX}</string>
      <key>StandardErrorPath</key>
      <string>#{var}/log/mongodb/output.log</string>
      <key>StandardOutPath</key>
      <string>#{var}/log/mongodb/output.log</string>
      <key>HardResourceLimits</key>
      <dict>
        <key>NumberOfFiles</key>
        <integer>1024</integer>
      </dict>
      <key>SoftResourceLimits</key>
      <dict>
        <key>NumberOfFiles</key>
        <integer>1024</integer>
      </dict>
    </dict>
    </plist>
    EOS
  end

  test do
    system "#{bin}/mongod", "--sysinfo"
  end
end
