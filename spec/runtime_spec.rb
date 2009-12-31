#!/usr/bin/env ruby

require 'stringio'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'
require 'protocol_buffers/compiler'

ProtocolBuffers::Compiler.compile_and_load(
  File.join(File.dirname(__FILE__), "proto_files", "simple.proto"))
ProtocolBuffers::Compiler.compile_and_load(
  File.join(File.dirname(__FILE__), "proto_files", "featureful.proto"))

describe ProtocolBuffers, "runtime" do

  it "can handle basic operations" do

    msg1 = Simple::Test1.new
    msg1.test_field.should == ""

    msg1.test_field = "zomgkittenz"

    ser = StringIO.new(msg1.to_s)
    msg2 = Simple::Test1.parse(ser)
    msg2.test_field.should == "zomgkittenz"
    msg2.should == msg1
  end

  it "doesn't serialize unset fields" do
    msg1 = Simple::Test1.new
    msg1.test_field.should == ""
    msg1.to_s.should == ""

    msg1.test_field = "zomgkittenz"
    msg1.to_s.should_not == ""
  end

  it "flags values that have been set" do
    a1 = Featureful::A.new
    a1.has_i2?.should == false
    a1.i2 = 5
    a1.has_i2?.should == true
  end

  it "flags sub-messages that have been set" do
    a1 = Featureful::A.new
    a1.value_for_tag?(a1.class.field_for_name(:sub1).tag).should == true
    a1.value_for_tag?(a1.class.field_for_name(:sub2).tag).should == false
    a1.value_for_tag?(a1.class.field_for_name(:sub3).tag).should == false

    a1.has_sub1?.should == true
    a1.has_sub2?.should == false
    a1.has_sub3?.should == false

    a1.sub2 = Featureful::A::Sub.new(:payload => "ohai")
    a1.has_sub2?.should == true
  end

  it "does type checking of repeated fields" do
    pending("do type checking of repeated fields") do
      a1 = Featureful::A.new
      proc do
        a1.sub1 << "dummy string"
      end.should raise_error(ProtocolBuffers::InvalidFieldValue)
    end
  end

  it "detects changes to a sub-message and flags it as set if it wasn't" do
    pending("figure out what to do about sub-message init") do
      # the other option is to start sub-messages as nil, and require explicit
      # instantiation of them. hmm which makes more sense?
      a1 = Featureful::A.new
      a1.has_sub2?.should == false
      a1.sub2.payload = "ohai"
      a1.has_sub2?.should == true
    end
  end

  it "shouldn't modify the default Message instance like this" do
    a1 = Featureful::A.new
    a1.sub2.payload = "ohai"
    a2 = Featureful::A.new
    a2.sub2.payload.should == ""
    sub = Featureful::A::Sub.new
    sub.payload.should == ""
  end

  it "doesn't allow defining fields after gen_methods is called" do
    proc do
      A.define_field(:optional, :string, "newfield", 15)
    end.should raise_error()
  end

  def filled_in_bit
    bit = Featureful::ABitOfEverything.new
    bit.double_field = 1.0
    bit.float_field = 2.0
    bit.int32_field = 3
    bit.int64_field = 4
    bit.uint32_field = 5
    bit.uint64_field = 6
    bit.sint32_field = 7
    bit.sint64_field = 8
    bit.fixed32_field = 9
    bit.fixed64_field = 10
    bit.sfixed32_field = 11
    bit.sfixed64_field = 12
    bit.bool_field = true
    bit.string_field = "14"
    bit.bytes_field = "15"
    bit
  end

  it "can serialize and de-serialize all basic field types" do
    bit = filled_in_bit

    bit2 = Featureful::ABitOfEverything.parse(bit.to_s)
    bit.should == bit2
    bit.fields.each do |tag, field|
      bit.value_for_tag(tag).should == bit2.value_for_tag(tag)
    end
  end

  it "does type checking" do
    bit = filled_in_bit

    proc do
      bit.fixed32_field = 1.0
    end.should raise_error(TypeError)

    proc do
      bit.double_field = 15
    end.should_not raise_error()
    bit2 = Featureful::ABitOfEverything.parse(bit.to_s)
    bit2.double_field.should == 15
    bit2.double_field.should == 15.0
    bit2.double_field.is_a?(Float).should == true

    proc do
      bit.bool_field = 1.0
    end.should raise_error(TypeError)

    proc do
      bit.string_field = 1.0
    end.should raise_error(TypeError)

    a1 = Featureful::A.new
    proc do
      a1.sub2 = "zomgkittenz"
    end.should raise_error(TypeError)
  end

  it "doesn't allow invalid enum values" do
    sub = Featureful::A::Sub.new

    proc do
      sub.payload_type.should == 0
      sub.payload_type = Featureful::A::Sub::Payloads::P2
      sub.payload_type.should == 1
    end.should_not raise_error()

    proc do
      sub.payload_type = 2
    end.should raise_error(ArgumentError)
  end

  it "enforces required fields on serialization" do
    ProtocolBuffers::Compiler.compile_and_load_string <<-EOS
      package tehUnknown;
      message MyResult {
        required string field_1 = 1;
        optional string field_2 = 2;
      }
    EOS

    res1 = TehUnknown::MyResult.new(:field_2 => 'b')

    proc { res1.to_s }.should raise_error(ProtocolBuffers::EncodeError)
  end

  it "enforces required fields on deserialization" do
    ProtocolBuffers::Compiler.compile_and_load_string <<-EOS
      package tehUnknown;
      message MyResult {
        optional string field_1 = 1;
        optional string field_2 = 2;
      }
    EOS

    res1 = TehUnknown::MyResult.new(:field_2 => 'b')
    buf = res1.to_s

    # now make field_1 required
    ProtocolBuffers::Compiler.compile_and_load_string <<-EOS
      package tehUnknown;
      message MyResult {
        required string field_1 = 1;
        optional string field_2 = 2;
      }
    EOS

    proc { TehUnknown::MyResult.parse(buf) }.should raise_error(ProtocolBuffers::DecodeError)
  end

  it "enforces valid values on deserialization" do
    ProtocolBuffers::Compiler.compile_and_load_string <<-EOS
      package tehUnknown;
      message MyResult {
        optional int32 field_1 = 1;
      }
    EOS

    res1 = TehUnknown::MyResult.new(:field_1 => 5)
    buf = res1.to_s

    ProtocolBuffers::Compiler.compile_and_load_string <<-EOS
      package tehUnknown;
      message MyResult {
        enum E { A = 1; }
        optional E field_1 = 1;
      }
    EOS

    proc { TehUnknown::MyResult.parse(buf) }.should raise_error(ProtocolBuffers::DecodeError)
  end

  it "ignores and passes on unknown fields" do
    ProtocolBuffers::Compiler.compile_and_load_string <<-EOS
      package tehUnknown;
      message MyResult {
        optional int32 field_1 = 1;
        optional int32 field_2 = 2;
        optional int32 field_3 = 3;
      }
    EOS

    res1 = TehUnknown::MyResult.new(:field_1 => 0xffff, :field_2 => 0xfffe,
                                   :field_3 => 0xfffd)
    serialized = res1.to_s

    # remove field_2 to pretend we never knew about it
    ProtocolBuffers::Compiler.compile_and_load_string <<-EOS
      package tehUnknown;
      message MyResult {
        optional int32 field_1 = 1;
        optional int32 field_3 = 3;
      }
    EOS

    res2 = nil
    proc do
      res2 = TehUnknown::MyResult.parse(serialized)
    end.should_not raise_error()

    res2.field_1.should == 0xffff
    res2.field_3.should == 0xfffd

    proc do
      res2.field_2.should == 0xfffe
    end.should raise_error(NoMethodError)

    serialized2 = res2.to_s

    # now we know about field_2 again
    ProtocolBuffers::Compiler.compile_and_load_string <<-EOS
      package tehUnknown;
      message MyResult {
        optional int32 field_1 = 1;
        optional int32 field_2 = 2;
      }
    EOS

    res3 = TehUnknown::MyResult.parse(serialized2)
    res3.field_1.should == 0xffff
    pending("pass on unknown fields") do
      res3.field_2.should == 0xfffe
    end
  end

end
