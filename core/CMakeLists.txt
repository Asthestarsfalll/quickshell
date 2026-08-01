cmake_minimum_required(VERSION 3.16)
project(ClavisCore VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)
include(CTest)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# globally enable MOC to parse Q_OBJECT macros
set(CMAKE_AUTOMOC ON)

set(CLAVIS_RELEASE "development" CACHE STRING "Clavis date release")
set(CLAVIS_COMMIT "unknown" CACHE STRING "Git commit embedded in the release")
set(CLAVIS_CHANNEL "stable" CACHE STRING "Clavis release channel")
set(CLAVIS_SOURCE_DIRTY "false" CACHE STRING "Whether the source tree was dirty")
set(CLAVIS_SOURCE_FINGERPRINT "unknown" CACHE STRING "Content fingerprint for reproducibility")
set(CLAVIS_SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/..")
get_filename_component(CLAVIS_SOURCE_ROOT "${CLAVIS_SOURCE_ROOT}" ABSOLUTE)
if(CLAVIS_COMMIT STREQUAL "unknown")
    find_package(Git QUIET)
    if(Git_FOUND)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-parse HEAD
            WORKING_DIRECTORY "${CLAVIS_SOURCE_ROOT}"
            OUTPUT_VARIABLE CLAVIS_GIT_COMMIT
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        if(CLAVIS_GIT_COMMIT)
            set(CLAVIS_COMMIT "${CLAVIS_GIT_COMMIT}")
        endif()
    endif()
endif()
if(NOT CLAVIS_BUILD_TIME)
    string(TIMESTAMP CLAVIS_BUILD_TIME "%Y-%m-%dT%H:%M:%SZ" UTC)
endif()
# Older development builds wrote release metadata at the build root, which can
# make a source-tree `key` look like an installed release. Remove only that
# obsolete generated location; installed prefixes are unaffected.
file(REMOVE "${CMAKE_BINARY_DIR}/release.json")
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/clavis_release.h.in"
    "${CMAKE_BINARY_DIR}/generated/clavis_release.h"
    @ONLY
)

set(CLAVIS_QML_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/qml")
set(CLAVIS_SHARE_INSTALL_DIR "${CMAKE_INSTALL_DATADIR}/clavis")
set(CLAVIS_LOCAL_PROFILE_SOURCE
    "${CLAVIS_SOURCE_ROOT}/local/profiles/default"
)

# Find Qt 6 basics
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Network ShaderTools LinguistTools)
find_package(Qt6Keychain REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(NCursesW IMPORTED_TARGET ncursesw REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava QUIET)
if(NOT Cava_FOUND)
    pkg_check_modules(Cava IMPORTED_TARGET cava REQUIRED)
endif()
qt_standard_project_setup(REQUIRES 6.5)

# Base reusable logic
add_subdirectory(src)

# Standalone command line tools
add_subdirectory(cli)
add_subdirectory(helper/rapl)

# A machine-local profile is intentionally ignored by Git, but local releases
# may still build and ship the user's prompt engine with the rest of Clavis.
if(EXISTS "${CLAVIS_LOCAL_PROFILE_SOURCE}/home/prompt_dev/main.cpp"
   AND EXISTS "${CLAVIS_LOCAL_PROFILE_SOURCE}/home/prompt_dev/modules.cpp")
    add_executable(clavis-prompt
        "${CLAVIS_LOCAL_PROFILE_SOURCE}/home/prompt_dev/main.cpp"
        "${CLAVIS_LOCAL_PROFILE_SOURCE}/home/prompt_dev/modules.cpp"
        "${CLAVIS_LOCAL_PROFILE_SOURCE}/home/prompt_dev/utils.h"
    )
    set_target_properties(clavis-prompt PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    )
    install(TARGETS clavis-prompt
        RUNTIME DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/libexec"
    )
endif()

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

# Quickshell plugins
add_subdirectory(plugin/sysmon)
add_subdirectory(plugin/weather)
add_subdirectory(plugin/weathermap)
add_subdirectory(plugin/niri)
add_subdirectory(plugin/audio)
add_subdirectory(plugin/media)
add_subdirectory(plugin/keyboard)
add_subdirectory(plugin/m3shapes)
add_subdirectory(plugin/i18n)
add_subdirectory(plugin/runtime)

# A release prefix is self-contained: the CLI, native QML modules and the
# Quickshell source tree are installed together and selected through `current`.
install(
    DIRECTORY "${CMAKE_BINARY_DIR}/Clavis/"
    DESTINATION "${CLAVIS_QML_INSTALL_DIR}/Clavis"
    FILES_MATCHING
        PATTERN "qmldir"
        PATTERN "*.qmltypes"
        PATTERN "*.so*"
)
install(
    DIRECTORY "${CMAKE_BINARY_DIR}/M3Shapes/"
    DESTINATION "${CLAVIS_QML_INSTALL_DIR}/M3Shapes"
    FILES_MATCHING
        PATTERN "qmldir"
        PATTERN "*.qmltypes"
        PATTERN "*.so*"
)

install(
    DIRECTORY
        "${CLAVIS_SOURCE_ROOT}/Common"
        "${CLAVIS_SOURCE_ROOT}/Components"
        "${CLAVIS_SOURCE_ROOT}/Modules"
        "${CLAVIS_SOURCE_ROOT}/Services"
        "${CLAVIS_SOURCE_ROOT}/Widgets"
    DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/qml"
    PATTERN "*.qmlc" EXCLUDE
)
install(
    FILES
        "${CLAVIS_SOURCE_ROOT}/shell.qml"
        "${CLAVIS_SOURCE_ROOT}/AppShell.qml"
        "${CLAVIS_SOURCE_ROOT}/controlcenter.qml"
    DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/qml"
)
install(
    DIRECTORY "${CLAVIS_SOURCE_ROOT}/assets/"
    DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/assets"
)
install(
    DIRECTORY "${CLAVIS_SOURCE_ROOT}/scripts/"
    DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/scripts"
    USE_SOURCE_PERMISSIONS
    PATTERN "__pycache__" EXCLUDE
    PATTERN "*.pyc" EXCLUDE
)
install(
    DIRECTORY "${CLAVIS_SOURCE_ROOT}/matugen/templates/"
    DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/defaults/matugen/templates"
)
install(
    DIRECTORY "${CLAVIS_SOURCE_ROOT}/packaging/defaults/"
    DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/defaults"
)
if(EXISTS "${CLAVIS_LOCAL_PROFILE_SOURCE}/home")
    install(
        DIRECTORY "${CLAVIS_LOCAL_PROFILE_SOURCE}/home/"
        DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/local-profile/home"
        USE_SOURCE_PERMISSIONS
    )
endif()
install(
    FILES
        "${CLAVIS_SOURCE_ROOT}/packaging/clavis-manager.py"
        "${CLAVIS_SOURCE_ROOT}/packaging/clavis_paths.py"
        "${CLAVIS_SOURCE_ROOT}/packaging/matugen_config.py"
    DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/libexec"
)
install(
    FILES
        "${CLAVIS_SOURCE_ROOT}/packaging/dependencies.toml"
    DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}"
)
install(
    DIRECTORY "${CLAVIS_SOURCE_ROOT}/systemd/user/"
    DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/systemd/user"
)
install(
    DIRECTORY "${CLAVIS_SOURCE_ROOT}/packaging/systemd/system/"
    DESTINATION "${CLAVIS_SHARE_INSTALL_DIR}/systemd/system"
)

configure_file(
    "${CLAVIS_SOURCE_ROOT}/packaging/release.json.in"
    "${CMAKE_CURRENT_BINARY_DIR}/generated/release.json"
    @ONLY
)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/generated/release.json" DESTINATION ".")
