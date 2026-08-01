# ==========================================
# 1. 开机问候 (Fastfetch 搭配高精度字符画)
# ==========================================
#fastfetch

# ==========================================
# 2. 基础设置与历史记录
# ==========================================
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY

# ==========================================
# 3. 补全系统准备与启动 (极其重要的顺序)
# ==========================================
# 将额外的补全包源目录加入 fpath
fpath=(~/.zsh/plugins/zsh-completions/src $fpath)

# 初始化补全引擎
autoload -Uz compinit
compinit

# 开启原生菜单选择UI (作为 fzf-tab 的底层兜底)
zstyle ':completion:*' menu select

# ==========================================
# 4. 加载核心功能插件 (必须在 compinit 之后)
# ==========================================
for plugin in \
    ~/.zsh/plugins/fzf-tab/fzf-tab.zsh \
    ~/.zsh/plugins/z/z.sh \
    ~/.zsh/plugins/zsh-autopair/autopair.zsh \
    ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    [[ -r "$plugin" ]] && source "$plugin"
done

# ==========================================
# 5. 语法高亮 (根据官方文档，必须放在 substring-search 之前)
# ==========================================
[[ -r ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ==========================================
# 6. 历史子串搜索插件与快捷键绑定
# ==========================================
if [[ -r ~/.zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
    source ~/.zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
fi

# 官方文档推荐的配置变量：确保搜索结果不重复 (强烈建议开启)
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

# ==========================================
# Archirithm Custom Prompt
# ==========================================
# 允许 PROMPT 变量内执行命令和颜色转义
setopt PROMPT_SUBST
zmodload zsh/datetime

# Matugen prompt palette. Reset to safe defaults before sourcing the generated
# fragment so a missing, partial, or invalid file never breaks the prompt.
typeset -g CLAVIS_PROMPT_PALETTE_FILE="${CLAVIS_PROMPT_PALETTE_FILE:-${CLAVIS_GENERATED_HOME:-$HOME/.local/share/clavis/profiles/default/generated}/zsh/prompt-colors.zsh}"
typeset -gA CLAVIS_PROMPT_DEFAULT_COLORS=(
    CLAVIS_PROMPT_PATH_BG "#89B4FA"
    CLAVIS_PROMPT_PATH_FG "#1E1E2E"
    CLAVIS_PROMPT_GIT_BG "#CBA6F7"
    CLAVIS_PROMPT_GIT_FG "#1E1E2E"
    CLAVIS_PROMPT_LANG_BG "#A6E3A1"
    CLAVIS_PROMPT_LANG_FG "#1E1E2E"
    CLAVIS_PROMPT_TIME_BG "#F9E2AF"
    CLAVIS_PROMPT_TIME_FG "#1E1E2E"
    CLAVIS_PROMPT_ERROR_BG "#F38BA8"
    CLAVIS_PROMPT_ERROR_FG "#1E1E2E"
    CLAVIS_PROMPT_CONNECTOR "#A6ADC8"
    CLAVIS_PROMPT_ARROW "#A6E3A1"
)

function clavis_prompt_load_colors() {
    local name
    for name in ${(k)CLAVIS_PROMPT_DEFAULT_COLORS}; do
        typeset -gx "$name=${CLAVIS_PROMPT_DEFAULT_COLORS[$name]}"
    done

    if [[ -r "$CLAVIS_PROMPT_PALETTE_FILE" ]]; then
        source "$CLAVIS_PROMPT_PALETTE_FILE"
    fi

    for name in ${(k)CLAVIS_PROMPT_DEFAULT_COLORS}; do
        if [[ ! "${(P)name}" =~ '^#[[:xdigit:]]{6}$' ]]; then
            typeset -gx "$name=${CLAVIS_PROMPT_DEFAULT_COLORS[$name]}"
        fi
    done
}
clavis_prompt_load_colors

# 1. 记录命令开始时间
function preexec() {
    typeset -g cmd_start_time=$EPOCHREALTIME
}

# 2. 计算耗时与保存状态码 (彻底剥离静态 PROMPT 赋值)
# 2. 渲染完整提示符与计算耗时
function precmd() {
    # 捕获状态码，并声明为全局变量
    typeset -g PROMPT_EXIT_CODE=$?
    typeset -g PROMPT_CMD_DURATION=""
    clavis_prompt_load_colors

    if [[ -n $cmd_start_time ]]; then
        local cmd_end_time=$EPOCHREALTIME
        local elapsed=$(( cmd_end_time - cmd_start_time ))
        local ms=$(( elapsed * 1000 ))
        PROMPT_CMD_DURATION="${ms%.*}ms"
        if (( ms > 1000 )); then
            local sec=$(( ms / 1000.0 ))
            printf -v PROMPT_CMD_DURATION "%.1fs" $sec
        fi
        unset cmd_start_time
    fi

    local path_segment="%F{$CLAVIS_PROMPT_PATH_BG}%K{$CLAVIS_PROMPT_PATH_BG}%F{$CLAVIS_PROMPT_PATH_FG}  %~ %k%F{$CLAVIS_PROMPT_PATH_BG}%f"
    local git_segment=""
    local git_branch="$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)"
    if [[ -n "$git_branch" ]]; then
        git_segment="%F{$CLAVIS_PROMPT_CONNECTOR} 󰜥 %f%F{$CLAVIS_PROMPT_GIT_BG}%K{$CLAVIS_PROMPT_GIT_BG}%F{$CLAVIS_PROMPT_GIT_FG} 󰘬 ${git_branch//\%/%%} %k%F{$CLAVIS_PROMPT_GIT_BG}%f"
    fi
    local duration_segment=""
    if [[ -n "$PROMPT_CMD_DURATION" ]]; then
        duration_segment="%F{$CLAVIS_PROMPT_CONNECTOR} 󰜥 %f%F{$CLAVIS_PROMPT_LANG_BG}%K{$CLAVIS_PROMPT_LANG_BG}%F{$CLAVIS_PROMPT_LANG_FG} 󰔚 $PROMPT_CMD_DURATION %k%F{$CLAVIS_PROMPT_LANG_BG}%f"
    fi
    local time_bg="$CLAVIS_PROMPT_TIME_BG"
    local time_fg="$CLAVIS_PROMPT_TIME_FG"
    if (( PROMPT_EXIT_CODE != 0 )); then
        time_bg="$CLAVIS_PROMPT_ERROR_BG"
        time_fg="$CLAVIS_PROMPT_ERROR_FG"
    fi
    PROMPT="%F{$CLAVIS_PROMPT_CONNECTOR}╭─ %f${path_segment}${git_segment}${duration_segment}  %F{${time_bg}}%K{${time_bg}}%F{${time_fg}}  %D{%H:%M:%S} %k%F{${time_bg}}%f"$'\n'"%F{$CLAVIS_PROMPT_CONNECTOR}╰─ %f%F{$CLAVIS_PROMPT_ARROW} %f"
    RPROMPT=""
}

# 4. 监听窗口缩放信号 (SIGWINCH) - 专治 Niri 平铺窗口缩放 Bug
TRAPWINCH() {
    # 强制 Zsh 立即重绘当前提示符。
    if [[ -o zle ]]; then
        zle reset-prompt
    fi
}

# 5. 瞬态坍缩魔法：当你按下回车键的一瞬间
function zle-line-finish() {
    # 历史记录与完整提示词共享 Matugen 调色板。
    PROMPT="%F{$CLAVIS_PROMPT_ARROW}%f "

    RPROMPT="%F{$CLAVIS_PROMPT_TIME_BG} %D{%H:%M:%S}%f"

    zle reset-prompt
}
zle -N zle-line-finish

# ==========================================
# Eza: 现代化的 ls 替代品
# ==========================================
# 基础替换：带图标、优先显示目录、跨平台着色
alias ls='eza --icons=always --color=always --group-directories-first'

# ll: 详细列表模式 (显示权限、大小、修改时间、Git状态)
alias ll='eza -alF --icons=always --color=always --group-directories-first --git'

# la: 显示所有文件 (包括隐藏文件)
alias la='eza -a --icons=always --color=always --group-directories-first'

# lt: 树状图模式 (同款 end_4 视觉效果)
# 默认展示 2 层深度，你可以随时用 lt -L 1 覆盖它
alias lt='eza --tree --level=2 --icons=always --color=always --group-directories-first'

# lsi: 像截图里一样，只显示带图标的干净网格阵列
alias lsi='eza --icons=always --grid -a'


proxy_on() {
    export http_proxy='http://127.0.0.1:20171'
    export https_proxy='http://127.0.0.1:20171'
    export all_proxy='socks5h://127.0.0.1:20170'

    export HTTP_PROXY="$http_proxy"
    export HTTPS_PROXY="$https_proxy"
    export ALL_PROXY="$all_proxy"

    export no_proxy='localhost,127.0.0.1,::1'
    export NO_PROXY="$no_proxy"

    echo "终端代理已开启"
}

proxy_off() {
    unset http_proxy https_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
    unset no_proxy NO_PROXY

    echo "终端代理已关闭"
}

proxy_status() {
    env | grep -iE '^(http|https|all|no)_proxy=' | sort
}
