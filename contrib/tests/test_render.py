"""
Render tests for MaterialX materials.

Uses pytest-subtests for hierarchical test reporting:
- Fast collection: just glob for .mtlx files
- Granular reporting: each element is a subtest
- Clear identification of which materials have issues
"""
import pytest
import MaterialX as mx
import MaterialX.PyMaterialXGenShader as mx_gen_shader
import MaterialX.PyMaterialXRender as mx_render
import struct as struct_module
from pathlib import Path

from rendertest.mtlxutils.render_material import render_material


def get_repo_root() -> Path:
    """Get MaterialX repository root."""
    return Path(__file__).parent.parent.parent


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


def render_element(renderer, doc, elem, search_path, output_path=None):
    """Render a single element and return (success, error_msg, output_file)."""
    result = render_material(
        renderer,
        doc,
        elem,
        output_path=output_path,
        search_path=search_path
    )
    
    if result.success:
        return True, None, getattr(result, "output_path", None)
    else:
        return False, result.error or result.shader_errors or "Unknown error", None


_seen_stems: dict[str, set[str]] = {}


def run_render_test_file(
    mtlx_file: Path,
    subtests,
    renderer,
    data_library,
    search_path,
    assert_image_matches_baseline,
    output_path: Path,
    relative_base_dir: Path | None = None
):
    doc = mx.createDocument()
    mx.readFromXmlFile(doc, str(mtlx_file))
    doc.setDataLibrary(data_library)
    
    valid, msg = doc.validate()
    assert valid, f"Document validation failed: {msg}"
    
    stem = mtlx_file.stem
    dir_key = str(output_path.parent.resolve())
    stems_for_dir = _seen_stems.setdefault(dir_key, set())
    assert stem not in stems_for_dir, (
        f"Output directory collision: '{stem}' was already used by another .mtlx file. "
        f"Current file: {mtlx_file}"
    )
    stems_for_dir.add(stem)

    # Set up search path
    file_search_path = mx.FileSearchPath(search_path.asString())
    file_search_path.append(str(mtlx_file.parent.resolve()))
    
    # Test each renderable element as a subtest
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
    
    for elem, elem_name in elements:
        with subtests.test(msg=elem_name):
            if is_adsk:
                # Skip Proceduralwood due to relative include issues
                if "Proceduralwood" in str(rel_path):
                    pytest.skip("adsklib relative includes require source build layout")
            else:
                if should_skip_element(rel_path, elem_name):
                    pytest.skip(get_element_skip_reason(rel_path, elem_name))
                    
            success, error, rendered_file = render_element(
                renderer, doc, elem, file_search_path, output_path=output_path
            )
            assert success, f"Render failed: {error}"
            
            assert_image_matches_baseline(rendered_file, base_dir=relative_base_dir)


class RenderEnvironment:
    """Encapsulates a specific MaterialX render execution environment."""
    
    def __init__(
        self,
        renderer,
        data_library: mx.Document,
        search_path: mx.FileSearchPath,
        output_dir: Path,
        assert_image_matches_baseline,
        flat_layout: bool = True,
    ):
        self.renderer = renderer
        self.data_library = data_library
        self.search_path = search_path
        self.output_dir = output_dir
        self.assert_image_matches_baseline = assert_image_matches_baseline
        self.flat_layout = flat_layout

    def get_output_path(self, mtlx_file: Path) -> Path:
        if self.flat_layout:
            return self.output_dir / mtlx_file.stem
            
        repo_root = get_repo_root()
        materials_root = repo_root / "resources" / "Materials"
        materials_dir = repo_root / "contrib" / "adsk" / "resources" / "Materials"
        
        if mtlx_file.is_relative_to(materials_dir):
            rel_path = mtlx_file.relative_to(materials_dir)
        elif mtlx_file.is_relative_to(materials_root):
            rel_path = mtlx_file.relative_to(materials_root)
        else:
            rel_path = Path(mtlx_file.name)
            
        return self.output_dir / rel_path.parent / mtlx_file.stem

    def run_test(self, mtlx_file: Path, subtests):
        """Run the render test for a single MaterialX file."""
        run_render_test_file(
            mtlx_file=mtlx_file,
            subtests=subtests,
            renderer=self.renderer,
            data_library=self.data_library,
            search_path=self.search_path,
            assert_image_matches_baseline=self.assert_image_matches_baseline,
            output_path=self.get_output_path(mtlx_file),
            relative_base_dir=self.output_dir
        )


class TestRenderStdlibMaterials:
    """
    Test rendering of standard MaterialX library materials.
    
    Covers resources/Materials/TestSuite and resources/Materials/Examples,
    matching the same test cases run by MaterialXTest/Catch2/CTest.
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
