#!/usr/bin/env ruby

# Unit test for GetOptions

require File.join(File.dirname(__FILE__), '../lib/getoptions')
require 'spec'


describe GetOptions do

  # String tests
  it "should parse strings, short type name" do
    opt = GetOptions.new(%w(string=s), %w(--str test))
    opt.string.should eql('test')
  end
  it "should parse strings, long type name" do
    opt = GetOptions.new(%w(string=string), %w(--str test))
    opt.string.should eql('test')
  end

  # Integer tests
  it "should parse integers, short type name" do
    opt = GetOptions.new(%w(int=i), %w(--int 5))
    opt.int.should eql(5)
  end
  it "should parse integers, long type name" do
    opt = GetOptions.new(%w(int=integer), %w(--int 5))
    opt.int.should eql(5)
  end
  it "should throw an exception on non integers" do
    lambda {
      GetOptions.new(%w(int=i), %w(--int NaN))
    }.should raise_error(GetOptions::ParseError, /expecting integer value/)
  end

  # Float tests
  it "should parse floats, short type name" do
    opt = GetOptions.new(%w(float=f), %w(--float 0.5))
    opt.float.should eql(0.5)
  end
  it "should parse floats, long type name" do
    opt = GetOptions.new(%w(float=float), %w(--float 0.5))
    opt.float.should eql(0.5)
  end
  it "should throw an exception on non floats" do
    lambda {
      GetOptions.new(%w(float=f), %w(--float NaN))
    }.should raise_error(GetOptions::ParseError, /expecting float value/)
  end

  # Flag tests
  it "should parse flags set to true" do
    opt = GetOptions.new(%w(flag!), %w(--flag))
    opt.flag.should eql(true)
  end
  it "should parse flags set to false" do
    opt = GetOptions.new(%w(flag!), %w(--no-flag))
    opt.flag.should eql(false)
  end

  # Increment tests
  it "should treat absense of option as 0 count" do
    opt = GetOptions.new(%w(incr+), %w())
    opt.incr.should eql(0)
  end
  it "should count options, 1 count" do
    opt = GetOptions.new(%w(incr+), %w(-i))
    opt.incr.should eql(1)
  end
  it "should count options, 5 count" do
    opt = GetOptions.new(%w(incr+), %w(-iiiii))
    opt.incr.should eql(5)
  end

  # List tests
  it "should parse a list of strings" do
    opt = GetOptions.new(%w(list=@s), %w(--list foo bar --li baz -l qux))
    opt.list.should eql(%w(foo bar baz qux))
  end
  it "should parse a list of integers" do 
    opt = GetOptions.new(%w(list=@i), %w(--list 1 2 --li 3 -l 4))
    opt.list.should eql([1,2,3,4])
  end
  it "should parse a list of integers w/ negative numbers" do 
    opt = GetOptions.new(%w(list=@i), %w(--list 1 -2 --li 3 -l -4))
    opt.list.should eql([1,-2,3,-4])
  end
  it "should not parse a list of non-integers" do
    lambda {
      GetOptions.new(%w(list=@i), %w(--list 1 2 oops 3))
    }.should raise_error(GetOptions::ParseError, /expecting integer value/)
  end
  it "should parse a list of floats" do
    opt = GetOptions.new(%w(list=@f), %w(--list 0.1 0.2 --li 0.3 -l 0.4))
    opt.list.should eql([0.1,0.2,0.3,0.4])
  end
  it "should parse a list of floats w/ negative numbers" do
    opt = GetOptions.new(%w(list=@f), %w(--list 0.1 -0.2 --li -0.3 -l 0.4))
    opt.list.should eql([0.1,-0.2,-0.3,0.4])
  end
  it "should not parse a list of non-floats" do
    lambda {
      GetOptions.new(%w(list=@f), %w(--list 0.1 0.2 oops 0.3))
    }.should raise_error(GetOptions::ParseError, /expecting float value/)
  end

  # Each / Enumerable tests
  it "should be able to use .each to iterate over options" do
    opt = GetOptions.new(%w(foo bar baz qux), %w(--foo --bar --qux))
    a = []
    opt.each do |k,o|
      a << "#{k},#{o}"  
    end
    a.should(equ(%w(bar=true qux=true foo=true)))
  end

  it "should be able to use .collect to collect options matching certain criteria" do
    opt = GetOptions.new(%w(a+ b+ c+), %w(-aaa -bbbb -ccccc))
    a = opt.collect do |k,o|
      (k =~ /a|b/) ? o : 0
    end
    a.sort.should equ([0,3,4])
  end

  # Optional argument tests
  it "should parse an optional string argument" do
    opt = GetOptions.new(%w(string:s), %w(--str))
    opt.string.should eql(nil)
  end
  it "should parse an optional integer argument" do
    opt = GetOptions.new(%w(int:i), %w(--int))
    opt.int.should eql(nil)
  end
  it "should parse an optional float argument" do
    opt = GetOptions.new(%w(float:f), %w(--float))
    opt.float.should eql(nil)
  end
  it "should parse an optional list argument" do
    opt = GetOptions.new(%w(list:@s), %w(--list))
    opt.list.should eql([])
  end

  # has_option test
  it "should check option presence" do
    opt = GetOptions.new(%w(string:s), %w(--string))
    opt.has_option?(:string).should eql(true) 
  end
  it "should fail on invalid option presence" do
    opt = GetOptions.new(%w(string:s), %w(--string))
    opt.has_option?(:blah).should_not eql(true) 
  end
  it "should fail on `nil' key option check" do
    lambda {
      opt = GetOptions.new(%w(string:s), %w(--string))
      opt.has_option?(nil).should_not eql(true) 
    }.should raise_error(GetOptions::ParseError, /`nil' cannot be an option key/)
  end

  # input array tests
  it "should retain non-options in input list (no option)" do
    input = %w(--flag x1 x2 x3)
    opt = GetOptions.new(%w(flag), input)
    input.should eql(%w(x1 x2 x3))
  end
  it "should retain non-options in input list (required option)" do
    input = %w(--string test x1 x2 x3)
    opt = GetOptions.new(%w(string=s), input)
    input.should eql(%w(x1 x2 x3))
  end
  it "should retain non-options in input list (optional option)" do
    input = %w(--string x1 x2 x3)
    opt = GetOptions.new(%w(string:s), input)
    input.should eql(%w(x2 x3))
  end
  it "should stop options parsing on --" do
    input = %w(--list x1 x2 x3 -- x4 x5 x6)
    opt = GetOptions.new(%w(list=@s), input)
    input.should eql(%w(x4 x5 x6))
  end

  # Accessor tests
  it "should be accessed as a hash (string key)" do
    opt = GetOptions.new(%w(flag!), %w(--flag))
    opt['flag'].should eql(true)
  end
  it "should be accessed as a hash (symbol key)" do
    opt = GetOptions.new(%w(flag!), %w(--flag))
    opt[:flag].should eql(true)
  end
  it "should fail on nil key" do
    lambda {
      opt = GetOptions.new(%w(flag!), %w(--flag))
      opt[nil]
    }.should raise_error(GetOptions::ParseError, /`nil' cannot be an option key/)
  end
  it "should fail on unknown key (string key)" do
    lambda {
      opt = GetOptions.new(%w(flag!), %w(--flag))
      opt['notanoption']
    }.should raise_error(GetOptions::ParseError, /program tried to access/)
  end
  it "should fail on unknown key (symbol key)" do
    lambda {
      opt = GetOptions.new(%w(flag!), %w(--flag))
      opt[:notanoption]
    }.should raise_error(GetOptions::ParseError, /program tried to access/)
  end

  # shorthand tests
  it "shorthand test, multiple flags" do
    opt = GetOptions.new(%w(aflag bflag cflag), %w(-ac)) 
    opt.aflag.should eql(true) 
    opt.bflag.should eql(nil) 
    opt.cflag.should eql(true)
  end
  it "shorthand test, multiple arguments" do
    opt = GetOptions.new(%w(astr=s bstr=s cstr=s), %w(-abc x1 x2 x3)) 
    opt.astr.should eql('x1') 
    opt.bstr.should eql('x2') 
    opt.cstr.should eql('x3')
  end
  it "shorthand test, list interoperability" do
    opt = GetOptions.new(%w(aflag bflag cflag list=@s), %w(--list foo -bar -ac)) 
    opt.aflag.should eql(true) 
    opt.bflag.should eql(nil) 
    opt.cflag.should eql(true) 
    opt.list.should eql(%w(foo -bar)) 
  end
  it "shorthand test, list interoperability with invalid option" do
    lambda {
      GetOptions.new(%w(aflag bflag cflag list=@s), %w(--list foo -bar -ac -q)) 
    }.should raise_error(GetOptions::ParseError, "unknown option 'q'")
  end

  # last option tests
  it "last option wins (boolean), true at the end" do
    opt = GetOptions.new(%w(flag!), %w(--flag --no-flag -f)) 
    opt.flag.should eql(true)
  end
  it "last option wins (boolean), false at the end" do
    opt = GetOptions.new(%w(flag!), %w(--flag --no-flag)) 
    opt.flag.should eql(false)
  end
  it "last option wins (float)" do
    opt = GetOptions.new(%w(float=f), %w(--float 0.1 -f 0.2)) 
    opt.float.should eql(0.2)
  end
  it "last option wins (int)" do
    opt = GetOptions.new(%w(int=i), %w(--int 1 -i 2)) 
    opt.int.should eql(2)
  end
  it "last option wins (string)" do
    opt = GetOptions.new(%w(string=s), %w(-s x1 --string x2)) 
    opt.string.should eql('x2')
  end

  # misc make it break tests
  it "should throw an exception on invalid types" do
    lambda {
      GetOptions.new(%w(arg=bogus), %w(--arg val))
    }.should raise_error(GetOptions::ParseError, /unknown argument type/)
  end
  it "should throw an exception when supplying an option that doesn't exist" do
    lambda {
      GetOptions.new(%w(string=s), %w(--notanoption))
    }.should raise_error(GetOptions::ParseError, /unknown option/)
  end
  it "should throw an exception when fetching an option that doesn't exist" do
    lambda {
      opt = GetOptions.new(%w(string=s), %w(--string test))
      opt.notanoption
    }.should raise_error(GetOptions::ParseError, /program tried to access an unknown/)
  end

  # inspect test
  it "inspect method should return proper results" do
    opt = GetOptions.new(%w(flag string=s int:i verbose+ list=@s), 
        %w(--int 5 -vvv --list 1 2 3 --flag --string test))
    opt.to_s
  end

end
