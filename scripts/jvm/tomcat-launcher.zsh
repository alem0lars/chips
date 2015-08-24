#!/bin/zsh


# {{{ Utility functions.

error()
{
  echo "Error: $1"
  exit -1
}

# }}}

# {{{ Configuration.

if [[ $# -lt 2 ]]; then
  error "You must provide the command (start or stop) and the instance name"
else
  export _inst_name="tomcat-8-$2"
fi

export CATALINA_HOME=${CATALINA_HOME:=/usr/share/tomcat-8}
export CATALINA_BASE=${CATALINA_BASE:=/var/lib/${_inst_name}}
export CATALINA_TMPDIR=${CATALINA_TMPDIR:=/var/tmp/${_inst_name}}
if [[ $# -gt 2 ]]; then
  export CATALINA_USER=$3
  export CATALINA_GROUP=$3
else
  export CATALINA_USER=${CATALINA_USER:=tomcat}
  export CATALINA_GROUP=${CATALINA_GROUP:=tomcat}
fi

export TOMCAT_START=${TOMCAT_START:=start}

export JPDA_TRANSPORT=${JPDA_TRANSPORT:="dt_socket"}
export JPDA_ADDRESS=${JPDA_ADDRESS:="8000"}
export JPDA_OPTS=${JPDA_OPTS="-Xdebug -Xrunjdwp:transport=${JPDA_TRANSPORT},address=${JPDA_ADDRESS},server=y,suspend=n"}

export JAVA_HOME=`java-config ${TOMCAT_JVM:+--select-vm ${TOMCAT_JVM}} --jre-home`

CLASSPATH=`java-config --classpath tomcat-8${TOMCAT_EXTRA_JARS:+,${TOMCAT_EXTRA_JARS}}`
export CLASSPATH="${CLASSPATH}${TOMCAT_EXTRA_CLASSPATH:+:${TOMCAT_EXTRA_CLASSPATH}}"

# }}}

# {{{ Lifecycle functions.

start()
{
  echo "Starting ${_inst_name} as user ${CATALINA_USER}:${CATALINA_GROUP}"

  if [ ! -e "${CATALINA_TMPDIR}" ]; then
    error "CATALINA_TMPDIR does not exist. Unable to start tomcat."
    error "Please see /etc/conf.d/${_inst_name} for more information."
  fi

  cmd=java
  args=
  if [ "${TOMCAT_START}" = "debug" ] || [ "${TOMCAT_START}" = "-security debug" ]; then
    cmd=jdb
    args="${args} -sourcepath ${CATALINA_HOME}/../../jakarta-tomcat-catalina/catalina/src/share"
  fi
  if [ "${TOMCAT_START}" = "-security debug" ] || [ "${TOMCAT_START}" = "-security start" ]; then
    args="${args} -Djava.security.manager"
    args="${args} -Djava.security.policy=${CATALINA_BASE}/conf/catalina.policy"
  fi
  if [ "${TOMCAT_START}" = "jpda start" ] ; then
    args="${args} ${JPDA_OPTS}"
  fi
  if [ -r "${CATALINA_HOME}"/bin/tomcat-juli.jar ]; then
    args="${args} -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager -Djava.util.logging.config.file=${CATALINA_BASE}/conf/logging.properties"
  fi

  export cmd
  export args

  sudo -u ${CATALINA_USER} -g ${CATALINA_GROUP} -E sh -s "$@" <<'EOF'
  cd "${CATALINA_TMPDIR}"
  echo $CATALINA_USER
  ${JAVA_HOME}/bin/${cmd} \
    ${JAVA_OPTS} \
    ${args} \
    -Dcatalina.base="${CATALINA_BASE}" \
    -Dcatalina.home="${CATALINA_HOME}" \
    -Djava.io.tmpdir="${CATALINA_TMPDIR}" \
    -classpath "${CLASSPATH}" \
    org.apache.catalina.startup.Bootstrap \
    ${CATALINA_OPTS} \
    ${TOMCAT_START}
EOF
}

stop()
{
  echo "Stopping ${_inst_name}"

  sudo -E sh -s "$@" <<'EOF'
  ${JAVA_HOME}/bin/java \
   ${JAVA_OPTS} \
   -classpath "${CLASSPATH}" \
   ${CATALINA_OPTS} \
   stop
EOF
}

# }}}

# Entry point.
if [[ "$1" == "start" ]]; then
  start
elif [[ "$1" == "stop" ]]; then
  stop
else
  error "Invalid command (first argument). It can be 'start' or 'stop'."
fi
