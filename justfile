set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set default-list

# Show all development workflows in Chinese without taking action
help-zh:
    @printf '%s\n' \
    '可用命令：' \
    '    dev         停止当前 Clavis Shell，并从源码启动支持热重载的开发实例' \
    '    dev-native  增量编译 C++ 与原生 QML 插件，并启动源码开发实例' \
    '    dn          dev-native 的简短别名' \
    '    build       使用 setup.sh 配置并构建正式构件，不创建 release' \
    '    test        使用 setup.sh 构建并运行完整 CTest，不创建 release' \
    '    doctor      只读检查构建与运行依赖，不安装软件' \
    '    install     构建、测试并安装新的不可变用户级 release' \
    '    releases    列出已安装的 release 与当前版本，不修改任何 release' \
    '    help-zh     显示中文命令帮助，不执行任何操作'

# Replace the active Shell and run Quickshell directly from source with hot reload
dev:
    key shell --dev --replace

# Incrementally build native components and replace the active Shell with a source development instance
dev-native:
    key shell --dev --native --replace

# Short alias for dev-native
alias dn := dev-native

# Configure and build release components without creating a release
build:
    ./setup.sh build

# Build the project and run the complete CTest suite without creating a release
test:
    ./setup.sh test

# Check build and runtime dependencies without installing software
doctor:
    ./setup.sh doctor

# Build, test, and install a new immutable user-level release
install:
    ./setup.sh install

# Show the current version and list all installed releases
releases:
    key version --json
    key release list
