#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

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

service=Services/DefaultApplicationsService.qml
page=Modules/ControlCenter/DefaultAppsPage.qml
general=Modules/ControlCenter/GeneralPage.qml
overview=Modules/ControlCenter/GeneralOverviewPage.qml

for file in "$service" "$page" "$general" "$overview"; do
    test -f "$file" || fail "missing default applications file: $file"
done

assert_contains "$general" 'case "default-apps": return Qt.resolvedUrl("DefaultAppsPage.qml")'
assert_contains "$general" 'case "default-apps": return qsTr("默认应用")'
assert_contains "$overview" 'root.sectionRequested("default-apps")'
assert_contains "$overview" 'iconName: "apps"'
assert_contains "$page" 'SearchSelectMenuField'
assert_contains "$page" 'DefaultApplicationsService.refresh()'
assert_contains "$page" 'DefaultApplicationsService.setRole'

if rg -n '"id": "default-apps"|DefaultAppsPage\.qml' \
        Modules/ControlCenter/ControlCenterWindow.qml >/dev/null; then
    fail "default apps must remain a General subpage, not a navigation-rail page"
fi

for role in browser mail file-manager terminal text-editor pdf-reader \
    image-viewer video-player music-player; do
    assert_contains "$service" "\"id\": \"$role\""
    assert_contains "$page" "roleId: \"$role\""
done

for mime in \
    'x-scheme-handler/https' \
    'x-scheme-handler/mailto' \
    'inode/directory' \
    'text/plain' \
    'application/pdf' \
    'image/png' \
    'video/mp4' \
    'audio/mpeg'; do
    assert_contains "$service" "\"$mime\""
done

assert_contains "$service" '"primaryMime": ""'
assert_contains "$service" '"mimes": []'
assert_contains "$service" 'StandardPaths.ConfigLocation'
assert_contains "$service" 'xdg-terminals.list'
assert_contains "$service" 'FileView {'
assert_contains "$service" 'atomicWrites: true'
assert_contains "$service" 'function terminalDefault(content)'
assert_contains "$service" 'function rewriteTerminalList(content, selectedId)'
assert_contains "$service" 'function syncCategoryCandidates()'
assert_contains "$service" 'id: terminalWatcher'
assert_contains "$service" 'onFileChanged: terminalWatcher.reload()'
assert_contains "$service" 'onSaved:'

assert_contains "$service" '["xdg-mime", "query", "default", definition.primaryMime]'
assert_contains "$service" '["xdg-mime", "default", normalized, definition.mimes[0]]'
assert_contains "$service" '["env", "LC_ALL=C", "gio", "mime", definition.primaryMime]'
assert_contains "$service" 'ApplicationService.findById'
assert_contains "$service" 'ApplicationService.getVisibleApplications'
assert_contains "$service" 'DesktopEntries.heuristicLookup'
assert_contains "$service" '"category": "WebBrowser"'
assert_contains "$service" '"category": "FileManager"'
assert_contains "$service" '"category": "TerminalEmulator"'
assert_contains "$service" 'if (definition.category === ""'

for file in "$service" "$page"; do
    for forbidden in 'sh -c' 'bash -c' 'sudo' 'pkexec' 'python' 'DMS Chooser' \
        'dms-open' 'x-scheme-handler/calendar' 'x-scheme-handler/geo'; do
        assert_not_contains "$file" "$forbidden"
    done
done

assert_not_contains Services/PersonalizationConfig.qml 'DefaultApplicationsService'
assert_not_contains Services/PersonalizationConfig.qml 'xdg-terminals.list'

echo "default applications architecture audit passed"
