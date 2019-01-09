# Execute a command as another user
# usage: exec_as USER COMMAND [ARG ...]
exec_as() {
  local USER=$1
  shift 1

  if [[ $USER = $(whoami) ]]; then
    eval $@
  else
    # use twice to be root and be allowed to use another user
    sudo -u "$USER" "$@"
  fi
}

# Execute a command through the Pilea console
# usage: exec_console AS_USER WORKDIR COMMAND [ARG ...]
exec_console() {
  local AS_USER=$1
  local WORKDIR=$2
  shift 2
  exec_as "$AS_USER" php "$WORKDIR/bin/console" --no-interaction --env=prod "$@"
}

WARNING () {	# Print on error output
  $@ >&2
}

QUIET () {	# redirect standard output to /dev/null
  $@ > /dev/null
}

CHECK_SIZE () {	# Check if enough disk space available on backup storage
  file_to_analyse=$1
  backup_size=$(du --summarize "$file_to_analyse" | cut -f1)
  free_space=$(df --output=avail "/home/yunohost.backup" | sed 1d)

  if [ $free_space -le $backup_size ]
  then
    WARNING echo "Not enough backup disk space for: $file_to_analyse."
    WARNING echo "Space available: $(HUMAN_SIZE $free_space)"
    ynh_die "Space needed: $(HUMAN_SIZE $backup_size)"
  fi
}

#
# COMPOSER
#

# Execute a composer command from a given directory
# usage: composer_exec workdir COMMAND [ARG ...]
exec_composer() {
  local workdir=$1
  shift 1

  COMPOSER_HOME="${workdir}/.composer" \
    php "${workdir}/composer.phar" $@ \
      -d "${workdir}" --quiet --no-interaction
}

# Install and initialize Composer in the given directory
# usage: init_composer destdir
init_composer() {
  local destdir=$1

  # install composer
  curl -sS https://getcomposer.org/installer \
    | COMPOSER_HOME="${destdir}/.composer" \
        php -- --quiet --install-dir="$destdir" \
    || ynh_die "Unable to install Composer"

  # update dependencies to create composer.lock
  exec_composer "$destdir" install \
    || ynh_die "Unable to install Pilea Composer dependencies"
}


# ============= FUTURE YUNOHOST HELPER =============
# Delete a file checksum from the app settings
#
# $app should be defined when calling this helper
#
# usage: ynh_remove_file_checksum file
# | arg: file - The file for which the checksum will be deleted
ynh_delete_file_checksum () {
  local checksum_setting_name=checksum_${1//[\/ ]/_}	# Replace all '/' and ' ' by '_'
  ynh_app_setting_delete $app $checksum_setting_name
}

#
# PHP7.2 helpers
#

ynh_install_php7 () {

  ynh_package_update
  ynh_package_install apt-transport-https --no-install-recommends

  wget -q -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php7.list

  ynh_package_update
  ynh_install_app_dependencies php7.2 php7.2-zip php7.2-fpm php7.2-mysql php7.2-xml php7.2-intl php7.2-mbstring php7.2-gd php7.2-curl php7.2-bcmath php7.2-opcache php7.2-sqlite3

  sudo update-alternatives --install /usr/bin/php php /usr/bin/php5 70
}

ynh_remove_php7 () {
  sudo rm -f /etc/apt/sources.list.d/php7.list
  sudo apt-key del 4096R/89DF5277
  sudo apt-key del 2048R/11A06851
  ynh_remove_app_dependencies php7.2 php7.2-zip php7.2-fpm php7.2-mysql php7.2-xml php7.2-intl php7.2-mbstring php7.2-gd php7.2-curl php7.2-bcmath php7.2-opcache php7.2-sqlite3
}

ynh_add_fpm7.2_config () {
  # Configure PHP-FPM 7.2 by default
  local fpm_config_dir="/etc/php/7.2/fpm"
  local fpm_service="php7.2-fpm"
  ynh_app_setting_set $app fpm_config_dir "$fpm_config_dir"
  ynh_app_setting_set $app fpm_service "$fpm_service"
  finalphpconf="$fpm_config_dir/pool.d/$app.conf"
  ynh_backup_if_checksum_is_different "$finalphpconf"
  sudo cp ../conf/php-fpm.conf "$finalphpconf"
  ynh_replace_string "__NAMETOCHANGE__" "$app" "$finalphpconf"
  ynh_replace_string "__FINALPATH__" "$final_path" "$finalphpconf"
  ynh_replace_string "__USER__" "$app" "$finalphpconf"
  sudo chown root: "$finalphpconf"
  ynh_store_file_checksum "$finalphpconf"

  if [ -e "../conf/php-fpm.ini" ]
  then
    finalphpini="$fpm_config_dir/conf.d/20-$app.ini"
    ynh_backup_if_checksum_is_different "$finalphpini"
    sudo cp ../conf/php-fpm.ini "$finalphpini"
    sudo chown root: "$finalphpini"
    ynh_store_file_checksum "$finalphpini"
  fi
  sudo systemctl reload $fpm_service
}

# Remove the dedicated php-fpm config
#
# usage: ynh_remove_fpm7.2_config
ynh_remove_fpm7.2_config () {
  local fpm_config_dir=$(ynh_app_setting_get $app fpm_config_dir)
  local fpm_service=$(ynh_app_setting_get $app fpm_service)
  ynh_secure_remove "$fpm_config_dir/pool.d/$app.conf"
  ynh_secure_remove "$fpm_config_dir/conf.d/20-$app.ini" 2>&1
  sudo systemctl reload $fpm_service
}