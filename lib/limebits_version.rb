require File.dirname(__FILE__) + '/limebits_utility.rb'

module LimebitsVersion

  class << self
    def get_git_version_info dir_path = '.'
      return Dir.chdir(dir_path) do 

        git_branch_string =
          Limebits::Utility.execute('bash -c "set -o pipefail; git branch --no-color | grep \\* | cut -d\' \' -f2"')[0].strip
        git_commit_string = Limebits::Utility.execute('git log -n1 --pretty=format:%H')[0].strip

        git_tag_string = nil

        git_for_each_ref_cmd = ("git for-each-ref --format='%(*objectname)" +
                                " %(refname)' --sort=-taggerdate refs/tags")
        for tag in Limebits::Utility.execute(git_for_each_ref_cmd)[0]
          if tag.include? git_commit_string
            git_tag_string = tag.split(' ', 2).last.strip
            git_tag_string.sub!('refs/tags/', '') 
            break
          end
        end

        pristine_cmd =
          "(git submodule foreach 'git status -a; test $? -ne 0'" +
          " && (git status -a; test $? -ne 0)) > /dev/null 2>&1"
        pristine = Limebits::Utility.execute(pristine_cmd,[0, 1])[1] == 0

        next {
          'tag'         => git_tag_string,
          'branch'      => git_branch_string,
          'commit'      => git_commit_string,
          'pristine'    => pristine,
        }
      end
    end

  end
  
end
