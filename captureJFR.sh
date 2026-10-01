#!/usr/bin/env bash
# Capture a separate, timed JFR recording for each supplied JVM PID.
# Supports Red Hat Linux and macOS with Bash 3.2 or newer.
# Requires a JDK with JFR support (Oracle JDK 8 or a suitable OpenJDK build).
# Run on the JVM host as the operating-system user that owns the JVMs.
# Use jcmd from a JDK matching the target JVM version.
set -uo pipefail

usage() {
    cat <<'EOF'
Usage: bash capture_jfr.sh PID [PID ...]
Platforms: Red Hat Linux and macOS; Bash 3.2 or newer.

Examples:
  bash capture_jfr.sh 1111 2222 3333 4444 5555
  DURATION=10m OUTPUT_DIR=/tmp/jfr bash capture_jfr.sh 1111 2222

Environment options:
  DURATION    Recording duration: positive integer followed by s, m, or h (default: 5m)
  SETTINGS    default or profile (default: profile)
  OUTPUT_DIR  Parent output directory (default: ./jfr_output)
  JCMD        Path to jcmd (default: JAVA_HOME/bin/jcmd, otherwise jcmd on PATH)
  UNLOCK_COMMERCIAL  auto, true, or false (default: auto)
                    auto: unlock only if JFR.start reports commercial features locked
                    true: unlock before starting; false: never unlock

Oracle JDK 8u40+ can unlock JFR at runtime. Earlier Oracle JDK 8 releases
require -XX:+UnlockCommercialFeatures -XX:+FlightRecorder at JVM startup.

Starts recordings in parallel and exits after reporting each start result.
Each JVM automatically stops and writes its .jfr file after DURATION.
A successful exit confirms recordings started, not that capture has finished.
Exit codes: 0 = all started; 1 = one or more failed; 2 = invalid input/setup.
EOF
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    usage
    exit 0
fi
if (( $# == 0 )); then usage >&2; exit 2; fi

duration=${DURATION:-5m}
settings=${SETTINGS:-profile}
output_dir=${OUTPUT_DIR:-./jfr_output}
jcmd_bin=${JCMD:-${JAVA_HOME:+$JAVA_HOME/bin/}jcmd}
unlock_commercial=${UNLOCK_COMMERCIAL:-auto}
[[ $duration =~ ^[1-9][0-9]*[smh]$ ]] || die 'DURATION must be like 60s, 5m, or 1h.'
[[ $settings == default || $settings == profile ]] || die 'SETTINGS must be default or profile.'
[[ $unlock_commercial == auto || $unlock_commercial == true || $unlock_commercial == false ]] ||
    die 'UNLOCK_COMMERCIAL must be auto, true, or false.'
command -v "$jcmd_bin" >/dev/null 2>&1 || die "jcmd not found: $jcmd_bin. Set JAVA_HOME or JCMD."

pids=()
for pid in "$@"; do
    # Normalize pasted nonbreaking spaces and trim whitespace at the edges.
    pid=${pid//$'\xc2\xa0'/ }
    pid=${pid#"${pid%%[![:space:]]*}"}
    pid=${pid%"${pid##*[![:space:]]}"}
    [[ $pid =~ ^[1-9][0-9]*$ ]] || die "Invalid PID: $pid"
    # Bash before 4.4 treats an empty array as unset under set -u.
    for previous in ${pids[@]+"${pids[@]}"}; do
        [[ $pid != "$previous" ]] || die "Duplicate PID: $pid"
    done
    pids+=("$pid")
done

# A distinct directory prevents overwriting recordings from previous runs.
umask 077
mkdir -p -- "$output_dir" || die "Cannot create directory: $output_dir"
output_dir=$(cd -- "$output_dir" && pwd -P) || die 'Cannot resolve output directory.'
# jcmd uses double quotes to preserve spaces in its filename argument.
[[ $output_dir != *'"'* && $output_dir != *'\'* && $output_dir != *$'\n'* ]] ||
    die 'OUTPUT_DIR cannot contain double quotes, backslashes, or newlines.'
run_dir=$(mktemp -d "$output_dir/capture_$(date +%Y%m%d_%H%M%S)_XXXXXX") || die 'Cannot create run directory.'
run_id=${run_dir##*/}

printf 'Duration: %s | Settings: %s\nOutput: %s\n' "$duration" "$settings" "$run_dir"
printf 'The JVM user must have write access to this directory.\n\n'

jobs=()
for pid in "${pids[@]}"; do
    (
        recording="$run_dir/pid_${pid}.jfr"
        log="$run_dir/pid_${pid}.log"
        : >"$log" || exit 1
        start_recording() {
            command_status=0
            response=$("$jcmd_bin" "$pid" JFR.start "name=${run_id}_${pid}" \
                "settings=$settings" "duration=$duration" dumponexit=true \
                "filename=\"$recording\"" 2>&1) || command_status=$?
            printf '\nJFR.start (exit %s):\n%s\n' "$command_status" "$response" >>"$log"
            # Some jcmd versions return zero even when a diagnostic command fails.
            [[ $command_status == 0 && $response == *'Started recording'* ]]
        }
        unlock_features() {
            printf '\nVM.unlock_commercial_features:\n' >>"$log"
            "$jcmd_bin" "$pid" VM.unlock_commercial_features >>"$log" 2>&1
        }
        if [[ $unlock_commercial == true ]]; then
            unlock_features || exit 1
        fi
        start_recording && exit 0
        if [[ $unlock_commercial == auto &&
              $response == *[Cc][Oo][Mm][Mm][Ee][Rr][Cc][Ii][Aa][Ll]* &&
              $response == *[Uu][Nn][Ll][Oo][Cc][Kk]* ]]; then
            # Retry only this JVM, and only once; preserve both attempts in its log.
            unlock_features || exit 1
            start_recording && exit 0
        fi
        exit 1
    ) &
    jobs+=("$!")
done

failed=0
for (( i=0; i<${#pids[@]}; i++ )); do
    pid=${pids[$i]}
    if wait "${jobs[$i]}"; then
        printf 'STARTED PID %s -> %s/pid_%s.jfr\n' "$pid" "$run_dir" "$pid"
    else
        printf 'FAILED  PID %s; see %s/pid_%s.log\n' "$pid" "$run_dir" "$pid" >&2
        failed=$((failed + 1))
    fi
done

printf '\nStarted: %s/%s. Files are written when each recording ends.\n' \
    "$((${#pids[@]} - failed))" "${#pids[@]}"
(( failed == 0 ))
