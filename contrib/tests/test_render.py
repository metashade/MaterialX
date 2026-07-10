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

    Consumed at **collection time** (``collect_render_test_files``) and
    **renderer init** (``mxrenderer.initializeRenderer``).
    """
    render_test_paths: tuple[str, ...]
    exclude_files: frozenset[str]
    override_files: frozenset[str]
    env_sample_count: int


@dataclass
class CliOptions:
    """CLI-derived options that govern test execution.

    Bundles all pytest command-line options (output paths, comparison
    modes, thresholds) into a single object threaded through
    ``RenderEnvironment``.
    """
    output_dir: Path
    flat_layout: bool = True
    baseline_dir: Path | None = None
    flip_threshold: float = 0.05
    shader_baseline_dir: Path | None = None
    render_output_dir: Path | None = None


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


def collect_render_test_files(
    options: MaterialXTestOptions | None = None,
    repo_root: Path | None = None,
) -> list:
    """Collect ``.mtlx`` files matching ``_options.mtlx`` render test scope.

    Mirrors the C++ ``ShaderRenderTester::collectTestFiles()`` logic:
    walk each ``renderTestPaths`` entry, apply ``overrideFiles`` as an include
    filter (when non-empty) or ``renderTestExcludeFiles`` as an exclude filter.
    """
    if options is None:
        options = parse_options_mtlx()
    if repo_root is None:
        repo_root = get_repo_root()

    render_paths = options.render_test_paths
    exclude_files = options.exclude_files
    override_files = options.override_files

    files: list = []
    materials_root = repo_root / "resources" / "Materials"

    def _accept(mtlx_file: Path) -> bool:
        """Apply ``overrideFiles`` as an include filter (when non-empty)
        or ``renderTestExcludeFiles`` as an exclude filter, mirroring C++
        ``ShaderRenderTester::collectTestFiles()``."""
        if override_files:
            return mtlx_file.name in override_files
        return mtlx_file.name not in exclude_files

    for rel_root in render_paths:
        root = repo_root / rel_root
        if root.is_file():
            if root.suffix == ".mtlx" and _accept(root):
                rel_path = root.relative_to(materials_root)
                file_id = str(rel_path).replace("\\", "/")
                files.append(pytest.param(root, id=file_id))
        elif root.is_dir():
            for mtlx_file in sorted(root.rglob("*.mtlx")):
                if not _accept(mtlx_file):
                    continue
                rel_path = mtlx_file.relative_to(materials_root)
                file_id = str(rel_path).replace("\\", "/")
                files.append(pytest.param(mtlx_file, id=file_id))

    assert files, (
        f"collect_render_test_files found no .mtlx files. "
        f"renderTestPaths={render_paths}, repo_root={repo_root}"
    )
    return files


def collect_mtlx_files(
    materials_root: Path,
    subdirs: list[str] | None = None,
    exclude_underscore: bool = False,
) -> list:
    """Collect .mtlx files under *materials_root* as pytest params.

    Args:
        materials_root: Base directory whose relative paths become test IDs.
        subdirs: If given, only search these subdirectories (each must exist).
                 If *None*, search *materials_root* itself.
        exclude_underscore: Skip files whose name starts with ``_``.
    """
    if not materials_root.exists():
        return []

    roots = (
        [materials_root / d for d in subdirs] if subdirs else [materials_root]
    )

    files = []
    for root in roots:
        if not root.exists():
            continue
        for mtlx_file in sorted(root.rglob("*.mtlx")):
            if exclude_underscore and mtlx_file.name.startswith("_"):
                continue
            rel_path = mtlx_file.relative_to(materials_root)
            file_id = str(rel_path).replace("\\", "/")
            files.append(pytest.param(mtlx_file, id=file_id))

    return files


def get_stdlib_files():
    """Stdlib .mtlx files (TestSuite + Examples)."""
    materials_root = get_repo_root() / "resources" / "Materials"
    return collect_mtlx_files(
        materials_root,
        subdirs=["TestSuite", "Examples"],
        exclude_underscore=True,
    )


def get_adsk_files():
    """Autodesk contributed .mtlx files."""
    materials_dir = (
        get_repo_root() / "contrib" / "adsk" / "resources" / "Materials"
    )
    return collect_mtlx_files(materials_dir)


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


def render_element(renderer, doc, elem, search_path, output_path=None):
    """Render a single element and return a :class:`RenderResult`."""
    return render_material(
        renderer,
        doc,
        elem,
        output_path=output_path,
        search_path=search_path,
    )


# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

class _RefDiffer:
    """Assert a generated file matches a committed reference.

    Mirrors ``metashade.util.testing.RefDiffer`` without pulling in the
    Metashade dependency.
    """
    def __init__(self, ref_dir: Path):
        self._ref_dir = ref_dir

    def __call__(self, path: Path):
        import filecmp
        ref = self._ref_dir / path.name
        assert filecmp.cmp(path, ref), (
            f"Shader source mismatch: {path.name} differs from "
            f"baseline at {ref}"
        )


_seen_stems: dict[str, set[str]] = {}


def _handle_shader_baselines(result, stem: str, opts: CliOptions):
    """Route dumped shaders to baselines (update) or compare (CI).

    * **Update mode** (no ``render_output_dir``): copy dumped shaders into
      the committed baseline directory for ``git diff`` review.
    * **CI mode** (``render_output_dir`` set): compare dumped shaders
      against the committed baselines and assert on mismatch.
    """
    if not result.shader_dump_paths or not opts.shader_baseline_dir:
        return
    baseline_subdir = opts.shader_baseline_dir / stem
    if opts.render_output_dir:
        differ = _RefDiffer(baseline_subdir)
        for dump_path in result.shader_dump_paths.values():
            if (baseline_subdir / dump_path.name).exists():
                differ(dump_path)
    else:
        import shutil
        baseline_subdir.mkdir(parents=True, exist_ok=True)
        for dump_path in result.shader_dump_paths.values():
            shutil.copy2(dump_path, baseline_subdir / dump_path.name)


def run_render_test_file(
    mtlx_file: Path, subtests, env: RenderEnvironment,
):
    """Run render tests for all renderable elements in *mtlx_file*."""
    doc = mx.createDocument()
    mx.readFromXmlFile(doc, str(mtlx_file))
    doc.setDataLibrary(env.data_library)

    valid, msg = doc.validate()
    assert valid, f"Document validation failed: {msg}"

    stem = mtlx_file.stem
    output_path = env.get_output_path(mtlx_file)
    dir_key = str(output_path.parent.resolve())
    stems_for_dir = _seen_stems.setdefault(dir_key, set())
    assert stem not in stems_for_dir, (
        f"Output directory collision: '{stem}' was already used by another "
        f".mtlx file. Current file: {mtlx_file}"
    )
    stems_for_dir.add(stem)

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

    opts = env.options
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
            )
            assert result.success, (
                f"Render failed: "
                f"{result.error or result.shader_errors or 'Unknown error'}"
            )

            env.assert_image_matches_baseline(result.output_path)
            _handle_shader_baselines(result, stem, opts)


# ---------------------------------------------------------------------------
# RenderEnvironment
# ---------------------------------------------------------------------------

class RenderEnvironment:
    """Encapsulates a specific MaterialX render execution environment."""

    def __init__(
        self,
        renderer,
        data_library: mx.Document,
        search_path: mx.FileSearchPath,
        options: CliOptions,
    ):
        self.renderer = renderer
        self.data_library = data_library
        self.search_path = search_path
        self.options = options

    @property
    def output_dir(self) -> Path:
        """Convenience accessor used by the HTML report hook."""
        return self.options.output_dir

    def get_output_path(self, mtlx_file: Path) -> Path:
        if self.options.flat_layout:
            return self.options.output_dir / mtlx_file.stem

        repo_root = get_repo_root()
        materials_root = repo_root / "resources" / "Materials"
        materials_dir = (
            repo_root / "contrib" / "adsk" / "resources" / "Materials"
        )

        if mtlx_file.is_relative_to(materials_dir):
            rel_path = mtlx_file.relative_to(materials_dir)
        elif mtlx_file.is_relative_to(materials_root):
            rel_path = mtlx_file.relative_to(materials_root)
        else:
            rel_path = Path(mtlx_file.name)

        return self.options.output_dir / rel_path.parent / mtlx_file.stem

    def assert_image_matches_baseline(self, rendered_file: Path | None):
        """Assert rendered image matches its baseline (FLIP comparison)."""
        if not (self.options.baseline_dir and rendered_file):
            return

        rel_rendered = rendered_file.relative_to(self.options.output_dir)
        baseline_file = self.options.baseline_dir / rel_rendered
        heatmap_file = rendered_file.parent / f"{rendered_file.stem}_diff.png"

        res = compare_rendered_image(
            rendered_file, baseline_file, heatmap_path=heatmap_file,
        )
        if not res['success']:
            assert False, f"Image comparison failed: {res['error']}"

        mean_flip = res['mean_flip']
        max_flip = res['max_flip']
        pct_diff = res['pct_diff_pixels']

        assert mean_flip < self.options.flip_threshold, (
            f"Image comparison failed! Mean FLIP: {mean_flip:.4f} "
            f"(threshold: {self.options.flip_threshold}), "
            f"Max FLIP: {max_flip:.4f}, "
            f"{pct_diff:.1f}% pixels differ. "
            f"Heatmap saved to {heatmap_file.name}"
        )

    def run_test(self, mtlx_file: Path, subtests):
        """Run the render test for a single MaterialX file."""
        run_render_test_file(mtlx_file, subtests, self)


# ---------------------------------------------------------------------------
# Test classes
# ---------------------------------------------------------------------------

class TestRenderStdlibMaterials:
    """
    Test rendering of standard MaterialX library materials.
    
    Covers all ``.mtlx`` files under ``resources/Materials/TestSuite`` and
    ``resources/Materials/Examples`` (a superset of the curated paths in
    ``_options.mtlx`` used by the C++ MaterialXTest suite).
    """

    @pytest.mark.parametrize("mtlx_file", get_stdlib_files())
    def test_render_file(
        self,
        mtlx_file: Path,
        subtests,
        stdlib_env: RenderEnvironment
    ):
        """Test all renderable elements in a stdlib material file."""
        stdlib_env.run_test(mtlx_file, subtests)


class TestRenderAdskMaterials:
    """Test rendering of Autodesk contributed materials."""

    @pytest.mark.parametrize("mtlx_file", get_adsk_files())
    def test_render_file(
        self,
        mtlx_file: Path,
        subtests,
        adsk_env: RenderEnvironment
    ):
        """Test all renderable elements in an Autodesk material file."""
        adsk_env.run_test(mtlx_file, subtests)
