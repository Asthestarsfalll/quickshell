add_executable(clavis-rapl-helper
    main.cpp
)
target_compile_features(clavis-rapl-helper PRIVATE cxx_std_17)
set_target_properties(clavis-rapl-helper PROPERTIES
    CXX_EXTENSIONS OFF
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)
install(
    TARGETS clavis-rapl-helper
    RUNTIME DESTINATION ${CLAVIS_SHARE_INSTALL_DIR}/libexec
)
