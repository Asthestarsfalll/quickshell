set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set default-list

# Show all development workflows in Chinese without taking action
help-zh:
    @printf '%s\n' \
        '可用命令：' \
        '    shell                  切换到已安装 release Shell，后台启动后返回终端' \
        '    shell-foreground       切换到 release Shell，并在前台显示实时日志' \
        '    sf                     shell-foreground 的简短别名' \
        '    dev                    切换到源码开发 Shell，后台启动后返回终端' \
        '    dev-foreground         切换到源码开发 Shell，并在前台显示实时日志' \
        '    df                     dev-foreground 的简短别名' \
        '    dev-native             增量构建原生构件并启动开发 Shell，随后返回终端' \
        '    dn                     dev-native 的简短别名' \
        '    dev-native-foreground  增量构建原生构件，并在前台显示实时日志' \
        '    dnf                    dev-native-foreground 的简短别名' \
        '    build                  使用 setup.sh 构建正式构件，不创建 release' \
        '    test                   构建项目并运行完整 CTest，不创建 release' \
        '    doctor                 只读检查构建与运行依赖，不安装软件' \
        '    install                构建并安装 Shell-only 用户级 release（不隐式测试）' \
        '    releases               查看当前版本和所有已安装 release' \
        '    help-zh                显示中文命令帮助，不执行任何操作'

# Replace the active Shell with the installed release and return immediately
shell:
    @key shell --replace

# Run the installed release Shell in the foreground with live logs
shell-foreground:
    @key shell --replace --foreground

alias sf := shell-foreground

# Replace the active Shell with the source development runtime and return immediately
dev:
    @key shell --dev --replace

# Run the source development Shell in the foreground with live logs
dev-foreground:
    @key shell --dev --replace --foreground

alias df := dev-foreground

# Build native components, replace the active Shell, and return immediately
dev-native:
    @key shell --dev --native --replace

alias dn := dev-native

# Build native components and run the development Shell in the foreground
dev-native-foreground:
    @key shell --dev --native --replace --foreground

alias dnf := dev-native-foreground

# Configure and build release components without creating a release
build:
    ./setup.sh build

# Build the project and run the complete CTest suite without creating a release
test:
    ./setup.sh test

# Check build and runtime dependencies without installing software
doctor:
    ./setup.sh doctor

# Build and install a Shell-only user-level release without implicit tests
install:
    ./setup.sh install

# Show the current version and list all installed releases
releases:
    key version --json
    key release list
