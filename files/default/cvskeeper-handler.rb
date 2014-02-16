require 'chef/log'
require 'chef/mixin/shell_out'

module Cvskeeper
  class EventHandler < ::Chef::EventDispatch::Base
    @resource_collection = nil
    @node = nil

    def converge_start(run_context)
      return unless Cvskeeper::Helpers.is_cvs_repo?

      # save resource collection for converge complete
      @resource_collection = run_context.resource_collection
      @node = run_context.node

      files = collect_paths(all_resources)
      Cvskeeper::Helpers.add_vcs(files)
    end

    def converge_complete
      return unless @resource_collection

      files = collect_paths(updated_resources)
      return if files.empty?

      message = []
      message << "Updated resources:"
      updated_resources.each do |res|
        message << "* #{res}"
      end

      Cvskeeper::Helpers.update_vcs(files, 'after', message.join("\n"))
    end

    private
    # The list of all resources in the current run context's +resource_collection+
    def all_resources
      @resource_collection.all_resources
    end

    # The list of all resources in the current run context's +resource_collection+
    # that are marked as updated
    def updated_resources
      @resource_collection.select { |r| r.updated }
    end

    def exclude_path
      r = Regexp.union(@node['cvs']['cvskeeper']['exclude'])
      Regexp.new("^(?:#{r.source})", r.options)
    end

    def collect_paths(resources)
      files = []
      resources.each do |r|
        next unless r.respond_to?(:path)
        next if !r.path || !r.path.start_with?('/etc')
        next if [:delete, 'delete', [:delete], ['delete']].include?(r.action)
        # FIXME: will this have side-effects? at least it prints logging out in unexpected place (here)
        next if r.should_skip?(r.action)
        files << r.path
      end

      files.uniq.reject do |f|
        exclude_path.match(f)
      end
    end
  end

  class Helpers
    extend Chef::Mixin::ShellOut

    def self.is_cvs_repo?
      File.directory?('/etc/CVS')
    end

    def self.add_vcs(files)
      add_vcs_dirs(files)

      # add each file to cvs
      add_files = files
        .reject { |f| in_vcs?(f) }
        .reject { |f| !File.exists?(f) }
        .reject { |f| File.symlink?(f) }
        .each { |f| files.delete(f) }
        .map { |f| relpath(f) }
      vcs_command_add(add_files) unless add_files.empty?

      # update cvs for files that already were in cvs
      update_vcs(files, 'before')
    end

    def self.add_vcs_dirs(files)
      # ensure dirs are in vcs
      dirs = files
        .map { |f| get_dirs(f) }
        .flatten
        .uniq
        .reject { |d| in_vcs?(d) }
        .reject { |d| !Dir.exists?(d) }
        .map { |d| relpath(d) }
        .compact

      return if dirs.empty?
      vcs_command_add(dirs, false)

      # cvs sucks, somewhy it doesn't update CVS/Entries when adding dirs
      vcs_command_status
    end

    def self.update_vcs(files, whence, extra_message = nil)
      files = files
        .reject { |f| !File.exists?(f) }
        .reject { |f| File.symlink?(f) }
        .map { |f| relpath(f) }

      vcs_command_commit(files, whence, extra_message) unless files.empty?
    end

    private

    def self.vcs_command_add(paths, commit=true)
      Chef::Log.warn "Cvskeeper: adding #{paths.join(', ')}"

      command = ''
      command << "cvs add #{paths.join(' ')}; "
      if commit
        message = '- Initial add from Chef recipe'
        command << "cvs ci -m '#{cvs_message(message)}' #{paths.join(' ')}"
      end
      run_cvs(command)
    end

    def self.vcs_command_commit(files, whence, extra_message = '')
      Chef::Log.warn "Cvskeeper: committing #{files.join(", ")}"
      message = cvs_message("- Changes #{whence} Chef recipe run")
      if extra_message
        message << "\n\n#{extra_message}"
      end
      command = "cvs ci -l -m '#{message}' #{files.join(' ')}"
      run_cvs(command)
    end

    def self.vcs_command_status
      command = 'cvs status'
      run_cvs(command)
    end

    def self.get_dirs(path)
      dir = File.dirname(path)
      dirs = [dir]
      if dir.length > 1 && dir.include?('/')
        dirs << get_dirs(dir)
      end
      dirs.reverse
    end

    def self.relpath(path, target='/etc')
      if path.start_with?("#{target}/")
        path.sub(%r[#{target}(?:/|$)], '')
      else
        nil
      end
    end

    def self.cvs_message(message)
      if ENV.has_key?('SUDO_USER')
        message << " (on behalf of #{ENV['SUDO_USER']})"
      end

      message
    end

    def self.run_cvs(command)
      cvswrapper = "#{Chef::Config['file_cache_path']}/cvswrapper"
      env = {}
      env['CVS_RSH'] = cvswrapper if File.exists?(cvswrapper)
      command = "set -ex; #{command}"
      so = shell_out(command, :env => env, :cwd => '/etc')
      raise "CVS error: #{so.stderr}\n#{so.stdout}" unless so.exitstatus == 0
    end

    def self.in_vcs?(path)
      dir, entry = File.split(path)
      return false unless Dir.exists?("#{dir}/CVS")

      is_dir = File.directory?(path)
      File.readlines("#{dir}/CVS/Entries").map do |l|
        e = l.chomp.split(/\//)
        return true if is_dir && e[0] == 'D' && e[1] == entry
        return true if !is_dir && e[0] != 'D' && e[1] == entry
      end
      false
    end
  end
end
