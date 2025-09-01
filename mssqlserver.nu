# utilities for backing up and restoring MS SQL Server databases
# (ported from https://github.com/AceCoderLaura/LaurasToolbox/blob/master/MSSQLServer.psm1)

const backup_dir = "C:\\Temp\\DBBackups\\"

export def export-database [target_database: string, target_server: string = "localhost"] {
    let timestamp = date now | date to-timezone UTC | format date "%d%m%y_%H%M";
    let filename = $target_database + $timestamp + ".bak";
    let target_db_backup_directory = $backup_dir | path join $target_database;
    mkdir $target_db_backup_directory;
    let backup_path = $target_db_backup_directory | path join $filename;
    sqlcmd -Q $"BACKUP DATABASE [($target_database)] TO DISK='($backup_path)' WITH COMPRESSION;" -S $target_server;
}

export def import-database [] {
}