class MigrationSettings
  
  attr_reader :git, :version, :original_branch, :migration_branch, :revision, :klass
  
  def initialize(options={})
    @git              = Git.open("#{RAILS_ROOT}")
    @version          = options[:version]
    @klass            = options[:klass]
    @revision         = options[:revision]
    @stash            = (git.status.changed.size > 0) ? true : false
    @clear_stash      = (git.branch.stashes.size > 0) ? true : false
    @migration_branch = "gitty_migration_".concat Digest::MD5.hexdigest("#{Time.now}")
    @original_branch  = git.branch.name
  end
  
  def revision
    if @revision.nil?
      filename = "#{@version}_#{@klass}.rb"
      file = Dir["db/migrate/0*#{filename}"].first
      commit = @git.log(10000).object(file).each{|c|c}.reverse.first
      self.class.send :define_method, :revision_author do commit.author.name end
      self.class.send :define_method, :revision_date do commit.date.to_s end
      self.class.send :define_method, :revision_message do commit.message end
      @revision = commit.sha
    end
    @revision
  rescue
    @revision = nil
  end
  
  def stash?
    @stash
  end
  
  def clear_stash?
    @clear_stash
  end
  
end