qt_add_library(ClavisI18n SHARED)

set_target_properties(ClavisI18n PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CLAVIS_QML_BUILD_DIR}/Clavis/I18n
)

qt_add_qml_module(ClavisI18n
    URI Clavis.I18n
    SOURCES
        src/i18n_manager.h
        src/i18n_manager.cpp
    OUTPUT_DIRECTORY ${CLAVIS_QML_BUILD_DIR}/Clavis/I18n
)

file(GLOB_RECURSE CLAVIS_TRANSLATION_SOURCES CONFIGURE_DEPENDS
    "${CLAVIS_SOURCE_ROOT}/Common/*.js"
    "${CLAVIS_SOURCE_ROOT}/Common/*.qml"
    "${CLAVIS_SOURCE_ROOT}/Components/*.js"
    "${CLAVIS_SOURCE_ROOT}/Components/*.qml"
    "${CLAVIS_SOURCE_ROOT}/Modules/*.js"
    "${CLAVIS_SOURCE_ROOT}/Modules/*.qml"
    "${CLAVIS_SOURCE_ROOT}/Services/*.js"
    "${CLAVIS_SOURCE_ROOT}/Services/*.qml"
    "${CLAVIS_SOURCE_ROOT}/Widgets/*.js"
    "${CLAVIS_SOURCE_ROOT}/Widgets/*.qml"
)
list(APPEND CLAVIS_TRANSLATION_SOURCES
    "${CLAVIS_SOURCE_ROOT}/AppShell.qml"
    "${CLAVIS_SOURCE_ROOT}/shell.qml"
)

qt_add_translations(ClavisI18n
    SOURCES ${CLAVIS_TRANSLATION_SOURCES}
    TS_FILES
        ${CLAVIS_SOURCE_ROOT}/i18n/clavis_en_US.ts
        ${CLAVIS_SOURCE_ROOT}/i18n/clavis_zh_CN.ts
        ${CLAVIS_SOURCE_ROOT}/i18n/clavis_zh_TW.ts
    LUPDATE_OPTIONS -no-obsolete
    RESOURCE_PREFIX "/i18n"
)

target_include_directories(ClavisI18n PUBLIC src)

target_link_libraries(ClavisI18n PRIVATE
    Qt6::Core
    Qt6::Qml
)
