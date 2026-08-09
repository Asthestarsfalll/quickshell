import QtQuick
import qs.Services

Item {
    id: root

    property string query: ""
    property var results: []
    readonly property bool loading: ClipboardService.loading
    readonly property bool available: ClipboardService.canList
        && (ClipboardService.watcherRunning
            || ClipboardService.entries.length > 0)
    readonly property bool canRestore: ClipboardService.canRestore
    readonly property bool actionRunning: ClipboardService.actionRunning
    readonly property var error: ClipboardService.error
    readonly property var resultModel: clipboardModel

    signal restored(string id)
    signal restoreFailed(string id, string code, string message)
    signal deleteFailed(string id, string code, string message)

    ListModel {
        id: clipboardModel
    }

    function mergedEntry(entry) {
        const id = String(entry.id || "");
        return ClipboardService.detail(id) || entry;
    }

    function textSummary(value) {
        const lines = String(value || "")
            .replace(/\r\n/g, "\n")
            .replace(/\r/g, "\n")
            .split("\n")
            .map(line => line.replace(/\t/g, " ").trim())
            .filter(line => line !== "");
        return lines;
    }

    function displayTitle(entry, rawPreview) {
        const kind = String(entry.payloadKind || "binary");
        if (kind === "file" || kind === "file-list") {
            const files = Array.isArray(entry.files) ? entry.files : [];
            if (files.length > 1)
                return qsTr("%n 个文件", "clipboard file count", files.length);
            if (files.length === 1 && String(files[0].name || "") !== "")
                return String(files[0].name);
            return qsTr("文件");
        }
        if (kind === "image")
            return qsTr("图片剪贴板");
        if (kind === "binary")
            return qsTr("二进制剪贴板");

        const lines = root.textSummary(rawPreview);
        if (lines.length > 0)
            return lines[0].slice(0, 240);
        if (String(entry.textSubtype || "") === "html")
            return qsTr("HTML 内容");
        return qsTr("空文本");
    }

    function displaySubtitle(entry, rawPreview) {
        const kind = String(entry.payloadKind || "binary");
        if (kind === "file" || kind === "file-list") {
            const files = Array.isArray(entry.files) ? entry.files : [];
            return files
                .slice(0, 3)
                .map(file => String(file.name || ""))
                .filter(name => name !== "")
                .join("、");
        }
        if (kind === "image") {
            const mime = String(entry.mimeType || "");
            const format = mime.indexOf("/") >= 0
                ? mime.split("/", 2)[1].toUpperCase() : "IMAGE";
            const details = [format];
            const width = Number(entry.width || 0);
            const height = Number(entry.height || 0);
            const byteSize = Number(entry.byteSize || 0);
            if (width > 0 && height > 0)
                details.push(width + "×" + height);
            if (byteSize > 0)
                details.push(byteSize + " B");
            return details.join(" · ");
        }
        if (kind === "binary") {
            const byteSize = Number(entry.byteSize || 0);
            return qsTr("未知二进制内容")
                + (byteSize > 0 ? " · " + byteSize + " B" : "");
        }

        const lines = root.textSummary(rawPreview);
        if (lines.length > 1)
            return (lines[1] + (lines.length > 2 ? "…" : "")).slice(0, 300);
        if (String(entry.textSubtype || "") === "html")
            return lines.length > 0 ? qsTr("HTML 内容") : qsTr("没有可安全显示的正文");
        return qsTr("文本");
    }

    function replaceModel(next) {
        clipboardModel.clear();
        for (let index = 0; index < next.length; index += 1)
            clipboardModel.append({ modelData: next[index] });
    }

    function resultForEntry(entry, index, sourceLength, needle) {
        const rawPreview = String(entry.preview || "");
        const searchText = String(entry.searchText || rawPreview);
        const title = root.displayTitle(entry, rawPreview);
        const subtitle = root.displaySubtitle(entry, rawPreview);
        const fileNames = Array.isArray(entry.files)
            ? entry.files.map(file => String(file.name || "")).join(" ")
            : "";
        const searchable = [
            title, subtitle, searchText, fileNames,
            String(entry.mimeType || "")
        ].join("\n").toLocaleLowerCase();
        if (needle !== "" && searchable.indexOf(needle) < 0)
            return null;

        return {
            provider: "clipboard",
            id: String(entry.id || ""),
            payloadKind: String(entry.payloadKind || "binary"),
            // Old schema-v2 CLI builds may still emit "code". Text
            // content now uses one consistent plain-text presentation.
            textSubtype: String(entry.textSubtype || "") === "code"
                ? "plain" : String(entry.textSubtype || ""),
            title: title,
            subtitle: subtitle,
            multiline: entry.multiline === true,
            lineCount: Number(entry.lineCount || 0),
            icon: String(entry.icon || "data_object"),
            preview: rawPreview,
            previewUrl: String(entry.previewUrl || ""),
            mimeType: String(entry.mimeType || ""),
            byteSize: Number(entry.byteSize || 0),
            width: Number(entry.width || 0),
            height: Number(entry.height || 0),
            fileCount: Number(entry.fileCount || 0),
            files: Array.isArray(entry.files) ? entry.files : [],
            fileOperation: entry.fileOperation || entry.operation || "",
            restorable: entry.restorable !== false,
            score: needle === "" ? sourceLength - index
                : (searchable.startsWith(needle) ? 2 : 1),
            actions: ["restore", "delete"]
        };
    }

    function rebuild() {
        const needle = String(root.query || "").trim().toLocaleLowerCase();
        // In the normal browsing view, inspection only enriches an existing
        // entry.  Keep the result collection stable so ListView can retain
        // its viewport and delegates.  Search is different: inspected text
        // can change whether an entry matches the query, so it is rebuilt
        // when details arrive.
        const useInspectedDetails = needle !== "";
        const source = ClipboardService.entries || [];
        const next = [];
        for (let index = 0; index < source.length; index += 1) {
            const entry = useInspectedDetails
                ? root.mergedEntry(source[index]) : source[index];
            const result = root.resultForEntry(
                entry, index, source.length, needle);
            if (result)
                next.push(result);
        }
        root.results = next;
        root.replaceModel(next);
    }

    function updateResult(id) {
        if (String(root.query || "").trim() !== "")
            return false;
        const normalizedId = String(id || "");
        const source = ClipboardService.entries || [];
        const sourceIndex = source.findIndex(
            entry => String(entry.id || "") === normalizedId);
        const resultIndex = root.results.findIndex(
            entry => String(entry.id || "") === normalizedId);
        if (sourceIndex < 0 || resultIndex < 0)
            return false;

        const result = root.resultForEntry(
            root.mergedEntry(source[sourceIndex]),
            sourceIndex,
            source.length,
            "");
        if (!result)
            return false;
        const next = root.results.slice();
        next[resultIndex] = result;
        clipboardModel.setProperty(resultIndex, "modelData", result);
        root.results = next;
        return true;
    }

    function removeResult(id) {
        const normalizedId = String(id || "");
        const index = root.results.findIndex(
            entry => String(entry.id || "") === normalizedId);
        if (index < 0)
            return false;
        clipboardModel.remove(index);
        const next = root.results.slice();
        next.splice(index, 1);
        root.results = next;
        return true;
    }

    function clearResults() {
        clipboardModel.clear();
        root.results = [];
    }

    function refresh() {
        ClipboardService.refresh(100);
    }

    function requestDetails(id) {
        return ClipboardService.inspect(id);
    }

    function releaseDetails(id) {
        return ClipboardService.cancelInspect(id);
    }

    function inspectSearchCandidates() {
        if (String(root.query || "").trim() === "")
            return;
        const source = ClipboardService.entries || [];
        // Inspection is serialized by ClipboardService, so a query never
        // starts an unbounded number of decoder processes concurrently.
        for (let index = 0; index < source.length; index += 1)
            ClipboardService.inspect(String(source[index].id || ""));
    }

    function execute(index) {
        const result = root.results[index];
        if (!result)
            return false;
        if (!root.canRestore) {
            const failure = ClipboardService.normalizedError(
                null,
                ClipboardService.dependencies.wlCopy
                    ? "cliphist_unavailable" : "wl_copy_unavailable",
                qsTr("剪贴板恢复不可用"));
            root.restoreFailed(result.id, failure.code, failure.message);
            return false;
        }
        if (result.restorable === false) {
            root.restoreFailed(
                result.id, "clipboard_mime_unsupported",
                qsTr("该格式无法可靠恢复"));
            return false;
        }
        return ClipboardService.restore(result.id);
    }

    function deleteEntry(index) {
        const result = root.results[index];
        return !!result && ClipboardService.deleteEntry(result.id);
    }

    function clear() {
        return ClipboardService.clear();
    }

    onQueryChanged: {
        root.rebuild();
        root.inspectSearchCandidates();
    }

    Connections {
        target: ClipboardService

        function onRevisionChanged() {
            root.rebuild();
            root.inspectSearchCandidates();
        }

        function onDetailsRevisionChanged() {
            if (String(root.query || "").trim() !== "")
                root.rebuild();
        }

        function onInspected(id) {
            root.updateResult(String(id));
        }

        function onRestored(id) {
            root.restored(String(id));
        }

        function onDeleted(id) {
            root.removeResult(String(id));
        }

        function onCleared() {
            root.clearResults();
        }

        function onActionFailed(action, id, code, message) {
            if (action === "restore")
                root.restoreFailed(String(id), String(code), String(message));
            else if (action === "delete")
                root.deleteFailed(String(id), String(code), String(message));
        }
    }
}
