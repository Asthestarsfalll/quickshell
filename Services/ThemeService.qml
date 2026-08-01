pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    property bool generating: false
    property string lastSource: ""
    property var availableIconThemes: [({ "label": qsTr("系统默认"), "value": "" })]
    property var availableCursorThemes: [({ "label": qsTr("系统默认"), "value": "" })]
    property string systemDefaultIconTheme: ""
    property string systemDefaultCursorTheme: ""

    readonly property string sessionDesktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("XDG_SESSION_DESKTOP") || "").toLowerCase()
    readonly property bool isNiriSession: sessionDesktop.indexOf("niri") !== -1 || (Quickshell.env("NIRI_SOCKET") || "") !== ""

    function applyConfigToAppearance() {
        Appearance.matugenScheme = PersonalizationConfig.matugenScheme;
        Appearance.matugenMode = PersonalizationConfig.themeMode;
    }

    function setMatugenScheme(value) {
        PersonalizationConfig.setMatugenScheme(value);
        root.applyConfigToAppearance();
        root.regenerateFromCurrentWallpaper();
    }

    function enabledMatugenTemplates() {
        const enabled = [];
        for (let i = 0;
             i < PersonalizationConfig.matugenTemplateIds.length;
             i += 1) {
            const id = PersonalizationConfig.matugenTemplateIds[i];
            if (PersonalizationConfig.isMatugenTemplateEnabled(id))
                enabled.push(id);
        }
        return enabled;
    }

    function setMatugenTemplateEnabled(id, enabled) {
        let changed =
            PersonalizationConfig.setMatugenTemplateEnabled(id, enabled);
        if (id === "fcitx5") {
            changed = PersonalizationConfig.setMatugenTemplateEnabled(
                "fcitx5_panel_svg", enabled) || changed;
            changed = PersonalizationConfig.setMatugenTemplateEnabled(
                "fcitx5_highlight_svg", enabled) || changed;
        }
        if (changed && enabled)
            root.regenerateFromCurrentWallpaper();
    }

    function setThemeMode(value) {
        PersonalizationConfig.setThemeMode(value);
        root.applyConfigToAppearance();
        UiPreferences.setDarkMode(PersonalizationConfig.themeMode === "dark");
        root.regenerateFromCurrentWallpaper();
    }

    function setCursorTheme(value) {
        PersonalizationConfig.setCursorTheme(value);
        root.applyCursorSettings();
    }

    function setCursorSize(value) {
        PersonalizationConfig.setCursorSize(value);
        root.applyCursorSettings();
    }

    function setCursorHideWhenTyping(value) {
        PersonalizationConfig.setCursorHideWhenTyping(value);
        root.applyCursorSettings();
    }

    function setCursorHideAfterInactiveMs(value) {
        PersonalizationConfig.setCursorHideAfterInactiveMs(value);
        root.applyCursorSettings();
    }

    function setIconTheme(value) {
        PersonalizationConfig.setIconTheme(value);
    }

    function effectiveIconTheme() {
        return PersonalizationConfig.iconTheme !== "" ? PersonalizationConfig.iconTheme : root.systemDefaultIconTheme;
    }

    function effectiveCursorTheme() {
        return PersonalizationConfig.cursorTheme !== "" ? PersonalizationConfig.cursorTheme : root.systemDefaultCursorTheme;
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function escapeKdlString(value) {
        return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    }

    function unique(values) {
        const result = [];
        const seen = {};
        for (let i = 0; i < values.length; i += 1) {
            const value = String(values[i] || "").trim();
            if (value === "" || seen[value])
                continue;
            seen[value] = true;
            result.push(value);
        }
        return result;
    }

    function dataDirs() {
        const raw = Quickshell.env("XDG_DATA_DIRS") || "";
        const base = raw.trim() !== "" ? raw.split(":") : ["/usr/local/share", "/usr/share"];
        return root.unique(base.concat([Paths.xdgDataHome, "/usr/local/share", "/usr/share"]));
    }

    function hasOption(options, value) {
        for (let i = 0; i < options.length; i += 1) {
            if (options[i].value === value)
                return true;
        }
        return false;
    }

    function defaultOption(label, systemDefault) {
        return {
            "label": systemDefault !== "" ? label + " · " + systemDefault : label,
            "value": ""
        };
    }

    function parseDetectedThemes(output, defaultLabel, currentValue, cursorThemes) {
        let systemDefault = "";
        const names = [];
        const lines = String(output || "").split("\n");
        for (let i = 0; i < lines.length; i += 1) {
            const line = lines[i].trim();
            if (line === "")
                continue;
            if (line.indexOf("SYSDEFAULT:") === 0) {
                systemDefault = line.substring(11).trim();
                continue;
            }
            names.push(line);
        }

        if (cursorThemes)
            root.systemDefaultCursorTheme = systemDefault;
        else
            root.systemDefaultIconTheme = systemDefault;

        const options = [root.defaultOption(defaultLabel, systemDefault)];
        const sorted = root.unique(names).sort((a, b) => a.localeCompare(b));
        for (let j = 0; j < sorted.length; j += 1)
            options.push({ "label": sorted[j], "value": sorted[j] });

        if (currentValue !== "" && !root.hasOption(options, currentValue))
            options.splice(1, 0, { "label": currentValue, "value": currentValue });

        return options;
    }

    function iconThemeDetectionScript() {
        const paths = root.dataDirs().map(dir => dir + "/icons").concat([Paths.homeDir + "/.icons"]);
        const pathsArg = paths.map(path => root.shellQuote(path)).join(" ");
        return `
            printf 'SYSDEFAULT:%s\\n' "$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | sed "s/'//g" || true)"
            for dir in ${pathsArg}; do
                [ -d "$dir" ] || continue
                for theme in "$dir"/*/; do
                    [ -d "$theme" ] || continue
                    basename "$theme"
                done
            done | grep -v '^icons$' | grep -v '^default$' | grep -v '^hicolor$' | grep -v '^locolor$' | sort -u
        `;
    }

    function cursorThemeDetectionScript() {
        const paths = root.dataDirs().map(dir => dir + "/icons").concat([Paths.homeDir + "/.icons"]);
        const pathsArg = root.unique(paths).map(path => root.shellQuote(path)).join(" ");
        return `
            printf 'SYSDEFAULT:%s\\n' "$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | sed "s/'//g" || true)"
            for dir in ${pathsArg}; do
                [ -d "$dir" ] || continue
                for theme in "$dir"/*/; do
                    [ -d "$theme" ] || continue
                    [ -d "$theme/cursors" ] || continue
                    basename "$theme"
                done
            done | grep -v '^icons$' | grep -v '^default$' | sort -u
        `;
    }

    function detectAvailableThemes() {
        detectIconThemesProcess.command = ["bash", "-c", root.iconThemeDetectionScript()];
        detectCursorThemesProcess.command = ["bash", "-c", root.cursorThemeDetectionScript()];
        detectIconThemesProcess.running = false;
        detectCursorThemesProcess.running = false;
        detectIconThemesProcess.running = true;
        detectCursorThemesProcess.running = true;
    }

    function applyCursorSettings() {
        root.generateNiriCursorConfig();
    }

    function generateNiriCursorConfig() {
        const niriDmsDir = Paths.generatedHome + "/niri";
        const cursorPath = niriDmsDir + "/cursor.kdl";
        const themeName = root.effectiveCursorTheme();
        const size = PersonalizationConfig.cursorSize;
        const hideWhenTyping = PersonalizationConfig.cursorHideWhenTyping;
        const hideAfterMs = PersonalizationConfig.cursorHideAfterInactiveMs;
        const hasCursorConfig = themeName !== "" || size !== 24 || hideWhenTyping || hideAfterMs > 0;
        let content = "";

        if (hasCursorConfig) {
            content = `// ! DO NOT EDIT !
// ! AUTO-GENERATED BY CLAVIS !
// ! CHANGES WILL BE OVERWRITTEN !
// ! PLACE YOUR CUSTOM CONFIGURATION ELSEWHERE !

cursor {
`;
            if (themeName !== "")
                content += `    xcursor-theme "${root.escapeKdlString(themeName)}"\n`;
            content += `    xcursor-size ${size}\n`;
            if (hideWhenTyping)
                content += "    hide-when-typing\n";
            if (hideAfterMs > 0)
                content += `    hide-after-inactive-ms ${hideAfterMs}\n`;
            content += "}\n";
        }

        writeNiriCursorProcess.command = [
            "bash", "-c",
            "mkdir -p " + root.shellQuote(niriDmsDir) + " && printf '%s' " + root.shellQuote(content) + " > " + root.shellQuote(cursorPath)
        ];
        writeNiriCursorProcess.running = false;
        writeNiriCursorProcess.running = true;
    }

    function generateFromWallpaper(path) {
        if (!path || path === "")
            return;

        root.applyConfigToAppearance();
        root.lastSource = path;
        const command = [
            "bash", Paths.scriptPath("theme", "generate_matugen_colors.sh"),
            "--image", path,
            "--scheme", PersonalizationConfig.matugenScheme,
            "--mode", PersonalizationConfig.themeMode,
            "--templates", root.enabledMatugenTemplates().join(",")
        ];
        generateColorsProcess.command = command;
        generateColorsProcess.running = false;
        generateColorsProcess.running = true;
    }

    function opaqueHexFromColor(value) {
        const color = Qt.color(value);
        const r = Math.round(Math.max(0, Math.min(1, color.r)) * 255).toString(16).padStart(2, "0");
        const g = Math.round(Math.max(0, Math.min(1, color.g)) * 255).toString(16).padStart(2, "0");
        const b = Math.round(Math.max(0, Math.min(1, color.b)) * 255).toString(16).padStart(2, "0");
        return "#" + r + g + b;
    }

    function generateFromColor(value) {
        if (!value || value === "")
            return;

        const sourceColor = root.opaqueHexFromColor(value);
        root.applyConfigToAppearance();
        root.lastSource = value;
        const command = [
            "bash", Paths.scriptPath("theme", "generate_matugen_colors.sh"),
            "--color", sourceColor,
            "--scheme", PersonalizationConfig.matugenScheme,
            "--mode", PersonalizationConfig.themeMode,
            "--templates", root.enabledMatugenTemplates().join(",")
        ];
        generateColorsProcess.command = command;
        generateColorsProcess.running = false;
        generateColorsProcess.running = true;
    }

    function regenerateFromCurrentWallpaper() {
        const path = WallpaperService.currentWallpaper
            || PersonalizationConfig.wallpaperPath;
        if (path && path !== "" && WallpaperService.isImagePath(path))
            root.generateFromWallpaper(path);
        else if (path && path !== "" && WallpaperService.isColorSource(path))
            root.generateFromColor(path);
    }

    Component.onCompleted: {
        root.applyConfigToAppearance();
        root.detectAvailableThemes();
        if (PersonalizationConfig.themeMode === "dark" && !UiPreferences.darkMode)
            UiPreferences.setDarkMode(true);
    }

    Connections {
        target: PersonalizationConfig

        function onMatugenSchemeChanged() {
            root.applyConfigToAppearance();
        }

        function onThemeModeChanged() {
            root.applyConfigToAppearance();
        }
    }

    Process {
        id: detectIconThemesProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.availableIconThemes = root.parseDetectedThemes(this.text, qsTr("系统默认"), PersonalizationConfig.iconTheme, false);
            }
        }
    }

    Process {
        id: detectCursorThemesProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.availableCursorThemes = root.parseDetectedThemes(this.text, qsTr("系统默认"), PersonalizationConfig.cursorTheme, true);
            }
        }
    }

    Process {
        id: writeNiriCursorProcess
    }

    Process {
        id: generateColorsProcess
        onRunningChanged: if (running) root.generating = true
        onExited: exitCode => {
            root.generating = false;
            if (exitCode === 0)
                Appearance.reloadColors();
            else
                console.error("Matugen color generation failed with exit code", exitCode);
        }
    }
}
