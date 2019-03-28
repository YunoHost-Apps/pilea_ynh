# dependencies used by the app
pkg_dependencies="apt-transport-https"

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
    /usr/bin/php7.2 "${workdir}/composer.phar" $@ \
      -d "${workdir}" --quiet --no-interaction
}

# Install and initialize Composer in the given directory
# usage: init_composer destdir
init_composer() {
  local destdir=$1

  # install composer
  curl -sS https://getcomposer.org/installer \
    | COMPOSER_HOME="${destdir}/.composer" \
        /usr/bin/php7.2 -- --quiet --install-dir="$destdir" \
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

# Pin a repository.
#
# usage: ynh_pin_repo --package=packages --pin=pin_filter --priority=priority_value [--name=name] [--append]
# | arg: -p, --package - Packages concerned by the pin. Or all, *.
# | arg: -i, --pin - Filter for the pin.
# | arg: -p, --priority - Priority for the pin
# | arg: -n, --name - Name for the files for this repo, $app as default value.
# | arg: -a, --append - Do not overwrite existing files.
#
# See https://manpages.debian.org/stretch/apt/apt_preferences.5.en.html for information about pinning.
#
ynh_pin_repo () {
  # Declare an array to define the options of this helper.
  local legacy_args=pirna
  declare -Ar args_array=( [p]=package= [i]=pin= [r]=priority= [n]=name= [a]=append )
  local package
  local pin
  local priority
  local name
  local append
  # Manage arguments with getopts
  ynh_handle_getopts_args "$@"
  package="${package:-*}"
  priority=${priority:-50}
  name="${name:-$app}"
  append=${append:-0}

  if [ $append -eq 1 ]
  then
    append="tee -a"
  else
    append="tee"
  fi

  mkdir -p "/etc/apt/preferences.d"
  echo "Package: $package
Pin: $pin
Pin-Priority: $priority" \
  | $append "/etc/apt/preferences.d/$name"
}

# Add a repository.
#
# usage: ynh_add_repo --uri=uri --suite=suite --component=component [--name=name] [--append]
# | arg: -u, --uri - Uri of the repository.
# | arg: -s, --suite - Suite of the repository.
# | arg: -c, --component - Component of the repository.
# | arg: -n, --name - Name for the files for this repo, $app as default value.
# | arg: -a, --append - Do not overwrite existing files.
#
# Example for a repo like deb http://forge.yunohost.org/debian/ stretch stable
#                             uri                               suite   component
# ynh_add_repo --uri=http://forge.yunohost.org/debian/ --suite=stretch --component=stable
#
ynh_add_repo () {
  # Declare an array to define the options of this helper.
  local legacy_args=uscna
  declare -Ar args_array=( [u]=uri= [s]=suite= [c]=component= [n]=name= [a]=append )
  local uri
  local suite
  local component
  local name
  local append
  # Manage arguments with getopts
  ynh_handle_getopts_args "$@"
  name="${name:-$app}"
  append=${append:-0}

  if [ $append -eq 1 ]
  then
    append="tee -a"
  else
    append="tee"
  fi

  mkdir -p "/etc/apt/sources.list.d"
  # Add the new repo in sources.list.d
  echo "deb $uri $suite $component" \
    | $append "/etc/apt/sources.list.d/$name.list"
}

# Add an extra repository correctly, pin it and get the key.
#
# usage: ynh_install_extra_repo --repo="repo" [--key=key_url] [--name=name] [--append]
# | arg: -r, --repo - Complete url of the extra repository.
# | arg: -k, --key - url to get the public key.
# | arg: -n, --name - Name for the files for this repo, $app as default value.
# | arg: -a, --append - Do not overwrite existing files.
ynh_install_extra_repo () {
  # Declare an array to define the options of this helper.
  local legacy_args=rkna
  declare -Ar args_array=( [r]=repo= [k]=key= [n]=name= [a]=append )
  local repo
  local key
  local name
  local append
  # Manage arguments with getopts
  ynh_handle_getopts_args "$@"
  name="${name:-$app}"
  append=${append:-0}
  key=${key:-0}

  if [ $append -eq 1 ]
  then
    append="--append"
    wget_append="tee -a"
  else
    append=""
    wget_append="tee"
  fi

  # Split the repository into uri, suite and components.
  # Remove "deb " at the beginning of the repo.
  repo="${repo#deb }"

  # Get the uri
  local uri="$(echo "$repo" | awk '{ print $1 }')"

  # Get the suite
  local suite="$(echo "$repo" | awk '{ print $2 }')"

  # Get the components
  local component="${repo##$uri $suite }"

  # Add the repository into sources.list.d
  ynh_add_repo --uri="$uri" --suite="$suite" --component="$component" --name="$name" $append

  # Pin the new repo with the default priority, so it won't be used for upgrades.
  # Build $pin from the uri without http and any sub path
  local pin="${uri#*://}"
  pin="${pin%%/*}"
  ynh_pin_repo --package="*" --pin="origin \"$pin\"" --name="$name" $append

  # Get the public key for the repo
  if [ -n "$key" ]
  then
    mkdir -p "/etc/apt/trusted.gpg.d"
    wget -q "$key" -O - | $wget_append /etc/apt/trusted.gpg.d/$name.gpg
  fi

  # Update the list of package with the new repo
  ynh_package_update
}

# Remove an extra repository and the assiociated configuration.
#
# usage: ynh_remove_extra_repo [--name=name]
# | arg: -n, --name - Name for the files for this repo, $app as default value.
ynh_remove_extra_repo () {
  # Declare an array to define the options of this helper.
  local legacy_args=n
  declare -Ar args_array=( [n]=name= )
  local name
  # Manage arguments with getopts
  ynh_handle_getopts_args "$@"
  name="${name:-$app}"

  ynh_secure_remove "/etc/apt/sources.list.d/$name.list"
  ynh_secure_remove "/etc/apt/preferences.d/$name"
  ynh_secure_remove "/etc/apt/trusted.gpg.d/$name.gpg"

  # Update the list of package to exclude the old repo
  ynh_package_update
}

#=================================================


# Install another version of php.
#
# usage: ynh_install_php --phpversion=phpversion
# | arg: -v, --phpversion - Version of php to install. Can be one of 7.1, 7.2 or 7.3
ynh_install_php () {
  # Declare an array to define the options of this helper.
  local legacy_args=v
  declare -Ar args_array=( [v]=phpversion= )
  local phpversion
  # Manage arguments with getopts
  ynh_handle_getopts_args "$@"

  # Store php_version into the config of this app
  ynh_app_setting_set $app php_version $phpversion

  # Install an extra repo to get multiple php versions
  ynh_install_extra_repo --repo="https://packages.sury.org/php/ $(lsb_release -sc) main" --key="https://packages.sury.org/php/apt.gpg" --name=php

  if [ "$phpversion" == "7.0" ]; then
    ynh_die "Do not use ynh_install_php to install php7.0"

  # Php 7.1
  elif [ "$phpversion" == "7.1" ]; then
    # Get the current version available for libpcre3 on packages.sury.org
    local libpcre3_version=$(apt-cache madison "libpcre3" | grep "packages.sury.org" | tail -n1 | awk '{print $3}')

    # equivs doesn't handle correctly this dependence.
    # Force the upgrade of libpcre3 for php7.1
    ynh_package_install "libpcre3=$libpcre3_version"

    local php_dependencies="php7.1, php7.1-fpm"

  # Php 7.2
  elif [ "$phpversion" == "7.2" ]; then
    # Get the current version available for libpcre3 on packages.sury.org
    local libpcre3_version=$(apt-cache madison "libpcre3" | grep "packages.sury.org" | tail -n1 | awk '{print $3}')

    # equivs doesn't handle correctly this dependence.
    # Force the upgrade of libpcre3 for php7.2
    ynh_package_install "libpcre3=$libpcre3_version"

    local php_dependencies="php7.2, php7.2-fpm"

  # Php 7.3
  elif [ "$phpversion" == "7.3" ]; then
    # Get the current version available for libpcre2-8-0 on packages.sury.org
    local libpcre2_version=$(apt-cache madison "libpcre2-8-0" | grep "packages.sury.org" | tail -n1 | awk '{print $3}')

    # equivs doesn't handle correctly this dependence.
    # Force the upgrade of libpcre2-8-0 for php7.3
    ynh_package_install "libpcre2-8-0=$libpcre2_version"

    local php_dependencies="php7.3, php7.3-fpm"

  else
    ynh_die "The version $phpversion of php isn't handle by this helper."
  fi

  # Store the ID of this app and the version of php requested for it
  echo "$YNH_APP_ID:$phpversion" | tee --append "/etc/php/ynh_app_version"

  # Build a control file for equivs-build
    echo "Section: misc
Priority: optional
Package: php${phpversion}-ynh-deps
Version: 1.0
Depends: $php_dependencies
Architecture: all
Description: Fake package for php_$phpversion dependencies
 This meta-package is only responsible of installing its dependencies." \
  > /tmp/php_${phpversion}-ynh-deps.control

  # Install the fake package for php
  ynh_package_install_from_equivs /tmp/php_${phpversion}-ynh-deps.control \
        || ynh_die --message="Unable to install dependencies"
  ynh_secure_remove /tmp/php_${phpversion}-ynh-deps.control

  # Advertise service in admin panel
  yunohost service add php${phpversion}-fpm --log "/var/log/php${phpversion}-fpm.log"
}

ynh_remove_php () {
  # Get the version of php used by this app
  local phpversion=$(ynh_app_setting_get $app php_version)

  if [ "$phpversion" == "7.0" ] || [ -z "$phpversion" ]
  then
    if [ "$phpversion" == "7.0" ]
    then
      ynh_print_err "Do not use ynh_remove_php to install php7.0"
    fi
    return 0
  fi

  # Remove the line for this app
  sed --in-place "/$YNH_APP_ID:$phpversion/d" "/etc/php/ynh_app_version"

  # If no other app uses this version of php, remove it.
  if ! grep --quiet "$phpversion" "/etc/php/ynh_app_version"
  then
    # Remove the metapackage for php
    ynh_package_autopurge php${phpversion}-ynh-deps
    # Then remove php-fpm php-cli for this version.
    # The previous command won't remove them, but we have to remove those package to clean php
    ynh_package_autopurge php${phpversion}-fpm php${phpversion}-cli

    if [ "$phpversion" == "7.1" ] || [ "$phpversion" == "7.2" ]
    then
      # Do not restore libpcre3 if php7.1 or 7.2 is still used.
      if ! grep --quiet --extended-regexp "7.1|7.2" "/etc/php/ynh_app_version"
      then
        # Get the current version available for libpcre3 on the standard repo
        local libpcre3_version=$(apt-cache madison "libpcre3" | grep "debian.org" | tail -n1 | awk '{print $3}')

        # Force to reinstall the standard version of libpcre3
        ynh_package_install --allow-downgrades libpcre3=$libpcre3_version >&2
      fi
    elif [ "$phpversion" == "7.3" ]
    then
      # Get the current version available for libpcre2-8-0 on the standard repo
      local libpcre2_version=$(apt-cache madison "libpcre2-8-0" | grep "debian.org" | tail -n1 | awk '{print $3}')

      # Force to reinstall the standard version of libpcre2-8-0
      ynh_package_install --allow-downgrades libpcre2-8-0=$libpcre2_version
    fi

    # Remove the service from the admin panel
    yunohost service remove php${phpversion}-fpm
  fi

  # If no other app uses alternate php versions, remove the extra repo for php
  if [ ! -s "/etc/php/ynh_app_version" ]
  then
    ynh_remove_extra_repo --name=php
    ynh_secure_remove /etc/php/ynh_app_version
  fi
}

#
# PHP7.2 helpers
#
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
}

# Remove the dedicated php-fpm config
#
# usage: ynh_remove_fpm7.2_config
ynh_remove_fpm7.2_config () {
  local fpm_config_dir=$(ynh_app_setting_get $app fpm_config_dir)
  local fpm_service=$(ynh_app_setting_get $app fpm_service)
  ynh_secure_remove "$fpm_config_dir/pool.d/$app.conf"
  ynh_secure_remove "$fpm_config_dir/conf.d/20-$app.ini" 2>&1
}