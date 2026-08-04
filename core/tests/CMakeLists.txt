find_package(Qt6 REQUIRED COMPONENTS Test)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
find_program(BASH_EXECUTABLE bash REQUIRED)

add_test(
    NAME shader_asset_tests
    COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/../tests/test_shader_assets.sh
)

add_test(
    NAME qml_unit_tests
    COMMAND Qt6::qmltestrunner -input ${CMAKE_SOURCE_DIR}/../tests/qml
)
set_tests_properties(qml_unit_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QPA_PLATFORMTHEME="
)

qt_add_executable(niri_workspace_deriver_tests
    niri_workspace_deriver_test.cpp
)

target_link_libraries(niri_workspace_deriver_tests PRIVATE
    ClavisNiriCore
    Qt6::Core
    Qt6::Test
)

add_test(
    NAME niri_workspace_deriver_tests
    COMMAND niri_workspace_deriver_tests
)

qt_add_executable(audio_visual_analyzer_tests
    audio_visual_analyzer_test.cpp
)

target_link_libraries(audio_visual_analyzer_tests PRIVATE
    ClavisAudioCore
    Qt6::Core
    Qt6::Test
)

add_test(NAME audio_visual_analyzer_tests COMMAND audio_visual_analyzer_tests)

qt_add_executable(clavis_paths_tests
    clavis_paths_test.cpp
)

target_link_libraries(clavis_paths_tests PRIVATE
    ClavisRuntimeCore
    Qt6::Core
    Qt6::Test
)

add_test(NAME clavis_paths_tests COMMAND clavis_paths_tests)

add_test(
    NAME niri_config_manager_tests
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/../tests/test_manage_niri_config.py
)

add_test(
    NAME xdg_autostart_manager_tests
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/../tests/test_manage_xdg_autostart.py
)

add_test(
    NAME clavis_user_service_installer_tests
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/../tests/test_install_clavis_user_services.py
)

add_test(
    NAME clavis_setup_install_tests
    COMMAND ${BASH_EXECUTABLE} ${CMAKE_SOURCE_DIR}/../tests/test_setup_install.sh
)

qt_add_executable(m3shapes_tests
    m3shapes_test.cpp
)

target_link_libraries(m3shapes_tests PRIVATE
    M3ShapesCore
    M3ShapesMorph
    M3ShapesGeometry
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Test
)

target_compile_features(m3shapes_tests PRIVATE cxx_std_20)
target_compile_definitions(m3shapes_tests PRIVATE
    M3SHAPES_IMPORT_PATH="$<SHELL_PATH:${CMAKE_BINARY_DIR}/lib/qml>"
)
add_dependencies(m3shapes_tests M3Shapes)

add_test(NAME m3shapes_tests COMMAND m3shapes_tests)
set_tests_properties(m3shapes_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)
