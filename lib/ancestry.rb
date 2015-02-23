require File.join(File.expand_path(File.dirname(__FILE__)), 'ancestry/class_methods')
require File.join(File.expand_path(File.dirname(__FILE__)), 'ancestry/instance_methods')
require File.join(File.expand_path(File.dirname(__FILE__)), 'ancestry/exceptions')
require File.join(File.expand_path(File.dirname(__FILE__)), 'ancestry/has_ancestry')

module Ancestry
  # ANCESTRY_PATTERN = /\A[0-9]+(\/[0-9]+)*(,[0-9]+(\/[0-9]+)*)*\Z/
  # This was modified to cycle through an array of values that may match this pattern, rather than 1 value
  ANCESTRY_PATTERN = /[\A[0-9]+(\/[0-9]+)*([0-9]+(\/[0-9]+)*)*\Z]/  
end