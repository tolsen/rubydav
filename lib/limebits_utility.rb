
module Limebits

  module Utility

    class << self
    
      def execute(cmd, successful_exit_codes = [0])
        out = `#{cmd}`
        exitcode = $?.exitstatus
        raise "Failed with exit code #{exitcode}: #{cmd}" unless
          successful_exit_codes.include? exitcode
        return [out, exitcode, $?]
      end
      
    end
    
  end
end
