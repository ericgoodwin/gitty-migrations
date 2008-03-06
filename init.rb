require 'git'
require 'gitty_migration'
ActiveRecord::Migration.send(:include, GittyMigration)