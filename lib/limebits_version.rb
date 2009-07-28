
module LimebitsVersion

  class << self
    def get_git_version_info dir_path = '.'
      return Dir.chdir(dir_path) do 

        git_branch_string =
          execute('set -o pipefail; git branch --no-color | grep \\* | cut -d" " -f2')[0].strip
        git_commit_string = execute('git log -n1 --pretty=format:%H')[0].strip

        git_tag_string = nil
        for tag in execute("git for-each-ref --format='%(*objectname)" +
                           " %(refname:short)' --sort=-taggerdate refs/tags")[0]
          if tag.include? git_commit_string
            git_tag_string = tag.split(' ', 2).last.strip
            break
          end
        end

        git_status_string = execute("make status")[0]
        git_status_a_exit_code = execute('make fail-if-not-pristine >& /dev/null', [0, 2])[1]

        next {
          'tag'         => git_tag_string,
          'branch'      => git_branch_string,
          'commit'      => git_commit_string,
          'status'      => git_status_string,
          'pristine'    => (git_status_a_exit_code == 0),
        }
      end
    end

    private

    def execute(cmd, successful_exit_codes = [0])
      out = `#{cmd}`
      exitcode = $?.exitstatus
      raise "Failed with exit code #{exitcode}: #{cmd}" unless
        successful_exit_codes.include? exitcode
      return [out, exitcode, $?]
    end
    
  end
  
end
