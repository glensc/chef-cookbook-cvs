require 'chef/log'
require 'chef/mixin/shell_out'
require 'chef/event_dispatch/base'

module Cvskeeper
  class EventHandler < ::Chef::EventDispatch::Base
    @resource_collection = nil
    @node = nil

    def converge_start(run_context)
      return unless Cvskeeper::Helpers.cvs_repo?

      # save resource collection for converge complete
      @resource_collection = run_context.resource_collection
      @node = run_context.node

      files = collect_paths(all_resources)
      Cvskeeper::Helpers.add_vcs(@node, files)
    rescue => e
      Chef::Log.warn "Cvskeeper: '#{e}':  #{e.backtrace[0]}"
    end

    def converge_complete
      return unless @resource_collection

      files = collect_paths(updated_resources)
      return if files.empty?

      Cvskeeper::Helpers.update_vcs(@node, files, 'after', updated_resources_message)
    rescue => e
      Chef::Log.warn "Cvskeeper: '#{e}':  #{e.backtrace[0]}"
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

    # return updated resources message
    # can be disabled with 'updated_resources' attribute
    def updated_resources_message
      message = []

      if @node['cvs']['cvskeeper']['updated_resources']
        message << 'Updated resources:'
        updated_resources.each do |res|
          message << "* #{res}"
        end
      end

      message.join("\n")
    end

    def path_excluded?(path)
      patterns = @node['cvs']['cvskeeper']['exclude'] || []
      patterns.any? do |p|
        File.fnmatch(p, path)
      end
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
        path_excluded?(f)
      end
    end
  end

  class Helpers
    extend Chef::Mixin::ShellOut

    def self.cvs_repo?
      File.directory?('/etc/CVS')
    end

    def self.add_vcs(node, files, message = nil)
      add_vcs_dirs(node, files)
      stat_outdated(node, files)

      # add each file to cvs
      add_files = files
        .reject { |f| in_vcs?(f) }
        .reject { |f| !File.exists?(f) }
        .reject { |f| File.symlink?(f) }
        .each { |f| files.delete(f) }
        .map { |f| relpath(f) }
      vcs_command_add(node, add_files, true, message) unless add_files.empty?

      # assume message set, that we only want to add new files
      # XXX refactor this!
      return unless message == nil

      # update cvs for files that already were in cvs
      update_vcs(node, files, 'before')
    end

    # ensure dirs are in vcs
    def self.add_vcs_dirs(node, files)
      dirs = files
        .map { |f| get_dirs(f) }
        .flatten
        .uniq
        .reject { |d| in_vcs?(d) }
        .reject { |d| !Dir.exists?(d) }
        .reject { |d| Dir.exists?("#{d}/CVS") }
        .map { |d| relpath(d) }
        .compact

      return if dirs.empty?
      vcs_command_add(node, dirs, false)

      # cvs sucks, somewhy it doesn't update CVS/Entries when adding dirs
      vcs_command_status(node)
    end

    # check that mentioned files do not have 'Needs Merge' status
    def self.stat_outdated(node, files)
      files = files
        .map { |f| relpath(f) }
      p files
      command = "cvs status #{files.join(' ')}"
      so = run_cvs(node, command)

      status = {}
      so.stdout.split(/\n/).each { |line|
        status[$1.chomp] = $2.chomp if line =~ /^File:\s+(\S+)\s+Status:\s+(.*)$/
      }
      Chef::Log.debug("CVS #{status.inspect}")
    end

    def self.update_vcs(node, files, whence, extra_message = nil)
      # add dirs/files to vcs first
      message = vcs_commit_message("- File added during recipe run on #{node.fqdn}")
      message << "\n\n#{extra_message}" if extra_message
      add_vcs(node, files, message)

      files = files
        .reject { |f| !File.exists?(f) }
        .reject { |f| File.symlink?(f) }
        .map { |f| relpath(f) }

      vcs_command_commit(node, files, whence, extra_message) unless files.empty?
    end

    private

    def self.vcs_command_add(node, paths, commit = true, message = nil)
      Chef::Log.warn "Cvskeeper: adding #{paths.join(', ')}"

      command = ''
      command << "cvs add #{paths.join(' ')}; "
      if commit
        message = vcs_commit_message("- Initial add from Chef recipe on #{node.fqdn}") if message == nil
        command << "cvs ci -m '#{message}' #{paths.join(' ')}"
      end
      run_cvs(node, command)
    end

    def self.vcs_command_commit(node, files, whence, extra_message = '')
      Chef::Log.warn "Cvskeeper: committing #{files.join(", ")}"
      message = vcs_commit_message("- Changes #{whence} Chef recipe run on #{node.fqdn}")
      message << "\n\n#{extra_message}" if extra_message
      command = "cvs ci -l -m '#{message}' #{files.join(' ')}"
      run_cvs(node, command)
    end

    def self.vcs_command_status(node)
      command = 'cvs status'
      run_cvs(node, command)
    end

    def self.get_dirs(path)
      dir = File.dirname(path)
      dirs = [dir]
      dirs << get_dirs(dir) if dir.length > 1 && dir.include?('/')
      dirs.reverse
    end

    def self.relpath(path, target = '/etc')
      if path.start_with?("#{target}/")
        path.sub(/#{target}(?:\/|$)/, '')
      else
        nil
      end
    end

    def self.vcs_commit_message(message)
      message << " (on behalf of #{ENV['SUDO_USER']})" if ENV.key?('SUDO_USER')
      message
    end

    def self.run_cvs(node, command)
      cvswrapper = node['cvs']['cvswrapper']
      env = {}
      env['CVS_RSH'] = cvswrapper if cvswrapper
      command = "set -ex; #{command}"
      so = shell_out(command, :env => env, :cwd => '/etc', :umask => 0002)
      Chef::Log.debug("CVS[#{command}]: rc:#{so.exitstatus}, out:'#{so.stderr}', err:'#{so.stdout}'; env:#{env.inspect}")

      raise "CVS error: #{so.stderr}\n#{so.stdout}" unless so.exitstatus == 0
      return so
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
