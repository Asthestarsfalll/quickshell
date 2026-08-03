# 纯底层可复用的架构层。RuntimeCore 先定义，供其他 core target 共享。
qt_add_library(ClavisRuntimeCore STATIC)
target_sources(ClavisRuntimeCore PRIVATE
    runtime/clavis_paths.h
    runtime/clavis_paths.cpp
)
set_target_properties(ClavisRuntimeCore PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_link_libraries(ClavisRuntimeCore PRIVATE Qt6::Core Qt6::Network)
target_include_directories(ClavisRuntimeCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisWeatherMapCore STATIC)
target_sources(ClavisWeatherMapCore PRIVATE
    weather_map_provider.h
    weather_map_provider.cpp
)

set_target_properties(ClavisWeatherMapCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisWeatherMapCore PRIVATE
    ClavisRuntimeCore
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6Keychain::Qt6Keychain
)
target_include_directories(ClavisWeatherMapCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisNiriCore STATIC)
target_sources(ClavisNiriCore PRIVATE
    niri_types.h
    niri_cast_parser.h
    niri_cast_parser.cpp
    niri_icon_lookup.h
    niri_icon_lookup.cpp
    niri_ipc_client.h
    niri_ipc_client.cpp
    niri_workspace_deriver.h
    niri_workspace_deriver.cpp
    niri_workspace_model.h
    niri_workspace_model.cpp
    niri_window_model.h
    niri_window_model.cpp
    niri_output_model.h
    niri_output_model.cpp
)

set_target_properties(ClavisNiriCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisNiriCore PRIVATE
    Qt6::Core
    Qt6::Network
)
target_include_directories(ClavisNiriCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisAudioCore STATIC)
target_sources(ClavisAudioCore PRIVATE
    audio_collector.h
    audio_collector.cpp
    audio_level_collector.h
    audio_level_collector.cpp
    audio_visual_analyzer.h
    audio_visual_analyzer.cpp
)

set_target_properties(ClavisAudioCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisAudioCore PRIVATE
    Qt6::Core
    PkgConfig::Pipewire
)
target_include_directories(ClavisAudioCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisMediaCore STATIC)
target_sources(ClavisMediaCore PRIVATE
    media_palette_backend.h
    media_palette_backend.cpp
)

set_target_properties(ClavisMediaCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisMediaCore PRIVATE
    Qt6::Core
    Qt6::Gui
)
target_include_directories(ClavisMediaCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# Material 3 expressive shape geometry and morphing backend.  The vendored
# source is kept in its own subdirectory because it requires C++20 while the
# rest of ClavisCore intentionally remains on C++17.
add_subdirectory(m3shapes)
