#!/bin/sh
# COESA LOCAL: entrypoint de dev mais rápido que docker/entrypoints/rails.sh.
# Diferenças: não apaga tmp/cache (preserva o cache do bootsnap, que evita
# reler/compilar milhares de arquivos .rb pelo bind mount do Windows) e só roda
# `bundle install` quando faltam gems.

set -x

rm -rf /app/tmp/pids/server.pid

echo "Waiting for postgres to become ready...."

$(docker/entrypoints/helpers/pg_database_url.rb)
PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  sleep 2;
done

echo "Database ready to accept connections."

bundle check || bundle install

exec "$@"
