# CollectJFR
Collect JFR for multiple WebLogic Server pids in one go

Usage:

JCMD=/path/to/weblogic-jdk/bin/jcmd \

DURATION=5m OUTPUT_DIR=/tmp/jfr \

./capture_jfr.sh 12845 2723 2724

NOTE:
