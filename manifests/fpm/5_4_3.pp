# Launches a PHP FPM service running PHP 5.4.3
# Installs PHP 5.4.3 if it doesn't already exist
#
# Usage:
#
#     include php::fpm::5_4_3
#
class php::fpm::5_4_3 {
  php::fpm { '5.4.3': }
}
