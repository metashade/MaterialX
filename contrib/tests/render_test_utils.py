"""
Utility functions for MaterialX rendering tests.
"""
from pathlib import Path
import pytest
import MaterialX as mx
import MaterialX.PyMaterialXGenShader as mx_gen_shader
import MaterialX.PyMaterialXRender as mx_render


def get_repo_root() -> Path:
    """Get MaterialX repository root."""
    return Path(__file__).parent.parent.parent


def get_output_path_for_file(mtlx_file: Path, output_dir: Path) -> Path:
    """Derive the output directory path for a given material file."""
    repo_root = get_repo_root()
    materials_root = repo_root / "resources" / "Materials"
    materials_dir = repo_root / "contrib" / "adsk" / "resources" / "Materials"
    
    if mtlx_file.is_relative_to(materials_root):
        rel_path = mtlx_file.relative_to(materials_root)
    elif mtlx_file.is_relative_to(materials_dir):
        rel_path = mtlx_file.relative_to(materials_dir)
    else:
        return None
        
    return output_dir / rel_path.parent / mtlx_file.stem


def _add_stream_if_missing(mesh, name, attr_type, index, stride, fill_func):
    """Helper to create and add a mesh stream if it doesn't exist."""
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
    
    This mirrors the C++ addAdditionalTestStreams() in RenderUtil.cpp,
    adding geometry attributes needed by geompropvalue, streams, and
    struct_texcoord tests.
    """
    import struct as struct_module
    
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


# Element skip patterns
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


def get_stdlib_files():
    """
    Get list of stdlib .mtlx files for parametrization.
    
    Fast collection - just globs for files, no parsing.
    """
    repo_root = get_repo_root()
    materials_root = repo_root / "resources" / "Materials"
    
    test_dirs = [
        materials_root / "TestSuite",
        materials_root / "Examples",
    ]
    
    files = []
    for test_dir in test_dirs:
        if test_dir.exists():
            for mtlx_file in sorted(test_dir.rglob("*.mtlx")):
                if not mtlx_file.name.startswith("_"):
                    rel_path = mtlx_file.relative_to(materials_root)
                    file_id = str(rel_path).replace("\\", "/")
                    files.append(pytest.param(mtlx_file, id=file_id))
    
    return files


def get_adsk_files():
    """
    Get list of adsk .mtlx files for parametrization.
    
    Fast collection - just globs for files, no parsing.
    """
    repo_root = get_repo_root()
    materials_dir = repo_root / "contrib" / "adsk" / "resources" / "Materials"
    
    if not materials_dir.exists():
        return []
    
    files = []
    for mtlx_file in sorted(materials_dir.rglob("*.mtlx")):
        rel_path = mtlx_file.relative_to(materials_dir)
        file_id = str(rel_path).replace("\\", "/")
        files.append(pytest.param(mtlx_file, id=file_id))
    
    return files


def compare_rendered_image(rendered_path: Path, baseline_path: Path, heatmap_path: Path = None) -> dict:
    """
    Compare a rendered image against a baseline image using NVIDIA FLIP.
    
    Returns a dictionary with comparison results:
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
        # Run FLIP evaluation (LDR mode, sRGB input)
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

    # Percentage of pixels with perceptible difference (FLIP > 0.01)
    diff_pixels = flip_map > 0.01
    pct_diff_pixels = 100.0 * diff_pixels.sum() / diff_pixels.size

    result = {
        'success': True,
        'mean_flip': float(mean_flip),
        'max_flip': max_flip,
        'pct_diff_pixels': pct_diff_pixels,
        'error': None,
        'heatmap_path': None
    }

    # Save heatmap if requested
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
