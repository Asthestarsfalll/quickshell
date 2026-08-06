#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
page="$repo_dir/Modules/ControlCenter/AutostartPage.qml"
popup="$repo_dir/Modules/ControlCenter/AppBrowserPopup.qml"
service="$repo_dir/Services/AutostartService.qml"
applications="$repo_dir/Services/ApplicationService.qml"
spotlight="$repo_dir/Modules/Launcher/SpotlightAppProvider.qml"
control_center="$repo_dir/Modules/ControlCenter/ControlCenterWindow.qml"
helper="$repo_dir/scripts/system/manage-xdg-"'autostart.py'
helper_test="$repo_dir/tests/test_manage_xdg_"'autostart.py'

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

for file in "$page" "$popup" "$service" "$applications" "$spotlight" "$control_center"; do
    test -f "$file" || fail "missing autostart architecture file: $file"
done

test ! -e "$helper" || fail "the Python autostart helper still exists"
test ! -e "$helper_test" || fail "the Python autostart helper test still exists"

assert_contains "$service" 'StandardPaths.ConfigLocation'
assert_contains "$service" 'command: ["mkdir", "-p", root.autostartDir]'
assert_contains "$service" 'FolderListModel'
assert_contains "$service" 'nameFilters: ["*.desktop"]'
assert_contains "$service" 'atomicWrites: true'
assert_contains "$service" 'watchChanges: true'
assert_contains "$service" 'FileViewError.toString'
assert_contains "$service" 'function initialize()'
assert_contains "$page" 'Component.onCompleted: {'
assert_contains "$page" 'AutostartService.initialize();'
assert_contains "$page" 'property var parentModal: null'
assert_contains "$page" 'source: Qt.resolvedUrl("AppBrowserPopup.qml")'
assert_contains "$page" 'ApplicationService.applications'
assert_contains "$page" 'AutostartService.addApplication'
assert_contains "$page" 'AutostartService.setEnabled'
assert_contains "$page" 'AutostartService.remove'
assert_contains "$popup" 'signal appSelected(var application)'
assert_contains "$popup" 'property var parentModal: null'
assert_contains "$popup" 'parentWindow: root.parentModal'
assert_contains "$popup" 'root.focusSearch()'
assert_contains "$applications" 'DesktopEntries.applications.values'
assert_contains "$spotlight" 'ApplicationService.getVisibleApplications()'
assert_not_contains "$spotlight" 'DesktopEntries.applications.values'
assert_not_contains "$control_center" 'root.raise()'
assert_not_contains "$control_center" 'root.requestActivate()'

legacy_xdg_autostart="/etc/xdg/"autostart
legacy_xdg_dirs="XDG_CONFIG_"DIRS
legacy_config_dirs="config_"dirs
legacy_system_dir_pattern="system_"dirs
legacy_list_applications="list_"applications
legacy_add_custom="add-"custom
legacy_command_wrapper="Command"" Wrapper"
legacy_command_template="%command""%"
legacy_tray_fix="Tray"" Icon"" Fix"
legacy_exec_detached="exec"Detached
legacy_manager_path="manager"Path
legacy_helper="manage-xdg-"autostart.py
legacy_json_parse="JSON.""parse"
legacy_ensure_dir_pattern="ensure_"directory
legacy_list_process="list"Process
legacy_operation_process="operation"Process
legacy_add_application="add-"application
legacy_set_hidden="set-"hidden

for file in "$page" "$popup" "$service"; do
    for pattern in \
        "$legacy_xdg_autostart" \
        "$legacy_xdg_dirs" \
        "$legacy_config_dirs" \
        "$legacy_system_dir_pattern" \
        "$legacy_list_applications" \
        "$legacy_add_custom" \
        "$legacy_command_wrapper" \
        "$legacy_command_template" \
        "$legacy_tray_fix" \
        "$legacy_exec_detached" \
        "$legacy_manager_path" \
        "$legacy_helper" \
        "$legacy_json_parse" \
        "$legacy_ensure_dir_pattern" \
        "$legacy_list_process" \
        "$legacy_operation_process" \
        "$legacy_add_application" \
        "$legacy_set_hidden"; do
        assert_not_contains "$file" "$pattern"
    done
done

legacy_command_line="Command"" Line"
assert_not_contains "$page" "$legacy_command_line"
assert_not_contains "$page" 'commandField'
assert_not_contains "$page" 'newEntryCommandWrapper'
assert_not_contains "$popup" "raise("
assert_not_contains "$popup" "requestActivate("

printf '%s\n' 'autostart architecture audit passed'
