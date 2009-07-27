
module LimebitsVersion

  class << self
    def get_git_version_info

      git_branch_string = `git branch --no-color | grep \\* | cut -d" " -f2`.strip
      git_commit_string = `git log -n1 --format=%H`.strip

      git_tag_string = ''
      for tag in `git for-each-ref --format='%(*objectname) %(refname:short)' --sort=-taggerdate refs/tags`
        if tag.include? git_commit_string
          git_tag_string = tag.split(' ', 2).last.strip
          break
        end
      end

      git_status_string = `git status`
      git_status_a_exit_code = system 'git status -a > /dev/null'
      datetime_string = Time.new.inspect

      return {
        'tag'         => git_tag_string,
        'branch'      => git_branch_string,
        'commit'      => git_commit_string,
        'status'      => git_status_string,
        'pristine'    => (not git_status_a_exit_code),
        'deployed_at' => datetime_string
      }
    end
    
  end
  
end
