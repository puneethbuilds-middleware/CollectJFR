# CollectJFR

# Capture JFR for Multiple WebLogic JVMs

`capture_jfr.sh` starts JFR recordings in parallel for the supplied PIDs and saves a separate `.jfr` file and log for each JVM.

Works on Linux and macOS with Bash 3.2+ and a JDK with JFR support.

## JDK 8: Dynamic JFR Enablement

For **WLS 12.2.1.4 on Oracle JDK 8**, JFR was commonly enabled using these JVM startup arguments:

```text
-XX:+UnlockCommercialFeatures -XX:+FlightRecorder
```

**With Oracle JDK 8u40+, this script can enable JFR dynamically even when WebLogic started without these arguments.**

If JFR reports locked commercial features, the script runs `VM.unlock_commercial_features` and retries the recording once. No restart is needed for runtime unlocking, and WebLogic startup arguments are not modified.

Oracle JDK 8 releases before 8u40 still require the startup arguments.

## Higher JDK Versions

On **JDK 11, 17, and 21 with JFR support**, recording starts directly without commercial unlocking. Keep `UNLOCK_COMMERCIAL=auto`, the default.

The script can also capture **WLS 14.1.2 and 15.1.1 running on their certified JDK 17/21 configurations**.

## Usage

Run on the JVM host as the operating-system user that owns the JVMs. Set `JAVA_HOME` to the JDK running WebLogic.

```bash
export JAVA_HOME=/path/to/weblogic-jdk
bash capture_jfr.sh 12845 2723 2724
```

Capture five JVMs for ten minutes:

```bash
DURATION=10m OUTPUT_DIR=/tmp/jfr \
bash capture_jfr.sh 1111 2222 3333 4444 5555
```

Select a specific `jcmd` and recording settings:

```bash
JCMD=/path/to/jdk/bin/jcmd SETTINGS=default DURATION=60s \
bash capture_jfr.sh 12845 2723
```

## Options

| Environment variable | Default | Description |
|---|---|---|
| `DURATION` | `5m` | Recording duration, such as `60s`, `10m`, or `1h` |
| `SETTINGS` | `profile` | `profile` or `default` |
| `OUTPUT_DIR` | `./jfr_output` | Parent output directory |
| `JCMD` | `$JAVA_HOME/bin/jcmd`, otherwise `jcmd` on PATH | JDK diagnostic executable |
| `UNLOCK_COMMERCIAL` | `auto` | `auto`, `true`, or `false` |

## Output

Each run creates a unique directory containing:

- `pid_<PID>.jfr` — recording file, saved when the recording ends.
- `pid_<PID>.log` — command responses, including any unlock and retry attempts.

**The script exits after starting recordings. The JVMs continue recording for the configured duration.** A successful start does not verify final file creation.

Use separate invocations for JVMs using different JDK installations or operating-system users. JVM attach must be available, and the output directory must be writable.

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | All recordings started |
| `1` | One or more recording starts failed; check the PID logs |
| `2` | Invalid input or setup failure |

Display help:

```bash
bash capture_jfr.sh --help
```

Compatibility is based on documented JFR commands and simulated tests. Live WebLogic capture has not been tested in the development environment.
