# I use this Capistrano task so I don't have manually run 'git push' before 'cap
# deploy'. It includes some error checking to make sure I'm on the right branch
# (master) and haven't got any uncommitted changes.

# Simply add the code below to config/deploy.rb, then run 'cap deploy:push' to
# test it, and 'cap deploy' to deploy as usual.

lock '3.3.5'

set :application, 'testapp'
set :repo_url, 'https://github.com/Srav6924/Ruby/tree/master/testapp.git'

ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

set :use_sudo, false
set :bundle_binstubs, nil
set :linked_files, fetch(:linked_files, []).push('config/database.yml')
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')

after 'deploy:publishing', 'deploy:restart'

namespace :deploy do
  task :restart do
    invoke 'unicorn:reload'
  end
end

namespace :deploy do
  desc "Push local changes to Git repository"
  task :push do

    # Check for any local changes that haven't been committed
    # Use 'cap deploy:push IGNORE_DEPLOY_RB=1' to ignore changes to this file (for testing)
    status = %x(git status --porcelain).chomp
    if status != ""
      if status !~ %r{^[M ][M ] config/deploy.rb$}
        raise Capistrano::Error, "Local git repository has uncommitted changes"
      elsif !ENV["IGNORE_DEPLOY_RB"]
        # This is used for testing changes to this script without committing them first
        raise Capistrano::Error, "Local git repository has uncommitted changes (set IGNORE_DEPLOY_RB=1 to ignore changes to deploy.rb)"
      end
    end

    # Check we are on the master branch, so we can't forget to merge before deploying
    branch = %x(git branch --no-color 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \\(.*\\)/\\1/').chomp
    if branch != "master" && !ENV["IGNORE_BRANCH"]
      raise Capistrano::Error, "Not on master branch (set IGNORE_BRANCH=1 to ignore)"
    end

    # Push the changes
    if ! system "git push #{fetch(:repository)} master"
      raise Capistrano::Error, "Failed to push changes to #{fetch(:repository)}"
    end

  end
end

if !ENV["NO_PUSH"]
  before "deploy", "deploy:push"
  before "deploy:migrations", "deploy:push"
end
