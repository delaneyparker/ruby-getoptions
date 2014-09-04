#!/usr/bin/env ruby
 
#
# == Synopsis
#
# GetOptions - Yet another command line argument parser for Ruby. 
#
# If you are familiar with Perl's Getopt::Long specification syntax you should 
# feel right at home.  The following specifications are currently supported:
#
#    default    -- This is the default case, the option is either there or it isn't
#    flag!      -- You can specify either --flag or --no-flag to set true or false
#    name|a1|a2 -- You can use '|' to set up option aliases.  In this example, the
#                  'name' option will be set if either 'name', 'a1', or 'a2' is 
#                  specified on the command line.
#
#    optional:x -- An argument with an optional argument of type x
#    required=x -- An argument with a required argument of type x 
#    alist=@x   -- An argument that takes a list of things of type x
#
# The following types are currently supported:
#        s|string  -- A string value 
#        i|integer -- An integer value
#        f|float   -- A floating point value
#        For integer and float, an exception will be thrown if ruby
#        can't find a way to convert the supplied argument string.
# 
# As with Getopt::Long, you specify the long form of the option, but it can 
# parse short options as well.  For example, if you have an option named 'help',
# both --help and -h would enable the option.  You can also specify a small 
# portion of the long form, and if it is enough to uniquely identify the option,
# it will work.  For example, --he or --hel would map to --help as long as you
# don't have --hell, --hello, ... as an option.
# 
# There are several ways to get the option data after parsing.  Of course there
# is the hash style, which could look something like:
#  
#   options = GetOptions.new(%w(help verbose!))
#   puts "I'm going to go do stuff now..." if options['verbose']
#
# You can also use a symbol (options[:verbose]) instead of a string if you want.
# In addition, you can access fields using the .-style accessor syntax:
#
#   show_help() if options.help
#
#
# == Examples
#
# Kicking the tires:
#
#   $ cat myscript1.rb
#   require 'getoptions'
#
#   opt = GetOptions.new(%w(help debug! verbose+ prefix:s size=i host=@s)) 
#   p opt
#
#   $ ./myscript1.rb --help 
#   help: true  
#
#   $ ./myscript1.rb --debug   
#   debug: true
#
#   $ ./myscript1.rb --no-debug
#   debug: false
#
#   $ ./myscript1.rb -vvvvv    
#   verbose: 5
#
#   $ ./myscript1.rb -vv --verbose
#   verbose: 3
#
#   $ ./myscript1.rb --pre        
#   prefix: nil
#
#   $ ./myscript1.rb --pre myprefix
#   prefix: "myprefix"
#
#   $ ./myscript1.rb --size 5      
#   size: 5
#
#
# Mixing arguments with non-arguments:
#
#   $ cat myscript2.rb
#   require 'getoptions'
#
#   opt = GetOptions.new(%w(help debug! verbose+ prefix:s size=i host=@s)) 
#   p opt
#   puts '--'
#   p ARGV
#
#   $ ./myscript2.rb --siz 10 file1 file2 file3
#   size: 10
#   --
#   ["file1", "file2", "file3"]
#
#   $ ./myscript2.rb --host host1 host2 -- file1 file2 file3
#   host: ["host1", "host2"]
#   --
#   ["file1", "file2", "file3"]
#
#
# Processing your own input stream:
#
#   $ cat myscript3.rb
#   require 'getoptions'
#
#   input = %w(-vv -w 1 -2 -- file1)
#   opt = GetOptions.new(%w(verbose+ weights:@i), input)
#   p opt
#   puts '--'
#   p input
#
#   $ ./myscript3.rb
#   verbose: 2
#   weights: [1, -2]
#   --
#   ["file1"]
#
#

require 'abbrev'

class GetOptions

  class ParseError < Exception
  end

  # For select, reject, and other goodies
  include Enumerable

  # :call-seq:
  #   new(option_specs, input = ARGV) -> opt
  #
  # Parse input based on metadata in option_specs.
  #
  # == Examples
  # 
  #   opt = GetOptions.new(%w(help verbose! strarg=s))
  #   puts "I'm going to go do stuff..." if (opt.verbose)
  #   ...
  #
  def initialize(option_specs, input = ARGV)
    build_dict(option_specs)

    @options = {}
    leftover = []
    until input.empty?
      arg = input.shift

      case arg
      # Stop if you hit --
      when '--' 
        break 

      # Long form 
      when /^--(\S+)/
        o, a = $1.split('=', 2)
        input.unshift(a) if a
        input = process_arguments(o, input) 

      # Short form
      when /^-(\S+)/
        o, a = $1.split('=', 2)
        input.unshift(a) if a
        o.scan(/./) do |c|
          input = process_arguments(c, input)
        end

      # Not an option, leave it
      else
        leftover << arg
      end
    end 

    # Put what didn't parse back into input
    input.concat(leftover)
  end 

  # :call-seq:
  #   opt[key] -> value
  #
  # Returns the value of the specified option.  If the option was in
  # the specification but not found in the input data, nill is returned.
  #
  def [](k)
    raise ParseError.new("`nil' cannot be an option key") if (k.nil?)
    sym = k.to_sym
    key = k.to_s

    case
    when @options.has_key?(sym); @options[sym]
    when @dict.has_key?(key);    (@dict[key].option_type == :increment) ? 0 : nil
    else raise ParseError.new("program tried to access an unknown option: #{key.inspect}")
    end
  end

  # :call-seq:
  #   has_option?(key) -> true or false
  #
  # Returns true if the specified key exists in the option input.
  #
  # == Examples
  # 
  #   opt = GetOptions.new(%w(help verbose! strarg=s))
  #   puts "I'm going to go do stuff..." if (opt.has_option(:verbose))
  #   puts "I don't exist..." if (opt.has_option(:bogus))
  #   ...
  #
  def has_option?(k)
    raise ParseError.new("`nil' cannot be an option key") if (k.nil?)
    @options.has_key?(k.to_sym)
  end

  alias to_s inspect

  def inspect
    @options.sort_by{|k| k.to_s}.collect do |key, val|
      "%s: %s" % [key.inspect, val.inspect]  
    end.join($/)
  end

  # :call-seq:
  #   opt.each { |key,val| block } -> Hash 
  # 
  # Iterate over each parsed option name and value.
  #
  # == Examples
  # opt.each do |key,val|
  #   puts "#{key} -> #{val.inspect}"
  # end
  # 
  def each
    @options.each do |key,value|
      yield key.to_s, value
    end
  end

  private

  # Wrapper to hash accessor
  def method_missing(method, *args) #:nodoc:
    self[method]
  end

  # Builds a keyword dictionary based on option specification
  def build_dict(option_specs) #:nodoc:
    @dict = {}
    keys = []
    option_specs.each do |option_spec|
      # Parse the specification
      m, label, oper, cont, arg = *option_spec.match(/([^=:]+)(?:([=:])([@])?(\w+))?/)
      raise ParseError.new("invalid option format for '#{option_spec}'") unless m

      # Figure out the specification type
      is_bang_arg  = label.gsub!(/!$/, '')
      is_increment = label.gsub!(/\+$/, '')
      forms        = label.split('|')
      key          = forms.first

      # Create an instance of OptionDefinition to hold metat data
      od = OptionDefinition.new(key)
      od.option_type = :boolean   if is_bang_arg
      od.option_type = :increment if is_increment
      if (arg)
        od.option_type = (oper == '=') ? :required_argument : :optional_argument
        od.container_type = case cont
          when '@'; :array
          else      :scalar
          end
        od.argument_type = case arg
          when 'f', 'float'  ; :float
          when 'i', 'integer'; :integer
          when 's', 'string' ; :string
          else raise ParseError.new("unknown argument type '#{arg}'")
          end
      end

      # Process alternate key names
      forms.each do |k|
        @dict[k] = od.dup
        keys << k
      end

      # Only support negation on long option names
      if (is_bang_arg)
        @dict["no-#{key}"] = od.dup
      end
    end

    # Allow abbreviated long options
    keys.abbrev.each do |ab,key|
      @dict[ab] = @dict[key].dup
      @dict[ab].abbreviated = true unless (ab == key)
    end
  end 

  # Parse all arguments for the current option
  def process_arguments(k, input) #:nodoc:
    if (opt = @dict[k])
      key = opt.key
      case opt.option_type
      when :boolean  
        @options[key] = (k != "no-#{key}")
      when :increment
        @options[key] ||= 0
        @options[key] +=  1
      when :optional_argument, :required_argument
        args = []
        loop do 
          break if (input.empty?)
          arg = input.shift

          is_arg = case arg
          # If it matches a long argument name, it isn't an argument
          when '--'
            false
          when /^--(\S+)/
            o, a = $1.split('=', 2)
            !@dict.has_key?(o)
          # If this is a valid shorthand option string, abort
          when /^-(\S+)/
            o, a = $1.split('=', 2)
            !o.scan(/./).all? { |c| @dict.has_key?(c) }
          else 
            true
          end

          # We've hit another option, get outta here
          #if (arg =~ /^-/)
          unless (is_arg)
            input.unshift(arg) 
            break
          end
          args << arg
          # If this is a scalar type, stop after the first argument
          break if opt.container_type == :scalar
        end

        if (args.empty?) 
          # No argument found, and one was required, complain about it
          if (opt.option_type == :required_argument) 
            raise ParseError.new("missing required argument for '#{key}'")
          # No argument found, but it was optional, set a default value
          else            
            case opt.container_type
            when :scalar; @options[key] = nil
            when :array;  @options[key] = []
            end
          end
        else
          args.each do |arg|
            val = case opt.argument_type
            when :float   
              # Try to parse float option, toss an exception if the parse failed
              Float(arg) rescue 
                raise ParseError.new("expecting float value for option '#{key}'") 
            when :integer 
              # Try to parse integer option, toss an exception if the parse failed
              Integer(arg) rescue  
                raise ParseError.new("expecting integer value for option '#{key}'") 
            else
              # Assume string type (no processing needed)
              arg
            end
            # Either set the option value (scalar) or add it to the list (array)
            case opt.container_type
            when :scalar; @options[key] = val
            when :array;  (@options[key] ||= []) << val
            end
          end
        end
      end
    else
      # If an exact match isn't found, try to make a suggestion
      candidates = @dict.keys.select do |c|
        (!@dict[c].is_abbreviated? && c =~ /^#{k}/)
      end
      matches = case candidates.size
      when 0
        nil
      when 1
        ", did you mean #{candidates.first}?"
      else
        ", close matches are: " +
        candidates[0, candidates.size - 1].join(", ") +
        " and " + candidates.last
      end
      raise ParseError.new("unknown option '#{k}'#{matches || ''}")
    end

    input
  end


  class OptionDefinition #:nodoc: all
    attr_accessor :key
    attr_accessor :option_type
    attr_accessor :argument_type
    attr_accessor :container_type
    attr_accessor :abbreviated

    def initialize(key)
      @key = key.to_sym
      @option_type = :boolean
      @abbreviated = false
    end

    def is_abbreviated? 
      @abbreviated
    end
  end

end
