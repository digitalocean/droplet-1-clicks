#!/bin/sh

# Dangerous functions commonly abused by PHP webshells after WP compromise.
# Applied to FPM only so WP-CLI (CLI SAPI) remains usable for maintenance.
DISABLE_FUNCTIONS="getmyuid,passthru,leak,listen,diskfreespace,tmpfile,link,dl,system,highlight_file,source,show_source,fpassthru,virtual,posix_ctermid,posix_getcwd,posix_getegid,posix_geteuid,posix_getgid,posix_getgrgid,posix_getgrnam,posix_getgroups,posix_getlogin,posix_getpgid,posix_getpgrp,posix_getpid,posix_getppid,posix_getpwuid,posix_getrlimit,posix_getsid,posix_getuid,posix_isatty,posix_kill,posix_mkfifo,posix_setegid,posix_seteuid,posix_setgid,posix_setpgid,posix_setsid,posix_setuid,posix_times,posix_ttyname,posix_uname,proc_open,proc_close,proc_nice,proc_terminate,escapeshellcmd,ini_alter,popen,pcntl_exec,socket_accept,socket_bind,socket_clear_error,socket_close,socket_connect,symlink,socket_listen,socket_create_listen,socket_read,socket_create_pair,stream_socket_server,shell_exec,exec,putenv"

# Configure PHP for FPM (used with Caddy)
sed -e "s|upload_max_filesize.*|upload_max_filesize = 16M|g" \
    -e "s|post_max_size.*|post_max_size = 16M|g" \
    -e "s|max_execution_time.*|max_execution_time = 60|g" \
    -e "s|^;*disable_functions.*|disable_functions = ${DISABLE_FUNCTIONS}|g" \
    -i /etc/php/8.3/fpm/php.ini

# Lock on the www pool so php_value / .user.ini cannot reopen these functions
POOL_CONF=/etc/php/8.3/fpm/pool.d/www.conf
if grep -q '^php_admin_value\[disable_functions\]' "$POOL_CONF"; then
    sed -i "s|^php_admin_value\[disable_functions\].*|php_admin_value[disable_functions] = ${DISABLE_FUNCTIONS}|" "$POOL_CONF"
else
    printf '\n; Harden against webshell persistence after WP compromise\nphp_admin_value[disable_functions] = %s\n' "$DISABLE_FUNCTIONS" >> "$POOL_CONF"
fi

# Also configure CLI version for WP-CLI
sed -e "s|upload_max_filesize.*|upload_max_filesize = 16M|g" \
    -e "s|post_max_size.*|post_max_size = 16M|g" \
    -e "s|max_execution_time.*|max_execution_time = 60|g" \
    -i /etc/php/8.3/cli/php.ini