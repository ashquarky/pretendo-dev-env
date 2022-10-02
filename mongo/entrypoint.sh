#!/usr/bin/env bash
# https://github.com/docker-library/mongo/issues/339#issuecomment-557606066

# call default entrypoint
usr/local/bin/docker-entrypoint.sh "$@" &

mongoShell='mongo'
if ! command -v "$mongoShell" > /dev/null; then
	mongoShell='mongosh'
fi

# check if mongod is already running and the tmp init setup is done
PS_COMMAND="ps aux | grep '[m]ongod' | grep -v 'docker-entrypoint.sh'"
IS_MONGO_RUNNING=$( bash -c "${PS_COMMAND}" )
while [ -z "${IS_MONGO_RUNNING}" ]
do
  echo "[INFO] Waiting for the MongoDB setup to finish ..."
  sleep 1
  IS_MONGO_RUNNING=$( bash -c "${PS_COMMAND}" )
done
# wait for mongod to be ready for connections
sleep 3

# check if replica set is already initiated
RS_STATUS=$( $mongoShell --quiet --authenticationDatabase admin --eval "rs.status().ok" )
if [[ $RS_STATUS -ne 1 ]]
then
  echo "[INFO] Replication set config invalid. Reconfiguring now."
  RS_CONFIG_STATUS=$( $mongoShell --quiet --authenticationDatabase admin --eval "rs.status().codeName" )
  if [[ $RS_CONFIG_STATUS == 'InvalidReplicaSetConfig' ]]
  then
    $mongoShell --quiet --authenticationDatabase admin > /dev/null <<EOF
config = rs.config()
config.members[0].host = hostname()
rs.reconfig(config, {force: true})
EOF
  else
    echo "[INFO] MongoDB setup finished. Initiating replicata set."
    $mongoShell --quiet --authenticationDatabase admin --eval "rs.initiate()" > /dev/null
  fi
else
  echo "[INFO] Replication set already initiated."
fi

wait