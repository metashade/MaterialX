"""
pytest configuration and fixtures for MaterialX rendering tests.

Fixtures are session-scoped to amortize setup cost across test cases.
Each pytest-xdist worker process gets its own fixture instances.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

_rendertest_path = Path(__file__).parent.parent / "utilities" / "scripts"
_mtlxutils_path = _rendertest_path / "rendertest"
sys.path.insert(0, str(_rendertest_path))
sys.path.insert(0, str(_mtlxutils_path))

import MaterialX as mx
import MaterialX.PyMaterialXGenShader as mx_gen_shader
import MaterialX.PyMaterialXRender as mx_render
from rendertest.mtlxutils import mxrenderer


def get_repo_root() -> Path:
    """Get MaterialX repository root."""
    return Path(__file__).parent.parent.parent


@pytest.fixture(scope="session")
def repo_root() -> Path:
    """MaterialX repository root path."""
    return get_repo_root()


# ---------------------------------------------------------------------------
# CLI options
# ---------------------------------------------------------------------------

def pytest_addoption(parser):
    """Register custom command-line options for MaterialX render tests."""
    parser.addoption(
        "--flip-threshold",
        action="store",
        type=float,
        default=0.05,
        help="Mean FLIP error threshold above which a comparison fails.",
    )
    parser.addoption(
        "--output-dir",
        action="store",
        default=None,
        help=(
            "Root directory for all test output.  Defaults to contrib/ "
            "(repo-relative, developer/baseline-update mode).  CI sets "
            "this to a temp directory and compares against committed "
            "baselines."
        ),
    )
    parser.addoption(
        "--no-render",
        action="store_true",
        default=False,
        help="Skip GPU rendering; only generate shaders and run source comparisons.",
    )


# ---------------------------------------------------------------------------
# Dataclass fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def mtlx_test_options():
    """Parsed ``_options.mtlx`` configuration (MaterialXTest settings)."""
    from test_render import parse_options_mtlx
    return parse_options_mtlx()


@pytest.fixture(scope="session")
def cli_options(request, repo_root):
    """CLI-derived options bundled into a :class:`CliOptions`."""
    from test_render import CliOptions

    output_opt = request.config.getoption("--output-dir")
    output_root = Path(output_opt) if output_opt else repo_root / "contrib"

    return CliOptions(
        output_root=output_root,
        no_render=request.config.getoption("--no-render"),
        flip_threshold=request.config.getoption("--flip-threshold"),
    )


# ---------------------------------------------------------------------------
# MaterialX library fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def search_path(repo_root) -> mx.FileSearchPath:
    """MaterialX search path including adsk libraries."""
    sp = mx.getDefaultDataSearchPath()
    adsk_path = repo_root / "contrib" / "adsk" / "libraries"
    if adsk_path.exists():
        sp.append(str(adsk_path))
    return sp


@pytest.fixture(scope="session")
def stdlib(search_path):
    """Load MaterialX standard library once per worker."""
    lib = mx.createDocument()
    library_folders = mx.getDefaultDataLibraryFolders()
    mx.loadLibraries(library_folders, search_path, lib)
    return lib


@pytest.fixture(scope="session")
def adsklib(search_path, repo_root):
    """Load Autodesk library once per worker."""
    lib = mx.createDocument()
    adsk_path = repo_root / "contrib" / "adsk" / "libraries"
    if adsk_path.exists():
        adsk_search = mx.FileSearchPath(str(adsk_path))
        mx.loadLibraries(["adsklib"], adsk_search, lib)
    return lib


@pytest.fixture(scope="session")
def libraries(stdlib, adsklib):
    """Combined libraries for document creation."""
    return [stdlib, adsklib]


@pytest.fixture(scope="session")
def data_library(stdlib, adsklib):
    """Combined data library (stdlib + adsklib) as a single document.

    Mirrors the C++ tests' single ``dependLib`` document.  Test documents
    reference it via ``Document.setDataLibrary`` rather than merging
    libraries in with ``importLibrary`` -- merging before upgrading
    old-syntax documents can produce spurious "too many bindings"
    validation errors.
    """
    lib = mx.createDocument()
    lib.importLibrary(stdlib)
    lib.importLibrary(adsklib)
    return lib


# ---------------------------------------------------------------------------
# Renderer fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def glsl_renderer(stdlib, search_path, repo_root, mtlx_test_options):
    """
    Initialize GLSL renderer once per worker process.
    
    This is the expensive setup that we want to share across tests.
    """
    # IBL paths
    lights_path = repo_root / "resources" / "Lights"
    radiance_path = lights_path / "san_giuseppe_bridge.hdr"
    irradiance_path = lights_path / "irradiance" / "san_giuseppe_bridge.hdr"
    
    # Geometry
    geometry_path = repo_root / "resources" / "Geometry" / "sphere.obj"
    
    # Render size
    width = height = 512
    
    renderer = mxrenderer.initializeRenderer(
        stdlib,
        search_path,
        str(radiance_path),
        str(irradiance_path),
        width,
        height,
        str(geometry_path),
        envSampleCount=mtlx_test_options.env_sample_count,
    )
    
    # Add test geometry streams for geompropvalue, streams, and struct_texcoord tests
    from test_render import add_additional_test_streams
    geom_handler = renderer.renderer.getGeometryHandler()
    for mesh in geom_handler.getMeshes():
        add_additional_test_streams(mesh)
    
    return renderer


@pytest.fixture(scope="session")
def renderer(request, cli_options, stdlib, search_path):
    """
    Session-scoped renderer fixture.
    
    When ``--no-render`` is active, returns a lightweight
    :class:`ShaderGenWrapper` that only needs the CPU-based shader
    generator (no OpenGL context).  Otherwise resolves the full
    ``glsl_renderer`` fixture on demand.
    """
    if cli_options.no_render:
        from rendertest.mtlxutils.mxrenderer import ShaderGenWrapper
        return ShaderGenWrapper(stdlib, search_path)
    return request.getfixturevalue("glsl_renderer")


# ---------------------------------------------------------------------------
# RenderEnvironment fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def stdlib_env(renderer, stdlib, search_path, cli_options):
    """RenderEnvironment for ASWF standard library materials tests."""
    from test_render import RenderEnvironment
    return RenderEnvironment(
        renderer=renderer,
        data_library=stdlib,
        search_path=search_path,
        cli_options=cli_options,
        env_subpath=Path("renders"),
    )


@pytest.fixture(scope="session")
def adsk_env(renderer, data_library, search_path, cli_options):
    """RenderEnvironment for Autodesk materials tests.

    Shares the ``renders/`` env_subpath with stdlib -- the ``adsk/``
    prefix lives in each :class:`RenderTestCase`'s ``output_subpath``.
    """
    from test_render import RenderEnvironment
    return RenderEnvironment(
        renderer=renderer,
        data_library=data_library,
        search_path=search_path,
        cli_options=cli_options,
        env_subpath=Path("renders"),
    )


# ---------------------------------------------------------------------------
# HTML report hooks
# ---------------------------------------------------------------------------

from collections import defaultdict

_pytest_config = None


def pytest_configure(config):
    """Store pytest config globally so we can access options in hooks."""
    global _pytest_config
    _pytest_config = config


_node_funcargs = {}
_subtest_html_extras = defaultdict(list)


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Capture funcargs for each test item for use in logreport."""
    outcome = yield
    report = outcome.get_result()
    _node_funcargs[item.nodeid] = item.funcargs


@pytest.hookimpl(tryfirst=True)
def pytest_runtest_logreport(report):
    """Append visual comparisons for failed subtests to the HTML report."""
    if type(report).__name__ == "SubtestReport" and report.failed:
        try:
            from pytest_html import extras
        except ImportError:
            return
            
        funcargs = _node_funcargs.get(report.nodeid)
        if not funcargs:
            return
            
        mtlx_file = funcargs.get("mtlx_file")
        if not mtlx_file:
            return
            
        # Extract the RenderEnvironment from funcargs
        from test_render import RenderEnvironment
        env = None
        for arg_val in funcargs.values():
            if isinstance(arg_val, RenderEnvironment):
                env = arg_val
                break
        if not env:
            return

        output_dir = env.output_dir

        context = getattr(report, "context", None)
        subtest_name = context.msg if context else None
        if not subtest_name:
            return

        # Try to find the test case to get output_subpath
        from test_render import RenderTestCase
        case = funcargs.get("case")
        if isinstance(case, RenderTestCase):
            output_path = env.get_output_path(case)
        elif mtlx_file:
            output_path = env.get_output_path_for_file(mtlx_file)
        else:
            return

        if not output_path or not output_path.exists():
            return
            
        # Find the rendered file
        import MaterialX as mx
        valid_elem_name = mx.createValidName(subtest_name)
        rendered_files = list(output_path.glob(f"{valid_elem_name}_*.png"))
        rendered_files = [
            f for f in rendered_files if not f.name.endswith("_diff.png")
        ]

        if not rendered_files:
            return
            
        rendered_file = rendered_files[0]
        
        # Heatmap path (no cross-env baseline comparison in HTML report)
        baseline_file = None
        heatmap_file = rendered_file.parent / f"{rendered_file.stem}_diff.png"
        
        # Determine HTML report directory to compute relative paths for images
        import os
        try:
            htmlpath_str = (
                _pytest_config.getoption("htmlpath")
                if _pytest_config
                else None
            )
        except ValueError:
            htmlpath_str = None
        html_dir = (
            Path(htmlpath_str).parent.resolve() if htmlpath_str else None
        )

        try:
            is_self_contained = (
                _pytest_config.getoption("self_contained_html")
                if _pytest_config
                else False
            )
        except ValueError:
            is_self_contained = False
        
        def get_image_src(path: Path) -> str:
            if not path or not path.exists():
                return ""
            if is_self_contained:
                import base64
                try:
                    with open(path, "rb") as f:
                        encoded = base64.b64encode(f.read()).decode("utf-8")
                        return f"data:image/png;base64,{encoded}"
                except Exception:
                    pass
            elif html_dir:
                try:
                    return os.path.relpath(
                        path.resolve(), html_dir,
                    ).replace("\\", "/")
                except ValueError:
                    return path.resolve().as_uri()
            return path.resolve().as_uri()
            
        rendered_src = get_image_src(rendered_file)
        baseline_src = get_image_src(baseline_file)
        heatmap_src = get_image_src(heatmap_file)
        
        if not rendered_src:
            return
            
        if baseline_src:
            baseline_img_tag = (
                f'<img src="{baseline_src}" style="max-width: 100%; '
                f'height: auto; border: 1px solid #ccc; border-radius: 4px;" />'
            )
        else:
            baseline_img_tag = (
                '<div style="padding: 50px 10px; background: #eee; '
                'border: 1px dashed #ccc; border-radius: 4px; color: #666; '
                'font-size: 12px;">Baseline image missing</div>'
            )

        if heatmap_src:
            heatmap_img_tag = (
                f'<img src="{heatmap_src}" style="max-width: 100%; '
                f'height: auto; border: 1px solid #ccc; border-radius: 4px;" />'
            )
        else:
            heatmap_img_tag = (
                '<div style="padding: 50px 10px; background: #eee; '
                'border: 1px dashed #ccc; border-radius: 4px; color: #666; '
                'font-size: 12px;">No heatmap (comparison passed or skipped)</div>'
            )

        html_content = f"""
        <div style="margin-top: 15px; padding: 15px; border: 1px solid #e74c3c; border-radius: 6px; background: #fdf2f2; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
            <h4 style="margin: 0 0 12px 0; color: #c0392b; font-size: 14px;">Visual Comparison for {subtest_name}</h4>
            <div style="display: flex; gap: 15px; flex-wrap: wrap;">
                <div style="flex: 1; min-width: 220px; text-align: center;">
                    <div style="font-weight: bold; margin-bottom: 6px; font-size: 12px; color: #555;">Baseline (Reference)</div>
                    {baseline_img_tag}
                </div>
                <div style="flex: 1; min-width: 220px; text-align: center;">
                    <div style="font-weight: bold; margin-bottom: 6px; font-size: 12px; color: #555;">Rendered (Current)</div>
                    <img src="{rendered_src}" style="max-width: 100%; height: auto; border: 1px solid #ccc; border-radius: 4px;" />
                </div>
                <div style="flex: 1; min-width: 220px; text-align: center;">
                    <div style="font-weight: bold; margin-bottom: 6px; font-size: 12px; color: #555;">FLIP Heatmap</div>
                    {heatmap_img_tag}
                </div>
            </div>
        </div>
        """
        _subtest_html_extras[report.nodeid].append(extras.html(html_content))

    elif type(report).__name__ == "TestReport" and report.when == "teardown":
        if report.nodeid in _subtest_html_extras:
            try:
                from pytest_html import extras
            except ImportError:
                return
            extra = getattr(report, "extras", [])
            extra.extend(_subtest_html_extras[report.nodeid])
            report.extras = extra
            del _subtest_html_extras[report.nodeid]
