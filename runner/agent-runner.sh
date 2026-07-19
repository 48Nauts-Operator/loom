#!/usr/bin/env bash
# Loom reference runner — the agent step of a Weave.
#
# This is the script Loom syncs into the sandbox and runs. It reads the goal
# (.loom-goal.txt) and optional model (.loom-model.txt) that the caller places
# in the working directory, launches the coding agent (claude by default, or
# codex), and streams a readable, secret-redacted log to .agent.log until the
# agent finishes.
#
# In xNAUT this exact script is embedded in `nautloom.rs` and run via `gitvm
# run` inside an agent-desktop sandbox. It is reproduced here as the reference
# runner — a standalone `loom` CLI is the roadmap (see README).
cd /workspace 2>/dev/null || cd .
: > .agent.log

# stream-json emits one JSON event per message/tool-call AS IT HAPPENS — unlike
# `--verbose` alone, which prints only the final result at the very end. A tiny
# jq formatter turns each event into a readable line; raw JSON if jq is missing.
cat > .agent-fmt.sh <<'FMT'
#!/usr/bin/env bash
# Redact secrets BEFORE anything hits the log: credentials in URLs
# (scheme://user:pass@host) and KEY=value / "key": "value" shapes for
# password/secret/token/api-key names. The log is persisted + streamed to the UI.
redact() {
  sed -Eu \
    -e 's#(://[^/:@[:space:]]+:)[^@[:space:]]+@#\1*****@#g' \
    -e 's#(([Pp]assword|PASSWORD|[Pp]asswd|[Ss]ecret|SECRET|[Tt]oken|TOKEN|[Aa]pi[_-]?[Kk]ey|API[_-]?KEY|[Aa]ccess[_-]?[Kk]ey)["'"'"']?[[:space:]]*[=:][[:space:]]*["'"'"']?)[^[:space:]"'"'"']+#\1*****#g'
}
if [ "$1" != "raw" ] && command -v jq >/dev/null 2>&1; then
  jq -rc 'if .type=="assistant" then (.message.content[]? | if .type=="text" then .text elif .type=="tool_use" then "· "+.name+"  "+((.input.command // .input.file_path // .input.pattern // .input.description // "")|tostring|.[0:140]) else empty end) elif .type=="result" then "[done] "+((.num_turns//0)|tostring)+" turns · "+(((.duration_ms//0)/1000)|floor|tostring)+"s" else empty end' 2>/dev/null | redact
else
  redact
fi
FMT
chmod +x .agent-fmt.sh

MODEL="$(cat .loom-model.txt 2>/dev/null | tr -d '[:space:]')"
# "codex" (or codex:<model>) switches the executor CLI; codex output is already
# plain text, so it skips the stream-json formatter.
case "$MODEL" in
  codex*)
    AGENT="codex exec --dangerously-bypass-approvals-and-sandbox \"\$(cat .loom-goal.txt)\" 2>&1 | ./.agent-fmt.sh raw"
    ;;
  *)
    MF=""; [ -n "$MODEL" ] && MF="--model $MODEL"
    AGENT="claude -p --verbose --output-format stream-json $MF --dangerously-skip-permissions \"\$(cat .loom-goal.txt)\" 2>&1 | ./.agent-fmt.sh"
    ;;
esac

if ! command -v tmux >/dev/null 2>&1; then sudo apt-get install -y -q tmux >/dev/null 2>&1 || true; fi
if command -v tmux >/dev/null 2>&1; then
  tmux kill-session -t nautloom 2>/dev/null || true
  tmux new-session -d -s nautloom "cd /workspace && $AGENT | tee -a .agent.log; echo __AGENT_DONE__ >> .agent.log"
  DISPLAY=:0 setsid xfce4-terminal --maximize --title 'Loom agent' --command 'tmux attach -t nautloom' >/dev/null 2>&1 &
  echo "tmux: nautloom  ·  attach: gitvm ssh, then  tmux attach -t nautloom"
else
  printf '%s\n' "cd /workspace && $AGENT" > .agent-cmd.sh
  DISPLAY=:0 setsid xfce4-terminal --maximize --title 'Loom agent' --command "bash -lc 'tail -f /workspace/.agent.log'" >/dev/null 2>&1 &
  # PTY via `script` so the pipe stays line-buffered and streams live.
  setsid bash -c 'script -qefc "bash /workspace/.agent-cmd.sh" /dev/null >> /workspace/.agent.log 2>&1; echo __AGENT_DONE__ >> /workspace/.agent.log' >/dev/null 2>&1 &
  echo "watch: gitvm ssh, then  tail -f /workspace/.agent.log"
fi

tail -f .agent.log &
TP=$!
for _ in $(seq 1 5400); do grep -q __AGENT_DONE__ .agent.log && break; sleep 1; done
kill $TP 2>/dev/null
echo "[agent step complete]"
