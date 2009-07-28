
module LimebitsVersion

  class << self
    def get_git_version_info dir_path = '.'
      return Dir.chdir(dir_path) do 

        git_branch_string =
          execute('set -o pipefail; git branch --no-color | grep \\* | cut -d" " -f2').strip
        git_commit_string = execute('git log -n1 --format=%H').strip

        git_tag_string = nil
        for tag in execute("git for-each-ref --format='%(*objectname)" +
                           " %(refname:short)' --sort=-taggerdate refs/tags")
          if tag.include? git_commit_string
            git_tag_string = tag.split(' ', 2).last.strip
            break
          end
        end

        git_status_string = execute("git status", [0, 1])

        git_status_a_exit_code = system 'git status -a > /dev/null'
        raise "git status -a failed: #{$?}" unless
          [0, 1].include? $?.exitstatus

        next {
          'tag'         => git_tag_string,
          'branch'      => git_branch_string,
          'commit'      => git_commit_string,
          'status'      => git_status_string,
          'pristine'    => (not git_status_a_exit_code),
        }
      end
    end

    private

    def execute(cmd, successful_exit_codes = [0])
      out = `#{cmd}`
      raise "Failed with exit code #{$?}: #{cmd}" unless
        successful_exit_codes.include? $?.exitstatus
      return out
    end
    
  end
  
end
