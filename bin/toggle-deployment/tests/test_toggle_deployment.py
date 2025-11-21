import tempfile
from pathlib import Path
from unittest.mock import Mock, patch

import pytest
import yaml

from toggle_deployment import (
    check_git_status,
    find_image_tag_files,
    parse_args,
    update_yaml_file,
)


class TestParseArgs:
    """Test argument parsing."""

    def test_enable_integration(self):
        args = parse_args(["--enable", "--integration"])
        assert args.enable is True
        assert args.disable is False
        assert args.integration is True
        assert args.staging is False
        assert args.production is False

    def test_disable_staging(self):
        args = parse_args(["--disable", "--staging"])
        assert args.enable is False
        assert args.disable is True
        assert args.integration is False
        assert args.staging is True
        assert args.production is False

    def test_production_with_dry_run(self):
        args = parse_args(["--enable", "--production", "--dry-run"])
        assert args.enable is True
        assert args.production is True
        assert args.dry_run is True

    def test_force_flag(self):
        args = parse_args(["--disable", "--integration", "--force"])
        assert args.force is True

    def test_missing_action_fails(self):
        with pytest.raises(SystemExit):
            parse_args(["--integration"])

    def test_missing_environment_fails(self):
        with pytest.raises(SystemExit):
            parse_args(["--enable"])

    def test_mutually_exclusive_actions(self):
        with pytest.raises(SystemExit):
            parse_args(["--enable", "--disable", "--integration"])

    def test_mutually_exclusive_environments(self):
        with pytest.raises(SystemExit):
            parse_args(["--enable", "--integration", "--staging"])


class TestCheckGitStatus:
    @patch("toggle_deployment.git.Repo")
    def test_clean_repo_passes(self, mock_repo_class):
        """Test that a clean repo passes the check."""
        mock_repo = Mock()
        mock_repo.is_dirty.return_value = False
        mock_repo_class.return_value = mock_repo

        # Should not raise
        check_git_status(Path("/tmp/test"))
        mock_repo.is_dirty.assert_called_once_with(untracked_files=True)

    @patch("toggle_deployment.git.Repo")
    def test_dirty_repo_fails(self, mock_repo_class):
        """Test that a dirty repo fails the check."""
        mock_repo = Mock()
        mock_repo.is_dirty.return_value = True
        mock_repo_class.return_value = mock_repo

        with pytest.raises(SystemExit) as exc_info:
            check_git_status(Path("/tmp/test"))
        assert exc_info.value.code == 1

    @patch("toggle_deployment.git.Repo")
    def test_dirty_repo_with_force_passes(self, mock_repo_class):
        """Test that --force allows running with dirty repo."""
        mock_repo = Mock()
        mock_repo.is_dirty.return_value = True
        mock_repo_class.return_value = mock_repo

        # Should not raise with force=True
        check_git_status(Path("/tmp/test"), force=True)


class TestFindImageTagFiles:

    def test_finds_files_in_environment(self):
        """Test that files are found in the correct environment directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            env_dir = repo_path / "charts" / "app-config" / "image-tags" / "integration"
            env_dir.mkdir(parents=True)

            # Create test files
            (env_dir / "app1").write_text("test: value\n")
            (env_dir / "app2").write_text("test: value\n")
            (env_dir / "app3").write_text("test: value\n")

            files = find_image_tag_files(repo_path, "integration")

            assert len(files) == 3
            assert all(f.parent == env_dir for f in files)
            assert {f.name for f in files} == {"app1", "app2", "app3"}

    def test_missing_directory_fails(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)

            with pytest.raises(SystemExit) as exc_info:
                find_image_tag_files(repo_path, "integration")
            assert exc_info.value.code == 1

    def test_ignores_subdirectories(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            env_dir = repo_path / "charts" / "app-config" / "image-tags" / "staging"
            env_dir.mkdir(parents=True)

            # Create files and a subdirectory
            (env_dir / "app1").write_text("test: value\n")
            (env_dir / "subdir").mkdir()
            (env_dir / "subdir" / "app2").write_text("test: value\n")

            files = find_image_tag_files(repo_path, "staging")

            assert len(files) == 1
            assert files[0].name == "app1"


class TestUpdateYamlFile:

    def test_adds_missing_key(self):
        """Test that automatic_deploys_enabled is added if missing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "test.yaml"
            file_path.write_text("image_tag: v1.0.0\npromote_deployment: true\n")

            result = update_yaml_file(file_path, True, dry_run=False)

            assert result is True
            data = yaml.safe_load(file_path.read_text())
            assert data["automatic_deploys_enabled"] is True
            assert data["image_tag"] == "v1.0.0"
            assert data["promote_deployment"] is True

    def test_updates_existing_key(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "test.yaml"
            file_path.write_text("image_tag: v1.0.0\nautomatic_deploys_enabled: true\n")

            result = update_yaml_file(file_path, False, dry_run=False)

            assert result is True
            data = yaml.safe_load(file_path.read_text())
            assert data["automatic_deploys_enabled"] is False
            assert data["image_tag"] == "v1.0.0"

    def test_no_change_when_already_set(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "test.yaml"
            file_path.write_text("image_tag: v1.0.0\nautomatic_deploys_enabled: true\n")

            result = update_yaml_file(file_path, True, dry_run=False)

            assert result is False

    def test_dry_run_mode(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "test.yaml"
            original_content = "image_tag: v1.0.0\n"
            file_path.write_text(original_content)

            result = update_yaml_file(file_path, True, dry_run=True)

            assert result is True
            assert file_path.read_text() == original_content

    def test_empty_file_handling(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "empty.yaml"
            file_path.write_text("")

            result = update_yaml_file(file_path, True, dry_run=False)

            assert result is False

    def test_preserves_existing_values(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "test.yaml"
            file_path.write_text(
                "image_tag: v2.5.0\npromote_deployment: false\ncustom_key: custom_value\n"
            )

            update_yaml_file(file_path, True, dry_run=False)

            data = yaml.safe_load(file_path.read_text())
            assert data["image_tag"] == "v2.5.0"
            assert data["promote_deployment"] is False
            assert data["custom_key"] == "custom_value"
            assert data["automatic_deploys_enabled"] is True

    def test_handles_malformed_yaml(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "bad.yaml"
            file_path.write_text("this is not: valid: yaml:\n  - bad")

            result = update_yaml_file(file_path, True, dry_run=False)

            assert result is False
