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

require 'jenksin_pipeline_builder/version'
require 'jenksin_pipeline_builder/utils'
require 'jenksin_pipeline_builder/xml_helper'
require 'jenksin_pipeline_builder/compiler'
require 'jenksin_pipeline_builder/job_builder'
require 'jenksin_pipeline_builder/module_registry'
require 'jenksin_pipeline_builder/builders'
require 'jenksin_pipeline_builder/wrappers'
require 'jenksin_pipeline_builder/triggers'
require 'jenksin_pipeline_builder/publishers'
require 'jenksin_pipeline_builder/view'
require 'jenksin_pipeline_builder/generator'

require 'jenksin_pipeline_builder/cli/helper'
require 'jenksin_pipeline_builder/cli/view'
require 'jenksin_pipeline_builder/cli/pipeline'
require 'jenksin_pipeline_builder/cli/base'
