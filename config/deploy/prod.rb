set :application, "nucore"
set :user, "nucore"
set :deploy_to, "/home/nucore/nucore.northwestern.edu"
set :rails_env, "production"

role :web, "nucore-prod.nubic.northwestern.edu"
role :app, "nucore-prod.nubic.northwestern.edu"
role :db,  "nucore-prod.nubic.northwestern.edu", :primary => true

set :use_sudo, false

########################################
# github
set :scm, "git"
set :deploy_via, :export
set :repository, "git@github.com:tablexi/nucore-nu.git"
set :branch, "master"

# forward keys to github
ssh_options[:forward_agent] = true

# github password
default_run_options[:pty] = true

########################################
default_environment["LD_LIBRARY_PATH"] = "/usr/lib/oracle/11.2/client64/lib"
default_environment["ORACLE_HOME"] = "/usr/lib/oracle/11.2/client64/lib"

after 'deploy:finalize_update', 'deploy:symlink_configs', 'deploy:symlink_revision'

namespace :deploy do
  task :restart, :except => { :no_release => true } do
    run "bash -l -c \"cd #{release_path} && RAILS_ENV=production bundle exec rake daemon:stop[auto_cancel]\""
    run "bash -l -c \"cd #{release_path} && RAILS_ENV=production bundle exec rake daemon:start[auto_cancel]\""
  end

  task :symlink_configs do
    run "ln -nfs #{deploy_to}/shared/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{deploy_to}/shared/config/settings.local.yml #{release_path}/config/settings.local.yml"
    run "ln -nfs #{deploy_to}/shared/config/ldap.yml #{release_path}/config/ldap.yml"
    run "ln -nfs #{deploy_to}/shared/config/newrelic.yml #{release_path}/config/newrelic.yml"
    run "ln -nfs #{deploy_to}/shared/config/database.yml #{release_path}/vendor/engines/nucs/config/database.yml"
    run "ln -nfs #{deploy_to}/shared/config/settings.pmu.yml #{release_path}/vendor/engines/pmu/config/settings.yml"
    run "ln -nfs #{deploy_to}/shared/files #{release_path}/public/files"
  end

  task :symlink_revision, :roles => :app do
    run "ln -nfs #{release_path}/REVISION #{release_path}/public/REVISION.txt"
  end

end

########################################
# save disk space
#   http://capitate.rubyforge.org/recipes/deploy.html#deploy:cleanup

after 'deploy:restart', 'deploy:cleanup'