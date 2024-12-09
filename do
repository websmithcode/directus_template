#!/bin/bash
source .env

command=$1
mode=local
base_dir="./data/.dev"
commands=("snapshot" "restore_snapshot" "db_flush" "db_dump" "db_restore" "psql" "redis" "directus")

--help() {
    cat <<EOF
Usage: ./do <command> [--prod]

Available commands:
  snapshot           Create a schema snapshot of the current state
  restore_snapshot   Restore the latest stable snapshot (or specified by name)
  db_flush           Clear the database (drop and recreate public schema)
  db_dump            Create a database backup
  db_restore         Restore database from the latest backup (or specified by name)
  psql               Execute psql commands in database container
  redis              Execute redis-cli commands in cache container
  directus           Execute commands in directus container

Options:
  --prod             Execute command in production mode (uses ./directus as base directory)

Examples:
  ./do snapshot
  ./do restore_snapshot 20241208_234025
  ./do db_restore 20241208_230458
  ./do psql
EOF
}

_is_command() {
    [[ " ${commands[*]} " =~ " ${command//-/_} " ]]
}

redis() {
    shift
    docker compose exec cache redis-cli "$@"
}

directus() {
    shift
    docker compose exec directus node cli.js "$@"
}

psql() {
    shift
    docker compose exec database psql "$@" -U "$DB_USER" -d "$DB_DATABASE"
}

snapshot() {
    mkdir -p "$base_dir/snapshots"
    snapshot_name=$2
    docker compose exec directus node cli.js schema snapshot > \
        "$base_dir/snapshots/$(date +%Y%m%d_%H%M%S)_$snapshot_name.yaml"
    echo "Snapshot created in $base_dir/snapshots/"
}

restore_snapshot() {
    mkdir -p "$base_dir/snapshots"
    mkdir -p ./directus/snapshots/tmp

    snapshot_name=$2

    if [ -z "$snapshot_name" ]; then
        last_stable=$(ls -t "$base_dir"/snapshots/*.yaml | head -n 1)
    else
        last_stable="$base_dir/snapshots/$snapshot_name.yaml"
    fi

    if [ ! -f "$last_stable" ]; then
        echo "Error: Snapshot file not found: $last_stable"
        exit 1
    fi

    echo "Restoring snapshot: $last_stable"

    cp "$last_stable" ./directus/snapshots/tmp/last-stable.yaml
    docker compose down -v
    docker compose up -d
    docker compose exec directus node cli.js schema apply ./snapshots/tmp/last-stable.yaml

    rm -rf ./directus/snapshots/tmp
}

db_flush() {
    echo "Flushing database..."
    docker compose exec database psql -U "$DB_USER" -d "$DB_DATABASE" \
        -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
    echo "Database flushed successfully"
}

db_dump() {
    mkdir -p "$base_dir/backups"
    dump_name=$2
    backup_file="$base_dir/backups/$(date +%Y%m%d_%H%M%S)_$dump_name.sql"
    docker compose exec database pg_dump -U "$DB_USER" -d "$DB_DATABASE" > "$backup_file"
    echo "Database backup created: $backup_file"
}

db_restore() {
    mkdir -p "$base_dir/backups"
    backup_name=$2

    if [ -z "$backup_name" ]; then
        last_backup=$(ls -t "$base_dir"/backups/*.sql | head -n 1)
    else
        last_backup="$base_dir/backups/$backup_name.sql"
    fi

    if [ ! -f "$last_backup" ]; then
        echo "Error: Backup file not found: $last_backup"
        exit 1
    fi

    echo "Restoring database from: $last_backup"
    db_flush
    docker compose exec -T database sh -c "psql -d $DB_DATABASE -U $DB_USER -a" < "$last_backup" >> /dev/null
    echo "Database restored successfully"
}

# Show help if no command provided
if [ -z "$command" ]; then
    --help
    exit 0
fi

# Validate command
if ! _is_command; then
    echo "Error: Unknown command: $command"
    --help
    exit 1
fi
shift

# Process flags
if [ $# -gt 0 ]; then
    for flag in "$@"; do
        if [[ $flag == --* ]]; then
            case $flag in
                --prod)
                    mode=prod
                    base_dir="./directus"
                    ;;
                *)
                    echo "Error: Unknown parameter: $flag"
                    --help
                    exit 1
                    ;;
            esac
            shift
        fi
    done
fi

# Execute command
"${command//-/_}" "$@"
