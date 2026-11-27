defmodule NervesSystemNanoKvmGo.MixProject do
  use Mix.Project

  @app :nerves_system_nano_kvm_go
  @source_url "https://github.com/cocoa-xu/#{@app}"
  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      description: description(),
      package: package(),
      deps: deps(),
      aliases: [loadconfig: [&bootstrap/1]]
    ]
  end

  def application do
    []
  end

  # Nerves 1 builds a system in its own directory only with nerves_bootstrap
  # started, which an application does in its config.exs
  defp bootstrap(args) do
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  def cli do
    [default_target: :target]
  end

  defp nerves_package do
    [
      type: :system,
      artifact_sites: [
        {:github_releases, "cocoa-xu/#{@app}"}
      ],
      build_runner_opts: build_runner_opts(),
      platform: Nerves.System.BR,
      platform_config: [
        defconfig: "nerves_defconfig"
      ],
      env: [
        {"TARGET_ARCH", "aarch64"},
        {"TARGET_CPU", "cortex_a53"},
        {"TARGET_OS", "linux"},
        {"TARGET_ABI", "gnu"},
        {"TARGET_GCC_FLAGS",
         "-mabi=lp64 -fstack-protector-strong -mcpu=cortex-a53 -fPIE -pie -Wl,-z,now -Wl,-z,relro"}
      ],
      checksum: source_finger_print_files()
    ]
  end

  defp deps do
    [
      {:nerves, "~> 1.11 or ~> 2.0 or ~> 2.0.0-dev", runtime: false},
      {:nerves_system_br, "1.35.3", runtime: false},
      {:nerves_toolchain_aarch64_nerves_linux_gnu, "~> 15.3.0", runtime: false}
    ]
  end

  defp description do
    """
    Nerves System - Sipeed NanoKVM-Go (Axera AX620QE)
    """
  end

  defp package do
    [
      files: package_files(),
      licenses: ["Apache-2.0", "GPL-2.0-only", "GPL-2.0-or-later"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp source_finger_print_files do
    [
      "boot",
      "fwup_include",
      "linux",
      "package",
      "rootfs_overlay",
      "uboot",
      "busybox.fragment",
      "Config.in",
      "external.mk",
      "fwup-ops.conf",
      "fwup.conf",
      "kernel.its",
      "mix.exs",
      "nerves_defconfig",
      "post-build.sh",
      "post-createfs.sh"
    ]
  end

  defp package_files do
    ["CHANGELOG.md", "LICENSES/*", "README.md", "REUSE.toml", "VERSION"] ++
      source_finger_print_files()
  end

  defp build_runner_opts do
    [make_args: ["source", "all", "legal-info"]]
  end
end
