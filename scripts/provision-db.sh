#!/usr/bin/env bash
set -euo pipefail

REQUIRED=(MYSQL_HOST MYSQL_PORT MYSQL_ROOT_USER MYSQL_ROOT_PASSWORD TEMPLATE_DB NEW_DB NEW_DB_USER NEW_DB_PASS DB_SSL_MODE)
for v in "${REQUIRED[@]}"; do
  if [ -z "${!v:-}" ]; then echo "Falta ${v}"; exit 1; fi
done

SSL_OPT=""
case "${DB_SSL_MODE:-DISABLED}" in
  REQUIRED|VERIFY_IDENTITY|VERIFY_CA) SSL_OPT="--ssl-mode=${DB_SSL_MODE}";;
  PREFERRED) SSL_OPT="--ssl-mode=PREFERRED";;
  *) SSL_OPT="--ssl-mode=DISABLED";;
esac

mysql_base="mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} ${SSL_OPT} --protocol=TCP --batch --skip-column-names"

echo "[1/4] Verificar se a base '${NEW_DB}' existe..."
if echo "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${NEW_DB}';" | eval $mysql_base | grep -q "^${NEW_DB}\$"; then
  echo "   -> Já existe. A saltar criação/clonagem."
else
  echo "[2/4] Criar base '${NEW_DB}'..."
  echo "CREATE DATABASE \`${NEW_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" | eval $mysql_base

  echo "[3/4] Clonar '${TEMPLATE_DB}' → '${NEW_DB}'..."
  mysqldump -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u"${MYSQL_ROOT_USER}" -p"${MYSQL_ROOT_PASSWORD}" ${SSL_OPT} \
    --routines --triggers --events --single-transaction --skip-lock-tables "${TEMPLATE_DB}" \
    | sed -E 's/DEFINER=`[^`]+`@`[^`]+`/DEFINER=CURRENT_USER/g' \
    | mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u"${MYSQL_ROOT_USER}" -p"${MYSQL_ROOT_PASSWORD}" ${SSL_OPT} "${NEW_DB}"
fi

echo "[4/4] Criar utilizador '${NEW_DB_USER}' com acesso só a '${NEW_DB}'..."
echo "
CREATE USER IF NOT EXISTS '${NEW_DB_USER}'@'%' IDENTIFIED BY '${NEW_DB_PASS}';
ALTER USER '${NEW_DB_USER}'@'%' IDENTIFIED BY '${NEW_DB_PASS}';
GRANT ALL PRIVILEGES ON \`${NEW_DB}\`.* TO '${NEW_DB_USER}'@'%';
FLUSH PRIVILEGES;
" | eval $mysql_base

echo "✅ Provisionamento concluído."
