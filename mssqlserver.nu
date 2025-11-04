# utilities for backing up and restoring MS SQL Server databases
# (ported from https://github.com/AceCoderLaura/LaurasToolbox/blob/master/MSSQLServer.psm1)

const backup_dir = "C:\\Databases"

export def export-database [target_database: string, target_server: string = "localhost"] {
    let timestamp = date now | date to-timezone UTC | format date "%d%m%y_%H%M";
    let filename = $target_database + $timestamp + ".bak";
    let target_db_backup_directory = $backup_dir | path join $target_database;
    mkdir $target_db_backup_directory;
    let backup_path = $target_db_backup_directory | path join $filename;
    sqlcmd -Q $"BACKUP DATABASE [($target_database)] TO DISK='($backup_path)' WITH COMPRESSION;" -S $target_server;
}

export def import-database [
    target_database: string,
    --backup-path: path,
    --select-latest,
    --target-server: string = "localhost",
    --verbose (-v)
] {
    if not ($select_latest xor $backup_path != null) {
        error make { msg: 'You must specify ONE of either --select-latest or --backup-path options.' }
    }

    let backup_path_actual = if $select_latest {
        let search_dir = $backup_dir | path join $target_database;
        let backup_file = ls -f $search_dir | sort-by modified --reverse | first;
        $backup_file.name;
    } else {
        if not ($backup_path | path exists) { error make { msg: 'Selected backup file does not exist.' } }
        $backup_path | path expand
    }

    if $verbose { print $"($backup_path_actual) was selected for restore." }

    let file_list_table = sqlcmd -Q $"RESTORE FILELISTONLY FROM DISK='($backup_path_actual)'" -S $target_server | detect columns --guess | skip 1 | take 2
    let logical_file_name = ($file_list_table | first).LogicalName
    let logical_log_name = ($file_list_table | last).LogicalName

    if $verbose {
        print "backup set contained the following files:";
        print $file_list_table;
    }

	let rawfiles_dir = $backup_dir | path join "RAWFILES";
	mkdir $rawfiles_dir
	
    let new_logical_file_name = $rawfiles_dir | path join $"($target_database).ldf";
    let new_logical_log_name = $rawfiles_dir | path join $"($target_database).mdf";

    let restore_sql = $"ALTER DATABASE [($target_database)] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    RESTORE DATABASE [($target_database)] FROM DISK='($backup_path_actual)' WITH
        REPLACE,
        MOVE '($logical_file_name)' TO '($new_logical_file_name)',
        MOVE '($logical_log_name)' TO '($new_logical_log_name)';
    ALTER DATABASE [($target_database)] SET MULTI_USER;
    GO";

    sqlcmd -Q $restore_sql -S $target_server;
}