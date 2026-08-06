#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

require_text() {
    grep -Fq -- "$2" "$1" || fail "$1 does not contain: $2"
}

reject_text() {
    if grep -Fq -- "$2" "$1"; then
        fail "$1 unexpectedly contains: $2"
    fi
}

if [ -e controlcenter.qml ]; then
    fail "the detached control center entry point still exists"
fi

require_text AppShell.qml 'LazyLoader {'
require_text AppShell.qml 'ControlCenterWindow {'
require_text AppShell.qml 'ControlCenterService.registerLoader'
require_text AppShell.qml 'ControlCenterService.registerWindow'
require_text AppShell.qml 'ControlCenterService.windowClosed'
require_text AppShell.qml 'target: "control-center"'
require_text Services/ControlCenterService.qml 'function open(pageId)'
require_text Services/ControlCenterService.qml 'function toggle(pageId)'
require_text Services/ControlCenterService.qml 'controlCenterLoader.active = true'
require_text Services/ControlCenterService.qml \
    'controlCenterLoader.active = false'
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'signal popoutClosed'
require_text Modules/ControlCenter/ControlCenterWindow.qml \
    'function showWindow()'

for file in \
    Modules/QuickSettings/QuickSettingsSurface.qml \
    Modules/Bar/QuickSettings/SettingsButton.qml \
    Modules/Sidebars/Left/ProfileHeaderCard.qml
do
    reject_text "$file" 'controlcenter.qml'
    require_text "$file" 'ControlCenterService.open()'
done

if rg -n 'controlcenter\.qml|qs[[:space:]]+--path|Paths\.shellDir[[:space:]]*\+[[:space:]]*"/controlcenter\.qml"' \
        AppShell.qml Modules Services core >/dev/null; then
    fail "a detached control center launch reference remains"
fi

echo "control center architecture tests passed"
