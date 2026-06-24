"""
Render tests for MaterialX materials with Metashade overrides.

This test file runs standard library materials against a MaterialX standard library
where Metashade implementations are loaded first, forcing them to take priority
by document insertion order.
"""
from pathlib import Path
import pytest
import MaterialX as mx
from test_render import run_render_test_file, add_additional_test_streams


def get_schlick_test_files():
    """Get list of .mtlx files that directly or transitively test Schlick BSDF."""
    repo_root = Path(__file__).parent.parent.parent
    materials_root = repo_root / "resources" / "Materials"
    
    # Targeted files for direct / transitive Schlick BSDF testing
    targeted = [
        "TestSuite/pbrlib/bsdf/generalized_schlick.mtlx",
        "TestSuite/pbrlib/edf/generalized_schlick_edf.mtlx",
        "TestSuite/pbrlib/surfaceshader/lama/lama_generalized_schlick.mtlx",
        "TestSuite/pbrlib/bsdf/thin_film_bsdf.mtlx",
        "TestSuite/pbrlib/surfaceshader/surface_ops.mtlx",
        "Examples/StandardSurface/standard_surface_default.mtlx",
        "Examples/StandardSurface/standard_surface_gold.mtlx",
        "Examples/StandardSurface/standard_surface_plastic.mtlx",
    ]
    
    files = []
    for rel_path_str in targeted:
        mtlx_file = materials_root / rel_path_str
        if mtlx_file.exists():
            files.append(pytest.param(mtlx_file, id=rel_path_str))

    if not files:
        pytest.skip(
            f"No targeted Schlick test files found under {materials_root}. "
            "Check that the MaterialX resources are present."
        )

    return files


@pytest.fixture(scope="session")
def output_dir(request, repo_root) -> Path:
    """Override output_dir to place Metashade results under their own root."""
    opt = request.config.getoption("--output-dir")
    if opt:
        path = Path(opt) / "metashade_schlick"
    else:
        path = repo_root / "contrib" / "renders" / "metashade_schlick"
    path.mkdir(parents=True, exist_ok=True)
    return path


class TestRenderMetashadeSchlickOverride:
    """
    Test rendering of standard MaterialX library materials with Metashade Schlick override.
    """
    
    @pytest.fixture(scope="class")
    def schlick_search_path(self, search_path, repo_root):
        """Create a custom search path including standard library source files and Metashade overrides."""
        custom_sp = mx.FileSearchPath(search_path.asString())
        
        # 1. Add the specific standard library folder needed by the Schlick BSDF implementation.
        # Find pbrlib/genglsl under the search_path directories to match standard library include resolution.
        import os
        sep = ';' if os.name == 'nt' else ':'
        for p_str in search_path.asString().split(sep):
            p = Path(p_str)
            pbrlib_genglsl = p / "libraries" / "pbrlib" / "genglsl"
            if pbrlib_genglsl.exists():
                custom_sp.append(pbrlib_genglsl.as_posix())
                break
            # Fallback if standard libraries are in checkout
            pbrlib_genglsl_local = p / "pbrlib" / "genglsl"
            if pbrlib_genglsl_local.exists():
                custom_sp.append(pbrlib_genglsl_local.as_posix())
                break
            
        # 2. Add Metashade override path
        metashade_mtlx_path = repo_root / "contrib" / "tests" / "metashade_ref"
        if not metashade_mtlx_path.exists():
            pytest.skip(
                f"Metashade override directory not found: {metashade_mtlx_path}. "
                "Ensure the metashade_ref directory is present in contrib/tests."
            )
        custom_sp.append(metashade_mtlx_path.as_posix())

        return custom_sp

    @pytest.fixture(scope="class")
    def schlick_stdlib(self, schlick_search_path, repo_root):
        """Create a custom stdlib document with Metashade Schlick override loaded first."""
        lib = mx.createDocument()
        
        # 1. Load Metashade Schlick override first
        override_mtlx = (
            repo_root / "contrib" / "tests" / "metashade_ref"
            / "mx_generalized_schlick_bsdf_metashade_genglsl_impl.mtlx"
        )
        if not override_mtlx.exists():
            pytest.skip(
                f"Metashade Schlick override file not found: {override_mtlx}. "
                "The test cannot validate override behavior without it."
            )
        mx.readFromXmlFile(lib, override_mtlx.as_posix())
            
        # 2. Load standard libraries second
        library_folders = mx.getDefaultDataLibraryFolders()
        mx.loadLibraries(library_folders, schlick_search_path, lib)
        return lib
        
    @pytest.fixture(scope="class")
    def schlick_renderer(self, schlick_stdlib, schlick_search_path, repo_root):
        """Create a custom renderer initialized with the overridden stdlib."""
        # IBL paths
        lights_path = repo_root / "resources" / "Lights"
        radiance_path = lights_path / "san_giuseppe_bridge.hdr"
        irradiance_path = lights_path / "irradiance" / "san_giuseppe_bridge.hdr"
        
        # Geometry
        geometry_path = repo_root / "resources" / "Geometry" / "sphere.obj"
        
        # Render size
        width = height = 512
        
        from rendertest.mtlxutils import mxrenderer
        
        renderer = mxrenderer.initializeRenderer(
            schlick_stdlib,
            schlick_search_path,
            str(radiance_path),
            str(irradiance_path),
            width,
            height,
            str(geometry_path)
        )
        
        # Add test geometry streams
        geom_handler = renderer.renderer.getGeometryHandler()
        for mesh in geom_handler.getMeshes():
            add_additional_test_streams(mesh)
            
        return renderer

    @pytest.mark.parametrize("mtlx_file", get_schlick_test_files())
    def test_render_file(
        self,
        mtlx_file: Path,
        subtests,
        schlick_renderer,
        schlick_stdlib,
        schlick_search_path,
        output_dir,
        assert_image_matches_baseline
    ):
        """Test all renderable elements in a stdlib material file using the Schlick override."""
        run_render_test_file(
            mtlx_file=mtlx_file,
            subtests=subtests,
            renderer=schlick_renderer,
            data_library=schlick_stdlib,
            search_path=schlick_search_path,
            output_dir=output_dir,
            assert_image_matches_baseline=assert_image_matches_baseline
        )
