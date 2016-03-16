#!/bin/bash
# Created by Roel Van de Paar, Percona LLC

# User configurable variables
BASEDIR="/sda/PS-19.01.16-mysql-5.7.10-1rc1-linux-x86_64-debug"       # Base directory (should contain mysql-test directory as a first level subdirectory, see TESTS_PATH)
  # IMPORTANT NOTE: we are currently discussing an issue whereby (for builds made with make_binary_distribution) ${BASEDIR}/plugin/*/*/*/*.test files are not present.
  # For this, the only workaround is to use a source directory for ${BASEDIR}, but there may be other caveats with doing this (TBD). Maybe better is to simply build
  # everything using a build generated by make_binary_distribution, but add the ${BASEDIR}/plugin/*/*/*/*.test (generated by setting BASEDIR to a source code build) results on
  # For this, it's recommended to take a copy of mtr_to_sql.sh and simply hack it below to only look for ${BASEDIR}/plugin/*/*/*/*.test in the second run 
FINAL_SQL=/tmp/mtr_to_sql.sql                                         # pquery final SQL grammar (i.e. file name for output generated by this script)

# Information
# - Originally, there were two versions of SQL generation, and they could be selected interdependently by passing an option to this script. This new version instead uses both
#   approaches in sequence - i.e. it first adds the SQL as generated by approach #1 (ref below) to the final SQL file, and then proceeds to add the SQL as generated by approach #2
#   This results in a larger, but more varied (and thus better), final SQL file/grammar. The new version also re-parses the generated SQL and adds more storage engine variations.
# - This script no longer creates any RQG grammars; RQG use was deprecated in favor of pquery. For a historical still-working no-longer-maintained version, see mtr_to_sql_RQG.sh
# - Current Filter list
#   - Not scanning for "^REVOKE " commands as these drop access and this hinders CLI/pquery testing. However, REVOKE may work for RQG/yy (TBD)
#   - egrep -vi Inline filters
#     - 'strict': this causes corruption bugs - see http://dev.mysql.com/doc/refman/5.6/en/innodb-parameters.html#sysvar_innodb_checksum_algorithm
#     - 'innodb_track_redo_log_now'  - https://bugs.launchpad.net/percona-server/+bug/1368530
#     - 'innodb_log_checkpoint_now'  - https://bugs.launchpad.net/percona-server/+bug/1369357 (dup of 1368530)
#     - 'innodb_purge_stop_now'      - https://bugs.launchpad.net/percona-server/+bug/1368552
#     - 'innodb_track_changed_pages' - https://bugs.launchpad.net/percona-server/+bug/1368530
#     - global/session debug         - https://bugs.launchpad.net/percona-server/+bug/1372675
# - Ideas for further improvement
#   - Scan original MTR file for multi-line statements and reconstruct (tr '\n' ' ' for example) to avoid half-statements ending up in resulting file

# Internal variables
TEMP_SQL=${FINAL_SQL}.tmp
TESTS_PATH=$(echo ${BASEDIR} | sed 's|$|/mysql-test/|;s|//|/|g')

echoit(){
  echo "[$(date +'%T')] $1"
}

if [ ! -r ${TESTS_PATH}/t/1st.test ]; then
  if [ ! -r ${TESTS_PATH}/mysql-test/t/1st.test ]; then
    echoit "Something is wrong; this script cannot locate/read ${TESTS_PATH}/t/1st.test"
    echoit "You may want to check the TESTS_PATH setting at the top of this script (currently set to '${TESTS_PATH}')"
    exit 1
  else
    echoit "Found tests located at ${TESTS_PATH}/mysql-test..."
    TESTS_PATH="${TESTS_PATH}/mysql-test"
  fi
else
  echoit "Found tests located at ${TESTS_PATH}..."
fi

# Setup
rm -f ${TEMP_SQL};  if [ -r ${TEMP_SQL} ]; then echoit "Something is wrong; this script tried to remove ${TEMP_SQL}, but the file is still there afterwards."; exit 1; fi
rm -f ${FINAL_SQL}; if [ -r ${FINAL_SQL} ]; then echoit "Something is wrong; this script tried to remove ${FINAL_SQL}, but the file is still there afterwards."; exit 1; fi
touch ${TEMP_SQL};  if [ ! -r ${TEMP_SQL} ]; then echoit "Something is wrong; this script tried to create ${TEMP_SQL}, but the file was not there afterwards."; exit 1; fi
touch ${FINAL_SQL}; if [ ! -r ${FINAL_SQL} ]; then echoit "Something is wrong; this script tried to create ${FINAL_SQL}, but the file was not there afterwards."; exit 1; fi
echoit "Generating SQL grammar for pquery..."
echoit "* Note this takes ~11 minutes on a very high end (i7/SSD/16GB) machine..."

# Stage 1: Approach #1
echoit "> Stage 1: Generating SQL with approach #1..."
egrep --binary-files=text -ih "^SELECT |^INSERT |^UPDATE |^DROP |^CREATE |^RENAME |^TRUNCATE |^REPLACE |^START |^SAVEPOINT |^ROLLBACK |^RELEASE |^LOCK |^XA |^PURGE |^RESET |^SHOW |^CHANGE |^START |^STOP |^PREPARE |^EXECUTE |^DEALLOCATE |^BEGIN |^DECLARE |^FETCH |^CASE |^IF |^ITERATE |^LEAVE |^LOOP |^REPEAT |^RETURN |^WHILE |^CLOSE |^GET |^RESIGNAL |^SIGNAL |^EXPLAIN |^DESCRIBE |^HELP |^USE |^GRANT |^ANALYZE |^CHECK |^CHECKSUM |^OPTIMIZE |^REPAIR |^INSTALL |^UNINSTALL |^BINLOG |^CACHE |^FLUSH |^KILL |^LOAD |^CALL |^DELETE |^DO |^HANDLER |^LOAD DATA |^LOAD XML |^ALTER |^SET " ${TESTS_PATH}/*/*.test ${TESTS_PATH}/*/*/*.test ${TESTS_PATH}/*/*/*/*.test ${TESTS_PATH}/*/*/*/*/*.test ${BASEDIR}/*/*/*.inc ${BASEDIR}/*/*/*/*.inc ${BASEDIR}*/*/*/*/*.inc ${BASEDIR}/*/*/*/*/*/*.inc ${BASEDIR}/plugin/*/*/*/*.test | \
 egrep --binary-files=text -vi "Is a directory" | \
 sort -u | \
  grep --binary-files=text -vi "strict" | \
  grep --binary-files=text -vi "restart_server_args" | \
  grep --binary-files=text -vi "\-\-error" | \
  grep --binary-files=text -vi "\-\-let" | \
  grep --binary-files=text -vi "\-\-enable" | \
  grep --binary-files=text -vi "\-\-disable" | \
  grep --binary-files=text -vi "\-\-de" | \
  grep --binary-files=text -vi "\-\-host" | \
  grep --binary-files=text -vi "\-\-connection" | \
  grep --binary-files=text -vi "\-\-help" | \
  grep --binary-files=text -vi "\-\-source" | \
  grep --binary-files=text -vi "\-\-eval" | \
  grep --binary-files=text -vi "\-\-echo" | \
  grep --binary-files=text -vi "\-\-die" | \
  grep --binary-files=text -vi "\-\-replace" | \
  grep --binary-files=text -vi "\-\-skip" | \
  grep --binary-files=text -vi "^print" | \
  grep --binary-files=text -vi "delete from mysql.user;" | \
  grep --binary-files=text -vi "drop table mysql.user;" | \
  grep --binary-files=text -vi "delete from mysql.user where user='root'" | \
  grep --binary-files=text -vi "[updatedelete]\+.*where user='root'" | \
  grep --binary-files=text -vi "innodb[-_]track[-_]redo[-_]log[-_]now" | \
  grep --binary-files=text -vi "innodb[-_]log[-_]checkpoint[-_]now" | \
  grep --binary-files=text -vi "innodb[-_]purge[-_]stop[-_]now" | \
  grep --binary-files=text -vi "set[ @globalsession\.\t]*innodb[-_]track_changed[-_]pages[ \.\t]*=" | \
  grep --binary-files=text -vi "yfos" | \
  grep --binary-files=text -vi "set[ @globalsession\.\t]*debug[ \.\t]*=" | \
 sed 's|SLEEP[ \t]*([\.0-9]\+)|SLEEP(0.01)|gi' | \
 sed 's/.*[^;]$//' | grep --binary-files=text -v "^$" | \
 sed 's/$/ ;;;/' | sed 's/[ \t;]*$/;/' >> ${TEMP_SQL}

# Approach #2
# DEPRECATED: Tabs are filtered, as they are highly likely CLI result output.  sed 's|\t|FILTERTHIS|' | \ 
# First two sed lines (change | and $$ to ; for Stored Procedures) are significant changes, more review/testing later may show better solutions
echoit "> Stage 2: Generating SQL with approach #2..."
cat ${TESTS_PATH}/*/*.test ${TESTS_PATH}/*/*/*.test ${TESTS_PATH}/*/*/*/*.test ${TESTS_PATH}/*/*/*/*/*.test ${BASEDIR}/*/*/*.inc ${BASEDIR}/*/*/*/*.inc ${BASEDIR}*/*/*/*/*.inc ${BASEDIR}/*/*/*/*/*/*.inc ${BASEDIR}/plugin/*/*/*/*.test | \
 sed 's/|/;\n/g' | \
 sed 's/$$/;\n/g' | \
 sed 's|^ERROR |FILTERTHIS|i' | \
 sed 's|^Warning|FILTERTHIS|i' | \
 sed 's|^Note|FILTERTHIS|i' | \
 sed 's|^Got one of the listed errors|FILTERTHIS|i' | \
 sed 's|^variable_value|FILTERTHIS|i' | \
 sed 's|^Antelope|FILTERTHIS|i' | \
 sed 's|^Barracuda|FILTERTHIS|i' | \
 sed 's|^count|FILTERTHIS|i' | \
 sed 's|^source.*include.*inc|FILTERTHIS|i' | \
 sed 's|^#|FILTERTHIS|' | \
 sed 's|^\-\-|FILTERTHIS|' | \
 sed 's|^@|FILTERTHIS|' | \
 sed 's|^{|FILTERTHIS|' | \
 sed 's|^\*|FILTERTHIS|' | \
 sed 's|^"|FILTERTHIS|' | \
 sed 's|ENGINE[= \t]*NDB|ENGINE=INNODB|gi' | \
 sed 's|^.$|FILTERTHIS|' | sed 's|^..$|FILTERTHIS|' | sed 's|^...$|FILTERTHIS|' | \
 sed 's|^[-0-9]*$|FILTERTHIS|' | sed 's|^c[0-9]*$|FILTERTHIS|' | sed 's|^t[0-9]*$|FILTERTHIS|' | \
 grep --binary-files=text -v "FILTERTHIS" | tr '\n' ' ' | sed 's|;|;\n|g;s|//|//\n|g;s/END\([|]\+\)/END\1\n/g;' | \
 sort -u | \
  grep --binary-files=text -vi "restart_server_args" | \
  grep --binary-files=text -vi "\-\-error" | \
  grep --binary-files=text -vi "\-\-let" | \
  grep --binary-files=text -vi "\-\-enable" | \
  grep --binary-files=text -vi "\-\-disable" | \
  grep --binary-files=text -vi "\-\-de" | \
  grep --binary-files=text -vi "\-\-host" | \
  grep --binary-files=text -vi "\-\-connection" | \
  grep --binary-files=text -vi "\-\-help" | \
  grep --binary-files=text -vi "\-\-source" | \
  grep --binary-files=text -vi "\-\-eval" | \
  grep --binary-files=text -vi "\-\-echo" | \
  grep --binary-files=text -vi "\-\-die" | \
  grep --binary-files=text -vi "\-\-replace" | \
  grep --binary-files=text -vi "\-\-skip" | \
  grep --binary-files=text -vi "^print" | \
  grep --binary-files=text -vi "^Ob%&0Z_" | \
  grep --binary-files=text -vi "^E/TB/]o" | \
  grep --binary-files=text -vi "^no cipher request crashed" | \
  grep --binary-files=text -vi "^[ \t]*DELIMITER" | \
  grep --binary-files=text -vi "^[ \t]*KILL" | \
  grep --binary-files=text -vi "^[ \t]*REVOKE" | \
  grep --binary-files=text -vi "^[ \t]*[<>{}()\.\@\*\+\^\#\!\\\/\'\`\"\;\:\~\$\%\&\|\+\=0-9]" | \
  grep --binary-files=text -vi "\\\q" | \
  grep --binary-files=text -vi "\\\r" | \
  grep --binary-files=text -vi "\\\u" | \
  grep --binary-files=text -vi "^[ \t]*.[ \t]*$" | \
  grep --binary-files=text -vi "^[ \t]*..[ \t]*$" | \
  grep --binary-files=text -vi "^[ \t]*...[ \t]*$" | \
  grep --binary-files=text -vi "^[ \t]*\-\-" | \
  grep --binary-files=text -vi "^[ \t]*while.*let" | \
  grep --binary-files=text -vi "^[ \t]*let" | \
  grep --binary-files=text -vi "^[ \t]*while.*connect" | \
  grep --binary-files=text -vi "^[ \t]*connect" | \
  grep --binary-files=text -vi "^[ \t]*while.*disconnect" | \
  grep --binary-files=text -vi "^[ \t]*disconnect" | \
  grep --binary-files=text -vi "^[ \t]*while.*eval" | \
  grep --binary-files=text -vi "^[ \t]*eval" | \
  grep --binary-files=text -vi "^[ \t]*while.*find" | \
  grep --binary-files=text -vi "^[ \t]*find" | \
  grep --binary-files=text -vi "^[ \t]*while.*exit" | \
  grep --binary-files=text -vi "^[ \t]*exit" | \
  grep --binary-files=text -vi "^[ \t]*while.*send" | \
  grep --binary-files=text -vi "^[ \t]*send" | \
  grep --binary-files=text -vi "^[ \t]*file_exists" | \
  grep --binary-files=text -vi "^[ \t]*enable_info" | \
  grep --binary-files=text -vi "^[ \t]*call mtr.add_suppression" | \
  grep --binary-files=text -vi "strict" | \
  grep --binary-files=text -vi "delete from mysql.user;" | \
  grep --binary-files=text -vi "drop table mysql.user;" | \
  grep --binary-files=text -vi "delete from mysql.user where user='root'" | \
  grep --binary-files=text -vi "[updatedelete]\+.*where user='root'" | \
  grep --binary-files=text -vi "innodb[-_]track[-_]redo[-_]log[-_]now" | \
  grep --binary-files=text -vi "innodb[-_]log[-_]checkpoint[-_]now" | \
  grep --binary-files=text -vi "innodb[-_]purge[-_]stop[-_]now" | \
  grep --binary-files=text -vi "innodb[-_]fil[-_]make[-_]page[-_]dirty[-_]debug" | \
  grep --binary-files=text -vi "set[ @globalsession\.\t]*innodb[-_]track_changed[-_]pages[ \.\t]*=" | \
  grep --binary-files=text -vi "yfos" | \
  grep --binary-files=text -vi "set[ @globalsession\.\t]*debug[ \.\t]*=" | \
  grep --binary-files=text -v "^[# \t]$" | grep --binary-files=text -v "^#" | \
 sed 's/$/ ;;;/' | sed 's/[ \t;]\+$/;/' | sed 's|^[ \t]\+||;s|[ \t]\+| |g' | \
 sed 's/^[|]\+ //' | sed 's///g' | \
 sed 's|end//;|end //;|gi' | \
 sed 's| t[0-9]\+ | t1 |gi' | \
 sed 's| m[0-9]\+ | t1 |gi' | \
 sed 's|mysqltest[\.0-9]*@|user@|gi' | \
 sed 's|mysqltest[\.0-9]*||gi' | \
 sed 's|user@|mysqltest@|gi' | \
 sed 's| .*mysqltest.*@| mysqltest@|gi' | \
 sed 's| test.[a-z]\+[0-9]\+[( ]\+| t1 |gi' | \
 sed 's| INTO[ \t]*[a-z]\+[0-9]\+| INTO t1 |gi' | \
 sed 's| TABLE[ \t]*[a-z]\+[0-9]\+\([;( ]\+\)| TABLE t1\1|gi' | \
 sed 's| PROCEDURE[ \t]*[psroc_-]\+[0-9]*[( ]\+| PROCEDURE p1(|gi' | \
 sed 's| FROM[ \t]*[a-z]\+[0-9]\+| FROM t1 |gi' | \
 sed 's|DROP PROCEDURE IF EXISTS .*;|DROP PROCEDURE IF EXISTS p1;|gi' | \
 sed 's|CREATE PROCEDURE.*BEGIN END;|CREATE PROCEDURE p1() BEGIN END;|gi' | \
 sed 's|^USE .*|USE test;|gi' | \
 sed 's|SLEEP[ \t]*([\.0-9]\+)|SLEEP(0.01)|gi' | \
 grep --binary-files=text -v "/^[^A-Z][^ ]\+$" >> ${TEMP_SQL}

# Grammar variations
echoit "> Stage 3: Adding grammar variations..."
cat ${TEMP_SQL} >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*InnoDB" | sed 's|InnoDB|TokuDB|gi' >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*InnoDB" | sed 's|InnoDB|MEMORY|gi' >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*MyISAM" | sed 's|MyISAM|InnoDB|gi' >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*MyISAM" | sed 's|MyISAM|TokuDB|gi' >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*MyISAM" | sed 's|MyISAM|MEMORY|gi' >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*Memory" | sed 's|Memory|InnoDB|gi' >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*Memory" | sed 's|Memory|TokuDB|gi' >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*CSV"    | sed 's|CSV|InnoDB|gi'    >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*CSV"    | sed 's|CSV|TokuDB|gi'    >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*CSV"    | sed 's|CSV|MEMORY|gi'    >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*Maria"  | sed 's|Maria|InnoDB|gi'  >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*Maria"  | sed 's|Maria|TokuDB|gi'  >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*Maria"  | sed 's|Maria|MEMORY|gi'  >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*Merge.*UNION" | sed 's|ENGINE.*|ENGINE=InnoDB;|gi' >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*Merge.*UNION" | sed 's|ENGINE.*|ENGINE=TokuDB;|gi' >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "ENGINE.*Merge.*UNION" | sed 's|ENGINE.*|ENGINE=Memory;|gi' >> ${FINAL_SQL}
cat ${TEMP_SQL} | grep --binary-files=text -i "DROP TABLE t1" >> ${FINAL_SQL}   # Ensure plenty of DROP TABLE t1
sed -i "s|CREATE.*VIEW.*t1.*|DROP VIEW v1;|gi" ${FINAL_SQL}  # Avoid views with name t1 + ensure plenty of DROP VIEW v1

# Shuffle final grammar
echoit "> Stage 4: Shuffling final grammar..."
rm -f ${TEMP_SQL}; if [ -r ${TEMP_SQL} ]; then echoit "Something is wrong; this script tried to remove ${TEMP_SQL}, but the file is still there afterwards."; exit 1; fi
mv ${FINAL_SQL} ${TEMP_SQL}; if [ ! -r ${TEMP_SQL} ]; then echoit "Something is wrong; this script tried to mv ${FINAL_SQL} ${TEMP_SQL}, but the ${TEMP_SQL} file was not there afterwards."; exit 1; fi; if [ -r ${FINAL_SQL} ]; then echoit "Something is wrong; this script tried to mv ${FINAL_SQL} ${TEMP_SQL}, but the ${FINAL_SQL} file is still there afterwards."; exit 1; fi
shuf --random-source=/dev/urandom ${TEMP_SQL} >> ${FINAL_SQL}
rm -f ${TEMP_SQL}; if [ -r ${TEMP_SQL} ]; then echoit "Something is wrong; this script tried to remove ${TEMP_SQL}, but the file is still there afterwards."; exit 1; fi

echoit "Done! Generated ${FINAL_SQL} for use with pquery/pquery-run.sh"
