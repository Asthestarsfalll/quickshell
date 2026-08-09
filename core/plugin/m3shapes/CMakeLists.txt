# Native Material 3 expressive shape QML module, vendored from soramanew/m3shapes.
# Keep the URI and output directory stable: existing QML imports `M3Shapes`.
qt_add_qml_module(M3Shapes
    URI M3Shapes
    SOURCES
        src/MaterialShapeItem.hpp
        src/MaterialShapeItem.cpp
        src/SmoothShapeMaterial.hpp
        src/SmoothShapeMaterial.cpp
    OUTPUT_DIRECTORY ${CLAVIS_QML_BUILD_DIR}/M3Shapes
)

# Compile and embed the analytic-antialiasing shaders at the resource paths
# consumed by SmoothShapeMaterial.cpp.
qt_add_shaders(M3Shapes "m3shapes_shaders"
    PREFIX "/m3shapes"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}"
    FILES
        shaders/smoothshape.vert
        shaders/smoothshape.frag
)

target_compile_features(M3Shapes PUBLIC cxx_std_20)
set_target_properties(M3Shapes PROPERTIES CXX_EXTENSIONS OFF)

target_include_directories(M3Shapes PUBLIC
    src
    ${CLAVIS_SOURCE_ROOT}/core/src
)

target_link_libraries(M3Shapes PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    M3ShapesCore
    M3ShapesMorph
    M3ShapesGeometry
)
