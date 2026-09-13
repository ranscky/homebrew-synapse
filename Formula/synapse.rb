class Synapse < Formula
  desc "Reverse proxy that compiles token-budgeted, task-aware context for LLM APIs"
  homepage "https://github.com/ranscky/synapse"
  version "0.1.15"
  license :cannot_represent # BSL 1.1 isn't representable in Homebrew's SPDX-based license DSL

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ranscky/synapse/releases/download/v0.1.15/synapse-darwin-arm64.tar.gz"
      sha256 "fd30f8e7a07110b39864d4d048624e3f4e8bf6cd9ef16decc13be0260a431ef0"
    else
      odie "Synapse does not yet publish an Intel macOS build. Build from source instead: https://github.com/ranscky/synapse#option-3--manual-build"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ranscky/synapse/releases/download/v0.1.15/synapse-linux-amd64.tar.gz"
      sha256 "d4d46f79dea7a4da546120e3859de5e3247216f930c66d6ca74f16e0257c7e56"
    else
      odie "Synapse does not yet publish an ARM Linux build. Build from source instead: https://github.com/ranscky/synapse#option-3--manual-build"
    end
  end

  def install
    bin.install "synapse"

    if OS.mac?
      lib.install "libonnxruntime.dylib"
    else
      lib.install "libonnxruntime.so"
    end

    (share/"synapse").install "models"
    (share/"synapse").install "ui" if File.exist?("ui")
    doc.install "README.md" if File.exist?("README.md")
    doc.install "synapse.yaml.example" if File.exist?("synapse.yaml.example")
  end

  def post_install
    config_path = etc/"synapse/synapse.yaml"
    return if config_path.exist?

    system bin/"synapse", "init", "--config", config_path.to_s, "--yes"
    model_path = opt_share/"synapse/models/all-MiniLM-L6-v2/model.onnx"
    inreplace config_path, /^model-path:.*/, "model-path: \"#{model_path}\""
  end

  service do
    run [opt_bin/"synapse", "--config", etc/"synapse/synapse.yaml"]
    keep_alive true
    log_path var/"log/synapse.log"
    error_log_path var/"log/synapse.log"
    environment_variables SYNAPSE_ORT_LIB_PATH: (opt_prefix/"lib"/(OS.mac? ? "libonnxruntime.dylib" : "libonnxruntime.so")).to_s
  end

  def caveats
    <<~EOS
      A default config was created at:
        #{etc}/synapse/synapse.yaml
      Edit it to point upstream-url at your model server (default assumes
      Ollama on http://localhost:11434).

      To run as a background service:
        brew services start synapse

      To run in the foreground instead, export the ONNX Runtime path first:
        export SYNAPSE_ORT_LIB_PATH=#{opt_prefix}/lib/#{OS.mac? ? "libonnxruntime.dylib" : "libonnxruntime.so"}
        synapse --config #{etc}/synapse/synapse.yaml

      Uninstalling does not remove your config or memory database. To fully
      clean up: rm -rf #{etc}/synapse ~/.local/share/synapse (or the
      equivalent on your OS).
    EOS
  end

  test do
    system "#{bin}/synapse", "--help"
  end
end