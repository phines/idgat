# INSPIRED BY: http://stackoverflow.com/questions/5722544/how-can-i-convert-an-mdb-access-file-to-mysql-or-plain-sql-file
# ARGS:
# 1. DataBase File (e.g. foo.mdb) -- required
# 2. DataBase Name (e.g. 'foo')   -- optional

# SANITY-CHECK ARGS:
if [[ $# -eq 0 ]]
then
    echo "USAGE: $0 db_file [db_name]"
    exit 1
elif [[ $# -eq 1 ]]
then
    echo "processing db file named $1"
    db_file=$1
    db_name='foo'
else
    echo "processing db file named $1 identified by name $2"
    db_file=$1
    db_name=$2
fi

#1 EXPORT SCHEMA:
echo "SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;" > schema_${db_name}.sql
echo "SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;" >> schema_${db_name}.sql
echo "SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';" >> schema_${db_name}.sql
echo "DROP SCHEMA IF EXISTS $db_name;" >> schema_${db_name}.sql
echo "CREATE SCHEMA ${db_name};" >> schema_${db_name}.sql
echo "USE ${db_name};" >> schema_${db_name}.sql
mdb-schema $db_file mysql >> schema_${db_name}.sql

#2 EXPORT DATA:
echo "SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;" > data_${db_name}.sql
echo "SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;" >> data_${db_name}.sql
echo "SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';" >> data_${db_name}.sql
echo "USE ${db_name};" >> data_${db_name}.sql
for table in `mdb-tables -1 $db_file`
do
    mdb-export -I mysql $db_file $table >> data_${db_name}.sql
done

exit 0
