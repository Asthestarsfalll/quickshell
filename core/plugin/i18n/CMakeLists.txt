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

qt_add_translations(ClavisI18n
    TS_FILES
        ${CLAVIS_SOURCE_ROOT}/i18n/clavis_en_US.ts
        ${CLAVIS_SOURCE_ROOT}/i18n/clavis_zh_CN.ts
        ${CLAVIS_SOURCE_ROOT}/i18n/clavis_zh_TW.ts
    RESOURCE_PREFIX "/i18n"
)

target_include_directories(ClavisI18n PUBLIC src)

target_link_libraries(ClavisI18n PRIVATE
    Qt6::Core
    Qt6::Qml
)
