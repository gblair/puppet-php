require 'puppet/util/execution'

Puppet::Type.type(:php_version).provide(:php_source) do
  include Puppet::Util::Execution
  desc "Provides PHP versions compiled from the official source code repository"

  def create
    install "#{@resource[:version]}"
  end

  def destroy
    FileUtils.rm_rf("#{@resource[:phpenv_root]}/versions/#{@resource[:version]}")
  end

  def exists?
    File.directory?("#{@resource[:phpenv_root]}/versions/#{@resource[:version]}")
  end

  def install(version)

    # First check we have a cached copy of the source repository, with this version tag
    confirm_cached_source(version)

    # Checkout the version as a build branch and prepare for building
    prep_build(version)

    # Configure - this is the hard part
    configure(version)

    # Make & install
    puts %x( cd #{@resource[:phpenv_root]}/php-src/ && make )
    puts %x( cd #{@resource[:phpenv_root]}/php-src/ && make install )
    puts %x( cd #{@resource[:phpenv_root]}/php-src/ && make clean )
  end

  private

  # Check that the cached repository is in place, and the version requested exists
  # as a tag in the repository
  #
  def confirm_cached_source(version)
    raise "Source repository is not present" if !File.directory?("#{@resource[:phpenv_root]}/php-src/.git")

    # Check if tag exists in current repo, if not fetch & recheck
    if !version_present_in_cache?(version)
      update_repository
      raise "Version #{version} not found in PHP source" if !version_present_in_cache?(version)
    end
  end

  # Update and fetch new tags from the remote repository
  #
  def update_repository
    %x( cd #{@resource[:phpenv_root]}/php-src/ && git fetch --tags )
  end

  # Check for a specific version within the PHP source repository
  #
  def version_present_in_cache?(version)
    tag = %x( cd #{@resource[:phpenv_root]}/php-src/ && git tag -l "php-#{version}" )
    tag.strip == "php-#{version}"
  end

  # Prepare the source repository for building by checkout out the correct
  # tag, and cleaning the source tree
  #
  def prep_build(version)
    # Reset back to master and ensure the build branch is removed
    %x( cd #{@resource[:phpenv_root]}/php-src/ && git checkout -f master && git branch -D build &> /dev/null )

    # Checkout version as build branch
    %x( cd #{@resource[:phpenv_root]}/php-src/ && git checkout php-#{version} -b build )

    # Clean everything
    %x( cd #{@resource[:phpenv_root]}/php-src/ && git clean -f -d -x )
  end

  # Configure our version of PHP for compilation
  #
  def configure(version)

    # Final bit of cleanup, just in case
    %x( cd #{@resource[:phpenv_root]}/php-src/ && rm -rf configure autom4te.cache )

    # Run buildconf to prepare build system for compilation
    puts %x( export PHP_AUTOCONF=#{autoconf} && cd #{@resource[:phpenv_root]}/php-src/ && ./buildconf --force )

    # Build configure options
    install_path = "#{@resource[:phpenv_root]}/versions/#{@resource[:version]}"
    config_path = "/opt/boxen/config/php/#{@resource[:version]}"
    args = get_configure_args(version, install_path, config_path)
    args = args.join(" ")

    # Right, the hard part - configure for our system
    puts "Configuring PHP #{version}: #{args}"
    puts %x( cd #{@resource[:phpenv_root]}/php-src/ && ./configure #{args} )
  end

  # Get a default set of configure options
  #
  def get_configure_args(version, install_path, config_path)

    args = [
      "--prefix=#{install_path}",
      "--localstatedir=/var",
      "--sysconfdir=#{config_path}",
      "--with-config-file-path=#{config_path}",
      "--with-config-file-scan-dir=#{config_path}/conf.d",

      "--with-iconv-dir=/usr",
      "--enable-dba",
      "--with-ndbm=/usr",
      "--enable-exif",
      "--enable-soap",
      "--enable-wddx",
      "--enable-ftp",
      "--enable-sockets",
      "--enable-zip",
      "--enable-pcntl",
      "--enable-shmop",
      "--enable-sysvsem",
      "--enable-sysvshm",
      "--enable-sysvmsg",
      "--enable-mbstring",
      "--enable-mbregex",
      "--enable-bcmath",
      "--enable-calendar",
      "--with-ldap",
      "--with-ldap-sasl=/usr",
      "--with-xmlrpc",
      "--with-kerberos=/usr",
      "--with-xsl=/usr",
      "--with-gd",
      "--enable-gd-native-ttf",
      "--with-freetype-dir=/opt/boxen/homebrew/opt/freetype",
      "--with-jpeg-dir=/opt/boxen/homebrew/opt/jpeg",
      "--with-png-dir=/opt/boxen/homebrew/opt/libpng",
      "--with-gettext=/opt/boxen/homebrew/opt/gettext",
      "--with-gmp=/opt/boxen/homebrew/opt/gmp",
      "--with-zlib=/opt/boxen/homebrew/opt/zlib",
      "--with-snmp=/usr",
      "--with-libedit",
      "--with-mhash",
      "--with-curl",
      "--with-openssl=/usr",
      "--with-bz2=/usr",

      "--with-mysql-sock=/tmp/mysql.sock",
      "--with-mysqli=mysqlnd",
      "--with-mysql=mysqlnd",
      "--with-pdo-mysql=mysqlnd",

      "--enable-fpm",
    ]

  end

  def autoconf
    autoconf = "#{@resource[:homebrew_path]}/bin/autoconf"

    # We need an old version of autoconf for PHP 5.3...
    autoconf << "213" if @resource[:version].match(/5\.3\../)

    autoconf
  end

end