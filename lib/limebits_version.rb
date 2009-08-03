
module LimebitsVersion

  class << self
    def get_git_version_info dir_path = '.'
      return Dir.chdir(dir_path) do 

        git_branch_string =
          execute('set -o pipefail; git branch --no-color | grep \\* | cut -d" " -f2')[0].strip
        git_commit_string = execute('git log -n1 --pretty=format:%H')[0].strip

        git_tag_string = nil
        for tag in execute("git for-each-ref --format='%(*objectname)" +
                           " %(refname)' --sort=-taggerdate refs/tags")[0]
          if tag.include? git_commit_string
            git_tag_string = tag.split(' ', 2).last.strip
            git_tag_string.sub!('refs/tags/', '') 
            break
          end
        end

        pristine =
          execute("(git submodule foreach 'git status -a; test $? -ne 0'" +
                  " && (git status -a; test $? -ne 0)) >& /dev/null",
                  [0, 1])[1] == 0

        next {
          'tag'         => git_tag_string,
          'branch'      => git_branch_string,
          'commit'      => git_commit_string,
          'pristine'    => pristine,
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
