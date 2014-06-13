#
# Copyright (c) 2014 Igor Moochnick
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

module JenkinsPipelineBuilder
  class PullRequestGenerator
    
  end
  class PullRequest

    # Accessors
    attr_reader :project    # The root project YAML as a hash
    attr_reader :number     # The pull request number
    attr_reader :jobs       # The jobs in the pull request as an array of hashes
    attr_reader :generator  # The generator job YAML as a hash

    # Initialize
    def initialize(project, number, jobs, generator)
        # Set instance vars
        @project = project.clone 
        @number = number
        @jobs = jobs
        @generator = generator

        # Debug
        puts "===Project==="
        puts @project
        puts "===Number==="
        puts @number
        puts "===Jobs==="
        puts @jobs
        puts "===Generator==="
        puts @generator

        # Run
        run!
    end

    private

    # Apply all changes
    def run!
        change_name!
        update_jobs!
        change_git!
    end

    # Change the git branch for each job
    def change_git!
        @jobs.each do |job|
            job[:value][:scm_branch] = "origin/pr/#{@number}/head"
        end
    end

    # Change the name of the pull request project
    def change_name!
        @project[:name] << "-PR#{@number}" if @project[:name]
        @project[:value][:name] << "-PR#{@number}" if @project[:value][:name]
    end

    # Apply any specified changes to each job
    def update_jobs!
        @jobs.each do |job|
            name = job[:name]
            changes = nil
            # Search the generator for changes
            @generator[:value][:jobs].each do |gen|
                if gen.keys[0] == name.to_sym
                    changes = gen[name.to_sym]
                end
            end
            # Apply changes
            if changes != nil
                apply_changes!(job[:value], changes)
            end
        end
    end

    # Apply changes to a single job
    def apply_changes!(original, changes)
        # Apply the specified changes
        changes.each do |cK, cV|
            # The change doesn't already exist in the original
            unless original.include? cK
                original[cK] = cV
            # The change does exists, so we need to replace!
            else
                # Loop through the original job
                original.each do |oK, oV|
                    if oK == cK
                        # The change is a hash
                        if cV.is_a? Hash and oV.is_a? Hash
                            apply_changes!(oV, cV)
                        # The change is an array
                        elsif cV.is_a? Array and oV.is_a? Array 
                            # Add changes
                            # cV.each do |elem|
                            #     unless oV.include? elem
                            #         original[oK].push elem
                            #     end
                            # end
                            # Replace entire array
                            original[oK] = cV
                        # The change is a string, etc
                        else 
                            original[oK] = cV
                        end
                    end
                end
            end
        end
    end
end

  end # class
end # module