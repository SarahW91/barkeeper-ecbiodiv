# Change these
server '46.101.149.34', port: 1694, roles: [:web, :app, :db], primary: true

set :repo_url,        'ssh://Sarah_Wiechers@bitbucket.org/kai42/gbol5.git'
set :application,     'gbol5'
set :user,            'sarah'
set :puma_threads,    [1, 5]
set :puma_workers,    2

# Always deploy currently checked out branch
set :branch, $1 if `git branch` =~ /\* (\S+)\s/m

set :rbenv_type, :user
set :rbenv_ruby, '2.3.3'

# Don't change these unless you know what you're doing
set :pty,             false
set :use_sudo,        false
set :stage,           :production
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_error_log,  "#{release_path}/log/puma.error.log"
set :ssh_options,     { port: 1694, forward_agent: true, user: fetch(:user), keys: %w(I:/.ssh/id_rsa) }
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true  # Change to false when not using ActiveRecord

set :sidekiq_log => File.join(release_path, 'log', 'sidekiq.log')
set :sidekiq_config => File.join(shared_path, 'config', 'sidekiq.yml')
#
# set :default_env, {
#     'VERSION' => '',
#     'RELEASE_DATE' => '',
#     'LAST_COMMIT_ID' => '',
#     'LAST_COMMIT_AUTHOR' => ''
# }

## Defaults:
# set :scm,           :git
# set :branch,        :master
# set :format,        :pretty
# set :log_level,     :debug
# set :keep_releases, 5

## Linked Files & Directories (Default None):
# set :linked_files, %w{config/database.yml}
# set :linked_dirs,  %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  before :start, :make_dirs
end

namespace :deploy do
  desc "Make sure local git is in sync with remote."
  task :check_revision do
    on roles(:app) do
      unless `git rev-parse HEAD` == `git rev-parse origin/#{fetch(:branch)}`
        puts "WARNING: HEAD is not the same as origin/master"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end

  desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end

  # desc 'Restart application'
  # task :restart do
  #   on roles(:app), in: :sequence, wait: 5 do
  #     invoke 'puma:restart'
  #   end
  # end

  before :starting,     :check_revision
  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  # after  :finishing,    :restart
end

before 'deploy:assets:precompile', :symlink_config_files

desc "Link shared files"
task :symlink_config_files do
  symlinks = {
      "#{shared_path}/config/database.yml" => "#{release_path}/config/database.yml",
      "#{shared_path}/config/local_env.yml" => "#{release_path}/config/local_env.yml"
  }

  on roles(:app) do
    execute symlinks.map{|from, to| "ln -nfs #{from} #{to}"}.join(" && ")
  end
end
#
# desc "Set new version info"
# task :set_version_info do
#   # needed: version number, release time, last commit id, person who did this commit
#
# end

# ps aux | grep puma    # Get puma pid
# kill -s SIGUSR2 pid   # Restart puma
# kill -s SIGTERM pid   # Stop puma