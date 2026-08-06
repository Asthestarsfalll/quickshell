#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
page="$repo_dir/Modules/ControlCenter/AutostartPage.qml"
popup="$repo_dir/Modules/ControlCenter/AppBrowserPopup.qml"
service="$repo_dir/Services/AutostartService.qml"
applications="$repo_dir/Services/ApplicationService.qml"
helper="$repo_dir/scripts/system/manage-xdg-autostart.py"
spotlight="$repo_dir/Modules/Launcher/SpotlightAppProvider.qml"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    rg -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

assert_not_contains() {
    if rg -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

for file in "$page" "$popup" "$service" "$applications" "$helper" "$spotlight"; do
    test -f "$file" || fail "missing autostart architecture file: $file"
done

assert_contains "$service" 'StandardPaths.ConfigLocation'
assert_contains "$service" 'Paths.systemScriptsDir + "/manage-xdg-autostart.py"'
assert_contains "$service" 'operationFinished'
assert_contains "$page" 'source: Qt.resolvedUrl("AppBrowserPopup.qml")'
assert_contains "$page" 'ApplicationService.applications'
assert_contains "$page" 'AutostartService.addApplication'
assert_contains "$page" 'AutostartService.setEnabled'
assert_contains "$page" 'AutostartService.remove'
assert_not_contains "$page" 'directoryChecked'
assert_not_contains "$page" 'directoryExists'
assert_not_contains "$page" '正在检查用户自启目录'
assert_not_contains "$page" '初始化自启目录'
assert_not_contains "$service" 'directoryChecked'
assert_not_contains "$service" 'directoryExists'
assert_not_contains "$service" 'function initialize'
assert_contains "$helper" 'ensure_directory(create=True)'
assert_not_contains "$helper" '"init"'
assert_contains "$popup" 'signal appSelected(var application)'
assert_contains "$popup" 'parentWindow: root.ownerWindow'
assert_contains "$applications" 'DesktopEntries.applications.values'
assert_contains "$spotlight" 'ApplicationService.getVisibleApplications()'
assert_not_contains "$spotlight" 'DesktopEntries.applications.values'

for file in "$page" "$popup" "$service" "$helper"; do
    for pattern in \
        '/etc/xdg/autostart' \
        'XDG_CONFIG_DIRS' \
        'config_dirs' \
        'system_dirs' \
        'list_applications' \
        'add-custom' \
        'Command Wrapper' \
        '%command%' \
        'Tray Icon Fix' \
        'execDetached'; do
        assert_not_contains "$file" "$pattern"
    done
done

assert_not_contains "$page" 'Command Line'
assert_not_contains "$page" 'commandField'
assert_not_contains "$page" 'newEntryCommandWrapper'
assert_not_contains "$helper" 'shlex'
assert_not_contains "$helper" 'XDG_DATA_DIRS'

printf '%s\n' 'autostart architecture audit passed'
