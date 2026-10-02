#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "pyyaml>=6",
# ]
# ///
"""Render every Argo CD Application as it would be rendered in-cluster.

Starting from the argo-bootstrap chart (installed by Terraform), render each
chart, find the Application resources in its output, render those, and so on
until no Applications are left. This is done for each environment.

Charts in this repo are rendered from the working copy, regardless of
targetRevision. Charts from Helm/OCI repositories are pulled and cached.

Usage:
  bin/render-argo-apps.py                      # all environments
  bin/render-argo-apps.py -e integration       # one environment
  bin/render-argo-apps.py --skip-remote-charts # don't pull third-party charts
  bin/render-argo-apps.py --lint               # also helm lint this repo's charts
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
from concurrent.futures import FIRST_COMPLETED, Future, ThreadPoolExecutor, wait
from dataclasses import dataclass, field
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
LOCAL_REPO = "github.com/alphagov/govuk-helm-charts"
ENVIRONMENTS = ["integration", "staging", "production"]

# How Terraform installs the bootstrap chart. See
# https://github.com/alphagov/govuk-infrastructure/blob/main/terraform/deployments/cluster-services/argo.tf
BOOTSTRAP_CHART = REPO_ROOT / "charts/argo-bootstrap"
BOOTSTRAP_RELEASE = "argo-bootstrap"
BOOTSTRAP_NAMESPACE = "cluster-services"


class YamlLoader(getattr(yaml, "CSafeLoader", yaml.SafeLoader)):
    pass


# PyYAML resolves a bare `=` (e.g. Alertmanager's `matchType: =`) to the
# obsolete YAML 1.1 "value" type, which it then can't construct.
YamlLoader.add_constructor("tag:yaml.org,2002:value", YamlLoader.construct_yaml_str)


class RenderError(Exception):
    pass


@dataclass
class HelmRelease:
    """Everything needed to run `helm template` or `helm lint` for one chart."""

    chart_dir: Path
    release: str
    namespace: str
    local: bool
    value_files: list[Path] = field(default_factory=list)
    inline_values: list[str] = field(default_factory=list)
    set_args: list[str] = field(default_factory=list)
    kube_version: str | None = None
    include_crds: bool = True
    skip_schema_validation: bool = False


@dataclass
class Node:
    """One rendered Argo CD node: the bootstrap chart or an Application."""

    env: str
    name: str
    parent: Node | None
    app: dict | None = None  # None for the bootstrap release
    manifests: str = ""
    releases: list[HelmRelease] = field(default_factory=list)
    children: list[Node] = field(default_factory=list)
    error: str | None = None
    lint_error: str | None = None
    skipped: str | None = None

    @property
    def path(self) -> str:
        parts = []
        node: Node | None = self
        while node:
            parts.append(node.name)
            node = node.parent
        return " -> ".join(reversed(parts))

    @property
    def namespace(self) -> str:
        """Namespace this node's resources go in if they don't set one."""
        if self.app is None:
            return BOOTSTRAP_NAMESPACE
        destination = (self.app.get("spec") or {}).get("destination") or {}
        return destination.get("namespace") or "default"

    @property
    def app_namespace(self) -> str:
        """Namespace the Application resource itself lives in."""
        assert self.app is not None and self.parent is not None
        return self.app["metadata"].get("namespace") or self.parent.namespace

    def output_path(self, output_dir: Path) -> Path:
        # Namespaces can't contain dots, so an Application's directory never
        # clashes with the bootstrap release's file.
        if self.app is None:
            return output_dir / self.env / f"{self.name}.yaml"
        return output_dir / self.env / self.app_namespace / f"{self.name}.yaml"


def normalise_repo_url(url: str) -> str:
    url = re.sub(r"^[a-z+]+://", "", url.strip().lower())
    url = re.sub(r"^[^@/]+@", "", url)
    return url.replace(":", "/").removesuffix("/").removesuffix(".git")


def is_local_repo(url: str) -> bool:
    return normalise_repo_url(url) == LOCAL_REPO


def run(cmd: list[str], include_stdout_on_error: bool = False, **kwargs) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True, check=False, **kwargs)
    if result.returncode != 0:
        output = result.stderr.strip()
        if include_stdout_on_error:
            output = f"{result.stdout.strip()}\n{output}".strip()
        raise RenderError(f"`{' '.join(cmd)}` failed:\n{output}")
    return result.stdout


class ChartCache:
    """Pulls charts from Helm/OCI repositories, once per chart version."""

    def __init__(self, cache_dir: Path):
        self.cache_dir = cache_dir
        self._locks: dict[str, threading.Lock] = {}
        self._locks_lock = threading.Lock()

    def get(self, repo_url: str, chart: str | None, version: str) -> Path:
        if repo_url.startswith("oci://"):
            # Argo CD's native OCI support: repoURL is the chart artifact.
            pull_args = [repo_url]
            chart = None
        elif chart:
            pull_args = [chart, "--repo", repo_url]
        else:
            raise RenderError(f"unsupported remote source {repo_url!r}")
        if not version or version == "HEAD":
            raise RenderError(f"remote chart {repo_url} {chart} has no pinned version")

        key = re.sub(r"[^A-Za-z0-9._-]+", "_", f"{repo_url}_{chart or ''}_{version}")
        dest = self.cache_dir / key
        with self._locks_lock:
            lock = self._locks.setdefault(key, threading.Lock())
        with lock:
            if not dest.exists():
                tmp = Path(tempfile.mkdtemp(dir=self.cache_dir, prefix=".pull-"))
                try:
                    run(["helm", "pull", *pull_args, "--version", version,
                         "--untar", "--untardir", str(tmp)])
                    tmp.rename(dest)
                except BaseException:
                    shutil.rmtree(tmp, ignore_errors=True)
                    raise
        (chart_dir,) = [p for p in dest.iterdir() if p.is_dir()]
        return chart_dir


class Renderer:
    def __init__(self, args: argparse.Namespace):
        self.kube_version: str = args.kube_version
        self.skip_remote: bool = args.skip_remote_charts
        args.chart_cache.mkdir(parents=True, exist_ok=True)
        self.charts = ChartCache(args.chart_cache)

    # -- Helm -----------------------------------------------------------------

    def values_args(self, release: HelmRelease, tmp: str) -> list[str]:
        """Arguments common to `helm template` and `helm lint`."""
        args = [
            "--namespace", release.namespace,
            "--kube-version", release.kube_version or self.kube_version,
        ]
        for f in release.value_files:
            args += ["--values", str(f)]
        for i, values in enumerate(release.inline_values):
            values_path = Path(tmp, f"inline-values-{i}.yaml")
            values_path.write_text(values)
            args += ["--values", str(values_path)]
        args += release.set_args
        if release.skip_schema_validation:
            args.append("--skip-schema-validation")
        return args

    def helm_template(self, release: HelmRelease) -> str:
        with tempfile.TemporaryDirectory(prefix="render-argo-apps-") as tmp:
            cmd = ["helm", "template", release.release, str(release.chart_dir)]
            cmd += self.values_args(release, tmp)
            if release.include_crds:
                cmd.append("--include-crds")
            return run(cmd)

    def helm_lint(self, release: HelmRelease):
        # helm lint always uses its own release name.
        with tempfile.TemporaryDirectory(prefix="render-argo-apps-") as tmp:
            cmd = ["helm", "lint", str(release.chart_dir), "--strict", "--quiet"]
            cmd += self.values_args(release, tmp)
            run(cmd, include_stdout_on_error=True)

    # -- Argo CD source handling ----------------------------------------------

    def resolve_chart_dir(self, source: dict) -> Path:
        """Local directory for a source's chart."""
        repo_url = source.get("repoURL", "")
        if is_local_repo(repo_url):
            if "path" not in source:
                raise RenderError(f"source for {repo_url} has no path")
            chart_dir = (REPO_ROOT / source["path"]).resolve()
            if not chart_dir.is_relative_to(REPO_ROOT):
                raise RenderError(f"path {source['path']!r} escapes the repo")
        else:
            chart_dir = self.charts.get(
                repo_url, source.get("chart"), str(source.get("targetRevision", ""))
            )
            if repo_url.startswith("oci://") and source.get("path"):
                chart_dir = (chart_dir / source["path"]).resolve()

        if not (chart_dir / "Chart.yaml").is_file():
            raise RenderError(
                f"{chart_dir} is not a Helm chart; only Helm sources are supported"
            )
        return chart_dir

    def resolve_value_file(
        self, value_file: str, chart_dir: Path, refs: dict[str, Path]
    ) -> Path:
        if value_file.startswith("$"):
            ref, _, rel = value_file[1:].partition("/")
            if ref not in refs:
                raise RenderError(f"valueFile {value_file!r} uses unknown ref ${ref}")
            return refs[ref] / rel
        if re.match(r"^[a-z]+://", value_file):
            raise RenderError(f"remote valueFile {value_file!r} is not supported")
        return chart_dir / value_file

    def source_release(
        self, app: dict, source: dict, refs: dict[str, Path]
    ) -> HelmRelease:
        chart_dir = self.resolve_chart_dir(source)
        helm = source.get("helm") or {}
        name = app["metadata"]["name"]
        destination = app["spec"].get("destination") or {}

        value_files = []
        for value_file in helm.get("valueFiles") or []:
            path = self.resolve_value_file(value_file, chart_dir, refs)
            if path.is_file():
                value_files.append(path)
            elif not helm.get("ignoreMissingValueFiles"):
                raise RenderError(f"valueFile {value_file!r} not found ({path})")

        # valuesObject takes precedence over values, and both over valueFiles.
        inline_values = []
        if helm.get("valuesObject") is not None:
            inline_values.append(yaml.safe_dump(helm["valuesObject"]))
        elif helm.get("values"):
            values = helm["values"]
            inline_values.append(values if isinstance(values, str) else yaml.safe_dump(values))

        set_args = []
        for param in helm.get("parameters") or []:
            flag = "--set-string" if param.get("forceString") else "--set"
            set_args += [flag, f"{param['name']}={param.get('value', '')}"]
        for param in helm.get("fileParameters") or []:
            path = self.resolve_value_file(param["path"], chart_dir, refs)
            set_args += ["--set-file", f"{param['name']}={path}"]

        return HelmRelease(
            chart_dir=chart_dir,
            release=helm.get("releaseName") or name,
            namespace=helm.get("namespace") or destination.get("namespace") or "default",
            local=is_local_repo(source.get("repoURL", "")),
            value_files=value_files,
            inline_values=inline_values,
            set_args=set_args,
            kube_version=helm.get("kubeVersion"),
            include_crds=not helm.get("skipCrds", False),
            skip_schema_validation=bool(helm.get("skipSchemaValidation")),
        )

    def render_application(
        self, app: dict
    ) -> tuple[str, list[HelmRelease], str | None]:
        """Returns (manifests, releases rendered, reason if skipped)."""
        spec = app.get("spec") or {}
        sources = spec.get("sources") or [spec.get("source") or {}]

        refs = {}
        for source in sources:
            if "ref" in source:
                if not is_local_repo(source.get("repoURL", "")):
                    raise RenderError(f"ref source {source['repoURL']!r} is not this repo")
                refs[source["ref"]] = REPO_ROOT

        outputs, releases, skipped = [], [], []
        for source in sources:
            # A source with only a ref exists purely to provide value files.
            if "ref" in source and not source.get("path") and not source.get("chart"):
                continue
            if not is_local_repo(source.get("repoURL", "")) and self.skip_remote:
                skipped.append(f"{source.get('repoURL')} {source.get('chart', '')}".strip())
                continue
            release = self.source_release(app, source, refs)
            outputs.append(self.helm_template(release))
            releases.append(release)

        reason = None
        if skipped:
            reason = f"remote chart {', '.join(skipped)}"
            if outputs:
                reason += " (other sources rendered)"
        return "---\n".join(outputs), releases, reason

    def bootstrap_release(self, env: str) -> HelmRelease:
        values_file = BOOTSTRAP_CHART / "ci" / f"{env}-values.yaml"
        if not values_file.is_file():
            raise RenderError(f"bootstrap values {values_file} not found")
        return HelmRelease(
            chart_dir=BOOTSTRAP_CHART,
            release=BOOTSTRAP_RELEASE,
            namespace=BOOTSTRAP_NAMESPACE,
            local=True,
            value_files=[values_file],
        )

    def render(self, node: Node) -> Node:
        try:
            if node.app is None:
                release = self.bootstrap_release(node.env)
                node.manifests = self.helm_template(release)
                node.releases = [release]
            else:
                node.manifests, node.releases, node.skipped = (
                    self.render_application(node.app)
                )
        except RenderError as e:
            node.error = str(e)
        return node

    def lint(self, node: Node) -> Node:
        """Lint the charts in this repo that the node rendered."""
        errors = []
        for release in node.releases:
            if not release.local:
                continue
            try:
                self.helm_lint(release)
            except RenderError as e:
                errors.append(str(e))
        if errors:
            node.lint_error = "\n".join(errors)
        return node


def find_kinds(manifests: str, kinds: set[str]) -> list[dict]:
    found = []
    for doc in yaml.load_all(manifests, Loader=YamlLoader):
        if (
            isinstance(doc, dict)
            and doc.get("kind") in kinds
            and str(doc.get("apiVersion", "")).startswith("argoproj.io/")
        ):
            found.append(doc)
    return found


def print_tree(node: Node, prefix: str = "", last: bool = True, root: bool = True):
    status = ""
    if node.error:
        status = "  [FAILED]"
    elif node.lint_error:
        status = "  [LINT FAILED]"
    elif node.skipped:
        status = f"  [skipped: {node.skipped}]"
    branch = "" if root else ("└── " if last else "├── ")
    print(f"{prefix}{branch}{node.name}{status}")
    child_prefix = prefix + ("" if root else ("    " if last else "│   "))
    children = sorted(node.children, key=lambda n: n.name)
    for i, child in enumerate(children):
        print_tree(child, child_prefix, i == len(children) - 1, root=False)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "-e", "--env", action="append", choices=ENVIRONMENTS,
        help="environment to render (repeatable; default: all)",
    )
    parser.add_argument(
        "-o", "--output-dir", type=Path, default=REPO_ROOT / "output",
        help="where to write rendered manifests (default: %(default)s)",
    )
    parser.add_argument(
        "--kube-version", default="1.36.3",
        help="Kubernetes version passed to helm template (default: %(default)s)",
    )
    parser.add_argument(
        "--skip-remote-charts", dest="skip_remote_charts", action="store_true",
        help="don't pull or render charts from outside this repo",
    )
    parser.add_argument(
        "--chart-cache", type=Path,
        default=Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
        / "govuk-helm-charts/charts",
        help="where to cache pulled charts (default: %(default)s)",
    )
    parser.add_argument(
        "-j", "--jobs", type=int, default=os.cpu_count() or 4,
        help="number of charts to render in parallel (default: %(default)s)",
    )
    parser.add_argument(
        "--lint", action="store_true",
        help="also run `helm lint --strict` on each chart from this repo, "
        "with the values it was rendered with",
    )
    parser.add_argument(
        "--tree", action="store_true", help="print the Application tree when done"
    )
    args = parser.parse_args()
    envs = args.env or ENVIRONMENTS

    if shutil.which("helm") is None:
        print("helm not found on PATH", file=sys.stderr)
        return 1

    renderer = Renderer(args)
    roots = [Node(env=env, name=BOOTSTRAP_RELEASE, parent=None) for env in envs]
    problems: list[str] = []
    seen: dict[tuple[str, str, str], Node] = {}
    projects: dict[str, set[str]] = {env: {"default"} for env in envs}
    rendered: list[Node] = []

    for env in envs:
        shutil.rmtree(args.output_dir / env, ignore_errors=True)

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        pending: set[Future[Node]] = {pool.submit(renderer.render, r) for r in roots}
        lint_futures: set[Future[Node]] = set()
        while pending:
            done, pending = wait(pending, return_when=FIRST_COMPLETED)
            for future in done:
                node = future.result()
                if future in lint_futures:
                    if node.lint_error:
                        problems.append(
                            f"[{node.env}] {node.path}: helm lint failed: {node.lint_error}"
                        )
                        print(f"[{node.env}] LINT FAILED {node.name}", file=sys.stderr)
                    continue
                rendered.append(node)
                if node.error:
                    problems.append(f"[{node.env}] {node.path}: {node.error}")
                    print(f"[{node.env}] FAILED {node.name}", file=sys.stderr)
                    continue
                print(f"[{node.env}] rendered {node.name}", file=sys.stderr)
                if args.lint:
                    lint_future = pool.submit(renderer.lint, node)
                    lint_futures.add(lint_future)
                    pending.add(lint_future)

                out = node.output_path(args.output_dir)
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_text(node.manifests)

                try:
                    resources = find_kinds(
                        node.manifests, {"Application", "ApplicationSet", "AppProject"}
                    )
                except yaml.YAMLError as e:
                    problems.append(
                        f"[{node.env}] {node.path}: invalid YAML in {out}: {e}"
                    )
                    continue

                for resource in resources:
                    kind, name = resource["kind"], resource["metadata"]["name"]
                    if kind == "AppProject":
                        projects[node.env].add(name)
                        continue
                    if kind == "ApplicationSet":
                        problems.append(
                            f"[{node.env}] {node.path}: ApplicationSet {name} is not supported"
                        )
                        continue

                    child = Node(env=node.env, name=name, parent=node, app=resource)
                    key = (node.env, child.app_namespace, name)
                    if key in seen:
                        problems.append(
                            f"[{node.env}] Application {child.app_namespace}/{name} is "
                            f"defined by both {seen[key].parent.path} and {node.path}"
                        )
                        continue
                    seen[key] = child
                    node.children.append(child)
                    pending.add(pool.submit(renderer.render, child))

    # Projects can be defined anywhere in the tree, so check once all are known.
    for node in rendered:
        if node.app is None:
            continue
        project = node.app.get("spec", {}).get("project", "default")
        if project not in projects[node.env]:
            problems.append(f"[{node.env}] {node.path}: unknown AppProject {project!r}")

    if args.tree:
        for root in roots:
            print(f"\n=== {root.env} ===")
            print_tree(root)

    print(file=sys.stderr)
    for env in envs:
        nodes = [n for n in rendered if n.env == env]
        failed = sum(1 for n in nodes if n.error)
        skipped = sum(1 for n in nodes if n.skipped)
        lint_failed = (
            f", {sum(1 for n in nodes if n.lint_error)} failed lint" if args.lint else ""
        )
        print(
            f"{env}: {len(nodes)} releases rendered to {args.output_dir / env} "
            f"({failed} failed, {skipped} skipped{lint_failed})",
            file=sys.stderr,
        )

    if problems:
        print(f"\n{len(problems)} problem(s):", file=sys.stderr)
        for problem in sorted(problems):
            print(f"\n{problem}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
