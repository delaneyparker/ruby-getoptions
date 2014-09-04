== Synopsis

GetOptions - Yet another command line argument parser for Ruby. 

If you are familiar with Perl's Getopt::Long specification syntax you should 
feel right at home.  The following specifications are currently supported:

   default    -- This is the default case, the option is either there or it isn't
   flag!      -- You can specify either --flag or --no-flag to set true or false
   name|a1|a2 -- You can use '|' to set up option aliases.  In this example, the
                 'name' option will be set if either 'name', 'a1', or 'a2' is 
                 specified on the command line.

   optional:x -- An argument with an optional argument of type x
   required=x -- An argument with a required argument of type x 
   alist=@x   -- An argument that takes a list of things of type x

The following types are currently supported:
       s|string  -- A string value 
       i|integer -- An integer value
       f|float   -- A floating point value
       For integer and float, an exception will be thrown if ruby
       can't find a way to convert the supplied argument string.

As with Getopt::Long, you specify the long form of the option, but it can 
parse short options as well.  For example, if you have an option named 'help',
both --help and -h would enable the option.  You can also specify a small 
portion of the long form, and if it is enough to uniquely identify the option,
it will work.  For example, --he or --hel would map to --help as long as you
don't have --hell, --hello, ... as an option.

There are several ways to get the option data after parsing.  Of course there
is the hash style, which could look something like:
 
  options = GetOptions.new(%w(help verbose!))
  puts "I'm going to go do stuff now..." if options['verbose']

You can also use a symbol (options[:verbose]) instead of a string if you want.
In addition, you can access fields using the .-style accessor syntax:

  show_help() if options.help


== Examples

Kicking the tires:

  $ cat myscript1.rb
  require 'getoptions'

  opt = GetOptions.new(%w(help debug! verbose+ prefix:s size=i host=@s)) 
  p opt

  $ ./myscript1.rb --help 
  help: true  

  $ ./myscript1.rb --debug   
  debug: true

  $ ./myscript1.rb --no-debug
  debug: false

  $ ./myscript1.rb -vvvvv    
  verbose: 5

  $ ./myscript1.rb -vv --verbose
  verbose: 3

  $ ./myscript1.rb --pre        
  prefix: nil

  $ ./myscript1.rb --pre myprefix
  prefix: "myprefix"

  $ ./myscript1.rb --size 5      
  size: 5


Mixing arguments with non-arguments:

  $ cat myscript2.rb
  require 'getoptions'

  opt = GetOptions.new(%w(help debug! verbose+ prefix:s size=i host=@s)) 
  p opt
  puts '--'
  p ARGV

  $ ./myscript2.rb --siz 10 file1 file2 file3
  size: 10
  --
  ["file1", "file2", "file3"]

  $ ./myscript2.rb --host host1 host2 -- file1 file2 file3
  host: ["host1", "host2"]
  --
  ["file1", "file2", "file3"]


Processing your own input stream:

  $ cat myscript3.rb
  require 'getoptions'

  input = %w(-vv -w 1 -2 -- file1)
  opt = GetOptions.new(%w(verbose+ weights:@i), input)
  p opt
  puts '--'
  p input

  $ ./myscript3.rb
  verbose: 2
  weights: [1, -2]
  --
  ["file1"]


