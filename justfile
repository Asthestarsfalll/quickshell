set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

root := justfile_directory()

# Show all development workflows in English without taking action
default:
    @just --list

# Show all development workflows in Chinese without taking action
help-zh:
    @printf '%s\n' \
        '可用命令：' \
        '    build              使用 setup.sh 配置并构建正式构件，不创建 release' \
        '    default            显示英文命令帮助，不执行任何操作' \
        '    dev                从源码启动 Quickshell，支持 QML 与资源热重载' \
        '    dev-native         增量编译 C++ 与原生 QML 插件后启动源码 Shell' \
        '    dev-native-replace 增量编译原生构件并停止当前 Shell 后启动开发实例' \
        '    dev-replace        停止当前 Clavis Shell 并切换到源码开发实例' \
        '    doctor             只读检查构建与运行依赖，不安装软件' \
        '    help-zh            显示中文命令帮助，不执行任何操作' \
        '    install            构建、测试并安装新的不可变用户级 release' \
        '    releases           列出已安装 release 与当前版本，不修改任何 release' \
        '    test               使用 setup.sh 构建并运行完整 CTest，不创建 release'

# Run Quickshell from source with QML and asset hot reload
dev:
    cd "{{root}}" && key shell --dev

# Stop the active Clavis Shell and replace it with a source development instance
dev-replace:
    cd "{{root}}" && key shell --dev --replace

# Incrementally build C++ and native QML plugins, then run the source Shell
dev-native:
    cd "{{root}}" && key shell --dev --native

# Incrementally build native components, stop the active Shell, and start development
dev-native-replace:
    cd "{{root}}" && key shell --dev --native --replace

# Configure and build release components through setup.sh without creating a release
build:
    cd "{{root}}" && ./setup.sh build

# Build and run the full CTest suite through setup.sh without creating a release
test:
    cd "{{root}}" && ./setup.sh test

# Check build and runtime dependencies without installing software
doctor:
    cd "{{root}}" && ./setup.sh doctor

# Build, test, and install a new immutable user-level release
install:
    cd "{{root}}" && ./setup.sh install

# List installed releases and the current version without changing releases
releases:
    cd "{{root}}" && key version --json
    cd "{{root}}" && key release list
