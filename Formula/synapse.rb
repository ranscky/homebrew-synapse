class Synapse < Formula
  desc "Reverse proxy that compiles token-budgeted, task-aware context for LLM APIs"
  homepage "https://github.com/ranscky/synapse"
  version "0.1.3"
  license :cannot_represent # BSL 1.1 isn't representable in Homebrew's SPDX-based license DSL

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/ranscky/synapse/releases/download/v0.1.3/synapse-darwin-arm64.tar.gz"
      sha256 "65ac1b3736c4972aa24a3de27df951d19a96fe9735911021a0487caac04fd7ac"
    else
      odie "Synapse does not yet publish an Intel macOS build. Build from source instead: https://github.com/ranscky/synapse#option-3--manual-build"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/ranscky/synapse/releases/download/v0.1.3/synapse-linux-amd64.tar.gz"
      sha256 "0be1e331db5e4f60b32726cd512ee5dbc7b89bcfe43654ea245a3867a0240466"
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

    system bin/"synapse", "init", "--config", config_path.to_s
    # opt_share resolves through Homebrew's version-independent opt/
    # symlink, so the config keeps working across `brew upgrade` instead
    # of pointing at a specific Cellar/synapse/<version> path that stops
    # existing once that version is removed.
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