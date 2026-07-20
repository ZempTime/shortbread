# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "pathname"
require "tmpdir"

class InstallerSourcePreflightTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("../..").expand_path
  MISE_DATA_HOME = if ENV["MISE_DATA_DIR"]
    Pathname.new(ENV.fetch("MISE_DATA_DIR"))
  elsif ENV["XDG_DATA_HOME"]
    Pathname.new(ENV.fetch("XDG_DATA_HOME")).join("mise")
  else
    Pathname.new(Dir.home).join(".local/share/mise")
  end
  APPROVED_PLUGIN = MISE_DATA_HOME.join("plugins/postgres")

  def test_allows_the_pinned_config_to_install_an_absent_plugin
    Dir.mktmpdir("shortbread-installer-test") do |directory|
      stdout, stderr, status = run_preflight(Pathname.new(directory).join("mise"))

      assert status.success?, stderr
      assert_empty stdout
    end
  end

  def test_accepts_the_approved_clean_postgresql_installer
    with_plugin_copy do |mise_data_dir, _plugin|
      stdout, stderr, status = run_preflight(mise_data_dir)

      assert status.success?, stderr
      assert_equal "PostgreSQL installer preflight: approved origin, revision, and clean tree\n", stdout
    end
  end

  def test_rejects_a_cached_plugin_with_a_different_origin
    with_plugin_copy do |mise_data_dir, plugin|
      git!(plugin, "remote", "set-url", "origin", "https://example.invalid/postgres.git")

      _stdout, stderr, status = run_preflight(mise_data_dir)

      refute status.success?
      assert_equal "PostgreSQL installer preflight failed: cached plugin origin is not approved.\n", stderr
    end
  end

  def test_rejects_a_cached_plugin_at_a_different_revision
    with_plugin_copy do |mise_data_dir, plugin|
      git!(plugin, "-c", "user.name=Shortbread Test", "-c", "user.email=test@shortbread.invalid",
        "commit", "--allow-empty", "-m", "test revision")

      _stdout, stderr, status = run_preflight(mise_data_dir)

      refute status.success?
      assert_equal "PostgreSQL installer preflight failed: cached plugin revision is not approved.\n", stderr
    end
  end

  def test_rejects_local_changes_in_the_cached_plugin
    with_plugin_copy do |mise_data_dir, plugin|
      plugin.join("unreviewed-installer").write("echo unsafe\n")

      _stdout, stderr, status = run_preflight(mise_data_dir)

      refute status.success?
      assert_equal "PostgreSQL installer preflight failed: cached plugin contains local changes.\n", stderr
    end
  end

  private

  def with_plugin_copy
    assert APPROVED_PLUGIN.directory?, "mise install must materialize the approved PostgreSQL plugin first"

    Dir.mktmpdir("shortbread-installer-test") do |directory|
      mise_data_dir = Pathname.new(directory).join("mise")
      plugin = mise_data_dir.join("plugins/postgres")
      FileUtils.mkdir_p(plugin.dirname)
      FileUtils.cp_r(APPROVED_PLUGIN, plugin)
      yield mise_data_dir, plugin
    end
  end

  def run_preflight(mise_data_dir)
    Open3.capture3(
      { "MISE_DATA_DIR" => mise_data_dir.to_s },
      ROOT.join("bin/check-installer-sources").to_s
    )
  end

  def git!(directory, *arguments)
    _stdout, stderr, status = Open3.capture3("git", "-C", directory.to_s, *arguments)
    assert status.success?, stderr
  end
end
