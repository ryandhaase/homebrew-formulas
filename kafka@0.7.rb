class KafkaAT07 < Formula
  desc "Publish-subscribe messaging rethought as a distributed commit log"
  homepage "https://kafka.apache.org/"
  url "https://dl.bintray.com/weblinc/mirrors/kafka-0.7.2.tar.gz"
  sha256 "6f6c9f6de136feaf49dab892fd54afce33939653470990c8073d7e3db1a0cb38"

  depends_on "zookeeper"
  depends_on :java => "1.8"

  def pour_bottle?; false; end

  def install
    data = var/"lib"
    inreplace "config/server.properties",
      "log.dir=/tmp/kafka-logs", "log.dir=#{data}/kafka-logs"

    libexec.install "libs"

    prefix.install "bin"
    bin.env_script_all_files(libexec/"bin", Language::Java.java_home_env("1.8"))
    Dir["#{bin}/*.sh"].each { |f| mv f, f.to_s.gsub(/.sh$/, "") }

    mv "config", "kafka@0.7"
    etc.install "kafka@0.7"
    libexec.install_symlink etc/"kafka" => "config"

    # create directory for kafka stdout+stderr output logs when run by launchd
    (var+"log/kafka").mkpath
  end

  plist_options :manual => "zookeeper-server-start #{HOMEBREW_PREFIX}/etc/kafka/zookeeper.properties & kafka-server-start #{HOMEBREW_PREFIX}/etc/kafka/server.properties"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>WorkingDirectory</key>
        <string>#{HOMEBREW_PREFIX}</string>
        <key>ProgramArguments</key>
        <array>
            <string>#{opt_bin}/kafka-server-start</string>
            <string>#{etc}/kafka@0.7/server.properties</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>StandardErrorPath</key>
        <string>#{var}/log/kafka/kafka_output.log</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/kafka/kafka_output.log</string>
    </dict>
    </plist>
    EOS
  end

  test do
    ENV["LOG_DIR"] = "#{testpath}/kafkalog"

    (testpath/"kafka").mkpath
    cp "#{etc}/kafka/zookeeper.properties", testpath/"kafka"
    cp "#{etc}/kafka/server.properties", testpath/"kafka"
    inreplace "#{testpath}/kafka/zookeeper.properties", "#{var}/lib", testpath
    inreplace "#{testpath}/kafka/server.properties", "#{var}/lib", testpath

    begin
      fork do
        exec "#{bin}/zookeeper-server-start #{testpath}/kafka/zookeeper.properties > #{testpath}/test.zookeeper-server-start.log 2>&1"
      end

      sleep 15

      fork do
        exec "#{bin}/kafka-server-start #{testpath}/kafka/server.properties > #{testpath}/test.kafka-server-start.log 2>&1"
      end

      sleep 30

      system "#{bin}/kafka-topics --zookeeper localhost:2181 --create --if-not-exists --replication-factor 1 --partitions 1 --topic test > #{testpath}/kafka/demo.out 2>/dev/null"
      pipe_output("#{bin}/kafka-console-producer --broker-list localhost:9092 --topic test 2>/dev/null", "test message")
      system "#{bin}/kafka-console-consumer --zookeeper localhost:2181 --topic test --from-beginning --max-messages 1 >> #{testpath}/kafka/demo.out 2>/dev/null"
      system "#{bin}/kafka-topics --zookeeper localhost:2181 --delete --topic test >> #{testpath}/kafka/demo.out 2>/dev/null"
    ensure
      system "#{bin}/kafka-server-stop"
      system "#{bin}/zookeeper-server-stop"
      sleep 10
    end

    assert_match(/test message/, IO.read("#{testpath}/kafka/demo.out"))
  end
end
