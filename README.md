# CollectJFR

Capture JFR for multiple WebLogic JVMs
capture_jfr.sh starts JFR recordings in parallel for the supplied PIDs and saves a separate .jfr file and log for each JVM. Designed for Linux and macOS with Bash 3.2+.
JDK 8 and higher JDKs
For WLS 12.2.1.4 on Oracle JDK 8, JFR was commonly enabled using these two JVM startup arguments:
-XX:+UnlockCommercialFeatures -XX:+FlightRecorder
With Oracle JDK 8u40+, this script can enable JFR dynamically even when WebLogic was started without these arguments. If the recording attempt reports locked commercial features, the script runs VM.unlock_commercial_features and retries once. No restart is needed for this runtime unlocking. It does not modify WebLogic startup arguments.
Oracle JDK 8 releases before 8u40 still require the startup arguments. The script cannot override JFR being explicitly disabled or missing from a JVM build.
On JDK 11/17/21 with JFR support, recording starts directly; no commercial unlocking is needed. Keep UNLOCK_COMMERCIAL=auto, the default. The same script can capture WLS 14.1.2 and 15.1.1 on their certified JDK 17/21 configurations.
Usage
Run on the JVM host as the JVM owner. Set JAVA_HOME to the JDK running WebLogic, or specify its jcmd using JCMD.
export JAVA_HOME=/path/to/weblogic-jdk
bash capture_jfr.sh 12845 2723 2724
Five JVMs, ten-minute recording, custom output directory:
DURATION=10m OUTPUT_DIR=/tmp/jfr \
bash capture_jfr.sh 1111 2222 3333 4444 5555
Defaults: 5 minutes, profile settings, ./jfr_output, automatic unlocking.
Optional settings:
JCMD=/path/to/jdk/bin/jcmd SETTINGS=default DURATION=60s \
bash capture_jfr.sh 12845 2723
The script exits after starting recordings. Each JVM continues recording and saves its file when the duration ends. The printed run directory contains pid_<PID>.jfr and pid_<PID>.log; inspect the log if a start fails.
Use separate invocations for JVMs running under different JDK installations or operating-system users. JVM attach must be available, and the output directory must be writable.
Exit codes: 0 = all started; 1 = one or more starts failed; 2 = invalid input/setup. A successful start does not verify final file creation.
bash capture_jfr.sh --help
Compatibility is based on documented JFR commands and simulated tests; live WebLogic capture has not been tested here.
