default_run_options[:pty] = true

#### Set these variables as needed ######################################################################
#
set :application, "mydomain.com" # The vhost container name (e.g. domain)
set :repository,  "git@github.com:USERNAME/REPONAME.git" # GitHub repo where the app lives
set :user, "username" # Username of your slice
set :slice, "xx.xx.xx.xx" # The IP address of your slice
#
#### You shouldn't need to change anything below ########################################################

set :deploy_to, "/home/#{user}/#{application}"


set :scm, :git

role :app, "#{slice}"
role :web, "#{slice}"
role :db,  "#{slice}", :primary => true

namespace :slicehost do
  desc "Setup Environment"
  task :setup_env do
    update_apt_get
    set_locale
    install_dev_tools
    install_git
    install_rails_stack
    install_apache
    install_passenger
    config_passenger
    config_vhost
  end
  
  desc "Update aptitude sources"
  task :update_apt_get do
    sudo "aptitude update"
  end

  desc "Set system locale"
  task :set_locale do
    sudo "locale-gen en_GB.UTF-8"
    sudo "/usr/sbin/update-locale LANG=en_GB.UTF-8"
  end
  
  desc "Install Development Tools"
  task :install_dev_tools do
    sudo "aptitude install build-essential -y"
  end
  
  desc "Install Git"
  task :install_git do
    sudo "aptitude install git-core git-svn -y"
  end
  
  desc "Install MySQL"
  task :install_mysql do
    sudo "aptitude install mysql-server mysql-client libmysqlclient15-dev libmysql-ruby1.8 -y"
  end
  
  desc "Install Ruby, Gems, and Rails"
  task :install_rails_stack do
    [
      "sudo aptitude install ruby1.8-dev ruby1.8 ri1.8 rdoc1.8 irb1.8 libreadline-ruby1.8 libruby1.8 libopenssl-ruby sqlite3 libsqlite3-ruby1.8 -y",
      "sudo ln -s /usr/bin/ruby1.8 /usr/bin/ruby",
      "sudo ln -s /usr/bin/ri1.8 /usr/bin/ri",
      "sudo ln -s /usr/bin/rdoc1.8 /usr/bin/rdoc",
      "sudo ln -s /usr/bin/irb1.8 /usr/bin/irb",
      "mkdir -p /home/#{user}/src",
      "cd /home/#{user}/src",
      "wget http://rubyforge.org/frs/download.php/45905/rubygems-1.3.1.tgz",
      "tar xvzf rubygems-1.3.1.tgz",
      "cd rubygems-1.3.1/ && sudo ruby setup.rb",
      "sudo ln -s /usr/bin/gem1.8 /usr/bin/gem",
      "sudo gem update",
      "sudo gem update --system",
      "sudo gem install rails"
    ].each {|cmd| run cmd}
  end
  
  desc "Install common gems"
  task :install_gems do
    run "gem sources -a http://gems.github.com"
    sudo "aptitude install imagemagick -y"
    sudo "aptitude install libmagick9-dev -y"
    sudo "gem install radiant"
    sudo "gem install flickr_fu"
    sudo "gem install haml"
    sudo "gem install mislav-will_paginate"
    sudo "gem install fastercsv"
    sudo "gem install RedCloth"
    sudo "gem install rmagick"    
    sudo "gem install xml-magic"
    sudo "gem install json"
    sudo "gem install thoughtbot-paperclip"
  end
  
  desc "Install Apache"
  task :install_apache do
    sudo "aptitude install apache2 apache2.2-common apache2-mpm-prefork 
          apache2-utils libexpat1 apache2-prefork-dev libapr1-dev -y"
    sudo "chown :sudo /var/www"
    sudo "chmod g+w /var/www"
  end
  
  desc "Install Passenger"
  task :install_passenger do
    run "sudo gem install passenger"
    input = ''
    run "sudo passenger-install-apache2-module" do |ch,stream,out|
      next if out.chomp == input.chomp || out.chomp == ''
      print out
      ch.send_data(input = $stdin.gets) if out =~ /(Enter|ENTER)/
    end
  end
  
  desc "Configure Passenger"
  task :config_passenger do
    passenger_config =<<-EOF
LoadModule passenger_module /usr/lib/ruby/gems/1.8/gems/passenger-2.1.3/ext/apache2/mod_passenger.so
PassengerRoot /usr/lib/ruby/gems/1.8/gems/passenger-2.1.3/bin/passenger-spawn-server
PassengerRuby /usr/bin/ruby1.8    
    EOF
    put passenger_config, "src/passenger"
    sudo "mv src/passenger /etc/apache2/conf.d/passenger"
  end
  
  desc "Configure VHost"
  task :config_vhost do
    vhost_config =<<-EOF
<VirtualHost *:80>
  ServerName #{slice}
  DocumentRoot #{deploy_to}/current/public
</VirtualHost>
    EOF
    put vhost_config, "src/vhost_config"
    sudo "mv src/vhost_config /etc/apache2/sites-available/#{application}"
    sudo "a2ensite #{application}"
    run "mkdir /home/#{user}/#{application}"
  end
  
  desc "Reload Apache"
  task :apache_reload do
    sudo "/etc/init.d/apache2 restart"
  end
end