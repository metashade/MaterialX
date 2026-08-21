"""
Render tests for MaterialX materials.

Uses pytest-subtests for hierarchical test reporting:
- Fast collection: just glob for .mtlx files
- Granular reporting: each element is a subtest
- Clear identification of which materials have issues
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pytest
import MaterialX as mx
import MaterialX.PyMaterialXGenShader as mx_gen_shader
import MaterialX.PyMaterialXRender as mx_render
import struct as struct_module

from rendertest.mtlxutils.render_material import render_material


# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class MaterialXTestOptions:
    """Parsed ``_options.mtlx`` configuration from MaterialXTest.

    Consumed at collection time and renderer initialization.
    """
    render_test_paths: tuple[str, ...]
    exclude_files: frozenset[str]
    override_files: frozenset[str]
    env_sample_count: int


@dataclass(frozen=True)
class RenderTestCase:
    """A single material file paired with its output subpath.

    Built at collection time so the input-to-output mapping is fixed
    before any test runs.  ``output_subpath`` is relative to the
    environment's output directory
    (``output_root / env_subpath / output_subpath``).
    """
    input_path: Path
    output_subpath: Path


@dataclass(frozen=True)
class CliOptions:
    """Immutable CLI-derived options shared across all test environments.

    ``output_root`` is the top-level directory for all test output.
    In developer mode it defaults to ``contrib/`` (repo-relative) so
    that renders land in committed directories.  CI overrides it via
    ``--output-dir`` to write to a temp directory.

    ``no_render`` suppresses GPU rendering; tests only generate shaders
    and run source-level comparisons.
    """
    output_root: Path
    no_render: bool = False
    flip_threshold: float = 0.05


# ---------------------------------------------------------------------------
# _options.mtlx parsing and file collection
# ---------------------------------------------------------------------------

def get_repo_root() -> Path:
    """Get MaterialX repository root."""
    return Path(__file__).parent.parent.parent


def _get_options_mtlx_path() -> Path:
    return (
        get_repo_root()
        / "resources"
        / "Materials"
        / "TestSuite"
        / "_options.mtlx"
    )


def parse_options_mtlx(
    options_path: Path | None = None,
) -> MaterialXTestOptions:
    """Parse ``_options.mtlx`` and return the MaterialXTest configuration."""
    if options_path is None:
        options_path = _get_options_mtlx_path()

    try:
        doc = mx.createDocument()
        mx.readFromXmlFile(doc, str(options_path))
        nodedef = doc.getNodeDef("TestSuiteOptions")

        def _split(name: str) -> list[str]:
            raw = nodedef.getInput(name).getValueString()
            return [s.strip() for s in raw.split(",") if s.strip()]

        return MaterialXTestOptions(
            render_test_paths=tuple(_split("renderTestPaths")),
            exclude_files=frozenset(_split("renderTestExcludeFiles")),
            override_files=frozenset(_split("overrideFiles")),
            env_sample_count=nodedef.getInput("envSampleCount").getValue(),
        )
    except Exception as exc:
        raise RuntimeError(
            f"Failed to parse _options.mtlx at {options_path}"
        ) from exc


def _accept_file(
    mtlx_file: Path,
    exclude_files: frozenset[str],
    override_files: frozenset[str],
) -> bool:
    """Apply ``overrideFiles`` as an include filter (when non-empty)
    or ``renderTestExcludeFiles`` as an exclude filter, mirroring C++
    ``ShaderRenderTester::collectTestFiles()``."""
    if override_files:
        return mtlx_file.name in override_files
    return mtlx_file.name not in exclude_files


def collect_aswf_test_files(
    options: MaterialXTestOptions | None = None,
    repo_root: Path | None = None,
) -> list:
    """Collect ASWF ``.mtlx`` files as :class:`RenderTestCase` pytest params.

    Uses the ``_options.mtlx`` render test scope.  Flat layout: each
    asset's ``output_subpath`` is ``aswf/<stem>``.
    """
    if options is None:
        options = parse_options_mtlx()
    if repo_root is None:
        repo_root = get_repo_root()

    materials_root = repo_root / "resources" / "Materials"
    seen: dict[str, Path] = {}
    files: list = []

    def _add(mtlx_file: Path):
        subpath = Path("aswf") / mtlx_file.stem
        key = str(subpath)
        if key in seen:
            raise ValueError(
                f"Output path collision: '{key}' maps to both "
                f"{seen[key]} and {mtlx_file}"
            )
        seen[key] = mtlx_file
        rel_path = mtlx_file.relative_to(materials_root)
        file_id = str(rel_path).replace("\\", "/")
        case = RenderTestCase(input_path=mtlx_file, output_subpath=subpath)
        files.append(pytest.param(case, id=file_id))

    for rel_root in options.render_test_paths:
        root = repo_root / rel_root
        if root.is_file():
            if root.suffix == ".mtlx" and _accept_file(
                root, options.exclude_files, options.override_files,
            ):
                _add(root)
        elif root.is_dir():
            for mtlx_file in sorted(root.rglob("*.mtlx")):
                if _accept_file(
                    mtlx_file, options.exclude_files, options.override_files,
                ):
                    _add(mtlx_file)

    assert files, (
        f"collect_aswf_test_files found no .mtlx files. "
        f"renderTestPaths={options.render_test_paths}, repo_root={repo_root}"
    )
    return files


def collect_adsk_test_files(
    repo_root: Path | None = None,
) -> list:
    """Collect Autodesk ``.mtlx`` files as :class:`RenderTestCase` pytest params.

    Hierarchical layout: each asset's ``output_subpath`` preserves
    the directory structure under ``adsk/``.
    """
    if repo_root is None:
        repo_root = get_repo_root()

    materials_root = (
        repo_root / "contrib" / "adsk" / "resources" / "Materials"
    )
    if not materials_root.exists():
        return []

    seen: dict[str, Path] = {}
    files: list = []
    for mtlx_file in sorted(materials_root.rglob("*.mtlx")):
        rel = mtlx_file.relative_to(materials_root)
        subpath = Path("adsk") / rel.parent / mtlx_file.stem
        key = str(subpath).replace("\\", "/")
        if key in seen:
            raise ValueError(
                f"Output path collision: '{key}' maps to both "
                f"{seen[key]} and {mtlx_file}"
            )
        seen[key] = mtlx_file
        file_id = f"adsk/{str(rel).replace(chr(92), '/')}"
        case = RenderTestCase(input_path=mtlx_file, output_subpath=subpath)
        files.append(pytest.param(case, id=file_id))

    return files


# ---------------------------------------------------------------------------
# Skip patterns
# ---------------------------------------------------------------------------

_SKIP_PATTERNS = {
    "struct_texcoord": "Struct texcoord tests need special handling",
    "upgrade": "Syntax upgrade test - may have compatibility issues",
}


def should_skip_element(rel_path: Path, elem_name: str) -> bool:
    """Check if an element should be skipped based on path patterns."""
    path_str = str(rel_path)
    for pattern in _SKIP_PATTERNS:
        if pattern in path_str:
            return True
    return False


def get_element_skip_reason(rel_path: Path, elem_name: str) -> str:
    """Get the skip reason for an element."""
    path_str = str(rel_path)
    for pattern, reason in _SKIP_PATTERNS.items():
        if pattern in path_str:
            return reason
    return "Unknown"


# ---------------------------------------------------------------------------
# Geometry stream helpers
# ---------------------------------------------------------------------------

def _add_stream_if_missing(mesh, name, attr_type, index, stride, fill_func):
    if mesh.getStream(name):
        return
    stream = mx_render.MeshStream.create(name, attr_type, index)
    stream.setStride(stride)
    stream.resize(mesh.getVertexCount() * stride)
    fill_func(stream.getData())
    mesh.addStream(stream)


def add_additional_test_streams(mesh):
    """
    Add additional test streams required by MaterialX test suite.
    
    This is a Python equivalent of the C++ addAdditionalTestStreams() in
    RenderUtil.cpp, adding geometry attributes needed by geompropvalue,
    streams, and struct_texcoord tests. Note that the generated patterns
    may not have exact bit-for-bit parity with the C++ implementation.
    """
    n = mesh.getVertexCount()
    if n < 1:
        return
    
    # Get existing UV data for generating test data
    uv_stream = mesh.getStream(f"i_{mx_render.MeshStream.TEXCOORD_ATTRIBUTE}_0")
    if not uv_stream:
        return
    uv = uv_stream.getData()
    
    TEXCOORD = mx_render.MeshStream.TEXCOORD_ATTRIBUTE
    COLOR = mx_render.MeshStream.COLOR_ATTRIBUTE
    GEOMPROP = mx_render.MeshStream.GEOMETRY_PROPERTY_ATTRIBUTE
    
    # Second UV set - copy from texcoord0
    _add_stream_if_missing(mesh, f"i_{TEXCOORD}_1", TEXCOORD, 1, 2,
        lambda d: [d.__setitem__(i, uv[i]) for i in range(len(uv))])
    
    # Vertex colors - RGBA from UV
    def fill_color0(d):
        for i in range(n):
            d[i*4], d[i*4+1], d[i*4+2], d[i*4+3] = uv[i*2], uv[i*2+1], 1.0, 1.0
    _add_stream_if_missing(mesh, f"i_{COLOR}_0", COLOR, 0, 4, fill_color0)
    
    def fill_color1(d):
        for i in range(n):
            d[i*4], d[i*4+1], d[i*4+2], d[i*4+3] = 1.0-uv[i*2], 1.0-uv[i*2+1], 0.0, 1.0
    _add_stream_if_missing(mesh, f"i_{COLOR}_1", COLOR, 1, 4, fill_color1)
    
    # Geometry properties for geompropvalue tests
    def fill_int(d):
        for i in range(n):
            d[i] = struct_module.unpack('f', struct_module.pack('i', i % 10))[0]
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_integer", GEOMPROP, 0, 1, fill_int)
    
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_float", GEOMPROP, 1, 1,
        lambda d: [d.__setitem__(i, uv[i*2]) for i in range(n)])
    
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_vector2", GEOMPROP, 1, 2,
        lambda d: [d.__setitem__(i, uv[i]) for i in range(len(uv))])
    
    def fill_vec3(d):
        for i in range(n):
            d[i*3], d[i*3+1], d[i*3+2] = uv[i*2], uv[i*2+1], 0.0
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_vector3", GEOMPROP, 1, 3, fill_vec3)
    
    def fill_vec4(d):
        for i in range(n):
            d[i*4], d[i*4+1], d[i*4+2], d[i*4+3] = uv[i*2], uv[i*2+1], 0.0, 1.0
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_vector4", GEOMPROP, 1, 4, fill_vec4)
    
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_color2", GEOMPROP, 1, 2,
        lambda d: [d.__setitem__(i, uv[i]) for i in range(len(uv))])
    
    def fill_color3(d):
        for i in range(n):
            d[i*3], d[i*3+1], d[i*3+2] = uv[i*2], uv[i*2+1], 1.0
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_color3", GEOMPROP, 1, 3, fill_color3)
    
    def fill_color4(d):
        for i in range(n):
            d[i*4], d[i*4+1], d[i*4+2], d[i*4+3] = uv[i*2], uv[i*2+1], 1.0, 1.0
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_color4", GEOMPROP, 1, 4, fill_color4)


# ---------------------------------------------------------------------------
# Rendering helpers
# ---------------------------------------------------------------------------

def find_renderable_elements(doc):
    """
    Find all renderable elements in a document.
    
    Returns list of (element, name) tuples.
    Materials with shader nodes come first, then other renderables.
    """
    elements = []
    
    # Material nodes with shaders
    for elem in doc.getMaterialNodes():
        if mx.getShaderNodes(elem):
            elements.append((elem, elem.getName()))
    
    # If no materials, check for renderable outputs
    if not elements:
        for elem in mx_gen_shader.findRenderableElements(doc, False):
            elements.append((elem, elem.getNamePath()))
    
    return elements


def compare_rendered_image(
    rendered_path: Path, baseline_path: Path,
    heatmap_path: Path | None = None,
) -> dict:
    """Compare a rendered image against a baseline using NVIDIA FLIP.

    Returns a dict with ``success``, ``mean_flip``, ``max_flip``,
    ``pct_diff_pixels``, ``error``, and ``heatmap_path`` keys.
    """
    if not rendered_path.exists():
        return {'success': False, 'error': f"Rendered image not found: {rendered_path}"}
    if not baseline_path.exists():
        return {'success': False, 'error': f"Baseline image not found: {baseline_path}"}

    try:
        import flip_evaluator as flip
        import numpy as np
    except ImportError as e:
        return {'success': False, 'error': f"Required packages missing: {e}"}

    try:
        flip_map, mean_flip, _ = flip.evaluate(
            str(baseline_path),
            str(rendered_path),
            "LDR",
            inputsRGB=True,
            applyMagma=False,
            computeMeanError=True,
            parameters={"ppd": 70.0}
        )
    except Exception as e:
        return {'success': False, 'error': f"FLIP evaluation failed: {e}"}

    flip_map = np.array(flip_map)
    max_flip = float(flip_map.max())
    diff_pixels = flip_map > 0.01
    pct_diff_pixels = 100.0 * diff_pixels.sum() / diff_pixels.size

    result = {
        'success': True,
        'mean_flip': float(mean_flip),
        'max_flip': max_flip,
        'pct_diff_pixels': pct_diff_pixels,
        'error': None,
        'heatmap_path': None,
    }

    if heatmap_path:
        try:
            heatmap_img, _, _ = flip.evaluate(
                str(baseline_path),
                str(rendered_path),
                "LDR",
                inputsRGB=True,
                applyMagma=True,
                computeMeanError=False,
                parameters={"ppd": 70.0}
            )
            from PIL import Image
            heatmap_arr = np.array(heatmap_img)
            if heatmap_arr.max() <= 1.0:
                heatmap_arr = (heatmap_arr * 255).astype(np.uint8)
            Image.fromarray(heatmap_arr).save(heatmap_path)
            result['heatmap_path'] = heatmap_path
        except Exception as e:
            result['error'] = f"Failed to save heatmap: {e}"

    return result


def render_element(
    renderer, doc, elem, search_path, output_path=None, no_render=False,
):
    """Render a single element and return a :class:`RenderResult`."""
    return render_material(
        renderer,
        doc,
        elem,
        output_path=output_path,
        search_path=search_path,
        no_render=no_render,
    )


# ---------------------------------------------------------------------------
# Shader baseline comparison (RefDiffer)
# ---------------------------------------------------------------------------

class _RefDiffer:
    """Assert a generated file matches a committed reference.

    Mirrors ``metashade.util.testing.RefDiffer``.
    """
    def __init__(self, ref_dir: Path):
        self._ref_dir = ref_dir

    def __call__(self, path: Path):
        import filecmp
        ref = self._ref_dir / path.name
        assert ref.exists(), (
            f"No committed baseline for {path.name} at {ref}"
        )
        assert filecmp.cmp(path, ref, shallow=False), (
            f"Shader source mismatch: {path.name} differs from "
            f"baseline at {ref}"
        )


def _check_shader_baselines(result, baseline_dir: Path):
    """Compare dumped shaders against committed baselines.

    Only runs in CI mode (when ``output_root`` differs from the
    committed ``contrib/`` tree).  In developer mode the shaders
    overwrite baselines directly and ``git diff`` serves this purpose.
    """
    if not result.shader_dump_paths:
        return
    differ = _RefDiffer(baseline_dir)
    for dump_path in result.shader_dump_paths.values():
        differ(dump_path)


# ---------------------------------------------------------------------------
# Image comparison
# ---------------------------------------------------------------------------

def _compare_render(result, image_ref_dir: Path, threshold: float):
    """Compare a rendered image against the reference environment's render.

    Uses NVIDIA FLIP to compute a perceptual difference metric and
    saves a magma heatmap (``*_diff.png``) next to the rendered image.
    Asserts that the mean FLIP error is within *threshold*.  Skips
    gracefully when reference images are missing.

    Requires ``flip_evaluator`` (``pip install flip-evaluator``).
    """
    if not result.output_path or not result.output_path.exists():
        return

    ref_image = image_ref_dir / result.output_path.name
    if not ref_image.exists():
        pytest.skip(
            f"Reference render not found: {ref_image}\n"
            f"Run the reference environment first."
        )

    import flip_evaluator as flip
    import numpy as np

    flip_map, mean_flip, _ = flip.evaluate(
        str(ref_image), str(result.output_path),
        "LDR", inputsRGB=True, applyMagma=False,
        computeMeanError=True, parameters={"ppd": 70.0},
    )

    mean_flip = float(mean_flip)
    if mean_flip <= threshold:
        return

    max_flip = float(np.array(flip_map).max())

    heatmap_path = result.output_path.parent / f"{result.output_path.stem}_diff.png"
    heatmap_img, _, _ = flip.evaluate(
        str(ref_image), str(result.output_path),
        "LDR", inputsRGB=True, applyMagma=True,
        computeMeanError=False, parameters={"ppd": 70.0},
    )
    from PIL import Image
    heatmap_arr = np.array(heatmap_img)
    if heatmap_arr.max() <= 1.0:
        heatmap_arr = (heatmap_arr * 255).astype(np.uint8)
    Image.fromarray(heatmap_arr).save(heatmap_path)

    assert False, (
        f"FLIP mean {mean_flip:.6f} exceeds threshold {threshold:.6f} "
        f"(max {max_flip:.6f}) for {result.output_path.name}\n"
        f"  ref:      {ref_image}\n"
        f"  rendered: {result.output_path}\n"
        f"  heatmap:  {heatmap_path}"
    )


# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

def _render_elements(
    mtlx_file: Path,
    output_path: Path,
    subtests,
    env: RenderEnvironment,
):
    """Core render loop shared by both test-case and legacy-file runners."""
    doc = mx.createDocument()
    mx.readFromXmlFile(doc, str(mtlx_file))
    doc.setDataLibrary(env.data_library)

    valid, msg = doc.validate()
    assert valid, f"Document validation failed: {msg}"

    file_search_path = mx.FileSearchPath(env.search_path.asString())
    file_search_path.append(str(mtlx_file.parent.resolve()))

    elements = find_renderable_elements(doc)
    if not elements:
        pytest.skip("No renderable elements in file")

    repo_root = get_repo_root()
    materials_root = repo_root / "resources" / "Materials"
    materials_dir = repo_root / "contrib" / "adsk" / "resources" / "Materials"

    if mtlx_file.is_relative_to(materials_root):
        rel_path = mtlx_file.relative_to(materials_root)
        is_adsk = False
    elif mtlx_file.is_relative_to(materials_dir):
        rel_path = mtlx_file.relative_to(materials_dir)
        is_adsk = True
    else:
        rel_path = Path(mtlx_file.name)
        is_adsk = False

    output_path.mkdir(parents=True, exist_ok=True)

    no_render = env.cli_options.no_render
    baseline_dir = env.get_baseline_dir(output_path)
    image_ref_dir = env.get_image_ref_dir(output_path)

    for elem, elem_name in elements:
        with subtests.test(msg=elem_name):
            if is_adsk:
                if "Proceduralwood" in str(rel_path):
                    pytest.skip(
                        "adsklib relative includes require source build layout"
                    )
            else:
                if should_skip_element(rel_path, elem_name):
                    pytest.skip(get_element_skip_reason(rel_path, elem_name))

            result = render_element(
                env.renderer, doc, elem, file_search_path,
                output_path=output_path,
                no_render=no_render,
            )
            assert result.success, (
                f"{'Shader generation' if no_render else 'Render'} failed: "
                f"{result.error or result.shader_errors or 'Unknown error'}"
            )

            if baseline_dir is not None:
                _check_shader_baselines(result, baseline_dir)

            if image_ref_dir is not None and not no_render:
                _compare_render(
                    result, image_ref_dir,
                    env.cli_options.flip_threshold,
                )


def run_render_test(
    case: RenderTestCase, subtests, env: RenderEnvironment,
):
    """Run render tests for a :class:`RenderTestCase`."""
    output_path = env.get_output_path(case)
    _render_elements(case.input_path, output_path, subtests, env)


# ---------------------------------------------------------------------------
# RenderEnvironment
# ---------------------------------------------------------------------------

class RenderEnvironment:
    """Encapsulates a specific MaterialX render execution environment.

    Path structure::

        output_root / env_subpath / case.output_subpath / <element>.png

    ``output_root`` comes from :class:`CliOptions`.
    ``env_subpath`` is a fixed relative path owned by this environment.
    ``case.output_subpath`` is determined at collection time.

    When ``image_ref_env_subpath`` is set, rendered images are compared
    against the corresponding images in the reference environment's output
    tree (same ``output_root``, different ``env_subpath``).
    """

    def __init__(
        self,
        renderer,
        data_library: mx.Document,
        search_path: mx.FileSearchPath,
        cli_options: CliOptions,
        env_subpath: Path,
        image_ref_env_subpath: Path | None = None,
    ):
        self.renderer = renderer
        self.data_library = data_library
        self.search_path = search_path
        self.cli_options = cli_options
        self.env_subpath = env_subpath
        self.image_ref_env_subpath = image_ref_env_subpath

    @property
    def output_dir(self) -> Path:
        """Full output directory for this environment."""
        return self.cli_options.output_root / self.env_subpath

    @property
    def is_ci_mode(self) -> bool:
        """``True`` when output diverges from committed baselines.

        In CI mode, ``output_root`` points to a temp directory while
        committed baselines live under ``repo_root / "contrib"``.
        """
        committed_root = get_repo_root() / "contrib"
        try:
            return (
                self.cli_options.output_root.resolve()
                != committed_root.resolve()
            )
        except OSError:
            return True

    def get_output_path(self, case: RenderTestCase) -> Path:
        """Resolve the output directory for a specific test case."""
        return self.output_dir / case.output_subpath

    def get_image_ref_dir(self, output_path: Path) -> Path | None:
        """Return the reference environment's render directory for comparison.

        Maps *output_path* from this environment's subtree to the
        corresponding directory in the reference environment's subtree.
        Returns ``None`` if no image ref environment is configured.
        """
        if self.image_ref_env_subpath is None:
            return None
        try:
            rel = output_path.relative_to(self.output_dir)
        except ValueError:
            return None
        return self.cli_options.output_root / self.image_ref_env_subpath / rel

    def get_baseline_dir(self, output_path: Path) -> Path | None:
        """Return the committed baseline directory for *output_path*.

        Returns ``None`` in developer mode (output overwrites baselines
        directly, use ``git diff``).  In CI mode, maps *output_path*
        back to its committed location under ``repo_root / "contrib"``.
        """
        if not self.is_ci_mode:
            return None
        try:
            rel = output_path.relative_to(self.cli_options.output_root)
        except ValueError:
            return None
        return get_repo_root() / "contrib" / rel

    def run_test(self, case: RenderTestCase, subtests):
        """Run the render test for a single material."""
        run_render_test(case, subtests, self)


# ---------------------------------------------------------------------------
# Test classes
# ---------------------------------------------------------------------------

class TestRenderAswfMaterials:
    """Test rendering of ASWF MaterialX library materials.

    Covers ``_options.mtlx`` render test paths (StandardSurface, OpenPbr,
    UsdPreviewSurface, pbrlib BSDFs, stdlib procedurals, etc.).
    """

    @pytest.mark.parametrize("case", collect_aswf_test_files())
    def test_render(
        self,
        case: RenderTestCase,
        subtests,
        stdlib_env: RenderEnvironment,
    ):
        """Test all renderable elements in an ASWF material file."""
        stdlib_env.run_test(case, subtests)


class TestRenderAdskMaterials:
    """Test rendering of Autodesk contributed materials."""

    @pytest.mark.parametrize("case", collect_adsk_test_files())
    def test_render(
        self,
        case: RenderTestCase,
        subtests,
        adsk_env: RenderEnvironment,
    ):
        """Test all renderable elements in an Autodesk material file."""
        adsk_env.run_test(case, subtests)
